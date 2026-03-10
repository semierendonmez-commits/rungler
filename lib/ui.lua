-- lib/ui.lua
-- screen drawing for rungler v2
-- 6 pages + attractor plot overlay (K1 held)
-- 128x64 OLED, lines aesthetic

local UI = {}
local Core

local W = 128
local H = 64
local HEADER_Y  = 8
local CONTENT_Y = 14
local PARAM_Y1  = 50
local PARAM_Y2  = 58

function UI.init(core_ref)
  Core = core_ref
end

--------------------------------------------------------------
function UI.draw()
  screen.clear()
  if Core.show_plot then
    UI.draw_attractor()
  else
    UI.draw_header()
    local draw_fn = {
      UI.draw_osc,
      UI.draw_rungler,
      UI.draw_gate,
      UI.draw_filter,
      UI.draw_fx,
      UI.draw_space,
    }
    if draw_fn[Core.page] then draw_fn[Core.page]() end
    UI.draw_footer()
  end
  screen.update()
end

--------------------------------------------------------------
-- HEADER
--------------------------------------------------------------
function UI.draw_header()
  for i = 1, Core.NUM_PAGES do
    local x = 2 + (i - 1) * 8
    if i == Core.page then
      screen.level(15)
      screen.rect(x, 1, 5, 5)
      screen.fill()
    else
      screen.level(3)
      screen.rect(x, 1, 5, 5)
      screen.stroke()
    end
  end
  screen.level(12)
  screen.font_face(1)
  screen.font_size(8)
  screen.move(54, HEADER_Y)
  screen.text(Core.PAGE_NAMES[Core.page])
  -- gate indicator
  if params:get("gate_mode") == 2 then
    screen.level(Core.gate_state > 0.1 and 15 or 4)
    screen.move(W - 20, HEADER_Y)
    screen.text("gate")
  end
  if Core.alt_mode then
    screen.level(8)
    screen.move(W - 8, HEADER_Y)
    screen.text("*")
  end
  screen.level(2)
  screen.move(0, HEADER_Y + 2)
  screen.line(W, HEADER_Y + 2)
  screen.stroke()
end

--------------------------------------------------------------
-- PAGE 1: OSC
--------------------------------------------------------------
function UI.draw_osc()
  local t = Core.anim.t
  local f_a = params:get("freq_a")
  local f_b = params:get("freq_b")
  local xmod_a = params:get("xmod_a")
  local xmod_b = params:get("xmod_b")
  local cy, amp = 30, 12

  -- osc A (left half)
  screen.level(10)
  for i = 1, 58 do
    local x = i + 2
    local ph = (t * 0.02 + i * 0.08) * (f_a / 80)
    local tri_ph = (ph % (2 * math.pi)) / (2 * math.pi)
    local v = tri_ph < 0.5 and (tri_ph * 4 - 1) or (3 - tri_ph * 4)
    v = v * (1 + xmod_a * 0.3 * math.sin(t * 0.005 + i * 0.2))
    local y = cy + v * amp
    if i > 1 then screen.line(x, y) else screen.move(x, y) end
  end
  screen.stroke()

  -- osc B (right half)
  screen.level(6)
  for i = 1, 58 do
    local x = i + 66
    local ph = (t * 0.02 + i * 0.08) * (f_b / 3)
    local tri_ph = (ph % (2 * math.pi)) / (2 * math.pi)
    local v = tri_ph < 0.5 and (tri_ph * 4 - 1) or (3 - tri_ph * 4)
    v = v * (1 + xmod_b * 0.3 * math.sin(t * 0.003 + i * 0.15))
    local y = cy + v * amp
    if i > 1 then screen.line(x, y) else screen.move(x, y) end
  end
  screen.stroke()

  -- cross-mod X
  if xmod_a > 0.01 or xmod_b > 0.01 then
    local lv = math.min(15, math.floor(3 + (xmod_a + xmod_b) * 4))
    screen.level(lv)
    screen.move(62, cy - 2); screen.line(66, cy + 2); screen.stroke()
    screen.move(66, cy - 2); screen.line(62, cy + 2); screen.stroke()
  end
  screen.level(4); screen.font_size(8)
  screen.move(2, CONTENT_Y); screen.text("A")
  screen.move(68, CONTENT_Y); screen.text("B")
end

