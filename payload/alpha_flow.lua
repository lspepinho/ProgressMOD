local timer = (function()
local M = {}
M.id = "alpha-timer-v1"
M.TIME_LIMIT = 1200
M.LOGF = "mod_alpha_hud.log"
function M.fmt(s)
  s = tonumber(s) or 0
  if s ~= s then s = 0 end
  if s < 0 then s = 0 end
  s = math.floor(s)
  return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end
function M.new(limit, onLoss)
  limit = tonumber(limit) or M.TIME_LIMIT
  if limit <= 0 then limit = M.TIME_LIMIT end
  return { limit = limit, left = limit, moves = 0,
    over = false, paused = false, fired = false,
    lossFn = (type(onLoss) == "function") and onLoss or nil }
end
function M.reset(t, limit)
  if type(t) ~= "table" then return nil end
  if tonumber(limit) and tonumber(limit) > 0 then t.limit = tonumber(limit) end
  t.left, t.moves, t.over, t.fired = t.limit, 0, false, false
  t.paused = false
  return t
end
function M.setPaused(t, b)
  if type(t) == "table" then t.paused = not not b end
end
function M.setLoss(t, fn)
  if type(t) == "table" and type(fn) == "function" then t.lossFn = fn end
end
function M.note(t, ok)
  if type(t) ~= "table" then return 0 end
  if ok == true then t.moves = (t.moves or 0) + 1 end
  return t.moves or 0
end
function M.syncMoves(t)
  if type(t) ~= "table" then return 0 end
  local function adopt(v)
    if type(v) == "number" and v > (t.moves or 0) then t.moves = v end
  end
  pcall(function()
    local a = _G.__ALPHA
    if a then
      if type(a.moves) == "function" then adopt(a.moves()) else adopt(a.moves) end
    end
  end)
  pcall(function()
    local ts = _G.__ALPHA_TOUCH
    if ts and type(ts.moves) == "number" then adopt(ts.moves) end
  end)
  return t.moves or 0
end
function M.isGamePaused()
  local p = false
  pcall(function()
    if _G.__ALPHA_PAUSED ~= nil then p = not not _G.__ALPHA_PAUSED return end
    if type(onHoverTouch) == "function" and debug and debug.getupvalue then
      local _, g = debug.getupvalue(onHoverTouch, 1)
      if type(g) == "table" then
        if g.Stop == true then p = true return end
        if g.Paused == true then p = true return end
        if g.Pause == true then p = true return end
      end
    end
  end)
  return p
end
function M.fireLoss(t, reason)
  if type(t) ~= "table" or t.fired then return false end
  t.fired, t.over, t.left = true, true, 0
  local ran, how = false, "none"
  pcall(function()
    if type(t.lossFn) == "function" then t.lossFn(reason or "timeout") ran = true how = "lossFn" end
  end)
  if not ran then pcall(function()
    local L = _G.__ALPHA_LOSS
    local G = nil
    pcall(function()
      if type(onHoverTouch) == "function" and debug and debug.getupvalue then
        local _, g = debug.getupvalue(onHoverTouch, 1) G = g
      end
    end)
    if L then
      if type(L.finalize) == "function" then
        L.finalize(G, reason or "timeout") ran = true how = "G.finalize"
      else
        for _, k in ipairs({ "lose", "trigger", "defeat", "onTimeout" }) do
          if type(L[k]) == "function" then L[k](reason or "timeout") ran = true how = "G." .. k break end
        end
      end
    end
  end) end
  if not ran then pcall(function()
    local a = _G.__ALPHA
    if a and type(a.lose) == "function" then a.lose(reason or "timeout") ran = true how = "ALPHA.lose" end
  end) end
  if not ran then pcall(function()
    local ok, m = pcall(require, "mod_alpha_loss")
    if ok and m then
      if type(m.finalize) == "function" then
        local G = nil
        pcall(function()
          if type(onHoverTouch) == "function" and debug and debug.getupvalue then
            local _, g = debug.getupvalue(onHoverTouch, 1) G = g
          end
        end)
        m.finalize(G, reason or "timeout") ran = true how = "mod_loss.finalize"
      elseif type(m.lose) == "function" then
        m.lose(reason or "timeout") ran = true how = "mod_loss"
      end
    end
  end) end
  return ran
end
function M.tick(t, dt, pausedFlag)
  if type(t) ~= "table" or t.over then return t and t.left or 0 end
  if pausedFlag == nil then pausedFlag = t.paused end
  if pausedFlag then return t.left end
  dt = tonumber(dt) or 0
  if dt <= 0 then return t.left end
  t.left = (t.left or t.limit or M.TIME_LIMIT) - dt
  if t.left <= 0 then t.left = 0 M.fireLoss(t, "timeout") end
  return t.left
end
function M.update(t, dt, opts)
  if type(t) ~= "table" then return 0, 0, false end
  local ignore = type(opts) == "table" and opts.ignorePause
  local paused = t.paused
  if not ignore then
    local gp = M.isGamePaused()
    if gp then paused = true end
  end
  if type(opts) == "table" and opts.paused ~= nil then paused = not not opts.paused end
  M.tick(t, dt, paused)
  M.syncMoves(t)
  return t.left, t.moves, t.over
end
function M.left(t) return (type(t) == "table" and t.left) or 0 end
function M.text(t) return M.fmt(M.left(t)) end
function M.isOver(t) return type(t) == "table" and t.over == true end
function M.selftest()
  assert(M.fmt(110) == "01:50", "110s=01:50")
  assert(M.fmt(0) == "00:00" and M.fmt(-5) == "00:00", "clamp")
  assert(M.fmt(61.9) == "01:01", "floor")
  local t = M.new(110)
  assert(t.left == 110 and t.moves == 0, "starts zeroed")
  M.note(t, true) M.note(t, false) M.note(t, nil)
  assert(t.moves == 1, "only validtes sum")
  M.tick(t, 10) assert(t.left == 100, "runs")
  M.tick(t, 5, true) assert(t.left == 100, "pausa congela")
  local fired = {}
  local n = M.new(3, function(r) fired[#fired + 1] = r end)
  M.tick(n, 2) assert(not M.isOver(n), "no timeout before")
  M.tick(n, 1) assert(M.isOver(n) and n.left == 0, "timeout zera")
  assert(#fired == 1 and fired[1] == "timeout", "defeat 1x")
  M.tick(n, 5) assert(#fired == 1, "disparo unico")
  return "TIMER_OK fmt+valid-only+pause+timeout1x"
end
function M.simulate()
  local t = M.new(M.TIME_LIMIT)
  local lossRan = false
  M.setLoss(t, function() lossRan = true end)
  M.tick(t, 20)
  assert(t.left == 1180, "20s elapsed")
  M.note(t, true) M.note(t, true) M.note(t, false)
  assert(t.moves == 2, "2 valid")
  M.tick(t, 10, true)
  assert(t.left == 1180, "pausado junto")
  M.tick(t, 1180)
  assert(M.isOver(t) and lossRan, "timeout->defeat")
  return "SIM_OK t=1200 moves=2 pause_freeze timeout->LOSS fmt=" .. M.text(t)
end
  return M
end)()
package.loaded["mod_alpha_timer"] = timer
local touch = (function()
local M = {}
M.id = "alpha-touch-v1"
M.COLS = 5
M.ROWS = 5
M.N = 25
local FIN, GP = nil, nil
pcall(function()
  local ok, m = pcall(require, "mod_alpha_finish")
  if ok and m then FIN = m end
end)
pcall(function()
  local ok, m = pcall(require, "mod_alpha_gameplay")
  if ok and m then GP = m end
end)
local EMPTY = ""
if FIN and FIN.EMPTY ~= nil then EMPTY = FIN.EMPTY
elseif GP and GP.EMPTY ~= nil then EMPTY = GP.EMPTY end
M.EMPTY = EMPTY
local function isTab(t) return type(t) == "table" end
function M.idx(c, r) return (r - 1) * M.COLS + c end
function M.rc(i)
  return ((i - 1) % M.COLS) + 1, math.floor((i - 1) / M.COLS) + 1
end
function M.valid_cr(c, r)
  c, r = tonumber(c), tonumber(r)
  if not (c and r) then return false end
  return c >= 1 and c <= M.COLS and r >= 1 and r <= M.ROWS
end
function M.neighbors(i, n)
  n = tonumber(n) or M.N
  if n > 10 then
    local okR, R = pcall(require, "mod_alpha_rows")
    if okR and R and R.neighbors then
      local cols, rows = 5, math.max(2, math.min(5, math.ceil(n / 5)))
      local okN, nb = pcall(R.neighbors, i, cols, rows)
      if okN and isTab(nb) then return nb end
    end
  end
  if FIN and FIN.neighbors then
    local ok, nb = pcall(FIN.neighbors, i)
    if ok and isTab(nb) then return nb end
  end
  if GP and GP.neighbors then
    local ok, nb = pcall(GP.neighbors, i)
    if ok and isTab(nb) then return nb end
  end
  local c, r = M.rc(i)
  local out = {}
  if r > 1 then out[#out + 1] = M.idx(c, r - 1) end
  if r < M.ROWS then out[#out + 1] = M.idx(c, r + 1) end
  if c > 1 then out[#out + 1] = M.idx(c - 1, r) end
  if c < M.COLS then out[#out + 1] = M.idx(c + 1, r) end
  return out
end
function M.find_empty(shadow)
  if isTab(shadow) and #shadow == 10 then
    if FIN and FIN.find_empty then
      local ok, e = pcall(FIN.find_empty, shadow)
      if ok and e then return e end
    end
    if GP and GP.find_empty then
      local ok, e = pcall(GP.find_empty, shadow)
      if ok and e then return e end
    end
  end
  if isTab(shadow) then
    local n = #shadow
    if n < 1 then n = M.N end
    for i = 1, n do if shadow[i] == EMPTY then return i end end
  end
  return nil
end
function M.touch(shadow, i)
  i = tonumber(i)
  if not isTab(shadow) then return false end
  local n = #shadow
  if n < 1 then n = M.N end
  if not (i and i >= 1 and i <= n) then return false end
  local v = nil
  pcall(function() v = shadow[i] end)
  if v == EMPTY then return false end
  if n > 10 then
    local okR, R = pcall(require, "mod_alpha_rows")
    if okR and R and R.touch then
      local cols, rows = 5, math.max(2, math.min(5, math.ceil(n / 5)))
      local okT, res = pcall(R.touch, shadow, i, cols, rows)
      if okT then return res == true end
    end
    return false
  end
  if FIN and FIN.touch then
    local ok, res = pcall(FIN.touch, shadow, i)
    if ok then return res == true end
    return false
  end
  if GP and GP.touch then
    local ok, res = pcall(GP.touch, shadow, i)
    if ok then return res == true end
    return false
  end
  local e = M.find_empty(shadow)
  if not e then return false end
  for _, nb in ipairs(M.neighbors(i, n)) do
    if nb == e then shadow[e] = shadow[i] shadow[i] = EMPTY return true end
  end
  return false
end
function M.slide_cr(shadow, c, r)
  if not isTab(shadow) then return false, "bad" end
  if not M.valid_cr(c, r) then return false, "oob" end
  local i = M.idx(c, r)
  local n = #shadow
  if n >= 1 and i > n then return false, "oob" end
  local v = nil
  pcall(function() v = shadow[i] end)
  if v == EMPTY then return false, "empty" end
  if not M.find_empty(shadow) then return false, "no-empty" end
  if M.touch(shadow, i) then return true, "ok" end
  return false, "blocked"
end
local function fire(fb, kind, reason)
  pcall(function()
    if isTab(fb) then
      if kind == "ok" and type(fb.ok) == "function" then fb.ok()
      elseif kind ~= "ok" and type(fb.err) == "function" then
        fb.err(reason)
      end
    end
  end)
end
function M.make(shadow)
  local s = { shadow = shadow, moves = 0 }
  function s.tap(c, r, fb)
    local ok, reason = M.slide_cr(s.shadow, c, r)
    if ok then s.moves = s.moves + 1 end
    fire(fb, ok and "ok" or "err", reason)
    return ok, reason
  end
  function s.tap_i(i, fb)
    i = tonumber(i)
    local n = M.N
    pcall(function() if type(s.shadow) == "table" and #(s.shadow) >= 1 then n = #(s.shadow) end end)
    if not (i and i >= 1 and i <= n) then
      fire(fb, "err", "oob")
      return false, "oob"
    end
    local c, r = M.rc(i)
    return s.tap(c, r, fb)
  end
  function s.snap()
    local t = {}
    local n = M.N
    pcall(function() if type(s.shadow) == "table" and #(s.shadow) >= 1 then n = #(s.shadow) end end)
    for i = 1, n do
      local v = s.shadow[i]
      t[#t + 1] = (v == EMPTY or v == nil) and "_" or tostring(v)
    end
    return table.concat(t)
  end
  return s
end
function M.selftest()
  local b = { "A", "B", "C", "D", "E", "F", "G", "H", "I", EMPTY }
  assert(M.touch(b, 1) == false, "far does not move")
  assert(M.touch(b, 9) == true, "neighbor moves")
  assert(b[9] == EMPTY and b[10] == "I", "swap w/ empty")
  local s = M.make({ "A", "B", "C", "D", "E", "F", "G", "H", EMPTY, "I" })
  local errs, oks = 0, 0
  local fb = { ok = function() oks = oks + 1 end,
    err = function() errs = errs + 1 end }
  assert(s.tap(1, 1, fb) == false, "invalid does not move")
  assert(s.moves == 0 and errs == 1 and oks == 0, "no moves on invalid")
  assert(s.tap(5, 2, fb) == true, "valid moves")
  assert(s.moves == 1 and oks == 1, "moves++ so no valido")
  assert(s.tap(9, 9, fb) == false, "oob does not crash")
  assert(s.tap_i(0, fb) == false and s.tap_i(11, fb) == false, "i oob L1 (10)")
  for i = 1, 10 do
    local c, r = M.rc(i)
    assert(M.valid_cr(c, r), "cell " .. i .. " valid")
  end
  local b25 = {}
  for i = 1, 25 do b25[i] = "A" end
  b25[25] = EMPTY b25[20] = "Z"
  assert(M.touch(b25, 20) == true, "5x5 vertical move")
  assert(b25[20] == EMPTY and b25[25] == "Z", "5x5 swap w/ empty")
  assert(M.valid_cr(5, 5) and not M.valid_cr(1, 6), "cr 5x5")
  return "TOUCH_OK slide+10cells+25cells+moves+feedback"
end
pcall(function() _G.__ALPHA_TOUCH = _G.__ALPHA_TOUCH or M end)
pcall(function()
  local ok, vs = pcall(require, "mod_alpha_vslide")
  if ok and vs and vs.install then pcall(vs.install) end
end)
  return M
end)()
package.loaded["mod_alpha_touch"] = touch
local vslide = (function()
local M = {}
M.id = "alpha-vslide-v2"
M.COLS = 5
local TOUCH, ROWS, BOARD = nil, nil, nil
local function req(n) local m = nil
  pcall(function() local ok, v = pcall(require, n) if ok then m = v end end) return m end
local function getTouch() if not TOUCH then TOUCH = req("mod_alpha_touch") end return TOUCH end
local function getRows() if not (ROWS and ROWS.layout) then ROWS = req("mod_alpha_rows") end return ROWS end
local function getBoard() if not (BOARD and BOARD.getCell) then BOARD = req("mod_alpha_board") end return BOARD end
local S = { zones = nil, zb = nil, zl = nil, hooked = false, proved = {}, noVis = false }
function M.layout(lv) local r = getRows()
  if r and r.layout then return r.layout(lv) end
  lv = math.max(1, math.floor(tonumber(lv) or 1))
  if lv <= 1 then return 5, 2, 10 end
  if lv == 2 then return 5, 3, 15 end
  return 5, 5, 25 end
function M.idx(c, r, cols) cols = tonumber(cols) or M.COLS return (r - 1) * cols + c end
function M.rc(i, cols) cols = tonumber(cols) or M.COLS
  return ((i - 1) % cols) + 1, math.floor((i - 1) / cols) + 1 end
function M.valid_cr(c, r, rows) c, r = tonumber(c), tonumber(r)
  rows = math.max(2, math.floor(tonumber(rows) or 2)) if rows > 5 then rows = 5 end
  return c and r and c >= 1 and c <= M.COLS and r >= 1 and r <= rows end
function M.slide_cr(shadow, c, r, cols, rows)
  local res = false
  pcall(function()
    cols = tonumber(cols) or M.COLS rows = tonumber(rows) or 2
    if type(shadow) ~= "table" or not M.valid_cr(c, r, rows) then return end
    local T, R, n = getTouch(), getRows(), cols * rows
    if n == 10 and T and T.slide_cr then
      local ok2, r2 = pcall(T.slide_cr, shadow, c, r) if ok2 then res = r2 end return end
    if R and R.touch then res = R.touch(shadow, (r - 1) * cols + c, cols, rows) == true return end
    if T and T.slide_cr then local ok3, r3 = pcall(T.slide_cr, shadow, c, r)
      if ok3 then res = r3 end end end)
  return res end
local function liveSlide(c, r) local ok = false
  pcall(function() local A = _G.__ALPHA
    if type(A) == "table" and type(A.slide) == "function" then ok = A.slide(c, r) end end)
  return ok == true end
M.liveSlide = liveSlide
local function getCell(board, c, r) local cell = nil
  pcall(function() local B = getBoard()
    if B and B.getCell then cell = B.getCell(board, c, r) end end)
  if cell == nil then pcall(function() if type(board) == "table" then
    if type(board[c]) == "table" then cell = board[c][r] end
    if cell == nil then cell = board[(r - 1) * M.COLS + c] end end end) end
  return cell end
local function levelNow() local lv = 1
  pcall(function() local A = _G.__ALPHA
    if type(A) == "table" and type(A.level) == "function" then lv = A.level() end end)
  return math.max(1, math.floor(tonumber(lv) or 1)) end
local function isBoardTab(t) if type(t) ~= "table" then return false end
  local n = 0 pcall(function() for _ in pairs(t) do n = n + 1 end end)
  return n == 5 or n == 10 or n == 15 or n == 25 end
local function scanStage()
  local board, cov = nil, {}
  pcall(function()
    if not (display and display.getCurrentStage and debug and debug.getupvalue) then return end
    local st = display.getCurrentStage()
    local function use(fn)
      if type(fn) ~= "function" then return end
      local _, u1 = debug.getupvalue(fn, 1)
      local _, u2 = debug.getupvalue(fn, 2)
      local _, u3 = debug.getupvalue(fn, 3)
      if not (type(u2) == "number" and type(u3) == "number") then return end
      if not M.valid_cr(u2, u3, 5) or not isBoardTab(u1) then return end
      if board == nil then board = u1 end
      if u1 == board then cov[M.idx(u2, u3)] = true end end
    local function walk(o, d) if d > 16 then return end
      local okI, idv = pcall(function() return o.ID end)
      if okI and idv == "custom2" then
        local _, fv = pcall(function() return o.Func end)
        use(fv) pcall(function() use(o._alphaOrig) end) end
      local nk = 0 pcall(function() nk = o.numChildren or 0 end)
      for i = 1, (nk or 0) do local _, ch = pcall(function() return o[i] end)
        if ch ~= nil then walk(ch, d + 1) end end end
    walk(st, 0) end)
  return board, cov end
function M.liveBoard() local b = nil pcall(function() b = scanStage() end) return b end
function M.covered(board) local sb, cov = scanStage()
  if board == nil then return cov end
  if sb ~= board then return {} end return cov end
function M.ensureZones(board, onSlide, lv)
  board = board or M.liveBoard() if not board then return 0 end
  lv = math.max(1, math.floor(tonumber(lv) or levelNow() or 1))
  if S.zones and S.zb == board and S.zl == lv then return S.zones.n or 0 end
  if S.zones then M.dropZones() end
  if S.noVis or not (display and display.newRect) then
    S.noVis = true return 0 end
  onSlide = onSlide or liveSlide
  local _, rows, n = M.layout(lv)
  local cov, made, cnt = M.covered(board), {}, 0
  pcall(function() for i = 1, n do if not cov[i] then
    local c, r = M.rc(i)
    if r <= rows then local cell = getCell(board, c, r)
      if cell ~= nil then local x, y, w, h, par = nil, nil, 62, 62, nil
        pcall(function() x, y = cell.x, cell.y
          w = cell.width or w h = cell.height or h par = cell.parent end)
        if type(x) == "number" and type(y) == "number" and par ~= nil then
          local cc, rr, z = c, r, nil
          pcall(function() z = display.newRect(par, x, y, w, h) end)
          if z ~= nil then pcall(function() z.alpha = 0.01 z.isHitTestable = true
            if z.toFront then z:toFront() end
            z:addEventListener("touch", function(ev)
              if ev.phase == "began" then pcall(function() onSlide(cc, rr) end) return true end
              return true end) end)
            made[#made + 1] = z; cnt = cnt + 1 end end end end end end end)
  S.zones = { list = made, n = cnt }; S.zb, S.zl = board, lv
  return cnt end
function M.dropZones() pcall(function()
  if S.zones then for _, z in ipairs(S.zones.list or {}) do
    pcall(function() if z then z.isVisible = false end end) end end end)
  S.zones, S.zb, S.zl = nil, nil, nil end
local function snapOf() local sn = nil
  pcall(function() local A = _G.__ALPHA
    if type(A) == "table" and type(A.snap) == "function" then sn = A.snap() end end)
  return sn end
local function movesOf() local m = nil
  pcall(function() m = _G.__ALPHA.moves() end) return m end
local function proveOnce()
  local sn0 = snapOf() local _, _, n = M.layout(levelNow())
  if type(sn0) ~= "string" or #sn0 ~= n then return false end
  local e = sn0:find("_", 1, true) if not e then return false end
  local ec, er = M.rc(e) local tc, tr, bc, br, dir
  if er == 1 then tc, tr, bc, br, dir = ec, 2, ec, 1, "UP+DOWN"
  else tc, tr, bc, br, dir = ec, er - 1, ec, er, "DOWN+UP" end
  local m0 = movesOf() if not liveSlide(tc, tr) then return false end
  local s1 = snapOf() if not liveSlide(bc, br) then return false end
  local s2, m1 = snapOf(), movesOf() if s2 ~= sn0 then return false end
  if type(m0) == "number" and type(m1) == "number" and m1 ~= m0 + 2 then return false end
  return true end
function M._frame()
  return
end
function M._frame_old() local mode = nil
  S.frameThrottle = (S.frameThrottle or 0) + 1
  if S.frameThrottle % 15 ~= 0 then return end
  pcall(function() if type(onHoverTouch) == "function" and debug and debug.getupvalue then
    local _, g = debug.getupvalue(onHoverTouch, 1)
    if type(g) == "table" then mode = g.ModeCurrent end end end)
  if mode ~= nil and mode ~= "alphabeth" then
    if S.zones ~= nil then M.dropZones() end S.proved = {} return end
  local board = M.liveBoard() if board == nil then return end
  if mode == nil and snapOf() == nil then return end
  local lv = levelNow()
  if S.zb ~= board or S.zl ~= lv then M.dropZones() end
  if S.zones == nil then M.ensureZones(board, liveSlide, lv) end
  if not S.proved[lv] and snapOf() ~= nil then
    if proveOnce() then S.proved[lv] = true end end end
function M.install()
  pcall(function() if Runtime and Runtime.addEventListener and not S.hooked then
    Runtime:addEventListener("enterFrame", M._frame)
    S.hooked = true end end)
  pcall(function() _G.__ALPHA_VSLIDE = _G.__ALPHA_VSLIDE or M end) return true end
function M.selftest() local T = getTouch() assert(T and T.make, "no touch")
  for c = 1, 5 do local b = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J" }
    b[c + 5] = "" local s = T.make(b) local sn0 = s.snap()
    assert(s.tap(c, 1) == true, "DOWN c" .. c)
    assert(s.tap(c, 2) == true, "UP-back c" .. c)
    assert(s.snap() == sn0 and s.moves == 2, "restore+moves c" .. c) end
  for c = 1, 5 do local b = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J" }
    b[c] = "" local s = T.make(b) local sn0 = s.snap()
    assert(s.tap(c, 2) == true, "UP c" .. c)
    assert(s.tap(c, 1) == true, "DOWN-back c" .. c)
    assert(s.snap() == sn0, "restore2 c" .. c) end
  local sH = T.make({ "A", "B", "C", "D", "E", "F", "G", "H", "", "I" })
  assert(sH.tap(5, 2) == true, "HORIZ move")
  assert(sH.tap(1, 1) == false and sH.moves == 1, "regression+moves")
  local R = getRows() assert(R and R.touch, "no rows")
  for _, lv in ipairs({ 2, 3 }) do local cols, rows, n = M.layout(lv)
    local t = R.target(lv) local sh = {}
    for i = 1, n do sh[i] = t[i] end
    assert(R.touch(sh, n - 5, cols, rows) == true, "VERT L" .. lv)
    assert(R.touch(sh, n, cols, rows) == true, "VERT-back L" .. lv)
    assert(M.slide_cr(sh, 5, rows - 1, cols, rows) == true, "vslide L" .. lv) end
  assert(type(M.covered(nil)) == "table", "covered safe")
  return "VSLIDE_OK down+up+horiz+L2+L3+safe" end
pcall(function() _G.__ALPHA_VSLIDE = _G.__ALPHA_VSLIDE or M end)
pcall(function() M.install() end)
  return M
end)()
package.loaded["mod_alpha_vslide"] = vslide
local gbridge = (function()
local M = {}
M.id = "alpha-gbridge-v1"
local function isG(t)
  if type(t) ~= "table" then return false end
  local ok, a, b, c = pcall(function()
    return t.Progress, t.ModeCurrent, t.Desktop
  end)
  if not ok then return false end
  return a ~= nil and b ~= nil and c ~= nil
end
function M.resolve()
  local found = nil
  pcall(function()
    local f = _G.onHoverTouch
    if type(f) == "function" and debug and debug.getupvalue then
      for i = 1, 8 do
        local ok, _, v = pcall(debug.getupvalue, f, i)
        if ok and isG(v) then found = v break end
      end
    end
  end)
  if not found then
    pcall(function()
      for _, v in pairs(_G) do
        if type(v) == "function" and debug and debug.getupvalue then
          for i = 1, 4 do
            local ok, _, u = pcall(debug.getupvalue, v, i)
            if ok and isG(u) then found = u break end
          end
        end
        if found then break end
      end
    end)
  end
  return found
end
function M.install()
  if _G.G ~= nil then
    return "skip (_G.G ja existe)"
  end
  local function logb(m)
    pcall(function()
      local f = io.open("modloader_v1.log", "a")
      if f then f:write("[modloader] ALPHA_GBRIDGE " .. tostring(m) .. "\n") f:close() end
    end)
  end
  local function try()
    local g = M.resolve()
    if g ~= nil and _G.G == nil then
      _G.G = g
      logb("bridged (Progress=" .. tostring(g.Progress) ..
        " Mode=" .. tostring(g.ModeCurrent) .. ")")
      return true
    end
    return false
  end
  if try() then return "bridged now" end
  pcall(function()
    if timer and timer.performWithDelay then
      local tries = 0
      local again = nil
      again = function()
        tries = tries + 1
        if _G.G ~= nil then return end
        if try() then return end
        if tries < 12 then
          timer.performWithDelay(5000, again)
        else
          logb("absent apos retries")
        end
      end
      timer.performWithDelay(5000, again)
      return "retry scheduled"
    end
  end)
  return "pending retry"
end
function M.selftest()
  local g = M.resolve()
  assert(g ~= nil, "resolve nil")
  assert(g.Progress ~= nil and g.ModeCurrent ~= nil, "shape")
  return "GBRIDGE_OK"
end
  return M
end)()
package.loaded["mod_alpha_gbridge"] = gbridge
local cheat = (function()
local M = {}
M.id = "alpha-cheat-v1"
M.SEQ = { "up", "up", "down", "down",
  "left", "right", "left", "right", "b", "a", "enter" }
M.GAP = 4.0
M.TAPS = 10
M.TAP_WINDOW = 4.0
M.LOGF = "mod_alpha_hud.log"
M.STROKE = { 1, 0.85, 0.25 }
local ROWS, BOARD, HUD, RBAR = nil, nil, nil, nil
pcall(function()
  local ok, m = pcall(require, "mod_alpha_rows")
  if ok then ROWS = m end
end)
pcall(function()
  local ok, m = pcall(require, "mod_alpha_board")
  if ok then BOARD = m end
end)
pcall(function()
  local ok, m = pcall(require, "mod_alpha_hud")
  if ok then HUD = m end
end)
pcall(function()
  local ok, m = pcall(require, "mod_alpha_realbar")
  if ok then RBAR = m end
end)
local S = { pos = 1, lastT = nil, active = false, box = nil,
  hintI = nil, lastSnap = nil, recent = {}, levelSeen = nil,
  pathKey = nil, pathSet = nil,
  hooked = false, keyHook = false, barObj = nil,
  tapN = 0, tapT = nil }
local function nowSec()
  local t = nil
  pcall(function()
    if system and system.getTimer then t = system.getTimer() / 1000 end
  end)
  if type(t) == "number" then return t end
  pcall(function() t = os.clock() end)
  return tonumber(t) or 0
end
local function banner(text, rgb)
  pcall(function()
    if HUD and HUD.banner then HUD.banner(text, rgb) end
  end)
end
function M.feed(key, now)
  key = tostring(key or "")
  now = tonumber(now) or 0
  if S.lastT ~= nil and (now - S.lastT) > M.GAP then
    S.pos = 1
  end
  S.lastT = now
  local want = M.SEQ[S.pos]
  if key == want then
    S.pos = S.pos + 1
    if S.pos > #M.SEQ then
      S.pos = 1
      S.active = not S.active
      return S.active and "on" or "off"
    end
    return nil
  end
  S.pos = (key == M.SEQ[1]) and 2 or 1
  return nil
end
function M.isActive() return S.active == true end
function M.onRound()
  S.active, S.hintI, S.lastSnap = false, nil, nil
  S.recent, S.levelSeen, S.pathKey, S.pathSet = {}, nil, nil, nil
  pcall(function()
    if S.box and S.box.isVisible ~= nil then S.box.isVisible = false end
  end)
  return true
end
local function getLevel()
  local lv = nil
  pcall(function()
    local A = _G.__ALPHA
    if type(A) == "table" and type(A.level) == "function" then
      lv = A.level()
    end
  end)
  return math.max(1, math.floor(tonumber(lv) or 1))
end
local function getBoard()
  local b = nil
  pcall(function()
    if type(_G.__ALPHA_BOARD) == "table" then b = _G.__ALPHA_BOARD end
  end)
  return b
end
local function cellOf(b, c, r)
  local cell = nil
  pcall(function()
    if BOARD and BOARD.getCell then cell = BOARD.getCell(b, c, r) end
  end)
  if cell == nil then
    pcall(function()
      if type(b) == "table" and type(b[c]) == "table" then
        cell = b[c][r]
      end
    end)
  end
  return cell
end
local function readShadow(b, cols, rows)
  local sh = nil
  pcall(function()
    if type(b) ~= "table" then return end
    sh = {}
    for i = 1, cols * rows do
      local c = ((i - 1) % cols) + 1
      local r = math.floor((i - 1) / cols) + 1
      local cell = cellOf(b, c, r)
      local s = nil
      pcall(function() if cell ~= nil then s = cell.Symbol end end)
      if type(s) ~= "string" then
        pcall(function()
          if cell ~= nil and cell.SymbolText ~= nil then
            s = cell.SymbolText.text
          end
        end)
      end
      if type(s) ~= "string" then s = "" end
      sh[i] = s
    end
  end)
  if type(sh) == "table" and #sh == cols * rows then return sh end
  return nil
end
local function correctOf(sh, tg, n)
  local hit = 0
  for i = 1, n do if sh[i] == tg[i] then hit = hit + 1 end end
  return hit
end
local function snapOf(sh, n)
  local t = {}
  for i = 1, n do
    local s = sh[i]
    t[#t + 1] = (s == "" or s == nil) and "_" or tostring(s)
  end
  return table.concat(t)
end
local function manhattan(sh, posOf, n, cols)
  local d = 0
  for i = 1, n do
    local s = sh[i]
    if s ~= "" and s ~= nil then
      local t = posOf[s]
      if t then
        local c1 = ((i - 1) % cols) + 1
        local r1 = math.floor((i - 1) / cols) + 1
        local c2 = ((t - 1) % cols) + 1
        local r2 = math.floor((t - 1) / cols) + 1
        local dd = math.abs(c1 - c2) + math.abs(r1 - r2)
        if dd ~= dd then dd = 0 end
        d = d + dd
      end
    end
  end
  return d
end
local function swapSnap(s, a, b)
  if a == b then return s end
  if a > b then a, b = b, a end
  return s:sub(1, a - 1) .. s:sub(b, b) .. s:sub(a + 1, b - 1) .. s:sub(a, a) .. s:sub(b + 1)
end
function M.bfsMove(shadow, target, cols, rows, pathSet, budget)
  if type(shadow) ~= "table" or type(target) ~= "table" then return nil end
  cols = math.max(1, math.floor(tonumber(cols) or 5))
  rows = math.max(1, math.floor(tonumber(rows) or 2))
  local n = cols * rows
  budget = math.max(50, math.floor(tonumber(budget) or M.BFS_BUDGET))
  local tn = snapOf(target, n)
  local start = snapOf(shadow, n)
  if start == tn then return nil end
  local e0 = nil
  for i = 1, n do if shadow[i] == "" or shadow[i] == nil then e0 = i break end end
  if e0 == nil then return nil end
  local maxK = -1
  if type(pathSet) == "table" then
    for _, k in pairs(pathSet) do
      if type(k) == "number" and k > maxK then maxK = k end
    end
  end
  local function neigh(e)
    local ec = ((e - 1) % cols) + 1
    local er = math.floor((e - 1) / cols) + 1
    local o = {}
    if er > 1 then o[#o + 1] = e - cols end
    if er < rows then o[#o + 1] = e + cols end
    if ec > 1 then o[#o + 1] = e - 1 end
    if ec < cols then o[#o + 1] = e + 1 end
    return o
  end
  local q = { { s = start, e = e0 } }
  local head, layerEnd, depth = 1, 1, 0
  local seen = { [start] = true }
  local parent = {}
  local expanded = 0
  local best, bestTotal, bestK = nil, nil, -1
  while head <= #q and expanded < budget do
    if head > layerEnd then
      if best ~= nil then break end
      depth = depth + 1
      layerEnd = #q
    end
    local cur = q[head]
    head = head + 1
    expanded = expanded + 1
    for _, x in ipairs(neigh(cur.e)) do
      local ns = swapSnap(cur.s, cur.e, x)
      if not seen[ns] then
        seen[ns] = true
        parent[ns] = { p = cur.s, mv = x }
        if ns == tn then
          local mv, c = nil, ns
          while c ~= start do local pr = parent[c] if pr == nil then break end mv, c = pr.mv, pr.p end
          return mv
        end
        if type(pathSet) == "table" then
          local k = pathSet[ns]
          if k ~= nil then
            local total = (depth + 1) + (maxK - k)
            if bestTotal == nil or total < bestTotal or (total == bestTotal and k > bestK) then
              best, bestTotal, bestK = ns, total, k
            end
          end
        end
        q[#q + 1] = { s = ns, e = x }
      end
    end
  end
  if best == nil then return nil end
  local mv, c = nil, best
  while c ~= start do local pr = parent[c] if pr == nil then return nil end mv, c = pr.mv, pr.p end
  return mv
end
M.BFS_BUDGET = 1500
M.PLAN_DEPTH = 6
M.PLAN_WIDTH = 10
M.SOLVE_BUDGET = 15000
function M.plan(shadow, target, cols, rows, tabu)
  if type(shadow) ~= "table" or type(target) ~= "table" then return nil end
  cols = math.max(1, math.floor(tonumber(cols) or 5))
  rows = math.max(1, math.floor(tonumber(rows) or 2))
  local n = cols * rows
  local depth = math.max(1, math.floor(tonumber(M.PLAN_DEPTH) or 6))
  local width = math.max(1, math.floor(tonumber(M.PLAN_WIDTH) or 10))
  local tn = snapOf(target, n)
  local start = snapOf(shadow, n)
  if start == tn then return nil end
  local posOf = {}
  for i = 1, n do
    local t = target[i]
    if t ~= "" and t ~= nil and posOf[t] == nil then posOf[t] = i end
  end
  local blocked = {}
  if type(tabu) == "table" then
    for _, s in ipairs(tabu) do
      if type(s) == "string" and s ~= tn then blocked[s] = true end
    end
  end
  local function eval(s)
    local man, miss = 0, 0
    for i = 1, n do
      local c = s:sub(i, i)
      if c ~= tn:sub(i, i) then miss = miss + 1 end
      if c ~= "_" then
        local t = posOf[c]
        if t then
          local c1 = ((i - 1) % cols) + 1
          local r1 = math.floor((i - 1) / cols) + 1
          local c2 = ((t - 1) % cols) + 1
          local r2 = math.floor((t - 1) / cols) + 1
          man = man + math.abs(c1 - c2) + math.abs(r1 - r2)
        end
      end
    end
    return man + 2 * miss
  end
  local function neigh(e)
    local ec = ((e - 1) % cols) + 1
    local er = math.floor((e - 1) / cols) + 1
    local o = {}
    if er > 1 then o[#o + 1] = e - cols end
    if er < rows then o[#o + 1] = e + cols end
    if ec > 1 then o[#o + 1] = e - 1 end
    if ec < cols then o[#o + 1] = e + 1 end
    return o
  end
  local e0 = nil
  for i = 1, n do if shadow[i] == "" or shadow[i] == nil then e0 = i break end end
  if e0 == nil then return nil end
  local curF = eval(start)
  local beam = { { s = start, e = e0, first = nil } }
  local seen = { [start] = true }
  local bestFirst, bestF = nil, curF
  for _ = 1, depth do
    local nxt = {}
    for _, st in ipairs(beam) do
      for _, x in ipairs(neigh(st.e)) do
        local ns = swapSnap(st.s, st.e, x)
        if not seen[ns] and not blocked[ns] then
          seen[ns] = true
          local f = eval(ns)
          local first = st.first or x
          if f < bestF then bestFirst, bestF = first, f end
          if f == 0 then return first end
          nxt[#nxt + 1] = { s = ns, e = x, first = first, f = f }
        end
      end
    end
    if #nxt == 0 then break end
    local keep = {}
    for _, st in ipairs(nxt) do
      local placed = false
      for i = 1, #keep do
        if (st.f or 1e9) < (keep[i].f or 1e9) then
          table.insert(keep, i, st)
          placed = true
          break
        end
      end
      if not placed then keep[#keep + 1] = st end
      if #keep > width then keep[#keep] = nil end
    end
    beam = keep
  end
  return bestFirst
end
local function hpush(h, nd)
  h[#h + 1] = nd
  local i = #h
  while i > 1 do
    local p = math.floor(i / 2)
    if h[p].f <= h[i].f then break end
    h[p], h[i] = h[i], h[p]
    i = p
  end
end
local function hpop(h)
  local top = h[1]
  h[1] = h[#h]
  h[#h] = nil
  local i, n = 1, #h
  while true do
    local l, r, m = i * 2, i * 2 + 1, i
    if l <= n and h[l].f < h[m].f then m = l end
    if r <= n and h[r].f < h[m].f then m = r end
    if m == i then break end
    h[m], h[i] = h[i], h[m]
    i = m
  end
  return top
end
local function manhattanStr(s, posOf, n, cols)
  local d = 0
  for i = 1, n do
    local c = s:sub(i, i)
    if c ~= "_" then
      local t = posOf[c]
      if t then
        d = d + math.abs(((i - 1) % cols) - ((t - 1) % cols))
          + math.abs(math.floor((i - 1) / cols) - math.floor((t - 1) / cols))
      end
    end
  end
  return d
end
local function heur(s, posOf, n, cols, rows)
  local man = manhattanStr(s, posOf, n, cols)
  local lc, used = 0, {}
  for r = 1, rows do
    for a = 1, cols do
      local i = (r - 1) * cols + a
      local ta = posOf[s:sub(i, i)]
      if s:sub(i, i) ~= "_" and ta and math.floor((ta - 1) / cols) + 1 == r and not used[i] then
        for b = a + 1, cols do
          local j = (r - 1) * cols + b
          local tb = posOf[s:sub(j, j)]
          if s:sub(j, j) ~= "_" and tb and math.floor((tb - 1) / cols) + 1 == r and not used[j] and ta > tb then
            used[i], used[j] = true, true
            lc = lc + 2
            break
          end
        end
      end
    end
  end
  for c = 1, cols do
    for a = 1, rows do
      local i = (a - 1) * cols + c
      local ta = posOf[s:sub(i, i)]
      if s:sub(i, i) ~= "_" and ta and ((ta - 1) % cols) + 1 == c and not used[i] then
        for b = a + 1, rows do
          local j = (b - 1) * cols + c
          local tb = posOf[s:sub(j, j)]
          if s:sub(j, j) ~= "_" and tb and ((tb - 1) % cols) + 1 == c and not used[j] and ta > tb then
            used[i], used[j] = true, true
            lc = lc + 2
            break
          end
        end
      end
    end
  end
  return man + lc
end
function M.solve(shadow, target, cols, rows, budget)
  if type(shadow) ~= "table" or type(target) ~= "table" then return nil end
  cols = math.max(1, math.floor(tonumber(cols) or 5))
  rows = math.max(1, math.floor(tonumber(rows) or 2))
  local n = cols * rows
  budget = math.max(50, math.floor(tonumber(budget) or M.SOLVE_BUDGET))
  local tn = snapOf(target, n)
  local start = snapOf(shadow, n)
  if start == tn then return nil end
  local posOf = {}
  for i = 1, n do local t = target[i] if t ~= "" and t ~= nil and posOf[t] == nil then posOf[t] = i end end
  local e0 = nil
  for i = 1, n do if shadow[i] == "" or shadow[i] == nil then e0 = i break end end
  if e0 == nil then return nil end
  local function neigh(e)
    local ec = ((e - 1) % cols) + 1
    local er = math.floor((e - 1) / cols) + 1
    local o = {}
    if er > 1 then o[#o + 1] = e - cols end
    if er < rows then o[#o + 1] = e + cols end
    if ec > 1 then o[#o + 1] = e - 1 end
    if ec < cols then o[#o + 1] = e + 1 end
    return o
  end
  local open = {}
  hpush(open, { s = start, e = e0, g = 0, f = heur(start, posOf, n, cols, rows) })
  local closed, parent, expanded = { [start] = 0 }, {}, 0
  while #open > 0 and expanded < budget do
    local cur = hpop(open)
    expanded = expanded + 1
    if cur.s == tn then
      local moves, c = {}, cur.s
      while c ~= start do local pr = parent[c] if pr == nil then return nil end moves[#moves + 1] = pr.mv c = pr.p end
      for i = 1, math.floor(#moves / 2) do moves[i], moves[#moves - i + 1] = moves[#moves - i + 1], moves[i] end
      return moves
    end
    if not (closed[cur.s] < cur.g) then
      for _, x in ipairs(neigh(cur.e)) do
        local ns = swapSnap(cur.s, cur.e, x)
        local g = cur.g + 1
        if closed[ns] == nil or g < closed[ns] then
          closed[ns] = g
          parent[ns] = { p = cur.s, mv = x }
          hpush(open, { s = ns, e = x, g = g, f = g + heur(ns, posOf, n, cols, rows) })
        end
      end
    end
  end
  return nil
end
function M.guide(shadow, target, cols, rows, tabu, pathSet)
  if type(shadow) ~= "table" or type(target) ~= "table" then return nil end
  cols = math.max(1, math.floor(tonumber(cols) or 5))
  rows = math.max(1, math.floor(tonumber(rows) or 2))
  local n = cols * rows
  if correctOf(shadow, target, n) >= n then return nil end
  local e = nil
  for i = 1, n do
    if shadow[i] == "" or shadow[i] == nil then e = i break end
  end
  if e == nil then return nil end
  local ec = ((e - 1) % cols) + 1
  local er = math.floor((e - 1) / cols) + 1
  local cand = {}
  if er > 1 then cand[#cand + 1] = e - cols end
  if er < rows then cand[#cand + 1] = e + cols end
  if ec > 1 then cand[#cand + 1] = e - 1 end
  if ec < cols then cand[#cand + 1] = e + 1 end
  if type(pathSet) == "table" then
    local cur = snapOf(shadow, n)
    local k = pathSet[cur]
    if k ~= nil then
      for _, x in ipairs(cand) do
        if shadow[x] ~= "" and shadow[x] ~= nil then
          shadow[e], shadow[x] = shadow[x], shadow[e]
          local sn = snapOf(shadow, n)
          shadow[e], shadow[x] = shadow[x], shadow[e]
          if pathSet[sn] ~= nil and pathSet[sn] > k then return x end
        end
      end
    end
    local bx, bk = nil, -1
    for _, x in ipairs(cand) do
      if shadow[x] ~= "" and shadow[x] ~= nil then
        shadow[e], shadow[x] = shadow[x], shadow[e]
        local sn = snapOf(shadow, n)
        shadow[e], shadow[x] = shadow[x], shadow[e]
        local kk = pathSet[sn]
        if kk ~= nil and kk > bk then bx, bk = x, kk end
      end
    end
    if bx ~= nil then return bx end
  end
  local sv = nil
  pcall(function() sv = M.solve(shadow, target, cols, rows, M.SOLVE_BUDGET) end)
  if type(sv) == "table" and #sv > 0 then return sv[1] end
  local bm = nil
  pcall(function() bm = M.bfsMove(shadow, target, cols, rows, pathSet, M.BFS_BUDGET) end)
  if bm ~= nil then return bm end
  local pl = nil
  pcall(function() pl = M.plan(shadow, target, cols, rows, tabu) end)
  if pl ~= nil then return pl end
  return M.hint(shadow, target, cols, rows, tabu)
end
function M.buildPath(shadow, pathArr, target, cols, rows, lv)
  if type(shadow) ~= "table" or type(pathArr) ~= "table" then return nil end
  if type(target) ~= "table" then return nil end
  cols = math.max(1, math.floor(tonumber(cols) or 5))
  rows = math.max(1, math.floor(tonumber(rows) or 2))
  local n = cols * rows
  local keyParts = {}
  for i = 1, #pathArr do keyParts[#keyParts + 1] = tostring(pathArr[i]) end
  local key = table.concat(keyParts, ",")
  local sim = {}
  for i = 1, n do sim[i] = shadow[i] end
  local set, order, k = {}, {}, 0
  set[snapOf(sim, n)] = 0
  order[1] = snapOf(sim, n)
  local R = ROWS
  if not (R and R.touch and R.is_win) then return nil end
  for j = #pathArr, 1, -1 do
    local t = tonumber(pathArr[j])
    local ok = false
    pcall(function() ok = (R.touch(sim, t, cols, rows) == true) end)
    if not ok then return nil end
    local sn = snapOf(sim, n)
    local prev = set[sn]
    if prev == nil then
      k = k + 1
      set[sn] = k
      order[#order + 1] = sn
    else
      while #order > 0 and order[#order] ~= sn do
        set[order[#order]] = nil
        order[#order] = nil
      end
      k = prev
    end
  end
  local win = false
  pcall(function() win = (R.is_win(sim, lv) == true) end)
  if not win then return nil end
  return set, key
end
function M.hint(shadow, target, cols, rows, tabu)
  if type(shadow) ~= "table" or type(target) ~= "table" then return nil end
  cols = math.max(1, math.floor(tonumber(cols) or 5))
  rows = math.max(1, math.floor(tonumber(rows) or 2))
  local n = cols * rows
  local e = nil
  for i = 1, n do if shadow[i] == "" or shadow[i] == nil then e = i break end end
  if e == nil then return nil end
  local ec = ((e - 1) % cols) + 1
  local er = math.floor((e - 1) / cols) + 1
  local cand = {}
  if er > 1 then cand[#cand + 1] = e - cols end
  if er < rows then cand[#cand + 1] = e + cols end
  if ec > 1 then cand[#cand + 1] = e - 1 end
  if ec < cols then cand[#cand + 1] = e + 1 end
  local posOf = {}
  for i = 1, n do
    local t = target[i]
    if t ~= "" and t ~= nil and posOf[t] == nil then posOf[t] = i end
  end
  local function isTabu(sn)
    if type(tabu) ~= "table" then return false end
    for _, s in ipairs(tabu) do if s == sn then return true end end
    return false
  end
  local cur = correctOf(shadow, target, n)
  local curMan = manhattan(shadow, posOf, n, cols)
  local best, bestScore, bestMan = nil, cur, curMan
  for _, x in ipairs(cand) do
    if shadow[x] ~= "" and shadow[x] ~= nil then
      shadow[e], shadow[x] = shadow[x], shadow[e]
      local s = correctOf(shadow, target, n)
      local m = manhattan(shadow, posOf, n, cols)
      local sn = snapOf(shadow, n)
      shadow[e], shadow[x] = shadow[x], shadow[e]
      if s >= n then return x end
      local better = false
      if s > bestScore then better = true
      elseif s == bestScore and m < bestMan then better = true end
      if better and not isTabu(sn) then
        best, bestScore, bestMan = x, s, m
      end
    end
  end
  if best ~= nil then return best end
  for _, x in ipairs(cand) do
    if shadow[x] ~= "" and shadow[x] ~= nil then
      if tabu == nil then return x end
      shadow[e], shadow[x] = shadow[x], shadow[e]
      local sn = snapOf(shadow, n)
      shadow[e], shadow[x] = shadow[x], shadow[e]
      if not isTabu(sn) then return x end
    end
  end
  for _, x in ipairs(cand) do
    if shadow[x] ~= "" and shadow[x] ~= nil then return x end
  end
  return nil
end
local function hideBox()
  pcall(function()
    if S.box and S.box.isVisible ~= nil then S.box.isVisible = false end
  end)
end
local function showBox(b, i, cols)
  pcall(function()
    if not (display and display.newRect) then return end
    local c = ((i - 1) % cols) + 1
    local r = math.floor((i - 1) / cols) + 1
    local cell = cellOf(b, c, r)
    if cell == nil then return end
    local x, y, w, h, par = nil, nil, 62, 62, nil
    pcall(function()
      x, y = cell.x, cell.y
      w = cell.width or w h = cell.height or h
      par = cell.parent
    end)
    if type(x) ~= "number" or type(y) ~= "number" or par == nil then return end
    local same = false
    pcall(function() same = (S.box ~= nil and S.box.parent == par) end)
    if not same then
      pcall(function()
        if S.box and S.box.removeSelf then S.box:removeSelf() end
      end)
      S.box = nil
    end
    if S.box == nil then
      local ok = pcall(function()
        S.box = display.newRect(par, x, y, w - 6, h - 6)
        S.box:setFillColor(1, 1, 1, 0)
        S.box:setStrokeColor(M.STROKE[1], M.STROKE[2], M.STROKE[3])
        S.box.strokeWidth = 4
      end)
      if not ok or S.box == nil then S.box = nil return end
    end
    pcall(function()
      S.box.x, S.box.y = x, y
      S.box.width, S.box.height = (w or 62) - 6, (h or 62) - 6
      S.box:setFillColor(1, 1, 1, 0)
      S.box:setStrokeColor(M.STROKE[1], M.STROKE[2], M.STROKE[3])
      S.box.strokeWidth = 4
      S.box.isVisible = true
      if S.box.toFront then S.box:toFront() end
    end)
  end)
end
local function refresh()
  if not S.active then hideBox() return end
  local mode = nil
  pcall(function()
    if type(onHoverTouch) == "function" and debug and debug.getupvalue then
      local _, g = debug.getupvalue(onHoverTouch, 1)
      if type(g) == "table" then mode = g.ModeCurrent end
    end
  end)
  if mode ~= nil and mode ~= "alphabeth" then
    if S.active then  end
    S.active = false
    S.hintI, S.lastSnap, S.recent, S.levelSeen = nil, nil, {}, nil
    S.pathKey, S.pathSet = nil, nil
    hideBox()
    return
  end
  local lv = getLevel()
  local cols, rows, n = 5, 5, 25
  pcall(function()
    if ROWS and ROWS.layout then cols, rows, n = ROWS.layout(lv) end
  end)
  local b = getBoard()
  if type(b) ~= "table" then hideBox() return end
  local sh = readShadow(b, cols, rows)
  if sh == nil then hideBox() return end
  if S.levelSeen ~= lv then S.levelSeen, S.recent = lv, {} end
  if S.recent == nil then S.recent = {} end
  local snap = snapOf(sh, n)
  if snap == S.lastSnap and S.hintI ~= nil then
    showBox(b, S.hintI, cols)
    return
  end
  S.lastSnap = snap
  S.recent[#S.recent + 1] = snap
  if #S.recent > 48 then table.remove(S.recent, 1) end
  local tg = nil
  pcall(function()
    if ROWS and ROWS.target then tg = ROWS.target(lv) end
  end)
  if type(tg) ~= "table" then hideBox() return end
  if correctOf(sh, tg, n) >= n then hideBox() S.hintI = nil return end
  local parr = nil
  pcall(function()
    local A = _G.__ALPHA
    if type(A) == "table" and type(A.path) == "function" then
      parr = A.path()
    end
  end)
  local pkey = nil
  if type(parr) == "table" then
    local kp = {}
    for i = 1, #parr do kp[#kp + 1] = tostring(parr[i]) end
    pkey = table.concat(kp, ",")
  end
  if pkey ~= S.pathKey then
    S.pathKey, S.pathSet = pkey, nil
    if pkey ~= nil then
      local set = M.buildPath(sh, parr, tg, cols, rows, lv)
      if set ~= nil then
        S.pathSet = set
      end
    end
  end
  local h = M.guide(sh, tg, cols, rows, S.recent, S.pathSet)
  S.hintI = h
  if h == nil then hideBox() return end
  showBox(b, h, cols)
end
local function onKey(ev)
  local done = false
  pcall(function()
    if type(ev) ~= "table" then return end
    if ev.phase ~= nil and ev.phase ~= "down" then return end
    local kn = ev.keyName
    if type(kn) ~= "string" then return end
    kn = kn:lower()
    local res = M.feed(kn, nowSec())
    if res == "on" then
      S.lastSnap = nil
      S.recent = {}
      S.pathKey, S.pathSet = nil, nil
      refresh()
    elseif res == "off" then
      hideBox()
      S.hintI, S.lastSnap, S.recent = nil, nil, {}
      S.pathKey, S.pathSet = nil, nil
    end
    done = true
  end)
  return done
end
local function onBarTap(ev)
  pcall(function()
    M.tapCount(true, nowSec())
  end)
  return true
end
local function hookBar()
  pcall(function()
    if RBAR == nil then
      local ok, m = pcall(require, "mod_alpha_realbar")
      if ok then RBAR = m end
    end
    local g = RBAR and RBAR.group and RBAR.group()
    if g == nil or g == S.barObj then return end
    if g.addEventListener then
      g.isHitTestable = true
      g:addEventListener("tap", onBarTap)
      S.barObj = g
      pcall(function() print("PROGRESSMOD bar hook") end)
    end
  end)
end
function M.tapCount(inside, now)
  now = tonumber(now) or 0
  if not inside then
    S.tapN, S.tapT = 0, nil
    return nil
  end
  if S.tapT ~= nil and (now - S.tapT) > M.TAP_WINDOW then
    S.tapN = 0
  end
  S.tapT = now
  S.tapN = (S.tapN or 0) + 1
  if S.tapN >= M.TAPS then
    S.tapN, S.tapT = 0, nil
    S.active = not S.active
    S.lastSnap = nil
    S.recent = {}
    S.pathKey, S.pathSet = nil, nil
    if S.active then
      refresh()
      pcall(function() print("PROGRESSMOD cheat on") end)
      return "on"
    else
      hideBox()
      S.hintI, S.lastSnap, S.recent = nil, nil, {}
      S.pathKey, S.pathSet = nil, nil
      pcall(function() print("PROGRESSMOD cheat off") end)
      return "off"
    end
  end
  return nil
end
local function onFrame()
  S.frameN = (S.frameN or 0) + 1
  if S.frameN % 30 ~= 0 then return end
  pcall(hookBar)
  pcall(refresh)
end
function M.install()
  pcall(function()
    if Runtime and Runtime.addEventListener and not S.keyHook then
      Runtime:addEventListener("key", onKey)
      S.keyHook = true
    end
  end)
  pcall(hookBar)
  pcall(function()
    pcall(function() print("PROGRESSMOD cheat touch hook") end)
  end)
  pcall(function()
    if Runtime and Runtime.addEventListener and not S.hooked then
      Runtime:addEventListener("enterFrame", onFrame)
      S.hooked = true
    end
  end)
  pcall(function()
    _G.__ALPHA_CHEAT = {
      toggle = function()
        S.active = not S.active
        S.lastSnap = nil
        if not S.active then hideBox() end
        return S.active
      end,
      isActive = function() return M.isActive() end,
      hint = function(sh, tg, c, r) return M.hint(sh, tg, c, r) end,
    }
  end)
  return true
end
function M.selftest()
  S.pos, S.lastT, S.active = 1, nil, false
  for i, k in ipairs(M.SEQ) do
    local r = M.feed(k, i)
    if i < #M.SEQ then assert(r == nil, "partial " .. i) end
  end
  assert(S.active == true, "turned on")
  for i, k in ipairs(M.SEQ) do M.feed(k, 100 + i) end
  assert(S.active == false, "turned off")
  M.feed("up", 200)
  M.feed("x", 201)
  assert(S.pos == 1, "reset on error")
  M.feed("up", 300)
  local r2 = M.feed("up", 300 + M.GAP + 1)
  assert(r2 == nil and S.pos == 2, "gap+restart")
  S.pos, S.lastT, S.active = 1, nil, false
  local sh = {}
  for i = 1, 25 do sh[i] = "Z" end
  local tg = {}
  for i = 1, 25 do tg[i] = "Z" end
  tg[1], tg[2] = "A", "B"
  sh[1], sh[2] = "B", ""
  local h = M.hint(sh, tg, 5, 5)
  assert(h == 1, "hint = 1 (improves), got " .. tostring(h))
  assert(sh[1] == "B" and sh[2] == "", "hint does not mutate")
  local full = {}
  for i = 1, 10 do full[i] = "A" end
  assert(M.hint(full, full, 5, 2) == nil, "no empty, no hint")
  local sh2 = { "B", "A", "C", "D", "E", "F", "G", "H", "", "I" }
  local tg2 = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "" }
  assert(M.hint(sh2, tg2, 5, 2) == 10, "no tabu = 10")
  local hT = M.hint(sh2, tg2, 5, 2, { "BACDEFGHI_" })
  assert(hT == 4, "tabu diverts to 4, got " .. tostring(hT))
  assert(sh2[9] == "" and sh2[10] == "I", "tabu does not mutate")
  local tgG = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "" }
  local shG = { "A", "B", "C", "D", "E", "F", "G", "H", "", "I" }
  local setG, keyG = M.buildPath(shG, { 10 }, tgG, 5, 2, 1)
  assert(type(setG) == "table" and keyG == "10", "caminho valido")
  assert(M.guide(shG, tgG, 5, 2, {}, setG) == 10, "no caminho => 10")
  local shD = { "A", "B", "C", "", "E", "F", "G", "H", "D", "I" }
  assert(M.guide(shD, tgG, 5, 2, {}, setG) == 9, "1 off => back 9")
  assert(M.buildPath(shG, { 1 }, tgG, 5, 2, 1) == nil, "invalid rewind = nil")
  assert(M.guide(shG, tgG, 5, 2, {}, nil) == 10, "no path = greedy")
  assert(M.guide(tgG, tgG, 5, 2, {}, setG) == nil, "solved with no hint")
  local X = { "A", "B", "C", "", "E", "F", "G", "H", "D", "I" }
  local X2 = { "A", "B", "", "C", "E", "F", "G", "H", "D", "I" }
  assert(M.bfsMove(X, tgG, 5, 2, setG) == 9, "bfs rejoin 1")
  assert(M.bfsMove(X, tgG, 5, 2, nil) == 9, "bfs target in 2")
  assert(M.bfsMove(X2, tgG, 5, 2, setG) == 4, "bfs rejoin 2")
  assert(M.guide(X2, tgG, 5, 2, {}, setG) == 4, "guide uses bfs")
  assert(X[4] == "" and X2[3] == "", "bfs does not mutate")
  assert(M.bfsMove(tgG, tgG, 5, 2, nil) == nil, "bfs solved = nil")
  assert(M.plan(sh2, tgG, 5, 2) == 10, "plan immediate victory")
  assert(M.plan(X2, tgG, 5, 2) == 4, "plan 3-line")
  assert(M.plan(tgG, tgG, 5, 2) == nil, "plan solved = nil")
  assert(sh2[9] == "" and X2[3] == "", "plan does not mutate")
  if ROWS and ROWS.touch then
    local sim = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "" }
    assert(ROWS.touch(sim, 9, 5, 2) == true, "loop step 1")
    assert(ROWS.touch(sim, 10, 5, 2) == true, "loop step 2")
    assert(ROWS.touch(sim, 9, 5, 2) == true, "loop step 3")
    local setL = M.buildPath(sim, { 10, 9, 10 }, tgG, 5, 2, 1)
    assert(type(setL) == "table", "valid loop")
    local cnt = 0
    for _ in pairs(setL) do cnt = cnt + 1 end
    assert(cnt == 2, "loop compressed (2 states), got " .. tostring(cnt))
    assert(M.guide(sim, tgG, 5, 2, {}, setL) == 10, "loop => 10 straight")
  end
  for i, k in ipairs(M.SEQ) do M.feed(k, 500 + i) end
  assert(S.active == true, "turned back on")
  assert(M.onRound() == true and S.active == false, "onRound invalidtes")
  S.pos, S.lastT, S.active = 1, nil, false
  local ROK, RR = pcall(require, "mod_alpha_rows")
  if ROK and RR then
    local sb = RR.scrambled(3, 4242)
    local stg = RR.target(3)
    local mv = M.solve(sb, stg, 5, 5, 15000)
    assert(type(mv) == "table" and #mv > 0, "solve finds")
    local snap0 = snapOf(sb, 25)
    local cp = {}
    for i = 1, 25 do cp[i] = sb[i] end
    for _, m in ipairs(mv) do assert(RR.touch(cp, m, 5, 5) == true, "solve: legal move") end
    assert(RR.is_win(cp, 3), "solve solves")
    assert(snapOf(sb, 25) == snap0, "solve does not mutate origin")
    local m2 = M.solve(X2, tgG, 5, 2, 1500)
    assert(type(m2) == "table" and #m2 == 3, "solve optimum=3, got " .. tostring(m2 and #m2))
    assert(M.solve(tgG, tgG, 5, 2) == nil, "solve solved = nil")
    assert(M.guide(X2, tgG, 5, 2, {}, setG) == m2[1], "guide uses solve")
  end
  S.active = false
  S.tapN, S.tapT = 0, nil
  for i = 1, M.TAPS - 1 do
    assert(M.tapCount(true, 1000 + i) == nil, "tap partial " .. i)
  end
  assert(S.active == false, "tap pending stays off")
  assert(M.tapCount(true, 1000 + M.TAPS) == "on", "tap toggles on")
  assert(S.active == true, "tap active")
  assert(M.tapCount(false, 2000) == nil, "tap outside resets")
  assert(S.tapN == 0, "tap count reset")
  for i = 1, M.TAPS do M.tapCount(true, 3000 + i) end
  assert(S.active == false, "tap toggles off")
  M.tapCount(true, 4000)
  assert(M.tapCount(true, 4000 + M.TAP_WINDOW + 1) == nil, "tap window restarts")
  assert(S.tapN == 1, "tap restarts at 1")
  S.tapN, S.tapT = 0, nil
  return "CHEAT_OK seq+guide+solve+bfs+loop+tabu+immutable"
end
  return M
end)()
package.loaded["mod_alpha_cheat"] = cheat
local flow = (function()
local M = {}
M.id = "alpha-flow-v11"
M.TIME_LIMIT, M.WIN_PAUSE, M.LOSS_DELAY, M.LAND_W, M.LAND_H = 1200, 2000, 1000, 1364, 768
local BOARD, HUD, GP, BAR, HL, TOUCH, TIM, WIN, LOSS = nil, nil, nil, nil, nil, nil, nil, nil, nil
local SEL, ROWS, DEFBAR, BLOG, SLD, RED, OUTL, RPHYS = nil, nil, nil, nil, nil, nil, nil, nil
local function req(n) local m = nil pcall(function() local ok, v = pcall(require, n) if ok then m = v end end) return m end
BOARD, HUD, GP, BAR, HL = req("mod_alpha_board"), req("mod_alpha_hud"), req("mod_alpha_gameplay"), req("mod_alpha_bar"), req("mod_alpha_highlight")
TOUCH, TIM, WIN, LOSS = req("mod_alpha_touch"), req("mod_alpha_timer"), req("mod_alpha_win"), req("mod_alpha_loss")
SEL, ROWS, DEFBAR, BLOG = req("mod_alpha_select"), req("mod_alpha_rows"), req("mod_alpha_defbar"), req("mod_alpha_barlogic"); RPHYS = req("mod_alpha_rowsphys")
local RBAR = req("mod_alpha_realbar")
local CHT = req("mod_alpha_cheat")
SLD = req("mod_alpha_slide") or TOUCH
RED, OUTL = req("mod_alpha_redsquare") or req("mod_alpha_redsq") or req("mod_alpha_red"), req("mod_alpha_selbox") or req("mod_alpha_outline") or SEL
if DEFBAR == nil then pcall(function() DEFBAR = _G.__ALPHA_DEFBAR end) end if SEL == nil then pcall(function() SEL = _G.__ALPHA_SELECT_MOD or _G.__ALPHA_SELECT end) end
local S = { api = nil, board = nil, over = false, t0 = nil, tick = 0, landT = 0, modeSeen = nil, seedN = 0, level = 1, tlim = 1200, tim = nil, lastT = nil, Gref = nil, wasStop = nil, Gseen = nil }
local function getG() local G = nil; pcall(function() local _, g = debug.getupvalue(onHoverTouch, 1) G = g end); return G end
local _gc, _gn = nil, 0
local function getGC()
  _gn = _gn + 1
  if _gc == nil or _gn % 6 == 1 then
    local g = getG()
    if g ~= nil then _gc = g end
  end
  return _gc
end
local function tNow() local t = 0 pcall(function() t = (system.getTimer and system.getTimer() or 0) end) return t end
local function call(m, fn, a, b, c) local ok = false pcall(function() if type(m) == "table" and type(m[fn]) == "function" then ok = (m[fn](a, b, c) ~= false) end end) return ok end
local function tLeft()
  if TIM and S.tim and TIM.left then local ok, v = pcall(TIM.left, S.tim) if ok and type(v) == "number" then return v end end
  local lim = _G.__ALPHA_TEST_TIMEOUT or S.tlim or M.TIME_LIMIT
  local el = (tNow() - (S.t0 or tNow())) / 1000
  if el < 0 then el = 0 end
  return math.max(0, lim - el)
end
local function isWinNow()
  if WIN and type(WIN.checkApi) == "function" then local ok, v = pcall(WIN.checkApi, S.api) if ok and v == true then return true end end
  local ok, w = pcall(function() return S.api.isWin() end)
  return ok and w == true
end
local onWin = nil
local function playSound(n) pcall(function() if type(S.snd) == "function" then S.snd(n) end end) end
local function selSync(c, r) pcall(function()
  for _, md in ipairs({ (OUTL ~= SEL) and OUTL or nil, SEL }) do if md then
    if md.set_cr then md.set_cr(S.board, BOARD.getCell, c, r) end
    if md.refresh then md.refresh(S.board, BOARD.getCell) elseif md.onSlid then md.onSlid(S.board, BOARD.getCell) end
    if md.follow then md.follow(S.board) end end end end) end
local function redSync(kind, c, r) pcall(function() if not RED then return end
  if kind == "err" then
    call(RED, "clear") call(RED, "hide")
  else call(RED, "clear") call(RED, "hide") end end) end
local function slideNote(ok) pcall(function() if SLD and SLD ~= TOUCH then
  if SLD.note then SLD.note(ok) elseif SLD.syncMoves then SLD.syncMoves() end end end) end
local function blogSync(why) pcall(function() if BLOG and BLOG.set and S.api and S.api.correct then local c, t = S.api.correct() BLOG.set(c, t, why) end end) end
local function doSlide(c, r)
  if S.over or not S.api then
    pcall(function()
    end)
    return false
  end
  local ok = false
  pcall(function() ok = S.api.slide(c, r) end)
  if ok then playSound("place") selSync(c, r) redSync("ok") slideNote(true) blogSync("move")
    pcall(function() if TIM and S.tim and TIM.note then TIM.note(S.tim, true) end end)
    pcall(function()  end)
    pcall(function() HUD.update(S.api.progress(), S.api.moves, tLeft()) end)
    pcall(function()
      if not S.over and onWin and isWinNow() then
        local G = S.Gref or getG()
        if G then onWin(G) end
      end
    end)
  else
    playSound("error") redSync("err", c, r)
    pcall(function() if S.api and S.api.refresh then S.api.refresh() end end)
    pcall(function() if S.api and S.api.janitor then S.api.janitor() end end)
    pcall(function() if S.api and S.api.hideReal then S.api.hideReal() end end)
    pcall(function()  end)
    pcall(function() local G = S.Gref or getG() if LOSS and LOSS.onWrongMove then LOSS.onWrongMove(G) end end)
  end
  return ok
end
local function wrap(b)
  local n = 0
  if not BOARD then return 0 end
  pcall(function()
    local st = display.getCurrentStage()
    local function walk(o, d)
      if d > 16 then return end
      local okI, idv = pcall(function() return o.ID end)
      if okI and idv == "custom2" then
        local okF, fv = pcall(function() return o.Func end)
        if okF and type(fv) == "function" and not o._alphaWrapped then
          local _, u1 = debug.getupvalue(fv, 1)
          local _, u2 = debug.getupvalue(fv, 2)
          local _, u3 = debug.getupvalue(fv, 3)
          if u1 == b and type(u2) == "number" and type(u3) == "number" then
            local cc, rr = u2, u3
            if not S.snd then pcall(function()
              for i = 4, 12 do local _, uv = debug.getupvalue(fv, i)
                if type(uv) == "function" then local inf = debug.getinfo(uv, "S")
                  if inf and (inf.linedefined or 1e9) < 5000 then S.snd = uv break end end end
            end) end
            o._alphaOrig = fv
            o._alphaWrapped = true
            o.Func = function() pcall(function() doSlide(cc, rr) end) end
            n = n + 1
          end
        end
      end
      local nk = 0; pcall(function() nk = o.numChildren or 0 end)
      for i = 1, (nk or 0) do local _, ch = pcall(function() return o[i] end) if ch ~= nil then walk(ch, d + 1) end end
    end
    walk(st, 0)
  end)
  if n > 0 then  end
  return n
end
local function unwrap()
  local n = 0
  pcall(function()
    local st = display.getCurrentStage()
    local function walk(o, d)
      if d > 16 then return end
      pcall(function()
        if o._alphaWrapped and type(o._alphaOrig) == "function" then
          o.Func = o._alphaOrig
          o._alphaOrig, o._alphaWrapped = nil, nil
          n = n + 1
        end
      end)
      local nk = 0; pcall(function() nk = o.numChildren or 0 end)
      for i = 1, (nk or 0) do local _, ch = pcall(function() return o[i] end) if ch ~= nil then walk(ch, d + 1) end end
    end
    walk(st, 0)
  end)
  if n > 0 then  end
  return n
end
local function barObj() return RBAR or DEFBAR or BAR end
local function hideNativePanel()
  pcall(function()
    local G = S.Gref or getG()
    local P = G and G.ProgressBarPanel
    if P ~= nil and P.isVisible ~= nil then P.isVisible = false end
  end)
end
local function showNativePanel()
  pcall(function()
    local G = S.Gref or getG()
    local P = G and G.ProgressBarPanel
    if P ~= nil and P.isVisible ~= nil then P.isVisible = true end
  end)
end
local function barPush(G)
  local c, t, p = 0, 10, 0
  if S.api and S.api.correct then c, t = S.api.correct() end
  if S.api then p = S.api.progress() end
  pcall(function() if BLOG and BLOG.compute then p = BLOG.compute(c, t or 10) end end)
  blogSync("push")
  pcall(function() if BLOG and BLOG.get then local g = BLOG.get() if type(g) == "number" then p = g end end end)
  local B = barObj()
  if B and B.push then pcall(function() B.push(G, c, t or 10) end)
  elseif BLOG and BLOG.sync then pcall(function() BLOG.sync(G, p) end)
  else pcall(function() local pw = (G.INI and G.INI.ProgressWidth) or 20 G.Progress = p * pw G.ProgressProcent = p end) end
  pcall(function() if B and B.update then B.update(p, S.board) end end)
  pcall(function() local D = DEFBAR or B if D and D.follow then D.follow(S.board) end end)
  return c, (t or 10), p
end
local function barDesc()
  if not S.api then return "Level " .. S.level .. ": ?" end
  local c, t = 0, 10
  if S.api.correct then c, t = S.api.correct() end
  local B = barObj()
  if B and B.describe then local ok, d = pcall(B.describe, S.level, c, t, S.api.snap()) if ok and d then return d end end
  return string.format("Level %d: %d/%d [%s]", S.level, c, t, S.api.snap())
end
local function startLevel(n)
  S.level = math.max(1, math.floor(tonumber(n) or 1))
  S.tlim = M.TIME_LIMIT
  if GP and GP.difficulty then
    local okD, d = pcall(GP.difficulty, S.level)
    if okD and d and d.time then S.tlim = d.time end
  end
  pcall(function() if _G.__ALPHA_TEST_TIMEOUT then S.tlim = _G.__ALPHA_TEST_TIMEOUT end end)
  S.seedN = S.seedN + 1
  local seed = S.seedN * 7919
  pcall(function() seed = seed + (system.getTimer and system.getTimer() or 0) end)
  S.api = BOARD.takeover(S.board, seed, S.level)
  pcall(function() if BLOG and BLOG.onLevel then BLOG.onLevel(S.level) elseif BLOG and BLOG.reset then BLOG.reset("level-" .. S.level) end end)
  pcall(function() if CHT and CHT.onRound then CHT.onRound() end end)
  pcall(function() if SEL and SEL.clear then SEL.clear() end end)
  pcall(function() if OUTL and OUTL ~= SEL and OUTL.clear then OUTL.clear() end end)
  pcall(function() redSync("ok") if RED and RED.reset then RED.reset("level-" .. S.level) end end)
  pcall(function() local B = barObj() if B and B.attach then B.attach(S.board) end end)
  pcall(function() if ROWS and ROWS.geometry then local g = ROWS.geometry(S.level)  end end)
  S.t0 = tNow()
  S.over = false
  S.winLogged = nil
  S.winWaiter, S.winWaitNext = nil, nil
  S.lastT = tNow()
  S.tim = nil
  pcall(function()
    if TIM and TIM.new then S.tim = TIM.new(S.tlim, function() local G = S.Gref if G and not S.over then finishRound(G, false) end end) end
  end)
  HUD.ensure(S.board)
  HUD.ensureZones(S.board, doSlide)
  HUD.show()
  hideNativePanel()
  pcall(function()
    S.volley = (S.volley or 0) + 1
    local tok = S.volley
    if timer and timer.performWithDelay then
      for _, ms in ipairs({ 800, 1600, 3000 }) do
        local delay = ms
        timer.performWithDelay(delay, function()
          pcall(function()
            if tok ~= S.volley then return end
            local G = S.Gref or getG()
            local P = G and G.ProgressBarPanel
            if P ~= nil and P.isVisible ~= nil then P.isVisible = false end
          end)
        end)
      end
    end
  end)
  pcall(function()
    if _G.__ALPHA_TASKBTN_HIDDEN then
      _G.__ALPHA_TASKBTN_HIDDEN = nil
      local G = S.Gref or getG()
      local hideByOS = false
      pcall(function()
        local OS = G and G.OS_Table and G.OS_Current and G.OS_Table[G.OS_Current]
        if OS and OS.HideTaskbarButton then hideByOS = true end
      end)
      if not hideByOS and type(G) == "table" and type(G.UI) == "table" then
        if G.UI.Taskbutton ~= nil and G.UI.Taskbutton.isVisible ~= nil then
          G.UI.Taskbutton.isVisible = true
        end
        if G.UI.TaskbuttonText ~= nil and G.UI.TaskbuttonText.isVisible ~= nil then
          G.UI.TaskbuttonText.isVisible = true
        end
      end
    end
  end)
  pcall(function() if RPHYS and S.level >= 2 and RPHYS.afterHud then RPHYS.afterHud(S.board, HUD.ensure(S.board), S.level, doSlide) end end)
  _G.__ALPHA = { slide = function(c, r) return doSlide(c, r) end,
    snap = function() return S.api.snap() end,
    path = function() return (S.api and S.api.path) or nil end,
    progress = function() local p = nil pcall(function() if BLOG and BLOG.get then p = BLOG.get() end end) if type(p) == "number" then return p end return S.api.progress() end,
    correct = function() return S.api.correct() end,
    moves = function() return S.api.moves end,
    level = function() return S.level end,
    isWin = function() return isWinNow() end,
    sound = function(n) playSound(n) end,
    timeLeft = function() return tLeft() end,
    lose = function() local G = S.Gref or getG() if G and not S.over then finishRound(G, false) end end,
    win = function() local G = S.Gref or getG() if G and not S.over then finishRound(G, true) end end,
    state = function() return S.level, (S.api and S.api.moves or 0), tLeft(), S.over end,
    select = SEL, rows = ROWS, rowsphys = RPHYS, defbar = barObj(), barlogic = BLOG, highlight = HL, gameplay = GP,
    yellow = HL, game = GP, touch = TOUCH, slideMod = SLD, redsq = RED, outline = OUTL,
    red = RED, gref = function() return S.Gref end,
    timer = S.tim, winMod = WIN, loss = LOSS }
  _G.__ALPHA_BAR = { level = S.level, correct = function()
      local c, t = S.api.correct() return c, t end,
    describe = function() return barDesc() end }
  pcall(function()
    local okL, LO = pcall(require, "mod_alpha_layout")
    if okL and LO and LO.applyBoard then LO.applyBoard() end
  end)
end
local function onSlide(c, r) return doSlide(c, r) end
local function finishRound(G, won)
  pcall(function() print("PROGRESSMOD finishRound won=" .. tostring(won) .. " tlim=" .. tostring(S.tlim)) end)
  if S.over then return end
  S.over = true
  S.volley = (S.volley or 0) + 1
  pcall(unwrap)
  if won and WIN and WIN.finalize then
    pcall(function() WIN.finalize(G, { via = "flow", snap = S.api and S.api.snap(), moves = S.api and S.api.moves }) end)
    return
  end
  if (not won) and LOSS and LOSS.finalize then
    pcall(LOSS.finalize, G, "timeout")
    pcall(function() HUD.update(S.api and S.api.progress() or 0, S.api and S.api.moves or 0, 0) end)
    return
  end
  if won then
    playSound("victory")
  else
    HUD.banner("DEFEAT", { 1, 0.35, 0.35 })
    playSound("bsod")
  end
  pcall(function()
    local pw = (G.INI and G.INI.ProgressWidth) or 20
    if won then G.Progress = pw G.ProgressProcent = 1 G.Win = true
    else G.Hearts = 0 G.Win = false end
    G.Stop = true
    if type(G.Duty) == "table" then G.Duty.BlockONOFFButton = true G.Duty.BlockTopMenyKeyControl = true end
  end)
  HUD.update(won and 1 or (S.api and S.api.progress() or 0), S.api and S.api.moves or 0, 0)
  local delay = won and M.WIN_PAUSE or M.LOSS_DELAY
  pcall(function()
    local MA = G.Mode and G.Mode.alphabeth
    if MA then delay = (won and MA.WinPause or MA.GameOverDelay) or delay end
  end)
  pcall(function()
    timer.performWithDelay(delay, function()
      pcall(function()
        if type(G.Break) == "function" then G.Break(won and 1 or 2)
        else  end
      end)
    end)
  end)
end
local function teardown(tag)
  S.winWaiter, S.winWaitNext = nil, nil
  pcall(function() if SEL and SEL.clear then SEL.clear() end end)
  pcall(function() if OUTL and OUTL ~= SEL and OUTL.clear then OUTL.clear() end end)
  pcall(function() if SEL and SEL.hide then SEL.hide() end end)
  pcall(function() if RED and RED.hide then RED.hide() elseif RED and RED.clear then RED.clear() end end)
  pcall(function() if BLOG and BLOG.onExit then BLOG.onExit() end end)
  pcall(function() if S.board and BOARD and BOARD.getCell then for c = 1, 5 do for r = 1, 5 do
    pcall(function() local cell = BOARD.getCell(S.board, c, r) if cell and cell.Yellow then cell.Yellow.isVisible = false end end)
  end end end end)
  pcall(unwrap)
  pcall(function() _G.__ALPHA_TASKBTN_HIDDEN = nil end)
  pcall(showNativePanel)
  HUD.hide(); HUD.dropZones(); S.api, S.board = nil, nil; S.t0, S.over = nil, false
  S.boardCell, S.boardCell2 = nil, nil
  pcall(function() _G.__ALPHA_BOARD = nil end)
  pcall(function() _G.__ALPHA_FLOW_HOLD = nil end)
end
local RL = { tries = 0, broke = false, opened = false, logged = {} }
local function relaunchTick(G, mode)
  if not _G.__ALPHA_WANT_RELAUNCH then return end
  if (S.tick % 120) ~= 0 then return end
  if RL.tries >= 20 then
    _G.__ALPHA_WANT_RELAUNCH = nil
    return
  end
  RL.tries = RL.tries + 1
  local stop = true
  pcall(function() stop = G.Stop end)
  if not stop and not RL.broke then
    RL.broke = true
    pcall(function() if type(G.Break) == "function" then G.Break() end end)
    RL.tries = 0
    return
  end
  local alpha, openers, modesWin = {}, {}, false
  pcall(function()
    if not (display and display.getCurrentStage) then return end
    local function scanUp(fn, want)
      if type(fn) ~= "function" or not (debug and debug.getupvalue) then return false end
      for i = 1, 25 do
        local ok, _, uv = pcall(debug.getupvalue, fn, i)
        if not ok or uv == nil then break end
        if type(uv) == "string" and uv:lower():find(want, 1, true) then return true end
        if type(uv) == "table" then
          local hit = false
          pcall(function()
            local c = 0
            for _, v in pairs(uv) do
              c = c + 1
              if c > 30 then break end
              if type(v) == "string" and v:lower():find(want, 1, true) then hit = true break end
            end
          end)
          if hit then return true end
        end
      end
      return false
    end
    local function walk(o, d)
      if d > 12 or (#alpha >= 5 and #openers >= 5 and modesWin) then return end
      pcall(function()
        local id, txt = nil, nil
        if type(o.ID) == "string" then id = o.ID end
        if o.text ~= nil and type(o.text) == "string" then txt = o.text end
        local tag = tostring(id or "") .. "|" .. tostring(txt or "")
        if tag:lower():find("gamemode", 1, true) then modesWin = true end
        if type(o.Func) == "function" then
          if scanUp(o.Func, "alphabeth") then
            local ld = "?"
            local ok, inf = pcall(debug.getinfo, o.Func, "S")
            if ok and type(inf) == "table" then ld = tostring(inf.linedefined) end
            alpha[#alpha + 1] = { fn = o.Func, line = ld, obj = o }
          elseif scanUp(o.Func, "gamemode") then
            local ld = "?"
            local ok, inf = pcall(debug.getinfo, o.Func, "S")
            if ok and type(inf) == "table" then ld = tostring(inf.linedefined) end
            openers[#openers + 1] = { fn = o.Func, line = ld, obj = o }
          end
        end
      end)
      local nk = 0
      pcall(function() nk = o.numChildren or 0 end)
      for i = 1, (nk or 0) do
        local _, ch = pcall(function() return o[i] end)
        if ch ~= nil then walk(ch, d + 1) end
      end
    end
    walk(display.getCurrentStage(), 0)
  end)
  for _, c in ipairs(alpha) do
    if not RL.logged["a" .. c.line] then RL.logged["a" .. c.line] = true  end
  end
  for _, c in ipairs(openers) do
    if not RL.logged["o" .. c.line] then RL.logged["o" .. c.line] = true  end
  end
  if #alpha > 0 and stop then
    local ok, err = pcall(alpha[1].fn)
    if not ok then
      ok, err = pcall(alpha[1].fn, { phase = "ended", name = "tap", target = alpha[1].obj })
    end
    RL.tries = 0
  elseif #alpha == 0 and not modesWin and #openers > 0 and not RL.opened then
    RL.opened = true
    local ok, err = pcall(openers[1].fn)
    if not ok then
      ok, err = pcall(openers[1].fn, { phase = "ended", name = "tap", target = openers[1].obj })
    end
    RL.tries = 0
  else
  end
end
local function onFrame()
  S.tick = S.tick + 1
  local G = getGC()
  if not G or not (BOARD and HUD) then return end
  S.Gref = G
  if S.tick - S.landT > 300 then
    S.landT = S.tick
    local pw, ph = 0, 0
    pcall(function() pw = display.pixelWidth or 0 ph = display.pixelHeight or 0 end)
    if pw > 0 and pw < ph then HUD.landscape("watchdog", M.LAND_W, M.LAND_H) end
  end
  if S.tick % 15 ~= 0 then return end
  local mode = nil
  pcall(function() mode = G.ModeCurrent end)
  if mode ~= "alphabeth" then
    if S.modeSeen == "alphabeth" then teardown("EXIT alphabeth") end
    S.modeSeen = mode
    S.Gseen, S.wasStop = G, nil
    pcall(function() relaunchTick(G, mode) end)
    return
  end
  if S.modeSeen ~= "alphabeth" then
    pcall(function()
      if _G.__ALPHA_WANT_RELAUNCH then
        _G.__ALPHA_WANT_RELAUNCH = nil
      end
    end)
    pcall(function() if WIN and WIN.reset then WIN.reset("enter-alphabeth") end end)
    pcall(function() if LOSS and LOSS.reset then LOSS.reset("enter-alphabeth") end end)
    pcall(function() if RED and RED.reset then RED.reset("enter-alphabeth") end end)
    HUD.landscape("enter", M.LAND_W, M.LAND_H)
  end
  S.modeSeen = mode
  pcall(function()
    if S.winWaiter ~= nil then
      local now = tNow()
      if now >= (S.winWaitNext or 0) then
        S.winWaitNext = now + 2
        pcall(S.winWaiter)
      end
    end
  end)
  local stop = true
  pcall(function() stop = G.Stop end)
  do
    local gChanged = (S.Gseen ~= nil and S.Gseen ~= G)
    local needReset, why = false, nil
    if gChanged and S.api then
      needReset, why = true, "new-G (reboot/reload)"
    end
    if not needReset and S.over and S.wasStop == true and stop == false then
      needReset, why = true, "Stop true->false post-end (retry)"
    end
    if not needReset and S.api and S.board and S.boardCell ~= nil and not stop then
      local c1, c2 = nil, nil
      pcall(function()
        if BOARD and BOARD.find then
          local f = BOARD.find()
          if type(f) == "table" and #f > 0 and f[1].board then
            local b0 = f[1].board
            if b0[2] then c1 = b0[2][2] end
            if b0[3] then c2 = b0[3][2] end
          end
        end
      end)
      if c1 ~= nil and (c1 ~= S.boardCell or c2 ~= S.boardCell2) then
        needReset, why = true, "new-board"
      end
    end
    if needReset then
      local keepLv = tonumber(S.level) or tonumber(_G.__ALPHA_LEVEL) or 3
      if keepLv < 3 then keepLv = 3 end
      pcall(function() if WIN and WIN.reset then WIN.reset("restart-modo") end end)
      pcall(function() if LOSS and LOSS.reset then LOSS.reset("restart-modo") end end)
      pcall(function() if RED and RED.reset then RED.reset("restart-modo") end end)
      pcall(function() if BLOG and BLOG.reset then BLOG.reset("restart-modo") end end)
      pcall(function() if HUD and HUD.dropZones then HUD.dropZones() end end)
      S.api, S.board, S.t0, S.tim = nil, nil, nil, nil
      S.over = false
      S.boardCell, S.boardCell2 = nil, nil
      pcall(function() _G.__ALPHA_FLOW_HOLD = nil end)
      pcall(function() _G.__ALPHA_BOARD = nil end)
      pcall(function() _G.__ALPHA_LEVEL = keepLv end)
    end
    S.Gseen, S.wasStop = G, stop
  end
  if stop then
    if S.api then HUD.update(S.api.progress(), S.api.moves, M.TIME_LIMIT) end
    return
  end
  if not S.api then
    local found = BOARD.find()
    if #found == 0 then return end
    S.board = found[1].board
    pcall(function() _G.__ALPHA_BOARD = S.board end)
    pcall(function()
      if S.board[2] then S.boardCell = S.board[2][2] end
      if S.board[3] then S.boardCell2 = S.board[3][2] end
    end)
    wrap(S.board)
    local lv0 = 3
    pcall(function()
      local c = tonumber(_G.__ALPHA_LEVEL) or 0
      if c >= 3 then lv0 = math.floor(c) end
    end)
    startLevel(lv0)
  end
  if not S.t0 then S.t0 = tNow()  end
  local now = tNow()
  if S.lastT and S.tim and TIM and TIM.update then
    local dt = (now - (S.lastT or now)) / 1000
    if dt < 0 then dt = 0 end
    if dt > 5 then dt = 5 end
    pcall(TIM.update, S.tim, dt)
    pcall(TIM.syncMoves, S.tim)
  end
  S.lastT = now
  local el = 0
  pcall(function() el = ((system.getTimer and system.getTimer() or 0) - (S.t0 or 0)) / 1000 end)
  local lim = _G.__ALPHA_TEST_TIMEOUT or S.tlim or M.TIME_LIMIT
  local c, t, p = barPush(G)
  HUD.update(p, S.api.moves, tLeft())
  pcall(function()
    if S.api and S.api.refresh and not S.over and S.tick % 60 == 0 then
      S.api.refresh()
    end
  end)
  pcall(function()
    if S.board and not S.over and S.tick % 300 == 0 then
      HUD.ensureZones(S.board, doSlide)
    end
  end)
  pcall(function()
    if S.api and not S.over and S.tick % 300 == 0 then
      local pv, wv, cc, tt, st = nil, nil, 0, 0, true
      pcall(function() pv = S.api.progress() end)
      pcall(function() wv = S.api.isWin() end)
      pcall(function() if S.api.correct then cc, tt = S.api.correct() end end)
      pcall(function() st = G.Stop end)
      print("PROGRESSMOD flowtick level=" .. tostring(S.level) .. " p=" .. tostring(pv) ..
        " iswin=" .. tostring(wv) .. " correct=" .. tostring(cc) .. "/" .. tostring(tt) ..
        " stop=" .. tostring(st))
    end
  end)
  pcall(function()
    if S.api and not S.over and S.tick % 180 == 0 then
      if S.api.janitor then S.api.janitor() end
      if S.api.hideReal then S.api.hideReal() end
    end
  end)
  local timOver = false
  pcall(function() if S.tim and TIM and TIM.isOver then timOver = TIM.isOver(S.tim) end end)
  pcall(function()
    if S.api and S.api.progress and not S.over and S.winLogged ~= S.level then
      local okp, pv = pcall(S.api.progress)
      if okp and type(pv) == "number" and pv >= 0.99 then
        S.winLogged = S.level
        local okw, wv = pcall(function() return S.api.isWin() end)
        local cc, tt = 0, 0
        pcall(function() if S.api.correct then cc, tt = S.api.correct() end end)
        local st = true
        pcall(function() st = G.Stop end)
        print("PROGRESSMOD nearwin level=" .. tostring(S.level) .. " p=" .. tostring(pv) ..
          " iswin=" .. tostring(wv) .. " correct=" .. tostring(cc) .. "/" .. tostring(tt) ..
          " over=" .. tostring(S.over) .. " stop=" .. tostring(st))
      end
    end
  end)
  if isWinNow() and not S.over then
    pcall(function() print("PROGRESSMOD onwin level=" .. tostring(S.level)) end)
    if S.level < 99 then onWin(G)
    else finishRound(G, true) end
  elseif (timOver or (S.t0 and el >= lim)) and not S.over then finishRound(G, false) end
end
onWin = function(G)
  S.over = true
  S.volley = (S.volley or 0) + 1
  pcall(unwrap)
  pcall(showNativePanel)
      local Gc, nl, moves, lv = G, S.level + 1, (S.api and S.api.moves or 0), S.level
      pcall(function() _G.__ALPHA_FLOW_HOLD = true end)
      pcall(function()
        local pw = (Gc.INI and Gc.INI.ProgressWidth) or 20
        Gc.Progress, Gc.ProgressProcent = pw, 1
      end)
      pcall(function() HUD.update(1, moves, tLeft()) end)
      local rwOk, rwErr = false, "n/a"
      pcall(function()
        local f = nil
        local F = _G.__WINREAL_FOUND
        if not (type(F) == "table" and type(F.win) == "function") then
          local W = _G.__WINREAL_MIN
          if type(W) == "table" and type(W.find) == "function" then
            W.find()
          end
          F = _G.__WINREAL_FOUND
        end
        if type(F) == "table" and type(F.win) == "function" then f = F.win end
        if type(f) == "function" then
          local okC, errC = pcall(f)
          if okC then
            rwOk, rwErr = true, "dyn"
            pcall(function() print("PROGRESSMOD win via real") end)
          else
            rwErr = tostring(errC)
          end
        else
          rwErr = "no-handle"
        end
      end)
      local delay = M.WIN_PAUSE
      pcall(function()
        local MA = Gc.Mode and Gc.Mode.alphabeth
        if MA and MA.WinPause then delay = MA.WinPause end
      end)
      local stage0, mode0, done = nil, nil, false
      pcall(function() stage0, mode0 = Gc.Stage, Gc.ModeCurrent end)
      local function stillHere()
        local cur = nil
        pcall(function() cur = Gc.ModeCurrent end)
        return cur == mode0
      end
      local function advance(tag)
        if done then return end
        done = true
        S.winWaiter, S.winWaitNext = nil, nil
        pcall(function() print("PROGRESSMOD win advance " .. tostring(tag)) end)
        pcall(function() _G.__ALPHA_FLOW_HOLD = nil end)
        pcall(function() if WIN and WIN.reset then WIN.reset("postgame-next") end end)
        if not stillHere() then
          pcall(function() teardown("postgame-exit") end)
          RL.tries, RL.broke, RL.opened = 0, false, false
          _G.__ALPHA_WANT_RELAUNCH = true
          return
        end
        pcall(function()
          Gc.Stop, Gc.Win = false, false
          if type(Gc.Duty) == "table" then
            Gc.Duty.BlockONOFFButton, Gc.Duty.BlockTopMenyKeyControl = false, false
          end
        end)
        pcall(function() _G.__ALPHA_LEVEL = nl end)
        startLevel(nl)
      end
      local function snapState()
        local m, st, sp, wn, pg, wiz = nil, nil, nil, nil, "?", "?"
        pcall(function()
          m, st = Gc.ModeCurrent, Gc.Stage
          sp, wn = Gc.Stop, Gc.Win
          local P = Gc.UI and Gc.UI.PostGamePanel
          if P == nil then pg = "nil"
          elseif P.isVisible == false then pg = "hidden"
          elseif P.isVisible == true then pg = "visible"
          end
          if Gc.Duty then wiz = Gc.Duty.WizardIndex end
        end)
        return m, st, sp, wn, pg, wiz
      end
      local sniffed = {}
      local function sniffFn(tag, fn)
        if type(fn) ~= "function" or sniffed[fn] then return end
        sniffed[fn] = true
        local info = "?"
        if debug and debug.getinfo then
          local ok, inf = pcall(debug.getinfo, fn, "S")
          if ok and type(inf) == "table" then
            info = tostring(inf.linedefined) .. "-" .. tostring(inf.lastlinedefined)
          end
        end
        local ups = {}
        if debug and debug.getupvalue then
          for i = 1, 30 do
            local ok, nm, uv = pcall(debug.getupvalue, fn, i)
            if not ok or nm == nil then break end
            local t = type(uv)
            if t == "string" or t == "number" or t == "boolean" then
              ups[#ups + 1] = tostring(nm) .. "=" .. tostring(uv):sub(1, 40)
            elseif t == "function" then
              local ld = "?"
              local ok2, inf2 = pcall(debug.getinfo, uv, "S")
              if ok2 and type(inf2) == "table" then ld = tostring(inf2.linedefined) end
              ups[#ups + 1] = tostring(nm) .. "=fn:" .. ld
            else
              ups[#ups + 1] = tostring(nm) .. ":" .. t
            end
            if #ups >= 12 then break end
          end
        end
      end
      local function sniffPostGame()
        pcall(function()
          local PB = Gc.Duty and Gc.Duty.PBasic
          if type(PB) == "table" then
            for _, k in ipairs({ "AnyKeyFunction", "AlmostAnyKeyFunc" }) do
              sniffFn("PB." .. k, PB[k])
            end
          end
        end)
        pcall(function()
          if not (display and Gc.UI and Gc.UI.PostGamePanel) then return end
          local panel = Gc.UI.PostGamePanel
          local nBtn = 0
          local function walk(o, d)
            if d > 8 or nBtn >= 10 then return end
            pcall(function()
              if type(o.Func) == "function" then
                nBtn = nBtn + 1
                sniffFn("btn" .. nBtn .. ".Func", o.Func)
              end
            end)
            local nk = 0
            pcall(function() nk = o.numChildren or 0 end)
            for i = 1, (nk or 0) do
              local _, ch = pcall(function() return o[i] end)
              if ch ~= nil then walk(ch, d + 1) end
            end
          end
          walk(panel, 0)
        end)
      end
      local waits = 0
      local seenPg, triedPost = false, false
      local function waiter()
        if done then return end
        if not stillHere() then
          local m, st = snapState()
          advance("left-mode")
          return
        end
        waits = waits + 1
        local m, st, sp, wn, pg, wiz = snapState()
        if pg == "visible" and not seenPg then
          seenPg = true
          pcall(function() print("PROGRESSMOD win panel visible") end)
        end
        pcall(function() sniffPostGame() end)
        if not seenPg and not triedPost and waits >= 6 then
          triedPost = true
          pcall(function()
            local F = _G.__WINREAL_FOUND
            local f = F and F.putpost
            if type(f) ~= "function" then f = F and F.gamewin end
            if type(f) == "function" then
              local ok = pcall(f)
              print("PROGRESSMOD win trypost " .. tostring(ok))
            else
              print("PROGRESSMOD win trypost none")
            end
          end)
        end
        if seenPg and sp == false and (pg == "nil" or pg == "hidden") then
          advance("pos-postgame")
          return
        end
        if waits >= 20 then
          advance("timeout")
          return
        end
      end
      S.winWaiter = waiter
      S.winWaitNext = tNow() + (delay + 1500) / 1000
end
function M.start()
  if S.started then return true end
  S.started = true
  pcall(function() Runtime:addEventListener("enterFrame", onFrame)  end)
  pcall(function() timer.performWithDelay(2000, function() HUD.landscape("boot+2s", M.LAND_W, M.LAND_H) end) end)
  return true
end
  return M
end)()
package.loaded["mod_alpha_flow"] = flow
return {
  ["mod_alpha_timer"] = timer,
  ["mod_alpha_touch"] = touch,
  ["mod_alpha_vslide"] = vslide,
  ["mod_alpha_gbridge"] = gbridge,
  ["mod_alpha_cheat"] = cheat,
  ["mod_alpha_flow"] = flow,
}
