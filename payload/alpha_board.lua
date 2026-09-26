local board = (function()
local M = {}
M.id = "alpha-board-v6"
M.COLS = 5
M.ROWS = 2
M.FONT = "fonts/selawkb.ttf"
M.FONTSIZE = 26
local FIN = nil
local GP, HL = nil, nil
pcall(function()
  local ok, m = pcall(require, "mod_alpha_finish")
  if ok and m then FIN = m end
end)
pcall(function()
  local ok, m = pcall(require, "mod_alpha_gameplay")
  if ok and m then GP = m end
end)
pcall(function()
  local ok, m = pcall(require, "mod_alpha_highlight")
  if ok and m then HL = m end
end)
local LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H", "I" }
local EMPTY = ""
if FIN then
  LETTERS = FIN.LETTERS or LETTERS
  EMPTY = FIN.EMPTY or EMPTY
end
M.LETTERS = LETTERS
M.EMPTY = EMPTY
M.TIME_LIMIT = (FIN and FIN.TIME_LIMIT) or 1200
local function idx(c, r) return (r - 1) * M.COLS + c end
local function rc(i)
  return ((i - 1) % M.COLS) + 1, math.floor((i - 1) / M.COLS) + 1
end
local function cellSym(cell)
  local s = nil
  pcall(function() s = cell.Symbol end)
  return s
end
local function find2()
  local out = {}
  if not (display and display.getCurrentStage) then return out end
  local groups = {}
  local order = {}
  pcall(function()
    local st = display.getCurrentStage()
    local function isCell(o)
      local okS, s = pcall(function() return o.Symbol end)
      if not okS or type(s) ~= "string" then return false end
      local okT, t = pcall(function() return o.SymbolText end)
      if not okT or t == nil then return false end
      return true
    end
    local function walk(o, d)
      if d > 16 or o == nil then return end
      if isCell(o) then
        local parent = nil
        pcall(function() parent = o.parent end)
        local k = tostring(parent)
        local g = groups[k]
        if not g then
          g = { parent = parent, cells = {} }
          groups[k] = g
          order[#order + 1] = k
        end
        g.cells[#g.cells + 1] = o
      end
      local nk = 0
      pcall(function() nk = o.numChildren or 0 end)
      for i = 1, (nk or 0) do
        local okC, ch = pcall(function() return o[i] end)
        if okC and ch ~= nil then walk(ch, d + 1) end
      end
    end
    walk(st, 0)
  end)
  local cols = M.COLS or 5
  for _, k in ipairs(order) do
    local g = groups[k]
    local cells = g.cells
    local n = #cells
    if n >= cols and (n % cols) == 0 then
      local xs = {}
      for i = 1, n do
        local x = 0
        pcall(function() x = cells[i].x or 0 end)
        xs[i] = { x = x, o = cells[i] }
      end
      table.sort(xs, function(a, b) return a.x < b.x end)
      local per = n / cols
      local b = {}
      local okb = true
      for c = 1, cols do
        b[c] = {}
        for r = 1, per do
          b[c][r] = xs[(c - 1) * per + r].o
        end
        table.sort(b[c], function(a, c2)
          local ya, yb = 0, 0
          pcall(function() ya = a.y or 0 end)
          pcall(function() yb = c2.y or 0 end)
          return ya < yb
        end)
      end
      if okb then
        out[#out + 1] = { board = b, cells = cells, n = n }
      end
    end
  end
  table.sort(out, function(a, b) return a.n > b.n end)
  if #out > 0 then
    pcall(function()
    end)
  end
  return out
end
function M.find_old()
  local out = {}
  if not (display and display.getCurrentStage and debug and
      debug.getupvalue) then return out end
  pcall(function()
    local st = display.getCurrentStage()
    local seen = {}
    local function walk(o, d)
      if d > 16 then return end
      local okI, idv = pcall(function() return o.ID end)
      if okI and idv == "custom2" then
        local okF, fv = pcall(function() return o.Func end)
        if okF and type(fv) == "function" then
          local ok1, _, u1 = pcall(debug.getupvalue, fv, 1)
          local ok2, _, u2 = pcall(debug.getupvalue, fv, 2)
          local ok3, _, u3 = pcall(debug.getupvalue, fv, 3)
          if ok1 and type(u1) == "table" and ok2 and
              type(u2) == "number" and ok3 and type(u3) == "number" then
            local n = 0
            pcall(function() for _ in pairs(u1) do n = n + 1 end end)
            if n == 10 and not seen[tostring(u1)] then
              seen[tostring(u1)] = true
              out[#out + 1] = { board = u1, obj = o, func = fv }
            end
          end
        end
      end
      local nk = 0
      pcall(function() nk = o.numChildren or 0 end)
      for i = 1, (nk or 0) do
        local okC, ch = pcall(function() return o[i] end)
        if okC and ch ~= nil then walk(ch, d + 1) end
      end
    end
    walk(st, 0)
  end)
  return out
end
function M.find()
  local r = nil
  pcall(function() r = find2() end)
  if type(r) == "table" and #r > 0 then return r end
  local o = nil
  pcall(function() o = M.find_old() end)
  if type(o) == "table" then return o end
  return {}
end
local function getCell(b, c, r)
  if type(b) ~= "table" then return nil end
  local col = b[c]
  if type(col) ~= "table" then return nil end
  return col[r]
end
M.getCell = getCell
M.cellSym = cellSym
local function completeCell(cell)
  pcall(function()
    if cell == nil then return end
    local s = cellSym(cell)
    if s == nil then cell.Symbol = "" end
    local hasST, hasY = false, false
    pcall(function() hasST = (cell.SymbolText ~= nil) end)
    pcall(function() hasY = (cell.Yellow ~= nil) end)
    local parent = nil
    pcall(function() parent = cell.parent end)
    local cx, cy = 0, 0
    pcall(function() cx = cell.x or 0 cy = cell.y or 0 end)
    if not hasST and parent then
      local tx = nil
      pcall(function()
        tx = display.newText(parent, cell.Symbol or "",
          cx, cy, M.FONT, M.FONTSIZE)
      end)
      if not tx then
        pcall(function()
          tx = display.newText(parent, cell.Symbol or "",
            cx, cy, native.systemFont, M.FONTSIZE)
        end)
      end
      if tx then
        pcall(function() tx:setFillColor(0, 0, 0) end)
        cell.SymbolText = tx
      end
    end
    if not hasY and parent then
      local w, h = 56, 56
      pcall(function() w = cell.width or w h = cell.height or h end)
      local mk = nil
      pcall(function()
        mk = display.newRect(parent, cx, cy, w - 6, h - 6)
      end)
      if mk then
        pcall(function()
          mk:setFillColor(1, 1, 1, 0)
          mk:setStrokeColor(1, 0.85, 0.25)
          mk.strokeWidth = 4
          mk.isVisible = false; mk:toFront()
          if cell.SymbolText then cell.SymbolText:toFront() end
        end)
        cell.Yellow = mk
      end
    end
  end)
end
local function paintCell(cell, letter)
  pcall(function()
    if cell == nil then return end
    cell.Symbol = letter
    if cell.SymbolText then
      pcall(function() cell.SymbolText.text = letter end)
    end
  end)
end
local function markEmpty(b, c, r, isEmpty)
  pcall(function()
    local cell = getCell(b, c, r)
    if cell and cell.Yellow and cell.Yellow.isVisible ~= nil then
      cell.Yellow.isVisible = false
    end
  end)
end
function M.takeover(b, seed, level, letters)
  for c = 1, M.COLS do
    for r = 1, M.ROWS do
      completeCell(getCell(b, c, r))
    end
  end
  level = math.max(1, math.floor(tonumber(level) or 1))
  local want = letters
  if type(want) ~= "table" then
    if GP and GP.level_letters then want = GP.level_letters(level)
    elseif FIN and FIN.level_letters then want = FIN.level_letters(level)
    else want = LETTERS end
  end
  if seed then math.randomseed(seed) end
  local shadow = {}
  for i = 1, 9 do shadow[i] = want[i] end
  shadow[10] = EMPTY
  local target = {}
  for i = 1, 9 do target[i] = want[i] end
  target[10] = EMPTY
  local nmoves = 30
  if GP and GP.difficulty then
    local okD, d = pcall(GP.difficulty, level)
    if okD and d and d.moves then nmoves = d.moves end
  end
  local e = 10
  local function nbs(i)
    local c, r = rc(i)
    local o = {}
    if r > 1 then o[#o + 1] = idx(c, r - 1) end
    if r < M.ROWS then o[#o + 1] = idx(c, r + 1) end
    if c > 1 then o[#o + 1] = idx(c - 1, r) end
    if c < M.COLS then o[#o + 1] = idx(c + 1, r) end
    return o
  end
  for _ = 1, nmoves do
    local ns = nbs(e)
    local pick = ns[math.random(#ns)]
    shadow[e] = shadow[pick]
    shadow[pick] = EMPTY
    e = pick
  end
  local function solved()
    for i = 1, 10 do if shadow[i] ~= target[i] then return false end end
    return true
  end
  if solved() then
    for i = 1, 10 do
      local okT = false
      if FIN and FIN.touch then okT = FIN.touch(shadow, i) end
      if okT then break end
    end
  end
  local api = { board = b, moves = 0, level = level, target = target }
  local function render()
    for i = 1, 10 do
      local c, r = rc(i)
      paintCell(getCell(b, c, r), shadow[i])
    end
    for i = 1, 10 do
      local c, r = rc(i)
      markEmpty(b, c, r, shadow[i] == EMPTY)
    end
    if HL and HL.refresh then pcall(HL.refresh, b, getCell, shadow, target, EMPTY) end
  end
  render()
  function api.snap()
    local t = {}
    for i = 1, 10 do
      local s = shadow[i]
      t[#t + 1] = (s == EMPTY) and "_" or s
    end
    return table.concat(t)
  end
  function api.slide(c, r)
    local i = idx(c, r)
    local ok = false
    if FIN and FIN.touch then
      ok = FIN.touch(shadow, i)
    else
      if shadow[i] ~= EMPTY then
        for _, j in ipairs(nbs(i)) do
          if shadow[j] == EMPTY then
            shadow[j] = shadow[i]
            shadow[i] = EMPTY
            ok = true
            break
          end
        end
      end
    end
    if ok then
      api.moves = api.moves + 1
      render()
    end
    return ok
  end
  function api.correct()
    local hit = 0
    for i = 1, 10 do if shadow[i] == target[i] then hit = hit + 1 end end
    return hit, 10
  end
  function api.progress()
    local hit = api.correct()
    return hit / 10
  end
  function api.isWin() return solved() end
  return api
end
function M._test()
  return { idx = idx, rc = rc }
end
  return M
end)()
package.loaded["mod_alpha_board"] = board
local textcolor = (function()
local M = {}
M.id = "alpha-textcolor-v1"
M.TEXT = { 0, 0, 0 }
M.HUD_TEXT = { 1, 1, 1 }
M.BANNER_WIN = { 0.4, 1, 0.4 }
M.BANNER_LOSS = { 1, 0.4, 0.4 }
M.YELLOW_STROKE = { 1, 0.85, 0.25 }
local function ink(tx)
  pcall(function()
    if tx and tx.setFillColor then tx:setFillColor(M.TEXT[1], M.TEXT[2], M.TEXT[3]) end
  end)
end
function M.paintSymbol(cell, _ok)
  if type(cell) ~= "table" then return false end
  ink(cell.SymbolText)
  pcall(function()
    if cell.SymbolText and cell.SymbolText.toFront then
      cell.SymbolText:toFront()
    end
  end)
  pcall(function()
    if cell.Yellow and cell.Yellow.toBack then cell.Yellow:toBack() end
  end)
  return true
end
function M.resetBoard(board, getCell)
  if type(board) ~= "table" or type(getCell) ~= "function" then return 0 end
  local n = 0
  for c = 1, 5 do
    for r = 1, 2 do
      pcall(function()
        local cell = getCell(board, c, r)
        if cell then if M.paintSymbol(cell, true) then n = n + 1 end end
      end)
    end
  end
  return n
end
local function hudInk(tx)
  pcall(function()
    if tx and tx.setFillColor then
      tx:setFillColor(M.HUD_TEXT[1], M.HUD_TEXT[2], M.HUD_TEXT[3])
    end
  end)
end
function M.paintHud(hud)
  if type(hud) ~= "table" then return false end
  hudInk(hud.pct)
  hudInk(hud.moves)
  return true
end
function M.selftest()
  local calls = {}
  local function mkTx() return {
    setFillColor = function(_, r, g, b) calls[#calls + 1] = { r, g, b } end,
    toFront = function() end,
  } end
  local cell = { SymbolText = mkTx(), Yellow = { toBack = function() end } }
  assert(M.paintSymbol(cell, false) == true, "paint ok")
  assert(M.paintSymbol(cell, true) == true, "paint ok2")
  for _, c in ipairs(calls) do
    assert(c[1] == 0 and c[2] == 0 and c[3] == 0, "glyph always black")
  end
  local b = {}
  for c = 1, 5 do b[c] = {} for r = 1, 2 do
    b[c][r] = { SymbolText = mkTx() }
  end end
  local n = M.resetBoard(b, function(bb, c, r) return bb[c][r] end)
  assert(n == 10, "10 cells reset")
  local hud = { pct = mkTx(), moves = mkTx() }
  assert(M.paintHud(hud) == true, "hud ok")
  for _, c in ipairs(calls) do
    local yellow = (c[1] == 1 and c[2] == 0.9 and c[3] == 0.4)
    assert(not yellow, "no yellow in text")
  end
  return "TEXTCOLOR_OK black10+hud"
end
  return M
end)()
package.loaded["mod_alpha_textcolor"] = textcolor
local highlight = (function()
local M = {}
M.id = "alpha-highlight-v7"
function M.refresh(board, getCell, shadow, target, empty)
  if type(board) ~= "table" or type(getCell) ~= "function" then return 0 end
  if type(shadow) ~= "table" or type(target) ~= "table" then return 0 end
  empty = empty == nil and "" or empty
  local n = #shadow
  if type(#target) == "number" and #target > n then n = #target end
  if n < 10 then n = 10 end
  if n > 25 then n = 25 end
  local painted = 0
  for i = 1, n do
    local c = ((i - 1) % 5) + 1
    local r = math.floor((i - 1) / 5) + 1
    pcall(function()
      local cell = getCell(board, c, r)
      if cell == nil then return end
      local s = shadow[i]
      local ok = (s == target[i])
      pcall(function()
        if cell.Yellow then
          cell.Yellow:setFillColor(1, 1, 1, 0)
          cell.Yellow:setStrokeColor(1, 0.85, 0.25)
          cell.Yellow.strokeWidth = 4
          if cell.x then cell.Yellow.x = cell.x end
          if cell.y then cell.Yellow.y = cell.y end
        end
      end)
      if s == empty then
        if cell.Yellow and cell.Yellow.isVisible ~= nil then
          cell.Yellow.isVisible = false
        end
      else
        if cell.Yellow and cell.Yellow.isVisible ~= nil then
          cell.Yellow.isVisible = false
        end
      end
      if cell.SymbolText and cell.SymbolText.setFillColor then
        local done = false
        pcall(function()
          local okT, TC = pcall(require, "mod_alpha_textcolor")
          if okT and TC and TC.paintSymbol then
            done = TC.paintSymbol(cell, ok)
          end
        end)
        if not done then cell.SymbolText:setFillColor(0, 0, 0) end
        pcall(function() cell.SymbolText:toFront() end)
      end
      painted = painted + 1
    end)
  end
  return painted
end
function M.selftest()
  local cells = {}
  for c = 1, 5 do
    cells[c] = {}
    for r = 1, 5 do
      cells[c][r] = { Yellow = { isVisible = false },
        SymbolText = { setFillColor = function() end } }
    end
  end
  local function getCell(b, c, r) return b[c] and b[c][r] end
  local n = M.refresh(cells, getCell,
    { "A", "B", "C", "D", "E", "F", "G", "H", "I", "" },
    { "A", "B", "C", "D", "E", "F", "G", "H", "I", "" }, "")
  assert(n == 10, "10 cells L1")
  local sh25, tg25 = {}, {}
  for i = 1, 25 do sh25[i] = "A" tg25[i] = "A" end
  local n25 = M.refresh(cells, getCell, sh25, tg25, "")
  assert(n25 == 25, "25 cells 5x5")
  return "HIGHLIGHT_OK 10+25"
end
  return M
end)()
package.loaded["mod_alpha_highlight"] = highlight
local outline = (function()
local M = {}
M.id = "alpha-outline-v1"
M.COLS, M.ROWS, M.N = 5, 5, 25
M.NOBOX = true
M.INSET, M.STROKE = 6, 4
M.LOGF = "mod_alpha_hud.log"
local S = { sel = nil, box = nil, noVis = false, hooked = false,
  board = nil, getCell = nil }
function M.idx(c, r) return (r - 1) * M.COLS + c end
function M.rc(i) return ((i - 1) % M.COLS) + 1, math.floor((i - 1) / M.COLS) + 1 end
function M.valid(i)
  i = tonumber(i)
  return i and i >= 1 and i <= M.N and math.floor(i) == i
end
function M.valid_cr(c, r)
  c, r = tonumber(c), tonumber(r)
  return c and r and c >= 1 and c <= M.COLS and r >= 1 and r <= M.ROWS
end
local function getCellOf(board, getCell, i)
  if type(getCell) == "function" and type(board) == "table" then
    local c, r = M.rc(i)
    local cell = nil
    pcall(function() cell = getCell(board, c, r) end)
    return cell
  end
  if type(board) == "table" then
    local c, r = M.rc(i)
    local cell = nil
    pcall(function()
      if type(board[c]) == "table" then cell = board[c][r] end
    end)
    return cell
  end
  return nil
end
local function stage()
  local st = nil
  pcall(function()
    if display and display.getCurrentStage then st = display.getCurrentStage() end
  end)
  return st
end
local function contentCenter(cell)
  local cx, cy = nil, nil
  pcall(function()
    local b = cell.contentBounds
    if type(b) == "table" and type(b.xMin) == "number" then
      cx = (b.xMin + b.xMax) / 2
      cy = (b.yMin + b.yMax) / 2
    end
  end)
  if type(cx) ~= "number" then
    pcall(function()
      if cell.localToContent then cx, cy = cell:localToContent(0, 0) end
    end)
  end
  if type(cx) ~= "number" then
    pcall(function()
      local ox, oy, o, guard = 0, 0, cell, 0
      while o ~= nil and guard < 16 do
        if type(o.x) == "number" then ox = ox + o.x end
        if type(o.y) == "number" then oy = oy + o.y end
        guard = guard + 1
        local p = nil
        pcall(function() p = o.parent end)
        if p == o then break end
        o = p
      end
      local st = stage()
      if st then
        if type(st.x) == "number" then ox = ox - st.x end
        if type(st.y) == "number" then oy = oy - st.y end
      end
      cx, cy = ox, oy
    end)
  end
  if type(cx) ~= "number" then
    pcall(function() cx, cy = cell.x, cell.y end)
  end
  if type(cx) ~= "number" or type(cy) ~= "number" then return nil end
  return cx, cy
end
local function toStage(cx, cy)
  local sx, sy = cx, cy
  pcall(function()
    local st = stage()
    if st and st.contentToLocal then sx, sy = st:contentToLocal(cx, cy) end
  end)
  return sx, sy
end
local function cellSize(cell)
  local w, h = nil, nil
  pcall(function()
    w = cell.contentWidth or cell.width
    h = cell.contentHeight or cell.height
  end)
  return tonumber(w) or 62, tonumber(h) or 62
end
local function ensureBox()
  if M.NOBOX then
    pcall(function()
      if S.box and S.box.removeSelf then S.box:removeSelf() end
    end)
    S.box = nil
    return nil
  end
  if S.noVis then return nil end
  local st = stage()
  if S.box ~= nil then
    local same = false
    pcall(function() same = (S.box.parent == st) end)
    if st ~= nil and not same then
      pcall(function()
        if S.box.removeSelf then S.box:removeSelf() end
      end)
      S.box = nil
    end
  end
  if S.box == nil then
    if not (display and display.newRect) then
      S.noVis = true
      return nil
    end
    local ok = pcall(function()
      S.box = display.newRect(st, 0, 0, 62 - M.INSET, 62 - M.INSET)
      S.box:setFillColor(1, 1, 1, 0)
      S.box:setStrokeColor(1, 0.85, 0.25)
      S.box.strokeWidth = M.STROKE
      S.box.isVisible = false
    end)
    if not ok or S.box == nil then
      S.box = nil
      S.noVis = true
      return nil
    end
  end
  return S.box
end
function M.refresh(board, getCell)
  if not M.valid(S.sel) then M.hide() return false end
  local cell = getCellOf(board, getCell, S.sel)
  if cell == nil then M.hide() return false end
  local ccx, ccy = contentCenter(cell)
  if ccx == nil then M.hide() return false end
  local sx, sy = toStage(ccx, ccy)
  local w, h = cellSize(cell)
  pcall(function()
    if type(w) == "number" then
      if w < 34 then w = 34 end
      if w > 90 then w = 90 end
    end
    if type(h) == "number" then
      if h < 34 then h = 34 end
      if h > 90 then h = 90 end
    end
  end)
  local box = ensureBox()
  if box == nil then return false end
  pcall(function()
    box.x, box.y = sx, sy
    box.width, box.height = w - M.INSET, h - M.INSET
    box:setFillColor(1, 1, 1, 0)
    box:setStrokeColor(1, 0.85, 0.25)
    box.strokeWidth = M.STROKE
    box.isVisible = true
    if box.toFront then box:toFront() end
    if cell.SymbolText and cell.SymbolText.toFront then
      cell.SymbolText:toFront()
    end
  end)
  local ok = false
  pcall(function()
    ok = (math.abs(box.x - sx) < 0.5 and math.abs(box.y - sy) < 0.5)
  end)
  return ok
end
function M.onSlid(board, getCell) return M.refresh(board, getCell) end
function M.set(board, getCell, i)
  if not M.valid(i) then return false end
  if getCellOf(board, getCell, i) == nil then return false end
  S.sel = math.floor(tonumber(i))
  S.board, S.getCell = board, getCell
  pcall(function()
    if S.lastLogSel ~= S.sel then
      S.lastLogSel = S.sel
      local c = getCellOf(board, getCell, S.sel)
      local cw, ch, cx, cy = nil, nil, nil, nil
      if c then
        pcall(function()
          local b = c.contentBounds
          if type(b) == "table" and type(b.xMin) == "number" then
            cx = (b.xMin + b.xMax) / 2
            cy = (b.yMin + b.yMax) / 2
            cw = b.xMax - b.xMin
            ch = b.yMax - b.yMin
          end
        end)
      end
    end
  end)
  return M.refresh(board, getCell)
end
function M.set_cr(board, getCell, c, r)
  if not M.valid_cr(c, r) then return false end
  return M.set(board, getCell, M.idx(c, r))
end
function M.selected() return S.sel end
function M.clear()
  S.sel = nil
  S.board, S.getCell = nil, nil
  M.hide()
end
function M.hide()
  pcall(function() if S.box and S.box.isVisible ~= nil then S.box.isVisible = false end end)
end
function M.drop()
  pcall(function()
    if S.hooked and Runtime and Runtime.removeEventListener then
      Runtime:removeEventListener("enterFrame", M._frame)
    end
  end)
  S.hooked = false
  pcall(function()
    if S.box and S.box.removeSelf then S.box:removeSelf() end
  end)
  S.box, S.sel, S.noVis = nil, nil, false
  S.board, S.getCell = nil, nil
end
function M._frame()
  S.fn = (S.fn or 0) + 1
  if S.fn % 6 ~= 0 then return end
  local mode = nil
  pcall(function()
    if type(onHoverTouch) == "function" and debug and debug.getupvalue then
      local _, g = debug.getupvalue(onHoverTouch, 1)
      if type(g) == "table" then mode = g.ModeCurrent end
    end
  end)
  if mode == nil then
    pcall(function()
      local A = _G.__ALPHA
      if type(A) == "table" and type(A.state) == "function" then
        local _, _, _, over = A.state()
        if over == true then mode = "outro" end
      end
    end)
  end
  if mode ~= nil and mode ~= "alphabeth" then M.clear() return end
  if M.valid(S.sel) and S.board ~= nil then
    pcall(M.refresh, S.board, S.getCell)
  end
end
local function dethrone()
  pcall(function()
    local ok, Old = pcall(require, "mod_alpha_select")
    if ok and type(Old) == "table" and Old ~= M then
      pcall(function() if Old.drop then Old.drop() end end)
      for k, v in pairs(M) do pcall(function() Old[k] = v end) end
    end
  end)
  pcall(function() package.loaded["mod_alpha_select"] = M end)
  pcall(function()
    _G.__ALPHA_SELECT_MOD = M
    if _G.__ALPHA and type(_G.__ALPHA) == "table" then
      _G.__ALPHA.select = M
    end
  end)
end
function M.install()
  dethrone()
  pcall(function()
    if Runtime and Runtime.addEventListener and not S.hooked then
      Runtime:addEventListener("enterFrame", M._frame)
      S.hooked = true
    end
  end)
  _G.__ALPHA_SELECT = _G.__ALPHA_SELECT or {
    set = function(b, g, i) return M.set(b, g, i) end,
    set_cr = function(b, g, c, r) return M.set_cr(b, g, c, r) end,
    clear = function() return M.clear() end,
    refresh = function(b, g) return M.refresh(b, g) end,
    onSlid = function(b, g) return M.onSlid(b, g) end,
    hide = function() return M.hide() end,
    selected = function() return M.selected() end,
  }
  return true
end
function M.takeover()
  M.install()
  return true
end
function M.selftest()
  assert(M.idx(1, 1) == 1 and M.idx(5, 1) == 5, "idx f1")
  assert(M.idx(1, 2) == 6 and M.idx(5, 2) == 10, "idx f2")
  assert(M.idx(1, 5) == 21 and M.idx(5, 5) == 25, "idx f5")
  local c, r = M.rc(7)
  assert(c == 2 and r == 2, "rc(7)=2,2")
  assert(M.valid(1) and M.valid(10) and M.valid(25), "1..25")
  assert(not M.valid(0) and not M.valid(26) and not M.valid(nil), "oob")
  assert(M.valid_cr(5, 2) and M.valid_cr(5, 5) and not M.valid_cr(6, 1), "cr 5x5")
  assert(M.selected() == nil, "starts with no selection")
  assert(M.set(nil, nil, 99) == false, "oob set does not stick")
  local win = { x = 300, y = 200, parent = nil }
  local cell = { x = 10, y = 10, width = 62, height = 62, parent = win }
  local ccx, ccy = contentCenter(cell)
  assert(ccx == 310 and ccy == 210, "sums parents, not raw x/y")
  local sx, sy = toStage(ccx, ccy)
  assert(sx == 310 and sy == 210, "stage (origin) = content")
  M.clear()
  assert(M.selected() == nil, "clear cleans")
  return "OUTLINE_OK idx+oob+space+clear"
end
function M._test() return { cc = contentCenter, ts = toStage, sz = cellSize, S = S } end
  return M
end)()
package.loaded["mod_alpha_outline"] = outline
local select = (function()
local M = {}
M.id = "alpha-select-v1"
M.COLS = 5
M.ROWS = 5
M.N = 25
M.NOBOX = true
M.INSET = 6
M.STROKE = 4
M.LOGF = "mod_alpha_hud.log"
local S = { sel = nil, box = nil, noVis = false, hooked = false,
  board = nil, getCell = nil }
function M.idx(c, r) return (r - 1) * M.COLS + c end
function M.rc(i)
  return ((i - 1) % M.COLS) + 1, math.floor((i - 1) / M.COLS) + 1
end
function M.valid(i)
  i = tonumber(i)
  return i and i >= 1 and i <= M.N and math.floor(i) == i
end
function M.valid_cr(c, r)
  c, r = tonumber(c), tonumber(r)
  if not (c and r) then return false end
  return c >= 1 and c <= M.COLS and r >= 1 and r <= M.ROWS
end
local function getCellOf(board, getCell, i)
  if type(getCell) == "function" and type(board) == "table" then
    local c, r = M.rc(i)
    local cell = nil
    pcall(function() cell = getCell(board, c, r) end)
    return cell
  end
  if type(board) == "table" then
    local c, r = M.rc(i)
    local cell = nil
    pcall(function()
      if type(board[c]) == "table" then cell = board[c][r] end
    end)
    return cell
  end
  return nil
end
local function cellGeom(cell)
  local g = {}
  pcall(function()
    g.x, g.y = cell.x, cell.y
    g.w, g.h = cell.width, cell.height
    g.parent = cell.parent
  end)
  if type(g.x) ~= "number" or type(g.y) ~= "number" then return nil end
  g.w = tonumber(g.w) or 62
  g.h = tonumber(g.h) or 62
  return g
end
local function ensureBox(geom)
  if M.NOBOX then
    pcall(function()
      if S.box and S.box.removeSelf then S.box:removeSelf() end
    end)
    S.box = nil
    return nil
  end
  if S.noVis then return nil end
  if S.box ~= nil then
    local same = false
    pcall(function() same = (S.box.parent == geom.parent) end)
    if geom.parent ~= nil and not same then
      pcall(function()
        if S.box.removeSelf then S.box:removeSelf() end
      end)
      S.box = nil
    end
  end
  if S.box == nil then
    if not (display and display.newRect) then
      S.noVis = true
      return nil
    end
    local parent = geom.parent
    if parent == nil then
      pcall(function()
        if display.getCurrentStage then parent = display.getCurrentStage() end
      end)
    end
    if parent == nil then
      S.noVis = true
      return nil
    end
    local ok = pcall(function()
      S.box = display.newRect(parent, geom.x, geom.y,
        geom.w - M.INSET, geom.h - M.INSET)
      S.box:setFillColor(1, 1, 1, 0)
      S.box:setStrokeColor(1, 0.85, 0.25)
      S.box.strokeWidth = M.STROKE
      S.box.isVisible = false
    end)
    if not ok or S.box == nil then
      S.box = nil
      S.noVis = true
      return nil
    end
  end
  return S.box
end
function M.refresh(board, getCell)
  local i = S.sel
  if not M.valid(i) then
    M.hide()
    return false
  end
  local cell = getCellOf(board, getCell, i)
  if cell == nil then
    M.hide()
    return false
  end
  local geom = cellGeom(cell)
  if geom == nil then
    M.hide()
    return false
  end
  local box = ensureBox(geom)
  if box == nil then return false end
  pcall(function()
    box.x, box.y = geom.x, geom.y
    box.width = geom.w - M.INSET
    box.height = geom.h - M.INSET
    box:setFillColor(1, 1, 1, 0)
    box:setStrokeColor(1, 0.85, 0.25)
    box.strokeWidth = M.STROKE
    box.isVisible = true
    if box.toFront then box:toFront() end
    if cell.SymbolText and cell.SymbolText.toFront then
      cell.SymbolText:toFront()
    end
  end)
  local ok = false
  pcall(function() ok = (box.x == geom.x and box.y == geom.y) end)
  return ok
end
function M.onSlid(board, getCell) return M.refresh(board, getCell) end
function M.set(board, getCell, i)
  if not M.valid(i) then return false end
  local cell = getCellOf(board, getCell, i)
  if cell == nil then return false end
  if cellGeom(cell) == nil then return false end
  S.sel = math.floor(tonumber(i))
  S.board, S.getCell = board, getCell
  return M.refresh(board, getCell)
end
function M.set_cr(board, getCell, c, r)
  if not M.valid_cr(c, r) then return false end
  return M.set(board, getCell, M.idx(c, r))
end
function M.selected() return S.sel end
function M.clear()
  S.sel = nil
  S.board, S.getCell = nil, nil
  M.hide()
end
function M.hide()
  pcall(function()
    if S.box and S.box.isVisible ~= nil then S.box.isVisible = false end
  end)
end
function M.drop()
  pcall(function()
    if S.hooked and Runtime and Runtime.removeEventListener then
      Runtime:removeEventListener("enterFrame", M._frame)
    end
  end)
  S.hooked = false
  pcall(function()
    if S.box and S.box.removeSelf then S.box:removeSelf() end
  end)
  S.box, S.sel, S.noVis = nil, nil, false
  S.board, S.getCell = nil, nil
end
function M._frame()
  S.fn = (S.fn or 0) + 1
  if S.fn % 6 ~= 0 then return end
  local mode = nil
  pcall(function()
    if type(onHoverTouch) == "function" and debug and debug.getupvalue then
      local _, g = debug.getupvalue(onHoverTouch, 1)
      if type(g) == "table" then mode = g.ModeCurrent end
    end
  end)
  if mode == nil then
    pcall(function()
      local A = _G.__ALPHA
      if type(A) == "table" and type(A.state) == "function" then
        local _, _, _, over = A.state()
        if over == true then mode = "outro" end
      end
    end)
  end
  if mode ~= nil and mode ~= "alphabeth" then M.clear() return end
  if M.valid(S.sel) and S.board ~= nil then
    pcall(M.refresh, S.board, S.getCell)
  end
end
function M.install()
  pcall(function()
    if Runtime and Runtime.addEventListener and not S.hooked then
      Runtime:addEventListener("enterFrame", M._frame)
      S.hooked = true
    end
  end)
  _G.__ALPHA_SELECT = _G.__ALPHA_SELECT or {
    set = function(b, g, i) return M.set(b, g, i) end,
    set_cr = function(b, g, c, r) return M.set_cr(b, g, c, r) end,
    clear = function() return M.clear() end,
    refresh = function(b, g) return M.refresh(b, g) end,
    onSlid = function(b, g) return M.onSlid(b, g) end,
    hide = function() return M.hide() end,
    selected = function() return M.selected() end,
  }
  return true
end
function M.selftest()
  assert(M.idx(1, 1) == 1 and M.idx(5, 1) == 5, "idx row 1")
  assert(M.idx(1, 2) == 6 and M.idx(5, 2) == 10, "idx row 2")
  assert(M.idx(1, 5) == 21 and M.idx(5, 5) == 25, "idx row 5")
  local c, r = M.rc(7)
  assert(c == 2 and r == 2, "rc(7)=2,2")
  local c25, r25 = M.rc(25)
  assert(c25 == 5 and r25 == 5, "rc(25)=5,5")
  assert(M.valid(1) and M.valid(10) and M.valid(25), "1..25 valid")
  assert(not M.valid(0) and not M.valid(26) and not M.valid(nil), "invalid oob")
  assert(M.valid_cr(5, 2) and M.valid_cr(3, 5) and not M.valid_cr(6, 1) and not M.valid_cr(1, 6), "cr 5x5")
  assert(M.selected() == nil, "starts with no selection")
  assert(M.set(nil, nil, 99) == false, "oob set does not stick")
  assert(M.set_cr(nil, nil, 9, 9) == false, "oob set_cr does not stick")
  M.clear()
  assert(M.selected() == nil, "clear cleans")
  return "SELECT_OK idx+oob+clear"
end
pcall(function() _G.__ALPHA_SELECT_MOD = _G.__ALPHA_SELECT_MOD or M end)
  return M
end)()
package.loaded["mod_alpha_select"] = select
local rowsphys = (function()
local M = {}
M.id = "alpha-rowsphys-v1"
M.COLS, M.LOGF, M.GAP_Y = 5, "mod_alpha_hud.log", 86
local ROWS, BOARD, HL = nil, nil, nil
local function req(n)
  local m = nil
  pcall(function() local ok, v = pcall(require, n) if ok then m = v end end)
  return m
end
local function R()
  if not (ROWS and ROWS.layout) then ROWS = req("mod_alpha_rows") end
  return ROWS
end
local function B()
  if not (BOARD and BOARD.takeover) then BOARD = req("mod_alpha_board") end
  return BOARD
end
local function H()
  if not (HL and HL.refresh) then HL = req("mod_alpha_highlight") end
  return HL
end
local S = { hooked = false, zx = nil }
function M.layout(lv)
  local r = R()
  if r and r.layout then return r.layout(lv) end
  lv = math.max(1, math.floor(tonumber(lv) or 1))
  if lv <= 1 then return 5, 2, 10 end
  if lv == 2 then return 5, 3, 15 end
  return 5, 5, 25
end
local function cellOf(b, c, r)
  if type(b) ~= "table" then return nil end
  local bd = B()
  if bd and bd.getCell then
    local cl = nil
    pcall(function() cl = bd.getCell(b, c, r) end)
    if cl ~= nil then return cl end
  end
  local cl = nil
  pcall(function() if type(b[c]) == "table" then cl = b[c][r] end end)
  return cl
end
M.cellOf = cellOf
local function xy(cl)
  local x, y = nil, nil
  pcall(function() x, y = cl.x, cl.y end)
  if type(x) == "number" and type(y) == "number" then return x, y end
  return nil, nil
end
local function measure(b)
  local a = cellOf(b, 1, 1)
  if not a then return nil end
  local x0, y0 = xy(a)
  if not (x0 and y0) then return nil end
  local w, h, par, sx, sy = 62, 62, nil, 62, 62
  pcall(function() w = a.width or w h = a.height or h par = a.parent end)
  local e = xy(cellOf(b, 2, 1))
  if e and e ~= x0 then sx = math.abs(e - x0) end
  local _, ey = xy(cellOf(b, 1, 2))
  if ey and ey ~= y0 then sy = math.abs(ey - y0) end
  if sx < 10 then sx = 62 end
  if sy < 10 then sy = 62 end
  return { x0 = x0, y0 = y0, sx = sx, sy = sy, w = w, h = h, parent = par }
end
local function cloneFont(b)
  local font, size = "fonts/progresspixel-bold.ttf", nil
  local fromH = false
  pcall(function()
    local done = false
    for c = 1, 5 do
      for r = 1, 2 do
        local cell = nil
        pcall(function()
          if type(b[c]) == "table" then cell = b[c][r] end
        end)
        if cell and cell.SymbolText then
          pcall(function()
            if cell.SymbolText.font ~= nil and
                type(cell.SymbolText.font) == "string" and
                cell.SymbolText.font ~= "" then
              font = cell.SymbolText.font
            end
            if cell.SymbolText.size ~= nil then size = cell.SymbolText.size end
            if size == nil and cell.SymbolText.fontSize ~= nil then
              size = cell.SymbolText.fontSize
            end
            if size == nil and cell.SymbolText.height ~= nil then
              size = cell.SymbolText.height
              fromH = true
            end
          end)
        end
        if size ~= nil then done = true break end
      end
      if done then break end
    end
  end)
  size = tonumber(size) or 26
  if fromH and (size < 18 or size > 40) then size = 26 end
  if size < 10 then size = 10 end
  if size > 64 then size = 64 end
  return font, size
end
local function dressCell(cl, x, y, w, h, par, font, size, forceFont)
  pcall(function()
    if display and par and display.newText and cl.SymbolText == nil then
      local tx = display.newText(par, cl.Symbol or "", x, y, font, size)
      if tx then
        tx:setFillColor(0, 0, 0)
        cl.SymbolText = tx
        cl.__dressed = true
      end
    end
    if display and par and display.newRect and cl.Yellow == nil then
      local mk = display.newRect(par, x, y, (w or 62) - 6, (h or 62) - 6)
      if mk then mk:setFillColor(1, 1, 1, 0) mk:setStrokeColor(1, 0.85, 0.25)
        mk.strokeWidth = 4 mk.isVisible = false mk:toFront()
        if cl.SymbolText and cl.SymbolText.toFront then cl.SymbolText:toFront() end
        cl.Yellow = mk end
    end
  end)
  if cl.Symbol == nil then cl.Symbol = "" end
  if cl.SymbolText == nil then
    cl.SymbolText = { text = "", toFront = function() end, setFillColor = function() end }
  end
  if cl.Yellow == nil then cl.Yellow = { isVisible = false } end
  if forceFont or cl.__dressed then
    pcall(function()
      local st = cl.SymbolText
      if st and st.setFillColor then
        pcall(function() st.font = font end)
        pcall(function() if st.size ~= nil then st.size = size end end)
      end
    end)
  end
  return cl
end
local function mkCell(b, c, r, g)
  if type(b[c]) ~= "table" then b[c] = {} end
  if b[c][r] ~= nil then return b[c][r] end
  local x, y = g.x0 + (c - 1) * g.sx, g.y0 + (r - 1) * g.sy
  local cl = { x = x, y = y, width = g.w, height = g.h, parent = g.parent, Symbol = "",
    __fake = true }
  local font, size = cloneFont(b)
  dressCell(cl, x, y, g.w, g.h, g.parent, font, size, true)
  b[c][r] = cl
  return cl
end
local function completeReal(b, c, r)
  local cell = nil
  pcall(function()
    if type(b[c]) == "table" then cell = b[c][r] end
  end)
  if cell == nil then return nil end
  local x, y, w, h, par = nil, nil, 62, 62, nil
  pcall(function()
    x, y = cell.x, cell.y
    w = cell.width or w h = cell.height or h
    par = cell.parent
    if cell.Symbol == nil then cell.Symbol = "" end
  end)
  if x == nil then return cell end
  local font, size = cloneFont(b)
  local force = (r == 2 and c >= 2)
  return dressCell(cell, x, y, w, h, par, font, size, force)
end
local ORIG = setmetatable({}, { __mode = "k" })
local function hideObj(o)
  pcall(function()
    if o ~= nil and o.isVisible ~= nil then o.isVisible = false end
  end)
end
local function hideRealCell(cell)
  if type(cell) ~= "table" then return end
  hideObj(cell)
  pcall(function() hideObj(cell.SymbolText) end)
  pcall(function() hideObj(cell.Yellow) end)
end
function M.hideReal(b)
  pcall(function()
    local L = ORIG[b]
    if type(L) == "table" then
      for _, o in ipairs(L) do hideRealCell(o) end
    end
  end)
  return true
end
local function replaceReal(b, c, r, g)
  local cur = nil
  pcall(function() if type(b[c]) == "table" then cur = b[c][r] end end)
  if cur == nil then return nil end
  if cur.__fake then return cur end
  hideRealCell(cur)
  local L = ORIG[b]
  if not L then L = {} ORIG[b] = L end
  L[#L + 1] = cur
  b[c][r] = nil
  return mkCell(b, c, r, g)
end
function M.ensure(b, lv)
  lv = math.max(1, math.floor(tonumber(lv) or 1))
  local cols, rows, n = M.layout(lv)
  if lv <= 1 or type(b) ~= "table" then return true, cols, rows, n end
  local g = measure(b)
  if not g then return false, cols, rows, n end
  for c = 1, cols do replaceReal(b, c, 1, g) end
  replaceReal(b, 1, 2, g)
  for c = 2, cols do completeReal(b, c, 2) end
  for c = 1, cols do for r = 3, rows do mkCell(b, c, r, g) end end
  M.hideReal(b)
  return true, cols, rows, n
end
function M.resize(b, lv)
  lv = math.max(1, math.floor(tonumber(lv) or 1))
  local cols, rows, n = M.layout(lv)
  local info = { cols = cols, rows = rows, n = n, stretched = false }
  local r = R()
  if r and r.geometry then
    local g = r.geometry(lv)
    info.fits, info.needH, info.mapH = g.fits, g.needH, g.mapH
  end
  pcall(function()
    local par = cellOf(b, 1, 1) and cellOf(b, 1, 1).parent
    if not (par and par.numChildren) then return end
    local yT, yB = nil, nil
    for c = 1, cols do for r = 1, rows do local _, y = xy(cellOf(b, c, r))
      if y then if not yT or y < yT then yT = y end if not yB or y > yB then yB = y end end
    end end
    if not (yT and yB) then return end
    local wantH = (yB - yT) + 120
    for i = 1, (par.numChildren or 0) do pcall(function()
      local ch = par[i]
      if ch == nil then return end
      local skip = false
      pcall(function() if ch._alphaNoStretch then skip = true end end)
      if skip then return end
      if ch and ch.width and ch.width >= 300 and ch.height >= 100 then
        if ch.height < wantH then ch.height = wantH info.stretched = true end
      end
    end) end
  end)
  return info
end
function M.janitor(b)
  local removed = 0
  pcall(function()
    if type(b) ~= "table" then return end
    local known, parents = {}, {}
    for c = 1, 5 do
      if type(b[c]) == "table" then
        for r = 1, 5 do
          local cell = b[c][r]
          if cell ~= nil then
            pcall(function()
              if cell.SymbolText ~= nil then
                known[cell.SymbolText] = true
              end
              if cell.Yellow ~= nil then known[cell.Yellow] = true end
              if cell.BG ~= nil then known[cell.BG] = true end
              if cell.parent ~= nil then parents[cell.parent] = true end
              known[cell] = true
            end)
          end
        end
      end
    end
    for par, _ in pairs(parents) do
      pcall(function()
        local nk = par.numChildren or 0
        local kill = {}
        for i = 1, nk do
          local ch = nil
          pcall(function() ch = par[i] end)
          if ch ~= nil and not known[ch] then
            local isText = false
            pcall(function()
              if type(ch.text) == "string" then isText = true end
            end)
            if isText then kill[#kill + 1] = ch end
          end
        end
        for _, ch in ipairs(kill) do
          pcall(function()
            if ch.removeSelf then ch:removeSelf() removed = removed + 1 end
          end)
        end
      end)
    end
  end)
  if removed > 0 then  end
  return removed
end
function M.bottom(b, lv)
  local _, _, n = M.layout(lv)
  local my = nil
  for i = 1, n do local _, y = xy(cellOf(b, ((i - 1) % 5) + 1, math.floor((i - 1) / 5) + 1))
    if y and (not my or y > my) then my = y end end
  return my
end
function M.target(lv)
  local r = R()
  if r and r.target then return r.target(lv) end
  return nil
end
local function paintAll(b, sh, lv)
  local _, _, n = M.layout(lv)
  for i = 1, n do
    local cl = cellOf(b, ((i - 1) % 5) + 1, math.floor((i - 1) / 5) + 1)
    if cl then pcall(function() cl.Symbol = sh[i] end)
      pcall(function()
        if cl.SymbolText then
          cl.SymbolText.text = sh[i]
          if cl.SymbolText.isVisible ~= nil then
            cl.SymbolText.isVisible = true
          end
          if cl.SymbolText.setFillColor then
            cl.SymbolText:setFillColor(0, 0, 0)
          end
        end
      end)
      pcall(function() if cl.Yellow and cl.Yellow.isVisible ~= nil then
        cl.Yellow.isVisible = false end end)
    end
  end
  pcall(function()
    local hl = H()
    if hl and hl.refresh and n >= 10 then
      hl.refresh(b, cellOf, sh, M.target(lv), "")
    end
  end)
end
function M.refreshBoard(b, sh, lv)
  pcall(paintAll, b, sh, lv)
  return true
end
function M.takeover(b, seed, lv)
  lv = math.max(1, math.floor(tonumber(lv) or 1))
  local r = R()
  if lv <= 1 or not r then
    local bd = B()
    if bd and bd.takeover then return bd.takeover(b, seed, lv) end
    return nil
  end
  M.ensure(b, lv) M.resize(b, lv)
  local sh, path = r.scrambled(lv, seed or (lv * 7919 + 5))
  local tg = r.target(lv)
  paintAll(b, sh, lv)
  local api = { board = b, moves = 0, level = lv, target = tg, path = path }
  function api.snap() return r.snap(sh, lv) end
  function api.refresh() paintAll(b, sh, lv) return true end
  function api.janitor() return M.janitor(b) end
  function api.hideReal() return M.hideReal(b) end
  function api.slide(c, rw)
    c, rw = tonumber(c), tonumber(rw)
    local _, rr = M.layout(lv)
    if not (c and rw and c >= 1 and c <= 5 and rw >= 1 and rw <= rr) then return false end
    if r.touch(sh, (rw - 1) * 5 + c, 5, rr) then
      api.moves = api.moves + 1 paintAll(b, sh, lv)
      return true
    end
    return false
  end
  function api.correct() return r.correct(sh, lv) end
  function api.progress() return r.progress(sh, lv) end
  function api.isWin() return r.is_win(sh, lv) end
  function api.rowOrdered(x) return r.row_ordered(sh, lv, x) end
  return api
end
function M.afterHud(board, hudRet, lv, onSlide)
  lv = math.max(1, math.floor(tonumber(lv) or 1))
  if lv <= 1 then return 0 end
  pcall(function()
    if S.zx then
      pcall(function()
        if S.zx.isVisible ~= nil then S.zx.isVisible = false end
      end)
      S.zx, S.zxN = nil, nil
    end
  end)
  pcall(function()
    local yN = M.bottom(board, lv)
    if not (yN and hudRet) then return end
    local byN = yN + M.GAP_Y
    if hudRet.pct and hudRet.pct.y and hudRet.pct.y < byN then
      local d = byN - hudRet.pct.y
      hudRet.pct.y = byN
      if hudRet.moves then hudRet.moves.y = hudRet.moves.y + d end
    end
    local okD, DB = pcall(require, "mod_alpha_defbar")
    if okD and DB and DB._test then local okS, t = pcall(DB._test)
      if okS and t and t.S then
        if t.S.back then t.S.back.y = byN end
        if t.S.fill then t.S.fill.y = byN end end end
  end)
  return 0
end
function M.install()
  if S.hooked then return true end
  local bd = B()
  pcall(function()
    if bd and bd.takeover and not bd._rpOrig then
      bd._rpOrig = bd.takeover
      bd.takeover = function(b, seed, lv)
        lv = math.max(1, math.floor(tonumber(lv) or 1))
        if lv >= 2 and R() then return M.takeover(b, seed, lv) end
        return bd._rpOrig(b, seed, lv) end
       end
  end)
  pcall(function()
    local okH, HUD = pcall(require, "mod_alpha_hud")
    if okH and HUD and HUD.ensureZones and not HUD._rpZ then HUD._rpZ = HUD.ensureZones
      HUD.ensureZones = function(b, onSlide) local r = HUD._rpZ(b, onSlide)
        pcall(function() local lv = 1
          pcall(function() if _G.__ALPHA and _G.__ALPHA.level then lv = _G.__ALPHA.level() end end)
          if math.floor(tonumber(lv) or 1) >= 2 then M.afterHud(b, nil, lv, onSlide) end end)
        return r end end
    if okH and HUD and HUD.ensure and not HUD._rpE then HUD._rpE = HUD.ensure
      HUD.ensure = function(b) local ret = HUD._rpE(b)
        pcall(function() local lv = 1
          pcall(function() if _G.__ALPHA and _G.__ALPHA.level then lv = _G.__ALPHA.level() end end)
          if math.floor(tonumber(lv) or 1) >= 2 then M.ensure(b, lv) M.resize(b, lv) end end)
        return ret end end
  end)
  S.hooked = true
  return true
end
function M.selftest()
  local svD = display
  local function body()
    display = { newRect = function(_, x, y, w, h)
        return { x = x, y = y, width = w, height = h, isVisible = false,
          setFillColor = function() end, setStrokeColor = function() end, toFront = function() end } end,
      newText = function(_, t, x, y) return { text = t, x = x, y = y,
        setFillColor = function() end, toFront = function() end } end,
      newGroup = function() return {} end }
    local b = {}
    for c = 1, 5 do b[c] = {} for r = 1, 2 do b[c][r] = { x = 100 + (c - 1) * 62,
      y = 200 + (r - 1) * 62, width = 62, height = 62, parent = { numChildren = 0 },
      Symbol = "", SymbolText = { text = "" }, Yellow = {} } end end
    local par = { numChildren = 0 }
    for c = 1, 5 do for r = 1, 2 do b[c][r].parent = par end end
    local ok2, _, r2, n2 = M.ensure(b, 2)
    assert(ok2 and r2 == 3 and n2 == 15 and b[3][3] and b[5][3], "L2 3x5 fisico")
    local ok3, _, r3, n3 = M.ensure(b, 3)
    assert(ok3 and r3 == 5 and n3 == 25 and b[1][5] and b[5][5], "L3 5x5 fisico")
    assert(b[3][3].x == b[3][1].x and b[1][3].y > b[1][2].y, "grid aligns/below")
    local a2 = M.takeover(b, 4242, 2)
    assert(a2 and #a2.snap() == 15, "snap15")
    local h2, t2 = a2.correct()
    assert(t2 == 15 and a2.progress() == h2 / 15, "p==c/t L2")
    local a3 = M.takeover(b, 777, 3)
    assert(a3 and #a3.snap() == 25, "snap25")
    local h3, t3 = a3.correct()
    assert(t3 == 25 and a3.progress() == h3 / 25 and a3.rowOrdered, "p==c/t+linhas L3")
    assert(M.bottom(b, 3) > M.bottom(b, 1), "window grows")
    local rz = M.resize(b, 3)
    assert(rz.rows == 5 and rz.n == 25, "resize 5x5")
    return "ROWSPHYS_OK 15/25phys+slide+bottom+resize"
  end
  local ok, res = pcall(body)
  display = svD
  if not ok then error(res, 0) end
  return res
end
  return M
end)()
package.loaded["mod_alpha_rowsphys"] = rowsphys
local layout = (function()
local M = {}
M.id = "alpha-layout-v3"
local SAVE = "C:\\Users\\lucas\\AppData\\Local\\Temp\\opencode\\modtest\\layout_pos.lua"
local S = { logf = "mod_alpha_hud.log",
  gs = 1.2, gx_off = 32, gy_off = -64, box_off = 8, boy_off = 8 }
local function boardOf()
  local b = nil
  pcall(function()
    if type(_G.__ALPHA_BOARD) == "table" then b = _G.__ALPHA_BOARD end
  end)
  if b ~= nil then return b end
  pcall(function()
    local ok, B = pcall(require, "mod_alpha_board")
    if ok and B then
      if B.takeBoard then b = B.takeBoard() end
      if b == nil then
        local f = B.find and B.find()
        if type(f) == "table" and #f > 0 and f[1] then b = f[1].board end
      end
    end
  end)
  return b
end
local function loadSaved()
  local out = nil
  pcall(function()
    local paths = { "layout_pos.lua", "Resources/layout_pos.lua",
      SAVE:gsub("\\", "/") }
    local content = nil
    for _, p in ipairs(paths) do
      local f = io.open(p, "r")
      if f then
        content = f:read("*a")
        f:close()
      end
      if content and #content > 0 then break end
    end
    if content then
      local loader = loadstring or load
      if loader then
        local fn, err = loader(content)
        if fn then
          local ok, v = pcall(fn)
          if ok and type(v) == "table" then out = v end
        end
      end
    end
    if out == nil then
      local chunk = loadfile("layout_pos.lua")
      if chunk == nil then
        chunk = loadfile(SAVE:gsub("\\", "/"))
      end
      if chunk then
        local ok, v = pcall(chunk)
        if ok and type(v) == "table" then out = v end
      end
    end
  end)
  return out
end
local function applyOffsets()
  pcall(function()
    local ok, R = pcall(require, "mod_alpha_realbar")
    if ok and R and R.setOffset then
      R.setOffset(S.box_off or 0, S.boy_off or 0)
    end
  end)
end
local function shiftGrid(dx, dy)
  local n = 0
  pcall(function()
    local bb = boardOf()
    if type(bb) ~= "table" then return end
    for c = 1, 5 do
      if type(bb[c]) == "table" then
        for r = 1, 5 do
          local cell = bb[c][r]
          if cell ~= nil then
            pcall(function()
              if type(cell.x) == "number" then cell.x = cell.x + dx end
              if type(cell.y) == "number" then cell.y = cell.y + dy end
            end)
            pcall(function()
              local st = cell.SymbolText
              if st and type(st.x) == "number" then
                st.x, st.y = st.x + dx, st.y + dy
              end
            end)
            pcall(function()
              local mk = cell.Yellow
              if mk and type(mk.x) == "number" then
                mk.x, mk.y = mk.x + dx, mk.y + dy
              end
            end)
            pcall(function()
              local bg = cell.BG
              if bg and type(bg.x) == "number" then
                bg.x, bg.y = bg.x + dx, bg.y + dy
              end
            end)
            n = n + 1
          end
        end
      end
    end
    pcall(function()
      local ok, H = pcall(require, "mod_alpha_hud")
      if ok and H and H.moveZones then H.moveZones(dx, dy) end
    end)
  end)
  return n
end
local function scaleCells(f)
  local n = 0
  pcall(function()
    local bb = boardOf()
    if type(bb) ~= "table" then return end
    local o = nil
    pcall(function()
      if type(bb[1]) == "table" and bb[1][1] then o = bb[1][1] end
    end)
    local x0, y0 = nil, nil
    pcall(function() if o then x0, y0 = o.x, o.y end end)
    if type(x0) ~= "number" or type(y0) ~= "number" then return end
    for c = 1, 5 do
      if type(bb[c]) == "table" then
        for r = 1, 5 do
          local cell = bb[c][r]
          if cell ~= nil then
            local fake = false
            pcall(function() fake = cell.__fake == true end)
            pcall(function()
              if type(cell.x) == "number" then
                cell.x = x0 + (cell.x - x0) * f
              end
              if type(cell.y) == "number" then
                cell.y = y0 + (cell.y - y0) * f
              end
              if fake then
                if tonumber(cell.width) then cell.width = cell.width * f end
                if tonumber(cell.height) then cell.height = cell.height * f end
              end
            end)
            pcall(function()
              local st = cell.SymbolText
              if st and type(cell.x) == "number" then
                st.x, st.y = cell.x, cell.y
              end
            end)
            pcall(function()
              local mk = cell.Yellow
              if mk and type(cell.x) == "number" then
                mk.x, mk.y = cell.x, cell.y
                if fake then
                  local w = (tonumber(cell.width) or 62) - 6
                  local h = (tonumber(cell.height) or 62) - 6
                  if w > 8 then mk.width = w end
                  if h > 8 then mk.height = h end
                end
              end
            end)
            n = n + 1
          end
        end
      end
    end
  end)
  return n
end
local function rezone()
  pcall(function()
    local ok, H = pcall(require, "mod_alpha_hud")
    if ok and H then
      local s = tonumber(S.gs) or 1
      if H.setZonePx then H.setZonePx(62 * s) end
      if H.dropZones then H.dropZones() end
      local A = _G.__ALPHA
      if type(A) == "table" and type(A.slide) == "function" then
        local bb = boardOf()
        if type(bb) == "table" and H.ensureZones then
          H.ensureZones(bb, function(c, r) return A.slide(c, r) end)
        end
      end
    end
  end)
end
function M.applyBoard()
  pcall(function()
    local bb = boardOf()
    if type(bb) ~= "table" then return end
    if S.applied_board == bb then return end
    S.applied_board = bb
    local s = tonumber(S.gs) or 1
    local dx, dy = tonumber(S.gx_off) or 0, tonumber(S.gy_off) or 0
    if s ~= 1 then
      local n = scaleCells(s)
    end
    if dx ~= 0 or dy ~= 0 then
      local n = shiftGrid(dx, dy)
    end
    if s ~= 1 or dx ~= 0 or dy ~= 0 then rezone() end
  end)
  return true
end
local function restoreLoop()
  if S.restored then return end
  S.restored = true
  local t = loadSaved()
  if type(t) == "table" then
    if tonumber(t.scale) then
      S.gs = tonumber(t.scale)
      if S.gs < 0.5 then S.gs = 0.5 end
      if S.gs > 2.0 then S.gs = 2.0 end
    end
    if type(t.off) == "table" then
      S.box_off = tonumber(t.off.x) or 0
      S.boy_off = tonumber(t.off.y) or 0
      applyOffsets()
    end
    if type(t.grid) == "table" then
      S.gx_off = tonumber(t.grid.x) or 0
      S.gy_off = tonumber(t.grid.y) or 0
    end
  else
  end
end
function M.install()
  pcall(function() restoreLoop() end)
  return true
end
function M.selftest()
  return "LAYOUT_OK"
end
  return M
end)()
package.loaded["mod_alpha_layout"] = layout
return {
  ["mod_alpha_board"] = board,
  ["mod_alpha_textcolor"] = textcolor,
  ["mod_alpha_highlight"] = highlight,
  ["mod_alpha_outline"] = outline,
  ["mod_alpha_select"] = select,
  ["mod_alpha_rowsphys"] = rowsphys,
  ["mod_alpha_layout"] = layout,
}