--------------------------------------------------------------
-- PAGE 2: RUNGLER
--------------------------------------------------------------
function UI.draw_rungler()
  local reg = Core.anim.rungler
  local chaos = params:get("chaos")
  local loop_len = params:get("loop_len")
  local box_w, box_h, gap = 12, 10, 2
  local sx = math.floor((W - (8 * box_w + 7 * gap)) / 2)
  local ry = 16

  for i = 1, 8 do
    local x = sx + (i - 1) * (box_w + gap)
    if i <= loop_len then
      if reg[i] == 1 then
        screen.level(15); screen.rect(x, ry, box_w, box_h); screen.fill()
      else
        screen.level(8); screen.rect(x, ry, box_w, box_h); screen.stroke()
      end
    else
      screen.level(2); screen.rect(x, ry, box_w, box_h); screen.stroke()
    end
  end

  -- flow arrows
  screen.level(4)
  for i = 1, 7 do
    local x = sx + i * (box_w + gap) - gap
    screen.move(x, ry + box_h / 2); screen.line(x + gap, ry + box_h / 2); screen.stroke()
  end

  -- feedback loop
  screen.level(math.floor(4 + chaos * 8))
  local lx = sx + 7 * (box_w + gap) + box_w
  screen.move(lx, ry + box_h); screen.line(lx, ry + box_h + 5)
  screen.line(sx, ry + box_h + 5); screen.line(sx, ry + box_h); screen.stroke()
  screen.level(chaos > 0.5 and 12 or 5)
  screen.font_size(8)
  screen.move(W / 2 - 6, ry + box_h + 4)
  screen.text(chaos > 0.5 and "xor" or "loop")

  -- rungler CV bar (bipolar)
  local cv = Core.rung_cv
  screen.level(8)
  local bar_y, bar_cx = 38, W / 2
  local bar_len = math.floor(math.abs(cv) * (W / 2 - 4))
  if cv >= 0 then
    screen.rect(bar_cx, bar_y, bar_len, 3); screen.fill()
  else
    screen.rect(bar_cx - bar_len, bar_y, bar_len, 3); screen.fill()
  end
  screen.level(4)
  screen.move(bar_cx, bar_y - 1); screen.line(bar_cx, bar_y + 4); screen.stroke()
end

--------------------------------------------------------------
-- PAGE 3: GATE
--------------------------------------------------------------
function UI.draw_gate()
  local mode   = params:get("gate_mode")
  local thresh = params:get("gate_thresh")

  -- step pattern (last 32 triggers)
  local sw, sh, sg = 3, 10, 1
  local sx = math.floor((W - (32 * (sw + sg))) / 2)
  local sy = 16

  for i = 1, Core.GATE_HIST_SIZE do
    local idx = ((Core.gate_hist_idx - 1 + i - 1) % Core.GATE_HIST_SIZE) + 1
    local val = Core.gate_hist[idx]
    local x = sx + (i - 1) * (sw + sg)
    if val == 1 then
      screen.level(12); screen.rect(x, sy, sw, sh); screen.fill()
    else
      screen.level(3); screen.rect(x, sy, sw, sh); screen.stroke()
    end
  end

  -- gate indicator
  if mode == 2 then
    local gb = math.max(1, math.floor(Core.gate_state * 15))
    screen.level(gb); screen.circle(W / 2, 36, 4); screen.fill()
    -- threshold line
    screen.level(6)
    screen.move(4, 42); screen.line(W - 4, 42); screen.stroke()
    local tx = math.floor(4 + thresh * (W - 8))
    screen.level(12)
    screen.move(tx, 40); screen.line(tx, 44); screen.stroke()
  else
    screen.level(4); screen.font_size(8)
    screen.move(W / 2 - 8, 36); screen.text("free")
  end
end

