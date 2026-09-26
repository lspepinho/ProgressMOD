local PATCHED, ORIG, LOGF = "patched_main.lu", "orig_main.lu", "modloader_v1.log"
pcall(function() print("ProgressMOD loader start") end)
pcall(function() _G.__PMOD_BOOTED = true end)
pcall(function()
  local okf, fin = pcall(require, "mod_alpha_finish")
  if okf and fin and fin.selftest then
    local oks, res = pcall(fin.selftest)
    if oks then
    else
    end
  else
  end
end)
local function try_load(path, tag)
  local chunk, err = loadfile(path)
  if chunk then
    local size = 0
    pcall(function()
      local f = io.open(path, "rb")
      if f then
        size = f:seek("end") or 0
        f:close()
      end
    end)
  else
  end
  return chunk
end
local chunk = try_load(PATCHED, "PATCHED")
local mode = "patched"
if not chunk then
  chunk = try_load(ORIG, "ORIG")
  mode = "orig-fallback"
else
  local probe = io.open(ORIG, "rb")
  if probe then
    probe:close()
  else
  end
end
pcall(function() print("ProgressMOD loader mode=" .. tostring(mode)) end)
if not chunk then
  error("modloader: neither " .. PATCHED .. " nem " .. ORIG .. " loaded")
end
pcall(function()
  if package and package.path and not package.path:find("?.lu;", 1, true) then
    package.path = "?.lu;?/init.lu;" .. package.path
  end
end)
local _tb = debug and debug.traceback or function(e) return e end
local _args = { ... }
local ok, err = xpcall(function() return chunk(unpack(_args)) end, _tb)
if not ok then
  error(err, 0)
end
pcall(function()
  if native and native.getProperty then
    local mode = native.getProperty("windowMode")
    if mode ~= nil and mode ~= "normal" then return end
  end
  if native and native.setProperty then
    native.setProperty("windowSize", { width = 1364, height = 768 })
  else
  end
end)
for _, m in ipairs({ "alpha_rules", "alpha_board", "alpha_hud",
    "alpha_end", "alpha_flow", "pibe_quark", "mod_defender_firewall" }) do
  pcall(function()
    local ok, mod = pcall(require, m)
  end)
end
pcall(function()
  local okp, pq = pcall(require, "pibe_quark")
  if okp and pq then
    pcall(function()
      local f = io.open("pibe_selftest.txt", "r")
      if f then
        f:close()
        if pq.selftest then pq.selftest() end
      end
    end)
    if pq.install then pcall(pq.install) end
  end
end)
pcall(function()
  local okf, fw = pcall(require, "mod_defender_firewall")
  if okf and fw then
    if fw.install then pcall(fw.install) end
  end
end)
pcall(function() local ok, gb = pcall(require, "mod_alpha_gbridge"); if ok and gb and gb.install then local oi, oe = pcall(gb.install);  else  end end)
pcall(function()
  local okr, rb = pcall(require, "mod_alpha_realbar")
  if okr and rb and rb.install then
    local oki, erri = pcall(rb.install)
  else
  end
end)
pcall(function()
  local okl, lo = pcall(require, "mod_alpha_layout")
  if okl and lo and lo.install then
    local oki, erri = pcall(lo.install)
  else
  end
end)
pcall(function()
  local okh, flow = pcall(require, "mod_alpha_flow")
  if okh and flow and flow.start then
    local oks, errs = pcall(flow.start)
  else
  end
end)
pcall(function()
  local okl, loss = pcall(require, "mod_alpha_loss")
  if okl and loss then
    if loss.selftest then local svT = timer pcall(loss.selftest) timer = svT end
    if loss.install then
      local oki, erri = pcall(loss.install)
    end
  else
  end
end)
pcall(function()
  local okw, win = pcall(require, "mod_alpha_win")
  if okw and win then
    if win.selftest then pcall(win.selftest) end
    if win.install then
      local oki, erri = pcall(win.install)
    end
  else
  end
end)
pcall(function()
  local okw, wr = pcall(require, "mod_winreal_min")
  if okw and wr and wr.install then
    local oki, erri = pcall(wr.install)
  else
  end
end)
pcall(function()
  local got, ids, winMod = {}, {}, nil
  for _, n in ipairs({ "mod_alpha_touch", "mod_alpha_timer",
      "mod_alpha_win", "mod_alpha_loss" }) do
    local okm, m = pcall(require, n)
    got[n] = (okm and m) and 1 or 0
    if okm and m then
      if m.id then ids[#ids + 1] = m.id end
      if m.selftest then local svT = timer pcall(m.selftest) timer = svT end
      if n == "mod_alpha_win" then winMod = m end
    end
  end
  if winMod and winMod.install then
    local oki, erri = pcall(winMod.install)
  end
end)
pcall(function()
  local got, ids = {}, {}
  for _, n in ipairs({ "mod_alpha_select", "mod_alpha_rows",
      "mod_alpha_barlogic" }) do
    local okm, m = pcall(require, n)
    got[n] = (okm and m) and 1 or 0
    if okm and m then
      if m.id then ids[#ids + 1] = m.id end
      if m.selftest then local svT = timer pcall(m.selftest) timer = svT end
      if m.install and n ~= "mod_alpha_rows" then
        local oki, erri = pcall(m.install)
      end
    end
  end
end)
pcall(function()
  local got, ids = {}, {}
  for _, n in ipairs({ "mod_alpha_highlight", "mod_alpha_select",
      "mod_alpha_barlogic", "mod_alpha_gameplay" }) do
    local okm, m = pcall(require, n)
    got[n] = (okm and m) and 1 or 0
    if okm and m then
      if m.id then ids[#ids + 1] = m.id end
      if m.selftest then local svT = timer pcall(m.selftest) timer = svT end
    end
  end
end)
pcall(function()
  local got, ids = {}, {}
  local function P(n) local okm, m = pcall(require, n) if okm and m then return m end end
  local L = { { "slide", P("mod_alpha_slide") or P("mod_alpha_touch") },
    { "outline", P("mod_alpha_selbox") or P("mod_alpha_outline") or P("mod_alpha_select") },
    { "rows", P("mod_alpha_rows") }, { "rowsphys", P("mod_alpha_rowsphys") } }
  for _, q in ipairs(L) do local n, m = q[1], q[2] got[n] = m and 1 or 0
    if m then if m.id then ids[#ids + 1] = m.id end
      if m.selftest then local svT = timer pcall(m.selftest) timer = svT end
      if m.install and n ~= "rows" then local o, e = pcall(m.install)
         end end end
end)
pcall(function()
  local okc, cht = pcall(require, "mod_alpha_cheat")
  if okc and cht then
    if cht.selftest then local svT = timer pcall(cht.selftest) timer = svT end
    if cht.install then
      local oki, erri = pcall(cht.install)
    end
  else
  end
end)
return err
