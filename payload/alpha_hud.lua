local hud = (function()
local M = {}
function M.rowsNow(b)
  local rows = nil
  pcall(function()
    local lv = nil
    if _G.__ALPHA and _G.__ALPHA.level then lv = _G.__ALPHA.level() end
    lv = math.max(1, math.floor(tonumber(lv) or 3))
    local ok, R = pcall(require, "mod_alpha_rows")
    if ok and R and R.layout then
      local _, r = R.layout(lv)
      rows = tonumber(r)
    end
  end)
  if type(rows) ~= "number" or rows < 2 or rows > 5 then
    pcall(function()
      local maxr = 0
      if type(b) == "table" then
        for c = 1, 5 do
          if type(b[c]) == "table" then
            for r, cell in pairs(b[c]) do
              if type(r) == "number" and cell ~= nil and r > maxr then
                maxr = math.floor(r)
              end
            end
          end
        end
      end
      if maxr >= 2 and maxr <= 5 then rows = maxr end
    end)
  end
  if type(rows) ~= "number" or rows < 2 or rows > 5 then rows = 5 end
  return rows
end
function M.gridParent(b)
  local pref = nil
  pcall(function()
    if type(b) == "table" then
      for _, col in pairs(b) do
        if type(col) == "table" then
          for _, cell in pairs(col) do
            if cell ~= nil then
              pcall(function() pref = cell.parent end)
              if pref ~= nil then return end
            end
          end
        end
        if pref ~= nil then break end
      end
    end
  end)
  return pref
end
function M.reanchor(b)
  pcall(function()
    local pref = M.gridParent(b)
    if pref == nil or not pref.insert then return end
    if S.hud and S.hud.g then
      pcall(function() pref:insert(S.hud.g) end)
    end
    if S.zones then
      pcall(function() pref:insert(S.zones) end)
    end
  end)
  return true
end
M.id = "alpha-hud-v6"
M.LOGF = "mod_alpha_hud.log"
local S = { hud = nil, zones = nil, noVis = false }
function M.cellXY(b, c, r)
  local x, y = nil, nil
  pcall(function()
    local cell = b[c] and b[c][r]
    x = cell.x
    y = cell.y
  end)
  return x, y
end
function M.landscape(tag, w, h)
  pcall(function()
    if _G.__ALPHA_NO_LANDSCAPE then return end
    if native and native.getProperty then
      local mode = native.getProperty("windowMode")
      if mode ~= nil and mode ~= "normal" then return end
    end
    if native and native.setProperty then
      native.setProperty("windowSize", { width = w, height = h })
    end
  end)
end
function M.ensure(b)
  if S.hud then
    local alive = false
    pcall(function()
      local g = S.hud.g
      if g ~= nil and g.isVisible ~= nil then
        local o, guard, live = g, 0, false
        while o ~= nil and guard < 12 do
          local p = nil
          pcall(function() p = o.parent end)
          if p == nil then break end
          if p == o then break end
          o = p
          guard = guard + 1
          if guard >= 2 then live = true end
        end
        if live then alive = true end
      end
    end)
    if not alive then
      pcall(function()
        if S.hud.g and S.hud.g.removeSelf then S.hud.g:removeSelf() end
      end)
      S.hud = nil
    else
      pcall(function()
        if S.hud.bar and S.hud.bar.reset then S.hud.bar.reset() end
      end)
      return S.hud
    end
  end
  if S.noVis or not b then return S.hud end
  pcall(function()
    local xs, ys = {}, {}
    local rows = M.rowsNow(b)
    for c = 1, 5 do
      for r = 1, rows do
        local x, y = M.cellXY(b, c, r)
        if x and y then xs[#xs + 1] = x ys[#ys + 1] = y end
      end
    end
    if #xs < 10 then return end
    table.sort(xs)
    table.sort(ys)
    local minX, maxX, minY, maxY = xs[1], xs[#xs], ys[1], ys[#ys]
    local cx = (minX + maxX) / 2
    local midY = (minY + maxY) / 2
    local cellW, cellH = 62, 62
    pcall(function()
      local c0 = b[1] and b[1][1]
      if c0 then cellW = c0.width or cellW cellH = c0.height or cellH end
    end)
    local dvH = math.max(10, (maxY - minY) - cellH * 0.45)
    local lhW = math.max(10, (maxX - minX) - cellW * 0.45)
    local g = display.newGroup()
    pcall(function() g._alphaNoStretch = true end)
    pcall(function()
      local pref = M.gridParent(b)
      if pref and pref.insert then pref:insert(g) end
    end)
    local by = maxY + 86
    local BAR = nil
    pcall(function()
      local ok, m = pcall(require, "mod_alpha_realbar")
      if ok and m then BAR = m end
    end)
    local barOk = false
    if BAR and BAR.attach then
      pcall(function() barOk = BAR.attach(cx, maxY) end)
    end
    if barOk then
    else
    end
    local pct = nil
    pcall(function() pct.isVisible = false end)
    local moves = nil
    local banner = nil
    pcall(function()
      banner = display.newText(g, "", cx, minY - 60,
        native.systemFontBold, 34)
      if banner then
        banner:setFillColor(0.4, 1, 0.4)
        banner.isVisible = false
      end
    end)
    S.hud = { g = g, bar = BAR, pct = pct, moves = moves,
      banner = banner }
  end)
  if not S.hud then
    S.noVis = true
  end
  return S.hud
end
function M.update(p, movesN, secsLeft)
  if not S.hud then return end
  local rp = p
  pcall(function()
    if S.hud.bar and S.hud.bar.update then
      local v = S.hud.bar.update(p)
      if type(v) == "number" then rp = v end
    end
  end)
  pcall(function()
    S.hud.pct.text = math.floor(rp * 100) .. "%"
    S.hud.moves.text = "MOVES " .. movesN .. "  " ..
        string.format("%02d:%02d", math.floor(secsLeft / 60),
          math.floor(secsLeft % 60))
  end)
end
function M.banner(text, rgb)
  if not S.hud then return end
  pcall(function()
    S.hud.banner.text = text
    S.hud.banner:setFillColor(rgb[1], rgb[2], rgb[3])
    S.hud.banner.isVisible = true
  end)
end
function M.hide()
  pcall(function()
    if S.hud and S.hud.g then S.hud.g.isVisible = false end
    if S.zones then S.zones.isVisible = false end
    if S.hud and S.hud.bar and S.hud.bar.hide then
      S.hud.bar.hide()
    end
  end)
end
function M.show()
  pcall(function()
    if S.hud and S.hud.g then S.hud.g.isVisible = true end
    if S.zones then S.zones.isVisible = true end
    if S.hud and S.hud.bar and S.hud.bar.show then
      S.hud.bar.show()
    end
  end)
end
function M.dropZones()
  S.zones = nil
  S.zonesBoard = nil
end
function M.setZonePx(px)
  pcall(function()
    px = tonumber(px) or 62
    if px < 16 then px = 16 end
    if px > 200 then px = 200 end
    S.zonePx = px
  end)
  return true
end
function M.moveZones(dx, dy)
  pcall(function()
    if S.zones then
      S.zones.x = (S.zones.x or 0) + (dx or 0)
      S.zones.y = (S.zones.y or 0) + (dy or 0)
    end
  end)
  return true
end
local function zonesAlive()
  local ok = false
  pcall(function()
    local g = S.zones
    if g == nil then return end
    if g.numChildren ~= nil and g.numChildren < 10 then return end
    local o, guard, live = g, 0, false
    while o ~= nil and guard < 12 do
      local p = nil
      pcall(function() p = o.parent end)
      if p == nil then break end
      if p == o then break end
      o = p
      guard = guard + 1
      if guard >= 2 then live = true end
    end
    if live then
      if g.isVisible == nil or g.isVisible == true then ok = true end
    end
  end)
  return ok
end
function M.ensureZones(b, onSlide)
  if S.noVis or not b then return end
  if S.zones and S.zonesBoard ~= nil and S.zonesBoard ~= b then
    pcall(function()
      if S.zones.removeSelf then S.zones:removeSelf() end
    end)
    S.zones, S.zonesBoard = nil, nil
  end
  if S.zones and zonesAlive() then return end
  if S.zones then
    pcall(function()
      if S.zones.removeSelf then S.zones:removeSelf() end
    end)
    S.zones = nil
  end
  pcall(function()
    local g = display.newGroup()
    pcall(function() g._alphaNoStretch = true end)
    pcall(function()
      local pref = M.gridParent(b)
      if pref and pref.insert then pref:insert(g) end
    end)
    local rows = M.rowsNow(b)
    local made = 0
    local zp = 62
    pcall(function() zp = tonumber(S.zonePx) or 62 end)
    for c = 1, 5 do
      for r = 1, rows do
        local x, y = M.cellXY(b, c, r)
        if x and y then
          local z = display.newRect(g, x, y, zp, zp)
          z.alpha = 0.01
          z.isHitTestable = true
          local cc, rr = c, r
          z:addEventListener("touch", function(ev)
            if ev.phase == "began" then
              pcall(function()
                if onSlide then onSlide(cc, rr) end
              end)
              return true
            end
            return true
          end)
        end
      end
    end
    S.zones = g
    S.zonesBoard = b
    pcall(function()
      if g and g.toFront then g:toFront() end
    end)
    local nz = 0
    pcall(function() nz = 5 * M.rowsNow(b) end)
  end)
  if not S.zones then
    S.noVis = true
  end
end
  return M
end)()
package.loaded["mod_alpha_hud"] = hud
local realbar = (function()
local M = {}
M.id = "alpha-realbar-v1"
local TRACK = { x0 = 96, x1 = 414, y0 = 48, y1 = 80, art = 512 }
local TILE = 32
local GAP_BELOW = 86
local S = { g = nil, track = nil, fill = nil, pct = nil, W = 560,
  skin = "95", attached = false }
local function skinOf()
  local sk = "95"
  pcall(function()
    local G = _G.G
    if G and G.OS_Table and G.OS_Current and G.OS_Table[G.OS_Current] then
      local s = G.OS_Table[G.OS_Current].Skin
      if type(s) == "string" and s ~= "" then sk = s end
    end
  end)
  return sk
end
local function fontOf()
  return "fonts/progresspixel-bold.ttf"
end
local function panelPath(sk)
  return "art/skins/" .. sk .. "/progressbarpanel.png"
end
local function hideLegacy()
  pcall(function()
    local ok, D = pcall(require, "mod_alpha_defbar")
    if ok and D and D.hide then pcall(D.hide) end
  end)
  pcall(function()
    local ok, B = pcall(require, "mod_alpha_bar")
    if ok and B and B.hide then pcall(B.hide) end
  end)
end
local function alive()
  local ok = false
  pcall(function()
    if S.g ~= nil and S.g.isVisible ~= nil then
      local o, guard, live = S.g, 0, false
      while o ~= nil and guard < 12 do
        local p = nil
        pcall(function() p = o.parent end)
        if p == nil then break end
        if p == o then break end
        o = p
        guard = guard + 1
        if guard >= 2 then live = true end
      end
      if live then ok = true end
    end
  end)
  return ok
end
local function drop()
  pcall(function()
    if S.g and S.g.removeSelf then S.g:removeSelf() end
  end)
  S.attached, S.g, S.track, S.fill, S.pct = false, nil, nil, nil, nil
end
function M.attach(cx, maxY, board)
  local b = board
  if b == nil and type(cx) == "table" then b = cx end
  if S.attached and S.g then
    if not alive() then
      drop()
    else
      pcall(function() M.follow(b) end)
      return true
    end
  end
  if not (display and display.newGroup and display.newImage and display.newRect and display.newText) then
    return false
  end
  local function newFrame(g, art)
    local img = nil
    pcall(function()
      if graphics and graphics.newImageSheet and display and display.newImage then
        local sheet = graphics.newImageSheet(art, { width = 512, height = 128, numFrames = 5 })
        if sheet then img = display.newImage(g, sheet, 1) end
      end
    end)
    return img
  end
  local ok = false
  pcall(function()
    S.skin = skinOf()
    local W = S.W
    local sc = W / TRACK.art
    local g = display.newGroup()
    local art = panelPath(S.skin)
    local frame = newFrame(g, art)
    if not frame then
      frame = newFrame(g, "art/skins/95/progressbarpanel.png")
    end
    if not frame then
      pcall(function() frame = display.newImage(g, art) end)
    end
    if not frame then
      pcall(function() frame = display.newImage(g, "art/skins/95/progressbarpanel.png") end)
    end
    if not frame then return end
    frame.xScale, frame.yScale = sc, sc
    pcall(function() frame.anchorX = 0 end)
    pcall(function() frame.anchorY = 0 end)
    pcall(function() frame.x = 0 end)
    pcall(function() frame.y = 0 end)
    frame.isHitTestable = false
    local tx = TRACK.x0 * sc
    local tw = (TRACK.x1 - TRACK.x0) * sc
    local ty = TRACK.y0 * sc
    local th = (TRACK.y1 - TRACK.y0) * sc
    local function setWrap(mode)
      pcall(function()
        if display.setDefault then
          display.setDefault("textureWrapX", mode)
          display.setDefault("textureWrapY", mode)
        end
      end)
    end
    setWrap("repeat")
    local built = false
    pcall(function()
      local track = display.newRect(g, 0, 0, tw, th)
      track.fill = { type = "image", filename = "art/progressbarback.png" }
      track.fill.scaleX = TILE / tw
      track.fill.scaleY = TILE / th
      track.isHitTestable = false
      local fill = display.newRect(g, 0, 0, 2, th)
      fill.anchorX = 0
      fill.fill = { type = "image", filename = "art/progressbar.png" }
      fill.fill.scaleX = TILE / 2
      fill.fill.scaleY = TILE / th
      fill.isHitTestable = false
      S.track, S.fill = track, fill
      built = true
    end)
    setWrap("clampToEdge")
    if not built then return end
    local pct = display.newText(g, "0%", 0, 0, fontOf(), 20)
    pct:setFillColor(1, 1, 1)
    pct.isHitTestable = false
    S.g, S.pct = g, pct
    S.tx, S.tw, S.ty, S.th = tx, tw, ty, th
    S.attached = true
    pcall(function() g._alphaNoStretch = true end)
    ok = true
  end)
  if ok then
    pcall(function() M.follow(b) end)
    if type(cx) == "number" and type(maxY) == "number" then
      pcall(function() M.move(cx, maxY) end)
    end
    pcall(function() M.crtFront() end)
  end
  return ok
end
function M.crtFront()
  pcall(function()
    local G = _G.G
    if G and G.UI and G.UI.CRT and G.UI.CRT.toFront then
      G.UI.CRT:toFront()
    end
  end)
  return true
end
function M.move(cx, maxY)
  if not S.g then return false end
  local ok = false
  pcall(function()
    if S.frozen then
      ok = true
      return
    end
    if S.lockX ~= nil and S.lockY ~= nil then
      S.g.x, S.g.y = S.lockX, S.lockY
      ok = true
      return
    end
    if not (cx and maxY) then return end
    local ox, oy = 0, 0
    pcall(function()
      if S.ox then ox = S.ox end
      if S.oy then oy = S.oy end
    end)
    S.g.x = cx - S.W / 2 + ox
    S.g.y = maxY + GAP_BELOW + oy
    ok = true
  end)
  return ok
end
function M.setOffset(dx, dy)
  pcall(function()
    S.ox = (S.ox or 0) + (dx or 0)
    S.oy = (S.oy or 0) + (dy or 0)
  end)
  local ox, oy = 0, 0
  pcall(function() ox, oy = S.ox or 0, S.oy or 0 end)
  return ox, oy
end
function M.getOffset()
  local ox, oy = 0, 0
  pcall(function() ox, oy = S.ox or 0, S.oy or 0 end)
  return ox, oy
end
function M.follow(board)
  if not S.attached then return false end
  local ok = false
  pcall(function()
    local minX, maxX, maxY, n = nil, nil, nil, 0
    local pref = nil
    local shared = true
    if type(board) == "table" then
      for _, col in pairs(board) do
        if type(col) == "table" then
          for _, cell in pairs(col) do
            local x, y = nil, nil
            pcall(function() x = cell.x y = cell.y end)
            if type(x) == "number" and type(y) == "number" then
              n = n + 1
              if not minX or x < minX then minX = x end
              if not maxX or x > maxX then maxX = x end
              if not maxY or y > maxY then maxY = y end
              local pr = nil
              pcall(function() pr = cell.parent end)
              if pref == nil then
                pref = pr
              elseif pr ~= pref then
                shared = false
              end
            end
          end
        end
      end
    end
    if n > 0 then
      if shared and pref ~= nil then
        local same = false
        pcall(function() same = (S.g and S.g.parent == pref) end)
        if not same then
          pcall(function() pref:insert(S.g) end)
        end
      end
      local cx, baseY = (minX + maxX) / 2, maxY
      pcall(function()
        local xs, ys = {}, {}
        if type(board) == "table" then
          for _, col in pairs(board) do
            if type(col) == "table" then
              for _, cell in pairs(col) do
                local x, y = nil, nil
                pcall(function() x = cell.x y = cell.y end)
                if type(x) == "number" and type(y) == "number" then
                  xs[#xs + 1] = x
                  ys[#ys + 1] = y
                end
              end
            end
          end
        end
        table.sort(xs)
        table.sort(ys)
        local m = #xs
        if m > 0 then
          if m % 2 == 1 then cx = xs[(m + 1) / 2]
          else cx = (xs[m / 2] + xs[m / 2 + 1]) / 2 end
          local q = ys[math.floor(m * 0.75)]
          if type(q) == "number" then baseY = q end
        end
      end)
      M.move(cx, baseY)
      ok = true
    end
  end)
  pcall(function() M.center(board) end)
  return ok
end
function M.center(board)
  return false
end
function M.update(p, board)
  if S.attached and not alive() then drop() end
  if not S.attached then
    if board then pcall(function() M.attach(nil, nil, board) end) end
    if not S.attached then return false end
  end
  if board then pcall(function() M.follow(board) end) end
  if type(p) ~= "number" then p = 0 end
  if p ~= p or p < 0 then p = 0 end
  if p > 1 then p = 1 end
  pcall(function()
    local fw = math.max(0, S.tw * p)
    S.fill.width = fw
    if fw > 0 then
      S.fill.fill.scaleX = TILE / fw
    end
    S.fill.x = S.tx
    S.fill.y = S.ty + S.th / 2
    S.track.x = S.tx + S.tw / 2
    S.track.y = S.ty + S.th / 2
    if S.pct then
      S.pct.text = tostring(math.floor(p * 100)) .. "%"
      S.pct.x = S.tx + S.tw / 2
      S.pct.y = S.ty + S.th / 2
    end
  end)
  pcall(function()
    local G = _G.G
    if G then
      local pw = 20
      pcall(function()
        if G.INI and G.INI.ProgressWidth then pw = G.INI.ProgressWidth end
      end)
      G.Progress = p * pw
      G.ProgressProcent = p
    end
  end)
  return true
end
function M.push(G, c, t)
  return true
end
function M.hide()
  pcall(function() if S.g then S.g.isVisible = false end end)
  return true
end
function M.show()
  pcall(function() if S.g then S.g.isVisible = true end end)
  pcall(function() M.crtFront() end)
  return true
end
function M.describe(level, c, t, snap)
  return "Level " .. tostring(level) .. ": " .. tostring(c) .. "/" .. tostring(t)
end
function M.install()
  hideLegacy()
  return true
end
function M.selftest()
  return "REALBAR_OK"
end
function M.nudge(dx, dy)
  if not (S.g and dx and dy) then return false end
  local ok = false
  pcall(function()
    S.g.x = (S.g.x or 0) + dx
    S.g.y = (S.g.y or 0) + dy
    ok = true
  end)
  return ok
end
function M.pos()
  local p = nil
  pcall(function()
    if S.g then p = { x = S.g.x, y = S.g.y } end
  end)
  return p
end
function M.group()
  local g = nil
  pcall(function() g = S.g end)
  return g
end
function M.setFrozen(f)
  pcall(function() S.frozen = (f == true) and true or nil end)
  return true
end
function M.isFrozen()
  local f = false
  pcall(function() f = S.frozen == true end)
  return f
end
function M.lock(x, y)
  pcall(function()
    if x == nil or y == nil then
      S.lockX, S.lockY = nil, nil
    else
      S.lockX, S.lockY = x, y
    end
  end)
  return true
end
  return M
end)()
package.loaded["mod_alpha_realbar"] = realbar
return {
  ["mod_alpha_hud"] = hud,
  ["mod_alpha_realbar"] = realbar,
}
