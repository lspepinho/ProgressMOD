local win = (function()
local M = {}
M.id = "alpha-win-v1"
M.WIN_PAUSE = 2000
M.POINTS_MULT = 1.5
M.N = 10
M.LOGF = "mod_alpha_hud.log"
local HUD, FIN, GP, BOARD = nil, nil, nil, nil
pcall(function() local ok, m = pcall(require, "mod_alpha_hud") if ok and m then HUD = m end end)
pcall(function() local ok, m = pcall(require, "mod_alpha_finish") if ok and m then FIN = m end end)
pcall(function() local ok, m = pcall(require, "mod_alpha_gameplay") if ok and m then GP = m end end)
pcall(function() local ok, m = pcall(require, "mod_alpha_board") if ok and m then BOARD = m end end)
local S = { over = false, breakCalled = false, winMoves = 0, snap = "?", via = nil, modeSeen = nil, tick = 0 }
local function getG()
  local G = nil
  pcall(function() local _, g = debug.getupvalue(onHoverTouch, 1) G = g end)
  return G
end
local _gc, _gn = nil, 0
local function getGC()
  _gn = _gn + 1
  if _gc == nil or _gn % 6 == 1 then
    local g = getG()
    if g ~= nil then _gc = g end
  end
  return _gc
end
function M.resolveDelay(G)
  local d = M.WIN_PAUSE
  pcall(function() local MA = G and G.Mode and G.Mode.alphabeth if MA and MA.WinPause then d = MA.WinPause end end)
  pcall(function() if _G.__ALPHA_TEST_DELAY then d = _G.__ALPHA_TEST_DELAY end end)
  d = tonumber(d) or M.WIN_PAUSE
  if d < 0 then d = 0 end
  return d
end
function M.resolveMult(G)
  local m = M.POINTS_MULT
  pcall(function() local MA = G and G.Mode and G.Mode.alphabeth if MA and MA.PointsMultiplier then m = MA.PointsMultiplier end end)
  m = tonumber(m) or M.POINTS_MULT
  if m <= 0 then m = M.POINTS_MULT end
  return m
end
local function isLossOver()
  local over = false
  pcall(function() local L = _G.__ALPHA_LOSS if L and type(L.isOver) == "function" then over = L.isOver() end end)
  return over == true
end
local function banner(t, rgb)
  pcall(function() if HUD and HUD.banner then HUD.banner(t, rgb) end end)
end
local function hudUpdate(p, moves, left)
  pcall(function() if HUD and HUD.update then HUD.update(p, moves, left) end end)
end
function M.target(level)
  local t = nil
  pcall(function() if GP and GP.target then t = GP.target(level or 1) end end)
  if type(t) ~= "table" then pcall(function() if FIN and FIN.target then t = FIN.target(level or 1) end end) end
  if type(t) ~= "table" then t = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "" } end
  return t
end
function M.isOrdered(shadow, level)
  if type(shadow) ~= "table" then return false end
  local t = M.target(level or 1)
  for i = 1, M.N do local s = shadow[i] if s ~= t[i] then return false end end
  return true
