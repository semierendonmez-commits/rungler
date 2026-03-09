-- rungler.lua
-- ─────────────────────────────────────────────────────
-- a circuit-bent chaotic synth voice for norns
-- inspired by Rob Hordijk's Benjolin & Blippoo Box
--
-- v2: + gate sequencer (rungler-driven rhythm)
--     + twin peak filter (dual BPF resonator)
--     + 4 stereo pan modes (manual/rungler/random/lfo)
--     + stereo width (Haas effect)
--     + attractor plot (K1 held)
--
-- E1: page select (6 pages)
-- E2: left parameter
-- E3: right parameter
-- K1 held: attractor plot
-- K2: alt mode (secondary params)
-- K3: randomize current page
-- K1+K3: reset all
--
-- v2.0.0 @semi
-- https://llllllll.co/t/rungler
-- ─────────────────────────────────────────────────────

engine.name = "Rungler"

local Core = include("rungler/lib/core")
local UI   = include("rungler/lib/ui")

local redraw_clock = nil
local rung_poll    = nil
local gate_poll    = nil

--------------------------------------------------------------
-- INIT
--------------------------------------------------------------
function init()
  Core.init_params()
  UI.init(Core)

  -- start polls
  rung_poll = poll.set("rung_cv")
  rung_poll.time = 1/15
  rung_poll.callback = function(val) Core.on_rung_cv(val) end
  rung_poll:start()

  gate_poll = poll.set("gate_state")
  gate_poll.time = 1/15
  gate_poll.callback = function(val) Core.on_gate_state(val) end
  gate_poll:start()

  -- redraw at 15fps
  redraw_clock = clock.run(function()
    while true do
      clock.sleep(1/15)
      Core.update_anim()
      redraw()
    end
  end)

  params:bang()
end

--------------------------------------------------------------
-- ENCODERS
--------------------------------------------------------------
function enc(n, d)
  if n == 1 then
    Core.page = util.clamp(Core.page + d, 1, Core.NUM_PAGES)
  else
    local active = Core.get_active_params()
    local param_id = active[n - 1]
    if param_id then
      params:delta(param_id, d)
    end
  end
end

--------------------------------------------------------------
-- KEYS
--------------------------------------------------------------
local k1_held = false

function key(n, z)
  if n == 1 then
    k1_held = (z == 1)
    Core.show_plot = (z == 1)
  elseif n == 2 then
    if z == 1 then
      Core.alt_mode = not Core.alt_mode
    end
  elseif n == 3 then
    if z == 1 then
      if k1_held then
        reset_all()
      else
        randomize_page()
      end
    end
  end
end

--------------------------------------------------------------
-- RANDOMIZE
--------------------------------------------------------------
function randomize_page()
  local primary = Core.page_params[Core.page]
  local alt     = Core.page_params_alt[Core.page]
  local all_p = {primary[1], primary[2], alt[1], alt[2]}

  for _, pid in ipairs(all_p) do
    if pid then
      local p = params:lookup_param(pid)
      if p then
        if p.t == 1 then
          -- number
          params:set(pid, math.floor(p.min + math.random() * (p.max - p.min)))
        elseif p.t == 2 then
          -- option
          params:set(pid, math.random(1, p.count))
        elseif p.t == 3 then
          -- control: use set_raw for proper warp handling
          params:set_raw(pid, math.random())
        end
      end
    end
  end
end

--------------------------------------------------------------
-- RESET
--------------------------------------------------------------
function reset_all()
  local defaults = {
    freq_a = 80, freq_b = 3, xmod_a = 0, xmod_b = 0,
    chaos = 0.5, loop_len = 8, xmod_filt = 0, output_mode = 1,
    gate_mode = 1, gate_thresh = 0.3, gate_attack = 0.005, gate_release = 0.3,
    filter_freq = 1200, filter_res = 0.5, filter_type = 1, peak_spread = 1.5,
    fold_amt = 0, crush_bits = 24, crush_rate = 48000,
    delay_time = 0, delay_fb = 0,
    pan = 0, pan_mode = 1, pan_depth = 0.5, stereo_width = 0,
    amp = 0.5,
  }
  for k, v in pairs(defaults) do
    params:set(k, v)
  end
end

--------------------------------------------------------------
-- REDRAW
--------------------------------------------------------------
function redraw()
  UI.draw()
end

--------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------
function cleanup()
  if redraw_clock then clock.cancel(redraw_clock) end
  if rung_poll then rung_poll:stop() end
  if gate_poll then gate_poll:stop() end
end
