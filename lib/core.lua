-- lib/core.lua
-- parameter definitions, state, poll handling, attractor plot buffer

local Core = {}

-- pages
Core.page       = 1
Core.NUM_PAGES  = 6
Core.PAGE_NAMES = {"OSC", "RUNGLER", "GATE", "FILTER", "FX", "SPACE"}
Core.alt_mode     = false
Core.show_plot    = false   -- K1 held = attractor overlay

-- poll data
Core.rung_cv     = 0
Core.gate_state  = 0
Core.prev_rung   = 0

-- attractor plot buffer (return map: x=rung(t), y=rung(t-1))
Core.PLOT_SIZE = 200
Core.plot = {}
for i = 1, 200 do Core.plot[i] = {x = 0, y = 0} end
Core.plot_idx = 1

-- gate step history (visual step sequencer)
Core.GATE_HIST_SIZE = 32
Core.gate_hist = {}
for i = 1, 32 do Core.gate_hist[i] = 0 end
Core.gate_hist_idx = 1
Core.prev_gate_state = 0

-- animation
Core.anim = {
  t = 0,
  rungler = {0,0,0,0,0,0,0,0},
  osc_b_val = 0,
}

--------------------------------------------------------------
-- PARAMS
--------------------------------------------------------------
function Core.init_params()
  params:add_separator("rungler_header", "r u n g l e r")

  -- oscillators
  params:add_separator("osc_header", "oscillators")
  params:add_control("freq_a", "osc a freq",
    controlspec.new(0.1, 12000, 'exp', 0, 80, 'Hz'))
  params:set_action("freq_a", function(v) engine.freq_a(v) end)

  params:add_control("freq_b", "osc b freq",
    controlspec.new(0.1, 12000, 'exp', 0, 3, 'Hz'))
  params:set_action("freq_b", function(v) engine.freq_b(v) end)

  params:add_control("xmod_a", "rung > osc a",
    controlspec.new(0, 2, 'lin', 0, 0, ''))
  params:set_action("xmod_a", function(v) engine.xmod_a(v) end)

  params:add_control("xmod_b", "rung > osc b",
    controlspec.new(0, 2, 'lin', 0, 0, ''))
  params:set_action("xmod_b", function(v) engine.xmod_b(v) end)

  -- rungler
  params:add_separator("rung_header", "rungler")
  params:add_control("chaos", "chaos",
    controlspec.new(0, 1, 'lin', 0, 0.5, ''))
  params:set_action("chaos", function(v) engine.chaos(v) end)

  params:add_number("loop_len", "register length", 3, 8, 8)
  params:set_action("loop_len", function(v) engine.loop_len(v) end)

  params:add_control("xmod_filt", "rung > filter",
    controlspec.new(0, 2, 'lin', 0, 0, ''))
  params:set_action("xmod_filt", function(v) engine.xmod_filt(v) end)

  params:add_option("output_mode", "output",
    {"filter", "osc a", "osc b", "xor", "pwm", "rungler"}, 1)
  params:set_action("output_mode", function(v) engine.output_mode(v - 1) end)

  -- gate
  params:add_separator("gate_header", "gate sequencer")
  params:add_option("gate_mode", "gate mode", {"free", "gated"}, 1)
  params:set_action("gate_mode", function(v) engine.gate_mode(v - 1) end)

  params:add_control("gate_thresh", "threshold",
    controlspec.new(0, 0.95, 'lin', 0, 0.3, ''))
  params:set_action("gate_thresh", function(v) engine.gate_thresh(v) end)

  params:add_control("gate_attack", "attack",
    controlspec.new(0.001, 0.5, 'exp', 0, 0.005, 's'))
  params:set_action("gate_attack", function(v) engine.gate_attack(v) end)

  params:add_control("gate_release", "release",
    controlspec.new(0.01, 4.0, 'exp', 0, 0.3, 's'))
  params:set_action("gate_release", function(v) engine.gate_release(v) end)

  -- filter
  params:add_separator("filt_header", "filter")
  params:add_control("filter_freq", "cutoff",
    controlspec.new(20, 20000, 'exp', 0, 1200, 'Hz'))
  params:set_action("filter_freq", function(v) engine.filter_freq(v) end)

  params:add_control("filter_res", "resonance",
    controlspec.new(0.05, 2.0, 'lin', 0, 0.5, ''))
  params:set_action("filter_res", function(v) engine.filter_res(v) end)

  params:add_option("filter_type", "type",
    {"lowpass", "bandpass", "highpass", "twin peak"}, 1)
  params:set_action("filter_type", function(v) engine.filter_type(v - 1) end)

  params:add_control("peak_spread", "peak spread",
    controlspec.new(1.05, 4.0, 'exp', 0, 1.5, 'x'))
  params:set_action("peak_spread", function(v) engine.peak_spread(v) end)

  -- fx
  params:add_separator("fx_header", "circuit bend")
  params:add_control("fold_amt", "wavefold",
    controlspec.new(0, 1, 'lin', 0, 0, ''))
  params:set_action("fold_amt", function(v) engine.fold_amt(v) end)

  params:add_control("crush_bits", "bit crush",
    controlspec.new(2, 24, 'lin', 1, 24, 'bits'))
  params:set_action("crush_bits", function(v) engine.crush_bits(math.floor(v)) end)

  params:add_control("crush_rate", "sample rate",
    controlspec.new(500, 48000, 'exp', 0, 48000, 'Hz'))
  params:set_action("crush_rate", function(v) engine.crush_rate(v) end)

  params:add_control("delay_time", "delay time",
    controlspec.new(0, 2, 'lin', 0, 0, 's'))
  params:set_action("delay_time", function(v) engine.delay_time(v) end)

  params:add_control("delay_fb", "delay feedback",
    controlspec.new(0, 0.95, 'lin', 0, 0, ''))
  params:set_action("delay_fb", function(v) engine.delay_fb(v) end)

  -- space
  params:add_separator("space_header", "stereo / space")
  params:add_option("pan_mode", "pan mode",
    {"manual", "rungler", "random", "lfo"}, 1)
  params:set_action("pan_mode", function(v) engine.pan_mode(v - 1) end)

  params:add_control("pan", "pan position",
    controlspec.new(-1, 1, 'lin', 0, 0, ''))
  params:set_action("pan", function(v) engine.pan(v) end)

  params:add_control("pan_depth", "auto-pan depth",
    controlspec.new(0, 1, 'lin', 0, 0.5, ''))
  params:set_action("pan_depth", function(v) engine.pan_depth(v) end)

  params:add_control("stereo_width", "stereo width",
    controlspec.new(0, 1, 'lin', 0, 0, ''))
  params:set_action("stereo_width", function(v) engine.stereo_width(v) end)

  -- master
  params:add_separator("master_header", "master")
  params:add_control("amp", "volume",
    controlspec.new(0, 1, 'lin', 0, 0.5, ''))
  params:set_action("amp", function(v) engine.amp(v) end)