--------------------------------------------------------------
-- PAGE 4: FILTER
--------------------------------------------------------------
function UI.draw_filter()
  local freq   = params:get("filter_freq")
  local res    = params:get("filter_res")
  local ftype  = params:get("filter_type")
  local spread = params:get("peak_spread")
  local t = Core.anim.t

  local base_y, curve_h = 40, 22
  local type_names = {"LP", "BP", "HP", "TW"}
  local freq_x = math.floor(util.linlin(
    math.log(20), math.log(20000), 4, W - 4, math.log(freq)))

  screen.level(2)
  screen.move(4, base_y); screen.line(W - 4, base_y); screen.stroke()

  screen.level(10)
  for i = 0, W - 8 do
    local x = i + 4
    local f_log = util.linlin(0, W - 8, math.log(20), math.log(20000), i)
    local f = math.exp(f_log)
    local dist = math.abs(f_log - math.log(freq))
    local resp = 0

    if ftype == 1 then -- LP
      resp = 1 / (1 + (dist * 3) ^ 2)
      if f > freq then resp = resp * math.max(0, 1 - (f - freq) / freq) end
    elseif ftype == 2 then -- BP
      resp = math.exp(-(dist ^ 2) * 4)
    elseif ftype == 3 then -- HP
      resp = 1 / (1 + (dist * 3) ^ 2)
      if f < freq then resp = resp * math.max(0, 1 - (freq - f) / freq) end
    elseif ftype == 4 then -- Twin Peak
      local f1, f2 = freq / spread, freq * spread
      local d1 = math.abs(f_log - math.log(math.max(20, f1)))
      local d2 = math.abs(f_log - math.log(math.min(20000, f2)))
      resp = math.exp(-(d1 ^ 2) * 4) + math.exp(-(d2 ^ 2) * 4)
      resp = resp * 0.7
    end

    resp = math.min(resp + res * 1.2 * math.exp(-(dist ^ 2) * 8), 1.5)
    local y = base_y - resp * curve_h + math.sin(t * 0.03 + i * 0.1) * 0.4
    if i > 0 then screen.line(x, y) else screen.move(x, y) end
  end
  screen.stroke()

  -- cutoff marker
  screen.level(15)
  screen.move(freq_x, base_y - curve_h - 2)
  screen.line(freq_x, base_y + 2); screen.stroke()

  -- twin peak markers
  if ftype == 4 then
    screen.level(8)
    local f1x = math.floor(util.linlin(
      math.log(20), math.log(20000), 4, W - 4,
      math.log(math.max(20, freq / spread))))
    local f2x = math.floor(util.linlin(
      math.log(20), math.log(20000), 4, W - 4,
      math.log(math.min(20000, freq * spread))))
    screen.move(f1x, base_y - 4); screen.line(f1x, base_y + 2); screen.stroke()
    screen.move(f2x, base_y - 4); screen.line(f2x, base_y + 2); screen.stroke()
  end

  screen.level(8); screen.font_size(8)
  local fs = freq >= 1000 and string.format("%.1fk", freq / 1000)
    or string.format("%.0f", freq)
  screen.move(freq_x + 2, CONTENT_Y + 2); screen.text(fs)
  screen.level(12)
  screen.move(W - 14, CONTENT_Y + 2); screen.text(type_names[ftype])
end

--------------------------------------------------------------
-- PAGE 5: FX
--------------------------------------------------------------
function UI.draw_fx()
  local fold = params:get("fold_amt")
  local bits = params:get("crush_bits")
  local dt   = params:get("delay_time")
  local dfb  = params:get("delay_fb")
  local t = Core.anim.t

  -- wavefolder (left)
  screen.level(math.min(15, math.floor(4 + fold * 10)))
  for i = 0, 55 do
    local ph = (i / 55) * 2 * math.pi + t * 0.02
    local val = math.sin(ph) * (1 + fold * 8)
    for _ = 1, 4 do
      if val > 1 then val = 2 - val
      elseif val < -1 then val = -2 - val
      else break end
    end
    local y = 30 - val * 14
    if i > 0 then screen.line(4 + i, y) else screen.move(4, y) end
  end
  screen.stroke()
  screen.level(4); screen.font_size(8)
  screen.move(4, CONTENT_Y); screen.text("fold")

  -- bit crusher (right)
  local steps = math.floor(2 ^ math.min(bits, 8))
  screen.level(7)
  for i = 0, 54 do
    local ph = (i / 54) * 2 * math.pi + t * 0.02
    local val = math.sin(ph)
    if bits < 23 then val = math.floor(val * steps + 0.5) / steps end
    local y = 30 - val * 14
    if i > 0 then screen.line(70 + i, y) else screen.move(70, y) end
  end
  screen.stroke()
  screen.level(4)
  screen.move(70, CONTENT_Y); screen.text(string.format("%db", math.floor(bits)))

  -- delay echoes
  if dt > 0.001 then
    local ne = math.floor(3 + dfb * 4)
    for i = 1, ne do
      local dx = 10 + i * 20
      local br = math.max(1, math.floor(12 - i * (10 / ne) * (1 - dfb)))
      screen.level(br); screen.circle(dx, 48, 2); screen.fill()
    end
  end
end

