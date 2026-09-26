local gameplay = (function()
local M = {}
M.id = "alpha-gameplay-v7"
M.ROWS = 2
M.COLS = 5
M.N = 10
M.EMPTY = ""
M.FULL = { "A", "B", "C", "D", "E", "F", "G", "H", "I",
  "K", "L", "M", "N", "O", "P", "Q", "R", "S",
  "T", "U", "V", "W", "X", "Y", "Z" }
M.BASE_TIME = 1200
M.BASE_MOVES = 30
local function idx(row, col) return (row - 1) * M.COLS + col end
local function rowcol(i)
  return math.floor((i - 1) / M.COLS) + 1, ((i - 1) % M.COLS) + 1
end
function M.neighbors(i)
  local r, c = rowcol(i)
  local out = {}
  if r > 1 then out[#out + 1] = idx(r - 1, c) end
  if r < M.ROWS then out[#out + 1] = idx(r + 1, c) end
  if c > 1 then out[#out + 1] = idx(r, c - 1) end
  if c < M.COLS then out[#out + 1] = idx(r, c + 1) end
  return out
end
function M.level_letters(n)
  n = math.max(1, math.floor(tonumber(n) or 1))
  local start = ((n - 1) * 9) % #M.FULL
  local out = {}
  for k = 1, 9 do
    out[k] = M.FULL[(start + k - 1) % #M.FULL + 1]
  end
  return out
end
function M.target(n)
  local t = M.level_letters(n)
  t[10] = M.EMPTY
  return t
end
function M.difficulty(n)
  n = math.max(1, math.floor(tonumber(n) or 1))
  local moves = M.BASE_MOVES + 15 * (n - 1)
  if moves > 120 then moves = 120 end
  return { moves = moves, time = M.BASE_TIME + 60 * (n - 1) }
end
function M.new_board(n)
  local t = M.target(n or 1)
  local b = {}
  for i = 1, 10 do b[i] = t[i] end
  return b
end
function M.find_empty(b)
  for i = 1, M.N do if b[i] == M.EMPTY then return i end end
  return nil
end
function M.touch(b, i)
  if b[i] == M.EMPTY then return false end
  local e = M.find_empty(b)
  if not e then return false end
  for _, x in ipairs(M.neighbors(i)) do
    if x == e then b[e] = b[i] b[i] = M.EMPTY return true end
  end
  return false
end
function M.correct(b, n)
  local t = M.target(n or 1)
  local hit = 0
  for i = 1, 10 do if b[i] == t[i] then hit = hit + 1 end end
  return hit, 10
end
function M.progress(b, n)
  local hit = M.correct(b, n)
  return hit / 10
end
function M.is_win(b, n) return M.progress(b, n) >= 1.0 end
function M.scrambled(n, seed)
  n = math.max(1, math.floor(tonumber(n) or 1))
  if seed then math.randomseed(seed) end
  local d = M.difficulty(n)
  local b = M.new_board(n)
  local e = M.N
  for _ = 1, d.moves do
    local ns = M.neighbors(e)
    local pick = ns[math.random(#ns)]
    b[e] = b[pick] b[pick] = M.EMPTY e = pick
  end
  if M.is_win(b, n) then
    for i = 1, 10 do if M.touch(b, i) then break end end
  end
  return b
end
function M.snap(b)
  local t = {}
  for i = 1, 10 do
    local s = b[i]
    t[#t + 1] = (s == M.EMPTY) and "_" or s
  end
  return table.concat(t)
end
function M.selftest()
  assert(#M.FULL == 25, "cast has 25 (A-Z no J)")
  for _, j in ipairs(M.FULL) do assert(j ~= "J", "no J") end
  local l1 = M.level_letters(1)
  assert(l1[1] == "A" and l1[9] == "I", "L1=A..I")
  local l2 = M.level_letters(2)
  assert(l2[1] == "K" and l2[9] == "S", "L2=K..S")
  local l3 = M.level_letters(3)
  assert(l3[1] == "T" and l3[7] == "Z" and l3[8] == "A", "L3=T..ZAB")
  local d1, d3 = M.difficulty(1), M.difficulty(3)
  assert(d1.moves == 30 and d1.time == 1200, "L1 base 20min")
  assert(d3.moves > d1.moves and d3.time == 1320, "+1min/level")
  local b = M.new_board(1)
  assert(M.is_win(b, 1), "new wins")
  local c, t = M.correct(b, 1)
  assert(c == 10 and t == 10, "10/10")
  local s = M.scrambled(1, 7)
  assert(not M.is_win(s, 1), "shuffled unsolved")
  assert(M.find_empty(s) ~= nil, "has empty")
  local e = M.find_empty(s)
  local mov = false
  for _, x in ipairs(M.neighbors(e)) do
    if s[x] ~= M.EMPTY then mov = true end
  end
  assert(mov, "has legal move")
  assert(not M.is_win(M.scrambled(2, 11), 2), "L2 jogavel")
  assert(not M.is_win(M.scrambled(3, 13), 3), "L3 jogavel")
  return "GAMEPLAY_OK 25/cycles/levels/solvable"
end
  return M
end)()
package.loaded["mod_alpha_gameplay"] = gameplay
local rows = (function()
local M = {}
M.id = "alpha-rows-v1"
M.COLS = 5
M.FULL = { "A", "B", "C", "D", "E", "F", "G", "H", "I",
  "K", "L", "M", "N", "O", "P", "Q", "R", "S",
  "T", "U", "V", "W", "X", "Y", "Z" }
M.EMPTY = ""
M.CELL = 62
M.LAND_W, M.LAND_H = 1364, 768
M.BASE_MOVES = 30
function M.layout(level)
  level = math.max(1, math.floor(tonumber(level) or 1))
  if level <= 1 then return 5, 2, 10 end
  if level == 2 then return 5, 3, 15 end
  return 5, 5, 25
end
function M.letters(level)
  level = math.max(1, math.floor(tonumber(level) or 1))
  local _, _, n = M.layout(level)
  local k = n - 1
  local out = {}
  if level <= 2 then
    for i = 1, k do out[i] = M.FULL[i] end
    return out
  end
  local start = ((level - 3) * k) % #M.FULL
  for i = 1, k do out[i] = M.FULL[(start + i - 1) % #M.FULL + 1] end
  return out
end
function M.target(level)
  local _, _, n = M.layout(level)
  local t = M.letters(level)
  t[n] = M.EMPTY
  return t
end
function M.idx(c, r, cols)
  cols = tonumber(cols) or M.COLS
  return (r - 1) * cols + c
end
function M.rc(i, cols)
  cols = tonumber(cols) or M.COLS
  return ((i - 1) % cols) + 1, math.floor((i - 1) / cols) + 1
end
function M.neighbors(i, cols, rows)
  cols = tonumber(cols) or M.COLS
  rows = tonumber(rows) or 2
  i = tonumber(i)
  if not (i and i >= 1 and i <= cols * rows) then return {} end
  local c, r = M.rc(i, cols)
  local out = {}
  if r > 1 then out[#out + 1] = M.idx(c, r - 1, cols) end
  if r < rows then out[#out + 1] = M.idx(c, r + 1, cols) end
  if c > 1 then out[#out + 1] = M.idx(c - 1, r, cols) end
  if c < cols then out[#out + 1] = M.idx(c + 1, r, cols) end
  return out
end
function M.find_empty(b, n)
  if type(b) ~= "table" then return nil end
  n = tonumber(n) or #b
  for i = 1, n do if b[i] == M.EMPTY then return i end end
  return nil
end
function M.touch(b, i, cols, rows)
  cols = tonumber(cols) or M.COLS
  rows = tonumber(rows) or 2
  i = tonumber(i)
  local n = cols * rows
  if not (type(b) == "table" and i and i >= 1 and i <= n) then
    return false
  end
  if b[i] == M.EMPTY then return false end
  local e = M.find_empty(b, n)
  if not e then return false end
  for _, x in ipairs(M.neighbors(i, cols, rows)) do
    if x == e then b[e] = b[i] b[i] = M.EMPTY return true end
  end
  return false
end
function M.scrambled(level, seed)
  level = math.max(1, math.floor(tonumber(level) or 1))
  if seed then math.randomseed(seed) end
  local cols, rows, n = M.layout(level)
  local t = M.target(level)
  local b = {}
  for i = 1, n do b[i] = t[i] end
  local moves = M.BASE_MOVES + 15 * (level - 1)
  if moves > 120 then moves = 120 end
  local e, path = n, {}
  for _ = 1, moves do
    local ns = M.neighbors(e, cols, rows)
    local pick = ns[math.random(#ns)]
    path[#path + 1] = e
    b[e] = b[pick] b[pick] = M.EMPTY e = pick
  end
  if M.is_win(b, level) then
    for i = 1, n do
      local e0 = e
      if M.touch(b, i, cols, rows) then
        path[#path + 1] = e0
        break
      end
    end
  end
  return b, path
end
function M.rewind(b, path, level)
  level = math.max(1, math.floor(tonumber(level) or 1))
  local cols, rows = M.layout(level)
  if type(b) ~= "table" or type(path) ~= "table" then return false end
  for j = #path, 1, -1 do
    if not M.touch(b, path[j], cols, rows) then return false end
  end
  return M.is_win(b, level)
end
function M.correct(b, level)
  level = math.max(1, math.floor(tonumber(level) or 1))
  local _, _, n = M.layout(level)
  local t = M.target(level)
  local hit = 0
  for i = 1, n do if b[i] == t[i] then hit = hit + 1 end end
  return hit, n
end
function M.progress(b, level)
  local hit, n = M.correct(b, level)
  return hit / n
end
function M.is_win(b, level) return M.progress(b, level) >= 1.0 end
function M.row_correct(b, level, row)
  level = math.max(1, math.floor(tonumber(level) or 1))
  local cols, rows = M.layout(level)
  row = math.floor(tonumber(row) or 0)
  if row < 1 or row > rows then return 0, cols end
  local t = M.target(level)
  local hit = 0
  for c = 1, cols do
    local i = M.idx(c, row, cols)
    if b[i] == t[i] then hit = hit + 1 end
  end
  return hit, cols
end
function M.row_ordered(b, level, row)
  local hit, cols = M.row_correct(b, level, row)
  return hit == cols
end
function M.geometry(level)
  local cols, rows, n = M.layout(level)
  local mapW = cols * M.CELL + 8
  local mapH = rows * M.CELL + 8
  local needH = mapH + 160
  local fits = (mapW <= M.LAND_W - 100) and (needH <= M.LAND_H - 60)
  local scale = 1
  if not fits then
    local s = math.min((M.LAND_W - 100) / mapW,
      (M.LAND_H - 60 - 160) / mapH)
    if s > 0 and s < 1 then scale = s end
  end
  return { cols = cols, rows = rows, n = n, cell = M.CELL,
    mapW = mapW, mapH = mapH, needH = needH, fits = fits, scale = scale }
end
function M.snap(b, level)
  level = math.max(1, math.floor(tonumber(level) or 1))
  local _, _, n = M.layout(level)
  local t = {}
  for i = 1, n do
    local s = b[i]
    t[#t + 1] = (s == M.EMPTY) and "_" or tostring(s)
  end
  return table.concat(t)
end
function M.describe(level)
  level = math.max(1, math.floor(tonumber(level) or 1))
  local cols, rows, n = M.layout(level)
  local t = M.target(level)
  return string.format("L%d %dx%d %dcells %dletters+empty snap=%s",
    level, cols, rows, n, n - 1, M.snap(t, level))
end
function M.selftest()
  assert(#M.FULL == 25, "cast 25 (A-Z no J)")
  for _, j in ipairs(M.FULL) do assert(j ~= "J", "no J") end
  local c1, r1, n1 = M.layout(1)
  assert(c1 == 5 and r1 == 2 and n1 == 10, "L1 5x2=10")
  local c2, r2, n2 = M.layout(2)
  assert(c2 == 5 and r2 == 3 and n2 == 15, "L2 5x3=15")
  local c3, r3, n3 = M.layout(3)
  assert(c3 == 5 and r3 == 5 and n3 == 25, "L3 5x5=25")
  local l1, l2, l3 = M.letters(1), M.letters(2), M.letters(3)
  assert(#l1 == 9 and l1[1] == "A" and l1[9] == "I", "L1=A..I")
  assert(#l2 == 14 and l2[1] == "A" and l2[14] == "O", "L2=A..O no J")
  assert(#l3 == 24 and l3[1] == "A" and l3[24] == "Y", "L3=A..Y no J")
  local seen = {}
  for _, x in ipairs(l3) do assert(x ~= "J", "L3 no J") assert(not seen[x], "L3 no repeats") seen[x] = true end
  local nb = M.neighbors(13, 5, 5)
  assert(#nb == 4, "center 5x5 = 4 neighbors")
  local canto = M.neighbors(1, 5, 5)
  assert(#canto == 2, "corner = 2 neighbors")
  local borda = M.neighbors(1, 5, 2)
  assert(#borda == 2, "corner 5x2 = 2 neighbors")
  assert(M.touch({ "A", "B" }, 9, 5, 2) == false, "outside grid does not move")
  for lv = 1, 3 do
    local cols, rows, n = M.layout(lv)
    local t = M.target(lv)
    assert(M.is_win(t, lv), "target L" .. lv .. " wins")
    assert(M.row_ordered(t, lv, 1), "row 1 ordered L" .. lv)
    assert(M.row_ordered(t, lv, rows), "last row L" .. lv)
    local s, path = M.scrambled(lv, 1000 + lv)
    assert(not M.is_win(s, lv), "shuffled L" .. lv .. " nao-resolvido")
    assert(M.find_empty(s, n) ~= nil, "has empty L" .. lv)
    assert(M.rewind(s, path, lv), "rewind resolve L" .. lv)
    local q = M.target(lv)
    q[1], q[2] = q[2], q[1]
    assert(not M.is_win(q, lv), "swap breaks victory L" .. lv)
    assert(not M.row_ordered(q, lv, 1), "row 1 flags swap L" .. lv)
    local h, tot = M.correct(q, lv)
    assert(tot == n and h == n - 2, "correct counts L" .. lv)
    local g = M.geometry(lv)
    assert(g.fits, "grid L" .. lv .. " fits in 1364x768")
    assert(#M.snap(t, lv) == n, "snap L" .. lv)
  end
  return "ROWS_OK 10/15/25cells+solvable+row+grid+fits"
end
pcall(function()
  local ok, rp = pcall(require, "mod_alpha_rowsphys")
  if ok and rp and rp.install then pcall(rp.install) end
end)
  return M
end)()
package.loaded["mod_alpha_rows"] = rows
local finish = (function()
local M = {}
M.ROWS = 2
M.COLS = 5
M.N = 10
M.LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H", "I" }
M.EMPTY = ""
M.TIME_LIMIT = 1200
M.FULL = { "A", "B", "C", "D", "E", "F", "G", "H", "I",
  "K", "L", "M", "N", "O", "P", "Q", "R", "S",
  "T", "U", "V", "W", "X", "Y", "Z" }
function M.level_letters(n)
  local ok, gp = pcall(require, "mod_alpha_gameplay")
  if ok and gp and gp.level_letters then return gp.level_letters(n) end
  n = math.max(1, math.floor(tonumber(n) or 1))
  local start = ((n - 1) * 9) % #M.FULL
  local out = {}
  for k = 1, 9 do out[k] = M.FULL[(start + k - 1) % #M.FULL + 1] end
  return out
end
function M.target(n)
  local ok, gp = pcall(require, "mod_alpha_gameplay")
  if ok and gp and gp.target then return gp.target(n) end
  local t = M.level_letters(n)
  t[10] = M.EMPTY
  return t
end
function M.correct(b, n)
  local t = M.target(n or 1)
  local hit = 0
  for i = 1, 10 do if b[i] == t[i] then hit = hit + 1 end end
  return hit, 10
end
local function idx(row, col)
  return (row - 1) * M.COLS + col
end
local function rowcol(i)
  local r = math.floor((i - 1) / M.COLS) + 1
  local c = ((i - 1) % M.COLS) + 1
  return r, c
end
function M.new_board()
  local b = {}
  for i = 1, 9 do b[i] = M.LETTERS[i] end
  b[10] = M.EMPTY
  return b
end
function M.neighbors(i)
  local r, c = rowcol(i)
  local out = {}
  if r > 1 then out[#out + 1] = idx(r - 1, c) end
  if r < M.ROWS then out[#out + 1] = idx(r + 1, c) end
  if c > 1 then out[#out + 1] = idx(r, c - 1) end
  if c < M.COLS then out[#out + 1] = idx(r, c + 1) end
  return out
end
function M.find_empty(b)
  for i = 1, M.N do
    if b[i] == M.EMPTY then return i end
  end
  return nil
end
function M.touch(b, i)
  if b[i] == M.EMPTY then return false end
  local e = M.find_empty(b)
  if not e then return false end
  for _, n in ipairs(M.neighbors(i)) do
    if n == e then
      b[e] = b[i]
      b[i] = M.EMPTY
      return true
    end
  end
  return false
end
function M.progress(b)
  local ok = 0
  for i = 1, 9 do
    if b[i] == M.LETTERS[i] then ok = ok + 1 end
  end
  if b[10] == M.EMPTY then ok = ok + 1 end
  return ok / M.N
end
function M.is_win(b)
  return M.progress(b) >= 1.0
end
function M.is_loss(elapsed)
  return elapsed >= M.TIME_LIMIT
end
function M.scrambled(moves, seed)
  if seed then math.randomseed(seed) end
  local b = M.new_board()
  local e = M.N
  for _ = 1, (moves or 20) do
    local ns = M.neighbors(e)
    local pick = ns[math.random(#ns)]
    b[e] = b[pick]
    b[pick] = M.EMPTY
    e = pick
  end
  return b
end
function M.selftest()
  local b = M.new_board()
  assert(M.is_win(b), "new board must win")
  assert(M.progress(b) == 1.0, "full progress")
  assert(M.touch(b, 1) == false, "A far from empty does not move")
  assert(M.touch(b, 9) == true, "adjacent I must slide")
  assert(not M.is_win(b), "after moving must not win")
  assert(M.progress(b) < 1.0, "partial progress")
  assert(M.touch(b, 10) == true, "deslizar de volta")
  assert(M.is_win(b), "must win again")
  assert(M.is_loss(1200) == true, "timeout = defeat")
  assert(M.is_loss(1199) == false, "before timeout with no defeat")
  local s = M.scrambled(20, 7)
  local e = M.find_empty(s)
  local movable = false
  for _, n in ipairs(M.neighbors(e)) do
    if s[n] ~= M.EMPTY then movable = true end
  end
  assert(movable, "shuffled must have movement")
  return "SELFTEST_OK win+slide+progress+loss"
end
  return M
end)()
package.loaded["mod_alpha_finish"] = finish
local barlogic = (function()
local M = {}
M.id = "alpha-barlogic-v1"
M.TOTAL = 10
M.LOGF = "mod_alpha_hud.log"
local S = { correct = 0, total = M.TOTAL, p = 0.0, won = false,
  reason = "boot" }
local function num(x, d)
  local v = tonumber(x)
  if v == nil or v ~= v then return d end
  return v
end
local function clamp01(p)
  p = num(p, 0)
  if p < 0 then return 0 end
  if p > 1 then return 1 end
  return p
end
M.clamp01 = clamp01
function M.compute(correct, total)
  local c = num(correct, 0)
  local t = num(total, M.TOTAL)
  if t <= 0 then return 0 end
  if c < 0 then c = 0 end
  if c > t then c = t end
  return clamp01(c / t)
end
function M.correctOf(board, target)
  if type(board) ~= "table" or type(target) ~= "table" then
    return 0, M.TOTAL
  end
  local hit, n = 0, M.TOTAL
  for i = 1, n do
    local b, t = board[i], target[i]
    if b == nil then b = "" end
    if t == nil then t = "" end
    if b == t then hit = hit + 1 end
  end
  return hit, n
end
function M.target(level)
  local lv = math.max(1, math.floor(num(level, 1)))
  local t = nil
  pcall(function()
    local ok, gp = pcall(require, "mod_alpha_gameplay")
    if ok and gp and gp.target then t = gp.target(lv) end
  end)
  if type(t) ~= "table" then
    pcall(function()
      local ok, fn = pcall(require, "mod_alpha_finish")
      if ok and fn and fn.target then t = fn.target(lv) end
    end)
  end
  if type(t) ~= "table" then
    t = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "" }
  end
  return t
end
function M.get() return S.p end
function M.state() return S.correct, S.total, S.p, S.won end
function M.isWin(p) return clamp01(p) >= 1.0 end
function M.sync(G, p)
  p = clamp01(p)
  pcall(function()
    if type(G) ~= "table" then return end
    local pw = 20
    pcall(function()
      if G.INI and G.INI.ProgressWidth then pw = G.INI.ProgressWidth end
    end)
    pw = num(pw, 20)
    if pw <= 0 then pw = 20 end
    G.Progress = p * pw
    G.ProgressProcent = p
  end)
  return p
end
local function getG()
  local G = nil
  pcall(function()
    local _, g = debug.getupvalue(onHoverTouch, 1)
    G = g
  end)
  return G
end
function M.publish()
  pcall(function()
    if type(_G.__ALPHA) ~= "table" then _G.__ALPHA = {} end
    _G.__ALPHA.progress = function() return S.p end
  end)
  pcall(function()
    _G.__ALPHA_BARLOGIC = { correct = S.correct, total = S.total,
      p = S.p, won = S.won, reason = S.reason, id = M.id }
  end)
  pcall(function() M.sync(getG(), S.p) end)
  return S.p
end
function M.set(correct, total, why)
  local t = math.max(1, math.floor(num(total, M.TOTAL)))
  local c = math.floor(num(correct, 0))
  if c < 0 then c = 0 end
  if c > t then c = t end
  S.correct, S.total = c, t
  S.p = clamp01(c / t)
  S.won = (S.p >= 1.0)
  if why ~= nil then S.reason = tostring(why) end
  M.publish()
  if S.won then  end
  return S.p
end
function M.observe(board, target, why)
  local c, t = M.correctOf(board, target)
  return M.set(c, t, why)
end
function M.reset(reason)
  S.correct, S.total, S.p, S.won = 0, M.TOTAL, 0.0, false
  S.reason = tostring(reason or "reset")
  M.publish()
  return S.p
end
function M.onEnter() return M.reset("enter") end
function M.onExit() return M.reset("exit") end
function M.onRetry() return M.reset("retry") end
function M.onTimeout() return M.reset("timeout") end
function M.onLevel(n) return M.reset("level-" .. tostring(num(n, 1))) end
function M.install()
  pcall(function()
    if type(_G.__ALPHA) ~= "table" then _G.__ALPHA = {} end
    local old = _G.__ALPHA.progress
    if type(old) == "function" then
      pcall(function() _G.__ALPHA_BARLOGIC_FALLBACK = old end)
    end
    _G.__ALPHA.progress = function() return S.p end
  end)
  M.reset("install")
  return true
end
function M.selftest()
  local G = { INI = { ProgressWidth = 20 } }
  assert(M.compute(0, 10) == 0, "starts at 0")
  assert(M.compute(nil, nil) == 0, "invalid => 0, never full")
  assert(M.compute(99, 10) == 1, "ceiling 1")
  assert(M.compute(-5, 10) == 0, "floor 0")
  assert(M.compute(5, 0) == 0, "total 0 => 0")
  M.reset("t")
  assert(M.get() == 0, "reset 0")
  assert(M.set(3, 10, "t") == 0.3, "3/10")
  assert(M.get() == 0.3, "rises")
  assert(M.set(1, 10, "t") == 0.1, "drops when order breaks")
  assert(M.isWin(1) and not M.isWin(0.9), "win only at 1")
  assert(M.set(10, 10, "t") == 1.0 and M.isWin(M.get()), "100% wins")
  M.sync(G, 0.5)
  assert(G.Progress == 10 and G.ProgressProcent == 0.5, "mirror 0.5*20")
  M.reset("t2")
  assert(M.get() == 0 and G.ProgressProcent ~= nil, "reset after win")
  local c, t = M.correctOf({ "A", "B", "X", "D", "E", "F", "G", "H", "I", "" },
    M.target(1))
  assert(c == 9 and t == 10, "9/10 with 1 error")
  assert(M.observe({ "A", "B", "C", "D", "E", "F", "G", "H", "I", "" },
    M.target(1), "t") == 1.0, "full order wins")
  M.reset("end")
  return "BARLOGIC_OK 0->up->down->100->reset"
end
  return M
end)()
package.loaded["mod_alpha_barlogic"] = barlogic
return {
  ["mod_alpha_gameplay"] = gameplay,
  ["mod_alpha_rows"] = rows,
  ["mod_alpha_finish"] = finish,
  ["mod_alpha_barlogic"] = barlogic,
}