end
function M.snapOf(shadow)
  local t = {}
  for i = 1, M.N do local s = shadow[i] t[#t + 1] = (s == "" or s == nil) and "_" or tostring(s) end
  return table.concat(t)
end
function M.checkApi(api)
  if type(api) ~= "table" then return false end
  local w = nil
  pcall(function() if type(api.isWin) == "function" then w = api.isWin() end end)
  if w ~= nil then return w == true end
  pcall(function() if type(api.progress) == "function" then local p = api.progress() if type(p) == "number" then w = (p >= 1.0) end end end)
  return w == true
end
local function pumpBreak(forceG)
  pcall(function()
    if not (S.over and not S.breakCalled and S.breakT0 ~= nil) then return end
    local now = 0
    pcall(function() if system and system.getTimer then now = system.getTimer() / 1000 end end)
    if now - (S.breakT0 or 0) < (tonumber(S.breakDelay) or 2000) / 1000 then return end
    local G = forceG or getG()
    if type(G) ~= "table" then return end
    local cur = nil
    pcall(function() cur = G.ModeCurrent end)
    if cur ~= nil and cur ~= "alphabeth" then return end
    if type(G.Break) ~= "function" then
      if not S.breakFailLogged then
        S.breakFailLogged = true
        pcall(function() print("PROGRESSMOD winbreak no-Break") end)
      end
      return
    end
    local fired = nil
    for _, args in ipairs({ { 1 }, {}, { true } }) do
      local ok = pcall(function() if #args == 0 then G.Break() else G.Break(args[1]) end end)
      if ok then fired = (#args == 0) and "Break()" or ("Break(" .. tostring(args[1]) .. ")") break end
    end
    if fired then
      S.breakCalled = true
      pcall(function() print("PROGRESSMOD winbreak " .. tostring(fired)) end)
    elseif not S.breakFailLogged then
      S.breakFailLogged = true
      pcall(function() print("PROGRESSMOD winbreak FAILED") end)
    end
  end)
end
local function applyScore(G)
  local mult = M.resolveMult(G)
  pcall(function()
    if type(G) ~= "table" then return end
    for _, k in ipairs({ "Wins", "wins", "WinCount", "winCount" }) do
      pcall(function() if type(G[k]) == "number" then G[k] = G[k] + 1 end end)
      if type(G[k]) == "number" then return end
    end
    pcall(function() if G.Wins == nil and G.wins == nil then G.Wins = 1 end end)
  end)
  pcall(function()
    if type(G) ~= "table" then return end
    for _, k in ipairs({ "Points", "points", "Score", "score" }) do
      local v = G[k]
      if type(v) == "number" then
        G[k] = v * mult
        return
      end
    end
  end)
end
function M.finalize(G, info)
  S.fcount = (S.fcount or 0) + 1
  pcall(function() print("PROGRESSMOD finalize win over=" .. tostring(S.over) .. " self=" .. tostring(S) .. " n=" .. tostring(S.fcount)) end)
  local hold = false
  pcall(function() hold = _G.__ALPHA_FLOW_HOLD == true end)
  if hold then
    if not S.fedBack then
      S.fedBack = true
      banner("VICTORY!", { 0.4, 1, 0.4 })
      pcall(function() local A = _G.__ALPHA if A and type(A.sound) == "function" then A.sound("victory") end end)
      pcall(function()
        local pw = 20
        if G.INI and G.INI.ProgressWidth then pw = G.INI.ProgressWidth end
        G.Progress, G.ProgressProcent = pw, 1
      end)
      hudUpdate(1, S.winMoves, 0)
    end
    if not S.breakArmed then
      S.breakArmed = true
      S.breakT0 = 0
      pcall(function() if system and system.getTimer then S.breakT0 = system.getTimer() / 1000 end end)
      S.breakDelay = M.resolveDelay(G)
    end
    return false
  end
  if S.over then return false end
  if isLossOver() then  return false end
  if type(G) ~= "table" then  return false end
  S.over = true
  info = (type(info) == "table") and info or {}
  S.via = info.via or "?"
  S.snap = info.snap or "?"
  local moves = info.moves
  if moves == nil then pcall(function() local A = _G.__ALPHA if A and type(A.moves) == "function" then moves = A.moves() end end) end
  S.winMoves = tonumber(moves) or 0
  pcall(function() local A = _G.__ALPHA if A and type(A.sound) == "function" then A.sound("victory") end end)
  pcall(function()
    local pw = 20
    if G.INI and G.INI.ProgressWidth then pw = G.INI.ProgressWidth end
    G.Progress, G.ProgressProcent, G.Win, G.Stop = pw, 1, true, true
    if type(G.Duty) == "table" then G.Duty.BlockONOFFButton, G.Duty.BlockTopMenyKeyControl = true, true end
  end)
  applyScore(G)
  hudUpdate(1, S.winMoves, 0)
  if not S.breakArmed then
    S.breakArmed = true
    S.breakT0 = 0
    pcall(function() if system and system.getTimer then S.breakT0 = system.getTimer() / 1000 end end)
    S.breakDelay = M.resolveDelay(G)
  end
  pcall(function() _G.__ALPHA_WIN_DONE = true end)
  return true
end
function M.isOver() return S.over end
function M.breakCalled() return S.breakCalled end
function M.reset(tag)
  pcall(function() print("PROGRESSMOD winreset " .. tostring(tag)) end)
  S.over, S.breakCalled, S.winMoves, S.snap, S.via = false, false, 0, "?", nil
  S.breakArmed, S.breakT0, S.breakDelay, S.breakFailLogged, S.fedBack = nil, nil, nil, nil, nil
  pcall(function() _G.__ALPHA_WIN_DONE = nil end)
  return true
end
local function readShadow()
  local sh = nil
  pcall(function()
    if not (BOARD and BOARD.find and BOARD.getCell and BOARD.cellSym) then return end
    local found = BOARD.find()
    if type(found) ~= "table" or #found == 0 then return end
    local b = found[1].board
    if type(b) ~= "table" then return end
    local t = {}
    for i = 1, M.N do
      local cell = BOARD.getCell(b, ((i - 1) % 5) + 1, math.floor((i - 1) / 5) + 1)
      if cell == nil then return end
      local s = BOARD.cellSym(cell)
      if s == nil then return end
      t[i] = s
    end
    sh = t
  end)
  return sh
end
local function currentLevel()
  local lv = nil
  pcall(function() local A = _G.__ALPHA if A and type(A.level) == "function" then lv = A.level() end end)
  return tonumber(lv) or 1
end
local function onFrame()
  local G = getGC()
  if not G then return end
  local mode = nil
  pcall(function() mode = G.ModeCurrent end)
  if mode ~= "alphabeth" then
    if S.modeSeen == "alphabeth" then M.reset("exit-alphabeth") end
    S.modeSeen = mode
    return
  end
  S.modeSeen = mode
  pcall(function() pumpBreak() end)
  local stop = true
  pcall(function() stop = G.Stop end)
  if stop or S.over or isLossOver() then return end
  S.tick = S.tick + 1
  if S.tick % 30 ~= 0 then return end
  local ordered, via, snap, moves = false, nil, nil, nil
  pcall(function()
    local A = _G.__ALPHA
    if type(A) == "table" then
      local w = nil
      if type(A.isWin) == "function" then w = A.isWin() end
      if w == nil and type(A.progress) == "function" then local p = A.progress() if type(p) == "number" then w = (p >= 1.0) end end
      if w == true then ordered, via = true, "flow" end
      if type(A.snap) == "function" then snap = A.snap() end
      if type(A.moves) == "function" then moves = A.moves() elseif type(A.moves) == "number" then moves = A.moves end
    end
  end)
  if not ordered then
    pcall(function()
      local sh = readShadow()
      if sh then
        if M.isOrdered(sh, currentLevel()) then ordered, via = true, "scan" end
        snap = M.snapOf(sh)
      end
    end)
  end
  if ordered then
    pcall(function() print("PROGRESSMOD winordered via=" .. tostring(via) .. " snap=" .. tostring(snap)) end)
    M.finalize(G, { via = via, snap = snap, moves = moves, level = currentLevel() })
  end
end
function M.install()
  if S.hooked then return true end
  S.hooked = true
  pcall(function()
    if Runtime and Runtime.addEventListener then Runtime:addEventListener("enterFrame", onFrame)
    else  end
  end)
  _G.__ALPHA_WIN = { finalize = function(g, i) return M.finalize(g, i) end, isOrdered = function(s, l) return M.isOrdered(s, l) end,
    checkApi = function(a) return M.checkApi(a) end, isOver = function() return M.isOver() end,
    breakCalled = function() return M.breakCalled() end, reset = function(t) return M.reset(t) end,
    winPause = function(g) return M.resolveDelay(g) end }
  return true
end
function M.selftest()
  local saveD, saveT, saveL = _G.__ALPHA_TEST_DELAY, timer, _G.__ALPHA_LOSS
  _G.__ALPHA_LOSS = nil
  local calls = {}
  local G = { Hearts = 3, Wins = 0, Points = 100, Win = false, Stop = false, Duty = {},
    Mode = { alphabeth = { WinPause = 2000, PointsMultiplier = 1.5 } }, INI = { ProgressWidth = 20 } }
  G.Break = function(a) calls[#calls + 1] = a end
  timer = { performWithDelay = function(d, f) calls.delay = d pcall(f) return true end }
  assert(M.resolveDelay(G) == 2000, "WinPause 2000")
  assert(M.resolveMult(G) == 1.5, "mult 1.5")
  assert(M.isOrdered({ "A", "B", "C", "D", "E", "F", "G", "H", "I", "" }, 1) == true, "order wins")
  assert(M.isOrdered({ "B", "A", "C", "D", "E", "F", "G", "H", "I", "" }, 1) == false, "outside does not win")
  assert(M.isOrdered(nil, 1) == false, "nil does not win")
  assert(M.checkApi({ isWin = function() return true end }) == true, "api win")
  assert(M.checkApi({ progress = function() return 1 end }) == true, "api p=1")
  assert(M.checkApi(nil) == false, "nil api does not win")
  assert(M.finalize(G, { via = "selftest", snap = "ABCDEFGHI_", moves = 12 }) == true, "fires")
  assert(G.Win == true and G.Stop == true, "Win/Stop")
  assert(G.Progress == 20 and G.ProgressProcent == 1, "full bar")
  assert(G.Wins == 1 and G.Points == 150, "1.5x")
  assert(G.Duty.BlockONOFFButton == true, "buttons")
  S.breakT0 = (S.breakT0 or 0) - 10
  pumpBreak(G)
  assert(calls[1] == 1, "Break(1) after WinPause")
  assert(M.finalize(G, {}) == false, "idempotente")
  assert(#calls == 1, "Break 1x")
  M.reset("t")
  _G.__ALPHA_LOSS = { isOver = function() return true end }
  local G2 = { Stop = false, Duty = {} }
  G2.Break = function() end
  assert(M.finalize(G2, {}) == false, "mutex LOSS")
  assert(not M.isOver(), "no over in mutex")
  M.reset("t2")
  _G.__ALPHA_LOSS = nil
  local G3 = { Stop = false, Duty = {} }
  local n = 0
  G3.Break = function(a) n = n + 1 if a == 1 then error("bad") end end
  assert(M.finalize(G3, {}) == true, "fires w/ fallback")
  S.breakT0 = (S.breakT0 or 0) - 10
  pumpBreak(G3)
  assert(n == 2, "Break() no fallback")
  M.reset("end")
  _G.__ALPHA_TEST_DELAY = saveD
  if saveT == nil then timer = nil else timer = saveT end
  _G.__ALPHA_LOSS = saveL
  return "WIN_OK order+stop+break1+score1.5x+idempotent"
end
  return M
end)()
package.loaded["mod_alpha_win"] = win
local loss = (function()
local M = {}
M.id = "alpha-loss-v1"
M.TIME_LIMIT = 1200
M.LOSS_DELAY = 1000
M.MAX_HEARTS = 3
local HUD = nil
pcall(function()
  local ok, m = pcall(require, "mod_alpha_hud")
  if ok and m then HUD = m end
end)
local S = { over = false, reason = nil, breakCalled = false,
  t0 = nil, modeSeen = nil }
local function getG()
  local G = nil
  pcall(function()
    local _, g = debug.getupvalue(onHoverTouch, 1)
    G = g
  end)
  return G
end
local _gc, _gn = nil, 0
local function getGC()
  _gn = _gn + 1
  if _gc == nil or _gn % 6 == 1 then
    local g = getG()
    if g ~= nil then _gc = g end
  end
  return _gc
end
function M.resolveDelay(G)
  local d = M.LOSS_DELAY
  pcall(function()
    local MA = G and G.Mode and G.Mode.alphabeth
    if MA and MA.GameOverDelay then d = MA.GameOverDelay end
  end)
  if _G.__ALPHA_TEST_DELAY then d = _G.__ALPHA_TEST_DELAY end
  d = tonumber(d) or M.LOSS_DELAY
  if d < 0 then d = 0 end
  return d
end
function M.resolveLimit()
  local lim = M.TIME_LIMIT
  pcall(function()
    if _G.__ALPHA_TEST_TIMEOUT then lim = _G.__ALPHA_TEST_TIMEOUT end
  end)
  lim = tonumber(lim) or M.TIME_LIMIT
  if lim < 0 then lim = 0 end
  return lim
end
local function banner(text, rgb)
  pcall(function()
    if HUD and HUD.banner then HUD.banner(text, rgb) end
  end)
end
local function hudUpdate(p, moves, left)
  pcall(function()
    if HUD and HUD.update then HUD.update(p, moves, left) end
  end)
end
local function scheduleBreak(G, delay, reason)
  local function fire()
    local okB = type(G) == "table" and type(G.Break) == "function"
    if not okB then
      pcall(function() print("PROGRESSMOD winbreak no-Break") end)
      return
    end
    local fired = nil
    for _, args in ipairs({ { 2 }, {}, { false } }) do
      local ok = pcall(function()
        if #args == 0 then G.Break() else G.Break(args[1]) end
      end)
      if ok then fired = (#args == 0) and "Break()" or ("Break(" .. tostring(args[1]) .. ")") break end
    end
    if fired then
      S.breakCalled = true
    else
    end
  end
  local hasTimer = false
  pcall(function()
    hasTimer = (timer and timer.performWithDelay) and true or false
  end)
  if hasTimer then
    if not pcall(function() timer.performWithDelay(delay, fire) end) then
      pcall(fire)
    end
  else
    pcall(fire)
  end
end
function M.finalize(G, reason)
  if S.over then return false end
  S.over = true
  S.reason = reason or "timeout"
  reason = S.reason
  pcall(function()
    local F = _G.__WINREAL_FOUND
    if not (type(F) == "table" and type(F.prelude) == "function") then
      local W = _G.__WINREAL_MIN
      if type(W) == "table" and type(W.find) == "function" then
        W.find()
      end
    end
  end)
  local realOk, realErr = false, "n/a"
  pcall(function()
    local F = _G.__WINREAL_FOUND
    local f = F and F.prelude
    if type(f) == "function" then
      local okC, errC = pcall(f)
      if okC then
        _G.__ALPHA_REAL_BSOD = true
        realOk = true
        pcall(function() print("PROGRESSMOD loss via real BSOD") end)
      else
        realErr = tostring(errC)
      end
    else
      realErr = "no-handle"
    end
  end)
  if not realOk then
    banner("DEFEAT", { 1, 0.35, 0.35 })
    pcall(function()  end)
    pcall(function() if type(S.snd) == "function" then S.snd("CatchReds") end end)
    pcall(function()
      local A = _G.__ALPHA
      if A and type(A.sound) == "function" then A.sound("CatchReds") end
    end)
    pcall(function() if type(S.snd) == "function" then S.snd("bsod") end end)
    pcall(function()
      local A = _G.__ALPHA
      if A and type(A.sound) == "function" then A.sound("bsod") end
    end)
    pcall(function()
      if type(G) == "table" and G.UI and G.UI.ProgressBarText then
        G.UI.ProgressBarText.text = "Error"
      end
    end)
    pcall(function()
      if audio and audio.pause then audio.pause(4) end
    end)
  end
  pcall(function()
    if type(G) ~= "table" then return end
    G.Hearts = 0
    local bumped = false
    for _, k in ipairs({ "Fails", "Fail", "fails", "FailsCount", "Losses", "losses" }) do
      pcall(function()
        if type(G[k]) == "number" then G[k] = G[k] + 1 bumped = true end
      end)
      if bumped then break end
    end
    if not bumped then
      pcall(function()
        if G.Fails == nil and G.Fail == nil then G.Fails = 1 end
      end)
    end
    G.Win = false
    G.Stop = true
    if type(G.Duty) == "table" then
      G.Duty.BlockONOFFButton = true
      G.Duty.BlockTopMenyKeyControl = true
    end
  end)
  pcall(function()
    if type(G) == "table" and type(G.UI) == "table" then
      if G.UI.Taskbutton ~= nil and G.UI.Taskbutton.isVisible ~= nil then
        G.UI.Taskbutton.isVisible = false
      end
      if G.UI.TaskbuttonText ~= nil and G.UI.TaskbuttonText.isVisible ~= nil then
        G.UI.TaskbuttonText.isVisible = false
      end
      _G.__ALPHA_TASKBTN_HIDDEN = true
    end
  end)
  pcall(function()
    local G2 = G or getG()
    local P = G2 and G2.ProgressBarPanel
    if P ~= nil and P.isVisible ~= nil then P.isVisible = false end
  end)
  hudUpdate(0, 0, 0)
  local delay = M.LOSS_DELAY
  pcall(function() delay = M.resolveDelay(G) end)
  if realOk then delay = delay + 2500 end
  if type(G) == "table" then scheduleBreak(G, delay, reason)
  else  end
  return true
end
function M.loseHeart(G)
  if S.over then return false end
  local h = nil
  pcall(function() if type(G) == "table" then h = G.Hearts end end)
  if type(h) ~= "number" then
    pcall(function() if type(G) == "table" then G.Hearts = M.MAX_HEARTS - 1 end end)
    h = M.MAX_HEARTS - 1
  else
    pcall(function() G.Hearts = math.max(0, h - 1) end)
  end
  local now = M.MAX_HEARTS - 1
  pcall(function() now = G.Hearts end)
  if now <= 0 then
    local saved = false
    pcall(function()
      if type(G) == "table" and type(G.Duty) == "table" and
          G.Duty.ExtraHeart == true then
        G.Duty.ExtraHeart = false
        local mh = M.MAX_HEARTS
        pcall(function()
          local MA = G.Mode and G.Mode.alphabeth
          if MA and MA.MaxHearts then mh = MA.MaxHearts end
        end)
        mh = tonumber(mh) or M.MAX_HEARTS
        G.Hearts = mh
        saved = true
      end
    end)
    if not saved then return M.finalize(G, "hearts") end
  end
  return true
end
function M.onWrongMove(G) return M.loseHeart(G) end
function M.isOver() return S.over end
function M.reason() return S.reason end
function M.breakCalled() return S.breakCalled end
function M.reset(tag)
  S.over, S.reason, S.breakCalled, S.t0 = false, nil, false, nil
  pcall(function() _G.__ALPHA_REAL_BSOD = nil end)
  return true
end
local function elapsed()
  local el = nil
  pcall(function()
    if _G.__ALPHA and _G.__ALPHA.timeLeft then
      local left = _G.__ALPHA.timeLeft()
      if type(left) == "number" then el = M.resolveLimit() - left end
    end
  end)
  if el ~= nil then return el end
  local now = nil
  pcall(function()
    if system and system.getTimer then now = system.getTimer() / 1000 end
  end)
  if now ~= nil and S.t0 ~= nil then return now - S.t0 end
  return 0
end
local function onFrame()
  S.frameThrottle = (S.frameThrottle or 0) + 1
  if S.frameThrottle % 30 ~= 0 then return end
  local G = getGC()
  if not G then return end
  local mode = nil
  pcall(function() mode = G.ModeCurrent end)
  if mode ~= "alphabeth" then
    if S.modeSeen == "alphabeth" then M.reset("exit-alphabeth") end
    S.modeSeen = mode
    return
  end
  if S.modeSeen ~= "alphabeth" then S.t0 = nil end
  S.modeSeen = mode
  local stop = true
  pcall(function() stop = G.Stop end)
  if stop then return end
  if not S.t0 then
    pcall(function()
      if system and system.getTimer then S.t0 = system.getTimer() / 1000 end
    end)
    if not S.t0 then S.t0 = 0 end
  end
  if S.over then return end
  local lim = M.resolveLimit()
  if elapsed() >= lim then M.finalize(G, "timeout") end
end
function M.install()
  if S.hooked then return true end
  S.hooked = true
  pcall(function()
    if Runtime and Runtime.addEventListener then
      Runtime:addEventListener("enterFrame", onFrame)
    else
    end
  end)
  _G.__ALPHA_LOSS = { finalize = function(g, r) return M.finalize(g, r) end,
    loseHeart = function(g) return M.loseHeart(g) end,
    onWrongMove = function(g) return M.onWrongMove(g) end,
    reset = function(t) return M.reset(t) end,
    isOver = function() return M.isOver() end,
    timeLimit = function() return M.resolveLimit() end }
  return true
end
function M.selftest()
  local saveT, saveD = timer, _G.__ALPHA_TEST_DELAY
  local calls = {}
  local G = { Hearts = 3, Fails = 0, Win = true, Stop = false,
    Duty = {}, Mode = { alphabeth = { GameOverDelay = 1000 } } }
  G.Break = function(a) calls[#calls + 1] = a end
  _G.__ALPHA_TEST_DELAY = 5
  timer = { performWithDelay = function(d, f)
    calls.delay = d pcall(f) return true end }
  assert(M.resolveDelay(G) == 5, "delay de teste")
  assert(M.finalize(G, "timeout") == true, "fires")
  assert(G.Hearts == 0, "Hearts=0")
  assert(G.Fails == 1, "fails+1")
  assert(G.Win == false and G.Stop == true, "Win/Stop")
  assert(G.Duty.BlockONOFFButton == true, "buttons")
  assert(calls.delay == 5 and calls[1] == 2, "Break(2) after delay")
  assert(M.finalize(G, "timeout") == false, "idempotente")
  assert(#calls == 1, "Break 1x")
  M.reset("t")
  local G2 = { Hearts = 1, Stop = false, Duty = {} }
  G2.Break = function(a) calls[#calls + 1] = a end
  assert(M.loseHeart(G2) == true, "heart zeroes => defeat")
  assert(G2.Hearts == 0 and G2.Fails == 1, "hearts=>Hearts=0 fails+1")
  M.reset("t2")
  local G3 = { Hearts = 3, Stop = false, Duty = {} }
  G3.Break = function() end
  assert(M.loseHeart(G3) == true, "3->2 with no defeat")
  assert(G3.Hearts == 2 and not M.isOver(), "keeps playing")
  M.reset("t3")
  local G4 = { Hearts = 3, Stop = false, Duty = {} }
  local fired = nil
  G4.Break = function() error("sig1") end
  local n = 0
  G4.Break = function(a) n = n + 1 if a == 2 then error("bad") end fired = a end
  assert(M.finalize(G4, "timeout") == true, "fires w/ fallback")
  assert(fired == nil, "Break() with no args in fallback")
  M.reset("t4")
  _G.__WINREAL_FOUND = { prelude = function() error("never") end }
  local G5 = { Hearts = 1, Stop = false, Duty = {} }
  G5.Break = function(a) end
  assert(M.finalize(G5, "hearts") == true, "fires w/ bogus prelude")
  assert(_G.__ALPHA_REAL_BSOD == nil, "no flag with bogus prelude")
  assert(G5.Hearts == 0, "legacy roda normal")
  _G.__WINREAL_FOUND = nil
  M.reset("t4b")
  _G.__ALPHA_TEST_DELAY = saveD
  if saveT == nil then timer = nil else timer = saveT end
  M.reset("end")
  return "LOSS_OK timeout+hearts+fails+break+retry"
end
  return M
end)()
package.loaded["mod_alpha_loss"] = loss
local winreal = (function()
local M = {}
M.id = [[winreal-min-v1]]
M.WIN_PAUSE_FALLBACK = 2000
M.quiet = false
local hooked = false
local function getG()
  local G = nil
  pcall(function()
    local _, g = debug.getupvalue(onHoverTouch, 1)
    G = g
  end)
  return G
end
M.getG = getG
function M.findReal()
  local found, seen, seenT, n = {}, {}, {}, 0
  local src = {}
  local grab = nil
  local FP = {
    win = { "fanfare", "ProgressBarPanel", "HideBinStatusPanel" },
    putpost = { "PutPostGameWindow", "POST_GAME_WINDOW" },
    gamewin = { "AfertWinCenterPanel", "GameWin" },
    prelude = { "PreludeToBSOD", "CatchReds" },
  }
  local dumpOk = true
  local function nupsOf(fn)
    local nu = nil
    pcall(function()
      if debug and debug.getinfo then
        local ok, inf = pcall(debug.getinfo, fn, "u")
        if ok and type(inf) == "table" then nu = tonumber(inf.nups) end
      end
    end)
    return nu
  end
  pcall(function()
    local G = getG()
    local mode = G and G.ModeCurrent
    if M.quiet then return end
    print("PROGRESSMOD winreal scan getg=" .. type(G) .. " mode=" .. tostring(mode))
    if type(G) == "table" then
      local ks = {}
      for k, v in pairs(G) do
        if type(v) == "function" and #ks < 40 then ks[#ks + 1] = tostring(k) end
      end
      print("PROGRESSMOD winreal gkeys " .. table.concat(ks, ","))
    end
  end)
  local function keyOf(where)
    local k = nil
    pcall(function()
      k = tostring(where or ""):match("[%.]([%w_]+)$")
    end)
    return k
  end
  local function arity(fn)
    local np = nil
    pcall(function()
      if debug and debug.getinfo then
        local ok, inf = pcall(debug.getinfo, fn, "u")
        if ok and type(inf) == "table" then np = tonumber(inf.nparams) end
      end
    end)
    return np
  end
  local function consider(fn, where, depth)
    if type(fn) ~= "function" or seen[fn] then return end
    if n > 3000 then return end
    seen[fn] = true
    n = n + 1
    local ok, inf = pcall(debug.getinfo, fn, "S")
    if ok and type(inf) == "table" and inf.what == "Lua" then
      local k = keyOf(where)
      if k == "PreludeToBSOD" and found.prelude == nil then
        found.prelude, src.prelude = fn, tostring(where)
      end
      if k == "GameWin" and found.gamewin == nil then
        found.gamewin, src.gamewin = fn, tostring(where)
      end
      if (k == "PutPostGameWindow" or k == "ShowPostGame" or k == "PostGame") and found.putpost == nil then
        found.putpost, src.putpost = fn, tostring(where)
      end
      if (k == "Win" or k == "WIN") and found.win == nil then
        local np = arity(fn)
        if np == nil or np <= 1 then
          found.win, src.win = fn, tostring(where)
        end
      end
      if dumpOk and (found.win == nil or found.putpost == nil or found.gamewin == nil or found.prelude == nil) then
        local okd, d = pcall(function()
          if string and string.dump then return string.dump(fn) end
        end)
        if not okd or type(d) ~= "string" then
          dumpOk = false
        else
          for _, role in ipairs({ "win", "putpost", "gamewin", "prelude" }) do
            if found[role] == nil then
              local all = true
              for _, m in ipairs(FP[role]) do
                if not d:find(m, 1, true) then all = false break end
              end
              if all then
                if role ~= "prelude" then
                  found[role], src[role] = fn, tostring(where) .. "#dump"
                else
                  local nu = nupsOf(fn)
                  if nu == nil or nu <= 10 then
                    found[role], src[role] = fn, tostring(where) .. "#dump"
                  end
                end
              end
            end
          end
        end
      end
      if found.win and found.putpost and found.gamewin and found.prelude then return end
      if debug and debug.getupvalue then
        for i = 1, 40 do
          local ok2, _, uv = pcall(debug.getupvalue, fn, i)
          if not ok2 or uv == nil then break end
          if type(uv) == "function" then consider(uv, tostring(where) .. ".up" .. i, depth)
          elseif grab and (type(uv) == "table" or type(uv) == "userdata") then
            pcall(grab, uv, tostring(where) .. ".upt" .. i, (tonumber(depth) or 0) + 1)
          end
        end
      end
    end
  end
  pcall(function()
    local G = getG()
    local KEYLIST = { "Break", "Win", "Stop", "Duty", "UI", "Mode", "INI",
      "Desktop", "Stage", "Progress", "Hearts", "AnyKeyAfterBSOD",
      "onKeyFunctionLocalWindow", "ReturnFromBSODActions", "GameWin", "WIN",
      "PutPostGameWindow", "PostGame", "ShowPostGame", "LevelComplete",
      "CompleteLevel", "NextLevel", "Pause", "Resume", "HideBinStatusPanel",
      "PreludeToBSOD", "BSOD" }
    grab = function(t, where, depth)
      if t == nil then return end
      if type(t) ~= "table" and type(t) ~= "userdata" then return end
      if seenT[t] then return end
      seenT[t] = true
      depth = tonumber(depth) or 0
      if depth > 2 or n > 3000 then return end
      for _, k in ipairs(KEYLIST) do
        local ok, v = pcall(function() return t[k] end)
        if ok and type(v) == "function" then consider(v, where .. "." .. k, depth) end
        if found.win and found.putpost and found.gamewin and found.prelude then return end
      end
      pcall(function()
        local c = 0
        for k, v in pairs(t) do
          c = c + 1
          if c > 200 then break end
          if type(v) == "function" then consider(v, where .. "." .. tostring(k), depth) end
          if found.win and found.putpost and found.gamewin and found.prelude then break end
        end
      end)
      if depth < 2 then
        pcall(function()
          local c = 0
          for k, v in pairs(t) do
            c = c + 1
            if c > 200 then break end
            if (type(v) == "table" or type(v) == "userdata") and not seenT[v] then
              grab(v, where .. "." .. tostring(k), depth + 1)
            end
            if found.win and found.putpost and found.gamewin and found.prelude then break end
            if n > 3000 then break end
          end
        end)
      end
    end
    grab(G, "G", 0)
    if G then
      local okD, duty = pcall(function() return G.Duty end)
      if okD then grab(duty, "Duty", 1) end
      local okU, ui = pcall(function() return G.UI end)
      if okU then grab(ui, "UI", 1) end
    end
    if not (found.win and found.putpost and found.gamewin and found.prelude) then grab(_G, "GLOB", 0) end
  end)
  pcall(function()
    if not (display and display.getCurrentStage) then return end
    local st = display.getCurrentStage()
    local function walk(o, d)
      if d > 10 or (found.win and found.putpost and found.gamewin and found.prelude) then return end
      pcall(function()
        if type(o.Func) == "function" then consider(o.Func, "disp.Func") end
        if type(o._alphaOrig) == "function" then consider(o._alphaOrig, "disp.Orig") end
      end)
      local nk = 0
      pcall(function() nk = o.numChildren or 0 end)
      for i = 1, (nk or 0) do
        local _, ch = pcall(function() return o[i] end)
        if ch ~= nil then walk(ch, d + 1) end
      end
    end
    walk(st, 0)
  end)
  pcall(function()
    local G = getG()
    if G and type(G.Break) == "function" then
      local ok, inf = pcall(debug.getinfo, G.Break, "S")
      if ok and type(inf) == "table" then
      end
    end
  end)
  pcall(function()
    local prev = _G.__WINREAL_FOUND
    if type(prev) == "table" then
      for k, v in pairs(found) do
        if v ~= nil then prev[k] = v end
      end
      found = prev
    end
    _G.__WINREAL_FOUND = found
  end)
  pcall(function()
    local parts = {}
    for _, k in ipairs({ "win", "putpost", "gamewin", "prelude" }) do
      local v = found[k]
      if type(v) == "function" then
        local info = "?"
        if debug and debug.getinfo then
          local ok, inf = pcall(debug.getinfo, v, "S")
          if ok and type(inf) == "table" then info = tostring(inf.linedefined) end
        end
        parts[#parts + 1] = k .. "@" .. tostring(src[k] or "?") .. ":" .. info
      end
    end
    if #parts > 0 then print("PROGRESSMOD winreal " .. table.concat(parts, " ")) end
    if #parts == 0 then print("PROGRESSMOD winreal none") end
  end)
  return found
end
function M.winPause(G)
  local d = M.WIN_PAUSE_FALLBACK
  pcall(function()
    local md = G and G.Mode and G.ModeCurrent and G.Mode[G.ModeCurrent]
    if md and md.WinPause then d = md.WinPause end
  end)
  d = tonumber(d) or M.WIN_PAUSE_FALLBACK
  if d < 0 then d = 0 end
  return d
end
function M.setState(G)
  if type(G) ~= [[table]] then return false end
  pcall(function()
    local pw = 20
    if G.INI and G.INI.ProgressWidth then pw = G.INI.ProgressWidth end
    if G.ProgressWidth and type(G.ProgressWidth) == [[number]] then pw = G.ProgressWidth end
    G.Progress = pw
    G.ProgressProcent = 100
    G.Win, G.Stop = true, true
    if type(G.Duty) == [[table]] then
      G.Duty.BlockONOFFButton = true
    end
  end)
  return true
end
function M.callReal(G)
  local via = nil
  pcall(function()
    if type(_G.GameWin) == [[function]] then
      _G.GameWin()
      via = [[GameWin]]
      return
    end
  end)
  if via then  return via end
  pcall(function()
    if type(G) == [[table]] and type(G.Break) == [[function]] then
      local ok = pcall(function() G.Break(1) end)
      if not ok then pcall(function() G.Break() end) end
      via = [[Break(1)]]
    end
  end)
  if via then  return via end
  return nil
end
function M.fallbackOverlay(msg)
  pcall(function()
    if display and display.newText and display.getCurrentStage then
      local st = display.getCurrentStage()
      local t = display.newText(st, msg or [[Congratulation! YOU GET IT!]],
        display.contentCenterX or 400, (display.contentCenterY or 300) - 40,
        native.systemFontBold or native.systemFont, 34)
      if t and t.toFront then t:toFront() end
    end
  end)
end
local fired = false
function M.fire(G, why)
  if fired then return false end
  if type(G) ~= [[table]] then G = getG() end
  if type(G) ~= [[table]] then  return false end
  fired = true
  M.setState(G)
  local via = M.callReal(G)
  if not via then
    M.fallbackOverlay()
    via = [[overlay]]
    pcall(function()
      if timer and timer.performWithDelay then
        timer.performWithDelay(M.winPause(G), function() end)
      end
    end)
  end
  pcall(function() _G.__WINREAL_MIN_DONE = via end)
  return true, via
end
function M.reset() fired = false pcall(function() _G.__WINREAL_MIN_DONE = nil end) return true end
function M.isFired() return fired end
function M.install()
  _G.__WINREAL_MIN = { fire = function(g, w) return M.fire(g, w) end,
    reset = function() return M.reset() end,
    find = function() return M.findReal() end,
    winPause = function(g) return M.winPause(g) end, id = M.id }
  if hooked then return true end
  hooked = true
  pcall(function()
    if Runtime and Runtime.addEventListener then
      local lastMode = nil
      local probed = {}
      local lastProbeAt = 0
      local tickN = 0
      Runtime:addEventListener([[enterFrame]], function()
        tickN = tickN + 1
        if tickN % 30 ~= 0 then return end
        local G = getG()
        if type(G) ~= [[table]] then return end
        local mode = nil
        pcall(function() mode = G.ModeCurrent end)
        if mode ~= lastMode then
          if lastMode ~= nil then M.reset() end
          lastMode = mode
        end
        local F0 = _G.__WINREAL_FOUND
        local complete = type(F0) == [[table]] and F0.win ~= nil and F0.prelude ~= nil
        if complete and probed[mode] then return end
        local nowT = 0
        pcall(function() if system and system.getTimer then nowT = system.getTimer() / 1000 end end)
        if mode ~= nil and mode ~= [[menu]] and (not probed[mode] or ((not complete) and (nowT - lastProbeAt) > 60)) then
          probed[mode] = true
          lastProbeAt = nowT
          pcall(function() M.findReal() end)
        end
      end)
    end
  end)
  return true
end
function M.selftest()
  M.quiet = true
  local svT, svD = timer, display
  local delays = {}
  timer = { performWithDelay = function(d, f) delays[#delays+1] = d pcall(f) return true end }
  assert(M.winPause({ Mode = { Normal = { WinPause = 1500 } }, ModeCurrent = [[Normal]] }) == 1500, [[pause-config]])
  assert(M.winPause({}) == 2000, [[pause-fallback]])
  local G = { INI = { ProgressWidth = 33 }, Duty = {} }
  assert(M.setState(G) == true, [[state]])
  assert(G.Progress == 33 and G.ProgressProcent == 100 and G.Win and G.Stop, [[cheia+stop]])
  local called = 0
  _G.GameWin = function() called = called + 1 end
  M.reset()
  local ok, via = M.fire({ INI = { ProgressWidth = 20 }, Duty = {}, Mode = { Normal = { WinPause = 9 } }, ModeCurrent = [[Normal]] }, [[t]])
  assert(ok and via == [[GameWin]] and called == 1, [[via-GameWin]])
  assert(M.fire({}, [[dup]]) == false, [[idempotente]])
  _G.GameWin = nil
  M.reset()
  local b = {}
  local G2 = { INI = { ProgressWidth = 20 }, Duty = {}, Break = function(a) b[#b+1] = a end }
  local ok2, via2 = M.fire(G2, [[t2]])
  assert(ok2 and via2 == [[Break(1)]] and b[1] == 1, [[via-Break]])
  M.reset()
  _G.GameWin = nil
  timer = svT display = svD
  M.quiet = false
  return [[WINREAL-MIN_OK GameWin16refs+estado5linhas+Breakfallback+idempotente]]
end
  return M
end)()
package.loaded["mod_winreal_min"] = winreal
return {
  ["mod_alpha_win"] = win,
  ["mod_alpha_loss"] = loss,
  ["mod_winreal_min"] = winreal,
}