--------------------------------------------------------------
-- PAGE 6: SPACE
--------------------------------------------------------------
function UI.draw_space()
  local mode  = params:get("pan_mode")
  local depth = params:get("pan_depth")
  local width = params:get("stereo_width")
  local cy = 30
  local mode_names = {"manual", "rungler", "random", "lfo"}

  -- speakers
  screen.level(6)
  screen.rect(4, cy - 8, 6, 16); screen.stroke()
  screen.rect(W - 10, cy - 8, 6, 16); screen.stroke()
  screen.level(3); screen.font_size(8)
  screen.move(5, cy + 14); screen.text("L")
  screen.move(W - 9, cy + 14); screen.text("R")

  -- compute approximate pan position for visualization
  local pan_pos = 0
  if mode == 1 then
    pan_pos = params:get("pan")
  elseif mode == 2 then
    pan_pos = Core.rung_cv * depth
  elseif mode == 3 then
    pan_pos = Core.rung_cv * depth * 0.7
  elseif mode == 4 then
    pan_pos = Core.anim.osc_b_val * depth
  end
  pan_pos = math.max(-1, math.min(1, pan_pos))

  -- pan dot
  local dot_x = math.floor(util.linlin(-1, 1, 16, W - 16, pan_pos))
  screen.level(15); screen.circle(dot_x, cy, 3); screen.fill()

  -- trail dots from recent history
  for i = 1, math.min(20, Core.PLOT_SIZE) do
    local idx = ((Core.plot_idx - 1 - i) % Core.PLOT_SIZE) + 1
    local px = math.max(-1, math.min(1, Core.plot[idx].x * depth))
    local dx = math.floor(util.linlin(-1, 1, 16, W - 16, px))
    screen.level(math.max(1, math.floor(8 - i * 0.4)))
    screen.pixel(dx, cy); screen.fill()
  end

  -- width brackets
  if width > 0.01 then
    local wp = math.floor(width * 40)
    screen.level(math.floor(4 + width * 8))
    screen.move(W/2 - wp, cy - 10); screen.line(W/2 - wp - 3, cy - 10)
    screen.line(W/2 - wp - 3, cy + 10); screen.line(W/2 - wp, cy + 10); screen.stroke()
    screen.move(W/2 + wp, cy - 10); screen.line(W/2 + wp + 3, cy - 10)
    screen.line(W/2 + wp + 3, cy + 10); screen.line(W/2 + wp, cy + 10); screen.stroke()
  end

  screen.level(8); screen.font_size(8)
  screen.move(W / 2 - 12, CONTENT_Y); screen.text(mode_names[mode])
end

--------------------------------------------------------------
-- ATTRACTOR PLOT (K1 held)
--------------------------------------------------------------
function UI.draw_attractor()
  screen.level(0); screen.rect(0, 0, W, H); screen.fill()

  -- axes
  screen.level(2)
  screen.move(W/2, 0); screen.line(W/2, H); screen.stroke()
  screen.move(0, H/2); screen.line(W, H/2); screen.stroke()

  -- plot return map: x=rung(t), y=rung(t-1)
  local newest = Core.plot_idx - 1
  if newest < 1 then newest = Core.PLOT_SIZE end

  for i = 1, Core.PLOT_SIZE do
    local idx = ((newest - i) % Core.PLOT_SIZE) + 1
    local pt = Core.plot[idx]
    local px = math.floor(util.linlin(-1, 1, 4, W - 4, pt.x))
    local py = math.floor(util.linlin(-1, 1, H - 4, 4, pt.y))
    local age = i / Core.PLOT_SIZE
    screen.level(math.max(1, math.floor(15 - age * 14)))
    screen.pixel(px, py); screen.fill()
  end

  -- current point crosshair
  local cur = Core.plot[newest]
  local cx = math.floor(util.linlin(-1, 1, 4, W - 4, cur.x))
  local cy = math.floor(util.linlin(-1, 1, H - 4, 4, cur.y))
  screen.level(15)
  screen.move(cx - 2, cy); screen.line(cx + 2, cy); screen.stroke()
  screen.move(cx, cy - 2); screen.line(cx, cy + 2); screen.stroke()

  screen.level(4); screen.font_size(8)
  screen.move(2, 8); screen.text("attractor")
  screen.move(2, H - 2); screen.text("rung(t)")
  screen.move(W - 32, 8); screen.text("rung(t-1)")
end

--------------------------------------------------------------
-- PARAM FOOTER
--------------------------------------------------------------
function UI.draw_footer()
  local active = Core.get_active_params()

  screen.level(2)
  screen.move(0, PARAM_Y1 - 4); screen.line(W, PARAM_Y1 - 4); screen.stroke()
  screen.font_size(8)

  -- E2 (left)
  screen.level(Core.alt_mode and 10 or 6)
  screen.move(2, PARAM_Y1)
  local p1 = params:lookup_param(active[1])
  screen.text("E2:" .. (p1 and p1.name or active[1]))
  screen.level(12); screen.move(2, PARAM_Y2)
  screen.text(params:string(active[1]))

  -- E3 (right)
  screen.level(Core.alt_mode and 10 or 6)
  screen.move(68, PARAM_Y1)
  local p2 = params:lookup_param(active[2])
  screen.text("E3:" .. (p2 and p2.name or active[2]))
  screen.level(12); screen.move(68, PARAM_Y2)
  screen.text(params:string(active[2]))
end

return UI
