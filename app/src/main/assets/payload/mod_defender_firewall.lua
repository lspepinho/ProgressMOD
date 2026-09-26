local M = {}
M.id = "defender-firewall-fix-v2"

M.RED_TASK = 4

M.SCAN_BUDGET = 400

M.DESK_BUDGET = 2000

local S = { hooked = false, rtWrapped = false, origAdd = nil,
            cachedG = nil, tick = 0 }

local function getG()
  if type(S.cachedG) == "table" then
    local ok = false
    pcall(function()
      ok = S.cachedG.ModeCurrent ~= nil and S.cachedG.Desktop ~= nil
    end)
    if ok then return S.cachedG end
    S.cachedG = nil
  end
  local G = nil
  pcall(function()
    if type(onHoverTouch) == "function" and debug and debug.getupvalue then

      for i = 1, 6 do
        local _, v = debug.getupvalue(onHoverTouch, i)
        if type(v) == "table" and v.ModeCurrent ~= nil and v.Desktop ~= nil then
          G = v
          break
        end
      end
    end
  end)
  if type(G) ~= "table" then
    pcall(function() G = _G.G end)
    if type(G) ~= "table" or G.ModeCurrent == nil then G = nil end
  end
  if type(G) ~= "table" then

    pcall(function()
      for _, v in pairs(_G) do
        if type(v) == "table" then
          local ok = false
          pcall(function()
            ok = v.ModeCurrent ~= nil and v.Desktop ~= nil
          end)
          if ok then G = v break end
        end
      end
    end)
  end
  if type(G) ~= "table" then return nil end
  S.cachedG = G
  return G
end

function M.forgetG()
  S.cachedG = nil
end

function M.inside(fw, x, y)
  if type(fw) ~= "table" then return false end
  x, y = tonumber(x), tonumber(y)
  local top, bottom, ledge, redge = nil, nil, nil, nil
  pcall(function()
    top = tonumber(fw.Top)
    bottom = tonumber(fw.Bottom)
    ledge = tonumber(fw.LEdge)
    redge = tonumber(fw.REdge)
  end)
  if not (top and bottom and ledge and redge and x and y) then return false end
  return y > top and y < bottom and x > ledge and x < redge
end

local function firewallBlocks(fw)

  if type(fw) ~= "table" then return false end
  local t = nil
  pcall(function() t = fw.Type end)
  if t ~= nil and t ~= "Firewall" then
    local v = nil
    pcall(function()
      if type(fw.BlockFilter) == "table" then v = fw.BlockFilter[M.RED_TASK] end
    end)
    return v == true
  end
  pcall(function()
    if type(fw.BlockFilter) ~= "table" then fw.BlockFilter = {} end
    fw.BlockFilter[M.RED_TASK] = true
  end)
  return true
end

M.firewallBlocks = firewallBlocks