end

--------------------------------------------------------------
-- PAGE PARAM MAPPING
--------------------------------------------------------------
Core.page_params = {
  [1] = {"freq_a",      "freq_b"},
  [2] = {"chaos",       "xmod_filt"},
  [3] = {"gate_thresh", "gate_release"},
  [4] = {"filter_freq", "filter_res"},
  [5] = {"fold_amt",    "delay_time"},
  [6] = {"pan_depth",   "stereo_width"},
}

Core.page_params_alt = {
  [1] = {"xmod_a",      "xmod_b"},
  [2] = {"loop_len",    "output_mode"},
  [3] = {"gate_attack", "gate_mode"},
  [4] = {"filter_type", "peak_spread"},
  [5] = {"crush_bits",  "delay_fb"},
  [6] = {"pan_mode",    "amp"},
}

function Core.get_active_params()
  if Core.alt_mode then
    return Core.page_params_alt[Core.page]
  else
    return Core.page_params[Core.page]
  end
end

--------------------------------------------------------------
-- POLL CALLBACKS
--------------------------------------------------------------
function Core.on_rung_cv(val)
  Core.prev_rung = Core.rung_cv
  Core.rung_cv = val
  -- add point to attractor return map
  Core.plot[Core.plot_idx] = {x = val, y = Core.prev_rung}
  Core.plot_idx = (Core.plot_idx % Core.PLOT_SIZE) + 1
end

function Core.on_gate_state(val)
  -- detect rising edge for gate history
  if val > 0.1 and Core.prev_gate_state <= 0.1 then
    Core.gate_hist[Core.gate_hist_idx] = 1
    Core.gate_hist_idx = (Core.gate_hist_idx % Core.GATE_HIST_SIZE) + 1
  end
  Core.prev_gate_state = val
  Core.gate_state = val
end

--------------------------------------------------------------
-- ANIMATION
--------------------------------------------------------------
function Core.update_anim()
  Core.anim.t = Core.anim.t + 1
  local c   = params:get("chaos")
  local f_a = params:get("freq_a")
  local f_b = params:get("freq_b")
  local t   = Core.anim.t

  -- pseudo shift register visual
  local clock_phase = (t * f_b * 0.01) % 1
  if clock_phase < 0.05 then
    for i = 8, 2, -1 do
      Core.anim.rungler[i] = Core.anim.rungler[i-1]
    end
    local data_bit = math.sin(t * f_a * 0.1) > 0 and 1 or 0
    local last_bit = Core.anim.rungler[8]
    if c > 0.5 then
      Core.anim.rungler[1] = (data_bit ~= last_bit) and 1 or 0
    else
      Core.anim.rungler[1] = data_bit
    end

    -- record gate miss (if below threshold) for visual history
    local thresh = params:get("gate_thresh")
    local dac = 0
    local ll = params:get("loop_len")
    for i = 1, 3 do
      local idx = math.max(1, ll - 3 + i)
      if idx >= 1 and idx <= 8 then
        dac = dac + Core.anim.rungler[idx] * (2 ^ (i - 1))
      end
    end
    local rung_abs = math.abs((dac / 1.75) * 2 - 1)
    if rung_abs <= thresh and params:get("gate_mode") == 2 then
      Core.gate_hist[Core.gate_hist_idx] = 0
      Core.gate_hist_idx = (Core.gate_hist_idx % Core.GATE_HIST_SIZE) + 1
    end
  end

  Core.anim.osc_b_val = math.sin(t * f_b * 0.02)
end

return Core