local function firewallsOf(G)
  local out = {}
  pcall(function()
    local grp = G.DefenderFirewalls
    if type(grp) ~= "table" then return end
    local n = tonumber(grp.numChildren) or 0
    for i = 1, n do
      local fw = nil
      pcall(function() fw = grp[i] end)
      if type(fw) == "table" then
        local t = nil
        pcall(function() t = fw.Type end)
        if t == "Firewall" then
          out[#out + 1] = fw
        elseif t == nil then

          local ok = false
          pcall(function()
            ok = tonumber(fw.Top) ~= nil and tonumber(fw.Bottom) ~= nil
              and tonumber(fw.LEdge) ~= nil and tonumber(fw.REdge) ~= nil
          end)
          if ok then out[#out + 1] = fw end
        end
      end
    end
  end)
  return out
end

M.firewallsOf = firewallsOf

local function removeSeg(seg)
  pcall(function()
    if display and display.remove then display.remove(seg) end
  end)
  pcall(function()
    if seg and seg.removeSelf and type(seg.removeSelf) == "function" then
      seg:removeSelf()
    end
  end)
end

function M.hitTest(seg, fws)
  if type(seg) ~= "table" or type(fws) ~= "table" then return false end
  local task = nil
  pcall(function() task = seg.TaskID end)
  if task ~= M.RED_TASK then return false end
  local sx, sy = nil, nil
  pcall(function() sx = tonumber(seg.x) sy = tonumber(seg.y) end)
  if not (sx and sy) then return false end
  for _, fw in ipairs(fws) do
    local blocks = false
    pcall(function() blocks = firewallBlocks(fw) end)
    if blocks then
      local hit = false
      pcall(function() hit = M.inside(fw, sx, sy) end)
      if hit then
        removeSeg(seg)
        return true
      end
    end
  end
  return false
end

function M.checkRed(seg)
  if type(seg) ~= "table" then return false end
  local task = nil
  pcall(function() task = seg.TaskID end)
  if task ~= M.RED_TASK then return false end
  local G = getG()
  if type(G) ~= "table" then return false end
  local mode = nil
  pcall(function() mode = G.ModeCurrent end)
  if mode ~= "defender" then return false end
  local fws = firewallsOf(G)
  if #fws == 0 then return false end
  return M.hitTest(seg, fws)
end

local function wrapSegment(obj)
  if type(obj) ~= "table" then return false end
  if obj.__fwWrapped then return true end
  local orig = nil
  pcall(function() orig = obj.enterFrame end)
  if type(orig) ~= "function" then return false end
  obj.__fwWrapped = true
  obj.enterFrame = function(self, ev)
    pcall(M.checkRed, self)
    return orig(self, ev)
  end
  return true
end

M.wrapSegment = wrapSegment

local function isSegmentListener(lis)
  if type(lis) ~= "table" then return false end
  local task = nil
  pcall(function() task = lis.TaskID end)
  if type(task) ~= "number" then return false end
  local ef = nil
  pcall(function() ef = lis.enterFrame end)
  return type(ef) == "function"
end

local function scanDesktop(G, fws)
  if type(G) ~= "table" or type(fws) ~= "table" or #fws == 0 then return 0 end
  local desk = G.Desktop
  if type(desk) ~= "table" then return 0 end
  local n = tonumber(desk.numChildren) or #desk
  if not n or n < 1 then n = 200 end
  if n > M.DESK_BUDGET then n = M.DESK_BUDGET end
  local removed = 0
  for i = n, 1, -1 do
    local seg = desk[i]
    if type(seg) == "table" and seg.TaskID == M.RED_TASK then
      if M.hitTest(seg, fws) then removed = removed + 1 end
    end
  end
  return removed
end

M.scanDesktop = scanDesktop

local function wrapDesktop(desk)
  if type(desk) ~= "table" then return false end
  if desk.__fwDeskWrapped then return true end
  local orig = nil
  pcall(function() orig = desk.enterFrame end)
  if type(orig) ~= "function" then return false end
  desk.__fwDeskWrapped = true
  desk.enterFrame = function(self, ev)
    local r = orig(self, ev)
    pcall(function()
      local G = getG()
      if type(G) ~= "table" then return end
      local mode = nil
      pcall(function() mode = G.ModeCurrent end)
      if mode ~= "defender" then return end
      local fws = firewallsOf(G)
      if #fws == 0 then return end
      scanDesktop(G, fws)
    end)
    return r
  end
  return true
end

M.wrapDesktop = wrapDesktop

local function sweepStage(fws, budget)
  local stage = nil
  pcall(function()
    if display and display.getCurrentStage then
      stage = display.getCurrentStage()
    end
  end)
  if type(stage) ~= "table" then return 0 end
  local visited, removed = 0, 0
  local function visit(node, depth)
    if visited >= budget then return end
    if type(node) ~= "table" then return end
    visited = visited + 1
    local task = nil
    pcall(function() task = node.TaskID end)
    if task == M.RED_TASK then
      pcall(function()
        if M.hitTest(node, fws) then removed = removed + 1 end
      end)
    end
    if depth < 8 and visited < budget then
      local n = nil
      pcall(function() n = tonumber(node.numChildren) end)
      if n and n > 0 then
        for i = 1, n do
          if visited >= budget then break end
          local ch = nil
          pcall(function() ch = node[i] end)
          if ch ~= nil then visit(ch, depth + 1) end
        end
      end
    end
  end
  pcall(visit, stage, 0)
  return removed
end

M.sweepStage = sweepStage

local function fallbackTick()
  S.tick = (S.tick or 0) + 1
  if (S.tick % 2) == 0 then return end
  local G = S.cachedG
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
    if type(G) ~= "table" then return end
  end
  local mode = G.ModeCurrent
  if mode ~= "defender" then return end
  local grp = G.DefenderFirewalls
  if type(grp) ~= "table" then return end
  local fws = firewallsOf(G)
  if #fws == 0 then return end
  local desk = G.Desktop
  if type(desk) == "table" then pcall(wrapDesktop, desk) end
  scanDesktop(G, fws)
end

function M.install()
  pcall(function()
    if S.hooked then return end
    S.hooked = true
    local rt = nil
    pcall(function() rt = Runtime end)
    if type(rt) ~= "table" then return end
    local origAdd = nil
    pcall(function() origAdd = rt.addEventListener end)
    if type(origAdd) ~= "function" then return end

    local seen = nil
    pcall(function() seen = rt.__fwPatched end)
    if seen then
      S.rtWrapped = true
      return
    end
    local function patchedAdd(a1, a2, a3, a4)

      local self, name, lis, extra = nil, nil, nil, nil
      if type(a1) == "table" and type(a2) == "string" then
        self, name, lis, extra = a1, a2, a3, a4
      elseif type(a1) == "string" then
        self, name, lis, extra = rt, a1, a2, a3
      else
        return origAdd(a1, a2, a3, a4)
      end
      if name == "enterFrame" then
        pcall(function()
          if isSegmentListener(lis) then wrapSegment(lis) end
        end)
      end
      if extra ~= nil then
        return origAdd(self, name, lis, extra)
      end
      return origAdd(self, name, lis)
    end
    local ok = pcall(function() rt.addEventListener = patchedAdd end)
    pcall(function()
      if ok and rt.addEventListener == patchedAdd then
        S.rtWrapped = true
        S.origAdd = origAdd
        rt.__fwPatched = true
      end
    end)
  end)

  pcall(function()
    if Runtime and Runtime.addEventListener and not S.fbHooked then
      Runtime:addEventListener("enterFrame", fallbackTick)
      S.fbHooked = true
    end
  end)
  pcall(function() _G.__DEFENDER_FW = M end)
  return true
end

function M.selftest()
  local svDisplay, svRuntime, svG = display, Runtime, _G.G

  local fw = { Top = 100, Bottom = 200, LEdge = 10, REdge = 60 }
  assert(M.inside(fw, 30, 150) == true, "inside blocks")
  assert(M.inside(fw, 5, 150) == false, "outside x")
  assert(M.inside(fw, 30, 50) == false, "outside y")
  assert(M.inside(fw, 10, 150) == false, "LEdge edge does not count")
  assert(M.inside(fw, 30, 100) == false, "Top edge does not count")
  assert(M.inside(nil, 30, 150) == false, "fw nil")
  assert(M.inside({}, 30, 150) == false, "fw without bounds")

  local fwNil = { Type = "Firewall", Top = 0, Bottom = 10, LEdge = 0, REdge = 10 }
  assert(M.firewallBlocks(fwNil) == true, "no BlockFilter blocks")
  assert(fwNil.BlockFilter[4] == true, "[4] created true")
  local fwNoRed = { Type = "Firewall", BlockFilter = {} }
  assert(M.firewallBlocks(fwNoRed) == true, "repairs [4]")
  assert(fwNoRed.BlockFilter[4] == true, "[4] became true")
  local fwOff = { Type = "Firewall", BlockFilter = { [4] = false } }
  assert(M.firewallBlocks(fwOff) == true, "false becomes true on Firewall")
  assert(fwOff.BlockFilter[4] == true, "[4] forced true")
  local avOff = { Type = "Antivirus", BlockFilter = { [4] = false } }
  assert(M.firewallBlocks(avOff) == false, "antivirus respects filter")
  assert(M.firewallBlocks(nil) == false, "nil does not block")

  local G0 = { DefenderFirewalls = { numChildren = 4,
    [1] = { Type = "Firewall" },
    [2] = { Type = "Antivirus" },
    [3] = { Type = "Firewall" },
    [4] = { Top = 0, Bottom = 10, LEdge = 0, REdge = 10 } } }
  assert(#M.firewallsOf(G0) == 3, "firewall + typeless")
  assert(#M.firewallsOf({}) == 0, "no group")

  local removed = {}
  display = { remove = function(o) removed[#removed + 1] = o end }
  local wall = { Type = "Firewall", Top = 100, Bottom = 200,
                 LEdge = 10, REdge = 60, BlockFilter = { [4] = false } }
  local red = { TaskID = 4, x = 30, y = 150 }
  assert(M.hitTest(red, { wall }) == true, "red inside destroyed")
  assert(removed[1] == red, "display.remove on red")
  assert(wall.BlockFilter[4] == true, "Firewall filter forced")
  assert(M.hitTest({ TaskID = 4, x = 500, y = 500 }, { wall }) == false,
    "red outside passes")
  assert(M.hitTest({ TaskID = 1, x = 30, y = 150 }, { wall }) == false,
    "blue untouched")
  assert(M.hitTest(red, {}) == false, "no firewall idle")

  local G = {
    ModeCurrent = "defender",
    DefenderFirewalls = { numChildren = 1, [1] = wall },
    Desktop = { numChildren = 0 },
  }
  S.cachedG = G
  local red2 = { TaskID = 4, x = 30, y = 150 }
  assert(M.checkRed(red2) == true, "checkRed destroys on defender")
  G.ModeCurrent = "Normal"
  assert(M.checkRed(red2) == false, "outside defender idle")
  G.ModeCurrent = "defender"
  G.DefenderFirewalls = { numChildren = 0 }
  assert(M.checkRed(red2) == false, "no firewall idle")
  S.cachedG = nil

  local segIn = { TaskID = 4, x = 30, y = 150 }
  local segOut = { TaskID = 4, x = 500, y = 500 }
  local segBlue = { TaskID = 1, x = 30, y = 150 }
  local G2 = {
    ModeCurrent = "defender",
    DefenderFirewalls = { numChildren = 1, [1] = wall },
    Desktop = { numChildren = 3, [1] = segOut, [2] = segBlue, [3] = segIn },
  }
  local n = M.scanDesktop(G2, M.firewallsOf(G2))
  assert(n == 1, "scanDesktop found 1")
  assert(removed[#removed] == segIn, "scanDesktop removed the inside one")

  local seg = { TaskID = 4, x = 30, y = 150 }
  display.getCurrentStage = function()
    return { numChildren = 2, [1] = { TaskID = 1, x = 0, y = 0 },
             [2] = seg }
  end
  local n2 = M.sweepStage({ wall }, 400)
  assert(n2 == 1, "sweep found 1")
  assert(removed[#removed] == seg, "sweep removed")

  local calls = {}
  local s3 = {
    TaskID = 4,
    enterFrame = function(self, ev) calls[#calls + 1] = ev return "ok" end,
  }
  assert(M.wrapSegment(s3) == true, "wraps segment")
  assert(M.wrapSegment(s3) == true, "idempotent")
  local ret = s3:enterFrame("ev1")
  assert(ret == "ok", "original called")
  assert(calls[1] == "ev1", "event forwarded")
  assert(M.wrapSegment({}) == false, "no enterFrame no wrap")
  assert(M.wrapSegment(nil) == false, "nil no wrap")

  local dCalls = {}
  local G3 = {
    ModeCurrent = "defender",
    DefenderFirewalls = { numChildren = 1, [1] = wall },
    Desktop = { numChildren = 1, [1] = { TaskID = 4, x = 30, y = 150 } },
  }
  S.cachedG = G3
  G3.Desktop.enterFrame = function(self, ev) dCalls[#dCalls + 1] = ev return "moved" end
  assert(M.wrapDesktop(G3.Desktop) == true, "wraps desktop")
  local dret = G3.Desktop:enterFrame("tick")
  assert(dret == "moved", "original movement runs")
  assert(dCalls[1] == "tick", "event forwarded")
  assert(removed[#removed] == G3.Desktop[1], "desktop swept the red")
  S.cachedG = nil

  local added = {}
  Runtime = {
    addEventListener = function(self, name, lis)
      added[#added + 1] = { name, lis }
      return true
    end,
  }
  S.hooked, S.rtWrapped, S.origAdd, S.fbHooked = false, false, nil, nil
  assert(M.install() == true, "install ok")
  local seg2 = { TaskID = 4, enterFrame = function() end }
  Runtime:addEventListener("enterFrame", seg2)
  assert(seg2.__fwWrapped == true, "segment detected on register")
  assert(#added == 2, "forward to original (sweep + segment)")
  local plain = function() end
  Runtime:addEventListener("enterFrame", plain)
  assert(#added == 3, "function forwarded untouched")

  local wall2 = { Type = "Firewall", Top = 0, Bottom = 10,
                  LEdge = 0, REdge = 10, BlockFilter = { [4] = false } }
  local G4 = {
    ModeCurrent = "defender",
    DefenderFirewalls = { numChildren = 1, [1] = wall2 },
    Desktop = { numChildren = 1, [1] = { TaskID = 4, x = 5, y = 5 } },
  }
  S.cachedG = G4
  S.rtWrapped = true
  local before = #removed
  for _, e in ipairs(added) do
    if type(e[2]) == "function" then e[2]() end
  end
  assert(#removed == before + 1, "tick sweeps even with rtWrapped")
  assert(wall2.BlockFilter[4] == true, "tick forced the filter")
  S.cachedG = nil

  display, Runtime, _G.G = svDisplay, svRuntime, svG
  S.hooked, S.rtWrapped, S.origAdd, S.fbHooked = false, false, nil, nil

  return "DEFWALL_OK red4+aabb+force+desk+sweep"
end

return M
