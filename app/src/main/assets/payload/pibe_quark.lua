local M = {}
M.id = "pibe-quark-v2"
M.PIBE_SITE = "ppp.pibe"
M.QUARK_SITE = "ppp.quark"
M.PIBE_FTP = "ftp.pibe"
M.QUARK_FTP = "ftp.quark"
M.PIBE_SAVE = "pibe_installed.save"
M.QUARK_SAVE = "quark_installed.save"
M.PIBE_KEYWORDS = { "pibe", "wine", "emulator", "baros", "computer" }
M.QUARK_KEYWORDS = { "quark", "proton", "sweeper", "defender", "progresstein3d", "progressball", "pinball" }

local S = { hooked = false, inet_wrapped = false, dl_wrapped = false, search_wrapped = false, frame = 0, siteTable = nil }

if _G.__PIBE_INSTALLED == nil then _G.__PIBE_INSTALLED = false end
if _G.__QUARK_INSTALLED == nil then _G.__QUARK_INSTALLED = false end

local function trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

function M.normalizeUrl(u)
  local s = trim(u or "")
  if s:sub(1, 5):lower() == "pb://" then
    s = s:sub(6)
  end
  s = trim(s)
  return s:lower()
end

function M.normalizeQuery(q)
  local s = trim(q or ""):lower()
  if s:sub(1, 5) == "pb://" then
    s = s:sub(6)
  end
  s = trim(s)
  if s:sub(1, 4) == "ppp." then
    s = s:sub(5)
  end
  return trim(s)
end

function M.queryMatches(q, kws)
  local nq = M.normalizeQuery(q)
  if nq == "" or #nq < 2 then return false end
  if type(kws) ~= "table" then return false end
  for _, kw in ipairs(kws) do
    kw = tostring(kw or ""):lower()
    if kw ~= "" then
      if nq == kw then return true end
      if nq:find(kw, 1, true) ~= nil then return true end
      if kw:find(nq, 1, true) ~= nil then return true end
    end
  end
  return false
end

local function saveRecord(path)
  local rec = nil
  pcall(function()
    local f = io.open(path, "r")
    if not f then return end
    local c = (f:read("*a") or "")
    f:close()
    c = trim(c):lower()
    if c == "1" or c == "true" or c == "yes" or c == "installed" then rec = true
    elseif c == "0" or c == "false" or c == "no" or c == "uninstalled" then rec = false end
  end)
  return rec
end

local function writeSave(path, v)
  pcall(function()
    local f = io.open(path, "w")
    if f then
      f:write(v and "1" or "0")
      f:close()
    end
  end)
end

local function getG()
  local G = nil
  pcall(function()
    if type(onHoverTouch) == "function" and debug and debug.getupvalue then
      local _, g = debug.getupvalue(onHoverTouch, 1)
      G = g
    end
  end)
  if type(G) ~= "table" then
    pcall(function() G = _G.G end)
  end
  if type(G) ~= "table" then return nil end
  return G
end

function M.isPibe()
  local v = false
  pcall(function() v = _G.__PIBE_INSTALLED == true end)
  if v then return true end
  local rec = nil
  pcall(function() rec = saveRecord(M.PIBE_SAVE) end)
  if rec ~= nil then return rec end
  pcall(function()
    local G = getG()
    if type(G) == "table" and type(G.INI) == "table" and G.INI.PibeInstalled == true then
      v = true
    end
  end)
  return v == true
end

function M.isQuark()
  local v = false
  pcall(function() v = _G.__QUARK_INSTALLED == true end)
  if v then return true end
  local rec = nil
  pcall(function() rec = saveRecord(M.QUARK_SAVE) end)
  if rec ~= nil then return rec end
  pcall(function()
    local G = getG()
    if type(G) == "table" and type(G.INI) == "table" and G.INI.QuarkInstalled == true then
      v = true
    end
  end)
  return v == true
end

function M.isBarOSNow()
  local G = nil
  pcall(function() G = getG() end)
  if type(G) ~= "table" then return true end
  local cur, tbl = nil, nil
  pcall(function() cur = G.OS_Current tbl = G.OS_Table end)
  if type(tbl) ~= "table" or cur == nil then return true end
  local def = tbl[cur]
  if type(def) ~= "table" then return true end
  local bar = false
  pcall(function() bar = def.BAR == true end)
  if bar then return true end
  local shine = false
  pcall(function()
    local gm = def.GameModes
    if type(gm) == "table" then
      for _, e in ipairs(gm) do
        if type(e) == "table" and type(e[1]) == "string" then
          local s = e[1]:lower()
          if s == "shine" or s == "relaxshine" or s == "hardcoreshine" then shine = true break end
        end
      end
    end
  end)
  if shine then return true end
  return false
end

local function markPibe(G)
  pcall(function() _G.__PIBE_INSTALLED = true end)
  pcall(function()
    if type(G) == "table" then
      if type(G.INI) ~= "table" then G.INI = {} end
      G.INI.PibeInstalled = true
    end
  end)
  writeSave(M.PIBE_SAVE, true)
end

local function markQuark(G)
  pcall(function() _G.__QUARK_INSTALLED = true end)
  pcall(function()
    if type(G) == "table" then
      if type(G.INI) ~= "table" then G.INI = {} end
      G.INI.QuarkInstalled = true
    end
  end)
  writeSave(M.QUARK_SAVE, true)
end

function M.installPibe()
  local G = nil
  pcall(function() G = getG() end)
  markPibe(G)
  S.sitesDirty = true
  pcall(function() M.ensureGameModes(G) end)
  pcall(function() M.ensureCorrectors(G) end)
  pcall(function() cleanHistory(G) end)
  return true
end

function M.installQuark()
  local G = nil
  pcall(function() G = getG() end)
  markQuark(G)
  S.sitesDirty = true
  pcall(function() M.ensureQuarkModes(G) end)
  pcall(function() cleanHistory(G) end)
  return true
end

local function removeSave(path)
  pcall(function() os.remove(path) end)
  writeSave(path, false)
end

function M.revertCorrectors(G)
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
  end
  if type(G) ~= "table" then return 0 end
  local modes = nil
  pcall(function() modes = G.Mode end)
  if type(modes) ~= "table" then return 0 end
  local count = 0
  pcall(function()
    for _, cfg in pairs(modes) do
      if type(cfg) == "table" then
        local jobs = {}
        for k, v in pairs(cfg) do
          if type(k) == "string" and type(v) == "number" then
            if k:sub(1, 11) == "__pibe_red_" or k:sub(1, 12) == "__pibe_pink_" then
              local orig = nil
              if k:sub(1, 11) == "__pibe_red_" then orig = k:sub(12)
              else orig = k:sub(13) end
              if type(orig) == "string" and orig ~= "" then
                jobs[#jobs + 1] = { mark = k, key = orig, val = v }
              end
            end
          end
        end
        for _, j in ipairs(jobs) do
          cfg[j.key] = j.val
          cfg[j.mark] = nil
          count = count + 1
        end
      end
    end
  end)
  return count
end

function M.removePibeModes(G)
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
  end
  if type(G) ~= "table" then return 0 end
  local osTable = nil
  pcall(function() osTable = G.OS_Table end)
  if type(osTable) ~= "table" then return 0 end
  local removed = 0
  pcall(function()
    for _, osDef in pairs(osTable) do
      if type(osDef) == "table" and type(osDef.GameModes) == "table" then
        local gm = osDef.GameModes
        for i = #gm, 1, -1 do
          local e = gm[i]
          if type(e) == "table" and e.__pibeAdded == true then
            table.remove(gm, i)
            removed = removed + 1
          end
        end
      end
    end
  end)
  pcall(function() M.removeNavEntries(G, "pibe") end)
  return removed
end

function M.removeQuarkModes(G)
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
  end
  if type(G) ~= "table" then return 0 end
  local removed = 0
  pcall(function()
    local osTable = G.OS_Table
    if type(osTable) == "table" then
      for _, osDef in pairs(osTable) do
        if type(osDef) == "table" and type(osDef.GameModes) == "table" then
          local gm = osDef.GameModes
          for i = #gm, 1, -1 do
            local e = gm[i]
            if type(e) == "table" and e.__quarkAdded == true then
              table.remove(gm, i)
              removed = removed + 1
            end
          end
        end
      end
    end
  end)
  pcall(function() M.removeNavEntries(G, "quark") end)
  pcall(function()
    if type(G.Duty) == "table" and type(G.Duty.GameModesPurchased) == "table"
      and type(S.quarkPids) == "table" then
      local purchased = G.Duty.GameModesPurchased
      for i = #purchased, 1, -1 do
        if S.quarkPids[purchased[i]] then
          table.remove(purchased, i)
          removed = removed + 1
        end
      end
      S.quarkPids = {}
    end
  end)
  return removed
end

local function cleanHistory(G)
  pcall(function()
    if type(G) ~= "table" then return end
    local h = G.Duty and G.Duty.ProgressnetHistory
    if type(h) ~= "table" then return end
    local bad = {
      ["ppp.pibe/download"] = true, ["ppp.pibe/install"] = true,
      ["ppp.quark/download"] = true, ["ppp.quark/install"] = true,
      ["ftp.pibe"] = true, ["ftp.quark"] = true,
    }
    for i = #h, 1, -1 do
      local u = h[i]
      if type(u) == "string" and bad[M.normalizeUrl(u)] then
        table.remove(h, i)
      end
    end
    local pos = G.Duty.ProgressnetHistoryPos
    if type(pos) == "number" and pos > #h then
      G.Duty.ProgressnetHistoryPos = math.max(1, #h)
    end
  end)
end

local function refreshSites()
  pcall(function()
    if S.siteTable then
      S.siteTable[M.PIBE_SITE] = buildPibeSite(M.isPibe(), S.progressillaTemplate)
      S.siteTable[M.QUARK_SITE] = buildQuarkSite(M.isQuark(), S.progressillaTemplate)
    end
  end)
end

function M.uninstallPibe()
  local G = nil
  pcall(function() G = getG() end)
  pcall(function() _G.__PIBE_INSTALLED = false end)
  S.sitesDirty = true
  pcall(function()
    if type(G) == "table" and type(G.INI) == "table" then
      G.INI.PibeInstalled = nil
    end
  end)
  removeSave(M.PIBE_SAVE)
  pcall(function() M.revertCorrectors(G) end)
  pcall(function() M.removePibeModes(G) end)
  pcall(function() cleanHistory(G) end)
  pcall(refreshSites)
  return true
end

function M.uninstallQuark()
  local G = nil
  pcall(function() G = getG() end)
  pcall(function() _G.__QUARK_INSTALLED = false end)
  S.sitesDirty = true
  pcall(function()
    if type(G) == "table" and type(G.INI) == "table" then
      G.INI.QuarkInstalled = nil
    end
  end)
  removeSave(M.QUARK_SAVE)
  pcall(function() M.removeQuarkModes(G) end)
  pcall(function() cleanHistory(G) end)
  pcall(refreshSites)
  return true
end

local function hasModeEntry(list, wantFirst)
  if type(list) ~= "table" then return false end
  wantFirst = tostring(wantFirst or ""):lower()
  for _, e in ipairs(list) do
    if type(e) == "table" and type(e[1]) == "string" then
      if e[1]:lower() == wantFirst then return true end
    end
  end
  return false
end

local function isBarOS(osDef)
  if type(osDef) ~= "table" then return false end
  local ok = false
  pcall(function()
    if osDef.BAR == true then ok = true end
  end)
  if ok then return true end
  pcall(function()
    local gm = osDef.GameModes
    if type(gm) == "table" then
      for _, e in ipairs(gm) do
        if type(e) == "table" and type(e[1]) == "string" then
          local s = e[1]:lower()
          if s == "shine" or s == "relaxshine" or s == "hardcoreshine" then
            ok = true
            break
          end
        end
      end
    end
  end)
  return ok
end

local function hasNatives(gm)
  if type(gm) ~= "table" then return false end
  local found = false
  pcall(function()
    for _, e in ipairs(gm) do
      if type(e) == "table" and type(e[1]) == "string" then
        local nav = nil
        pcall(function() nav = e.__pqNav end)
        local pf, qf = false, false
        pcall(function() pf = e.__pibeAdded == true end)
        pcall(function() qf = e.__quarkAdded == true end)
        if nav == nil and not pf and not qf then
          found = true
          break
        end
      end
    end
  end)
  return found
end

function M.ensureGameModes(G)
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
  end
  if type(G) ~= "table" then return 0 end
  if not M.isPibe() then return 0 end
  local osTable = nil
  pcall(function() osTable = G.OS_Table end)
  if type(osTable) ~= "table" then return 0 end
  local patched = 0
  pcall(function()
    for _, osDef in pairs(osTable) do
      if type(osDef) == "table" and type(osDef.GameModes) == "table" then
        if isBarOS(osDef) and hasNatives(osDef.GameModes) then
          for _, want in ipairs({ "Relax", "Normal", "Hardcore" }) do
            if not hasModeEntry(osDef.GameModes, want) then
              local e = { want }
              e.__pibeAdded = true
              osDef.GameModes[#osDef.GameModes + 1] = e
              patched = patched + 1
            end
          end
        end
      end
    end
  end)
  return patched
end

function M.ensureCorrectors(G)
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
  end
  if type(G) ~= "table" then return 0 end

  if not M.isPibe() then return 0 end
  local modes = nil
  pcall(function() modes = G.Mode end)
  if type(modes) ~= "table" then return 0 end
  local count = 0
  pcall(function()
    for _, cfg in pairs(modes) do
      if type(cfg) == "table" then
        for k, v in pairs(cfg) do
          if type(v) == "number" and type(k) == "string" then
            local kl = k:lower()
            local isRed = kl:find("red", 1, true) ~= nil
            local isPink = kl:find("pink", 1, true) ~= nil
              or kl:find("rosa", 1, true) ~= nil
              or kl:find("rose", 1, true) ~= nil
            if isRed then
              if not cfg["__pibe_red_" .. k] then
                cfg["__pibe_red_" .. k] = v
                cfg[k] = v * 1.05
                count = count + 1
              end
            elseif isPink then
              if not cfg["__pibe_pink_" .. k] then
                cfg["__pibe_pink_" .. k] = v
                cfg[k] = v * 1.03
                count = count + 1
              end
            end
          end
        end
      end
    end
  end)
  return count
end

local function modeHas(list, pred)
  if type(list) ~= "table" then return false end
  for _, e in ipairs(list) do
    if type(e) == "table" and type(e[1]) == "string" then
      local ok = false
      pcall(function() ok = pred(e[1]) == true end)
      if ok then return true end
    end
  end
  return false
end

local function isSweeperName(s)
  s = tostring(s or ""):lower()
  return s:find("sweep", 1, true) ~= nil or s == "minesweeper"
end

local function isDefenderName(s)
  s = tostring(s or ""):lower()
  return s:find("defend", 1, true) ~= nil or s == "defender"
end

local function isSteinName(s)
  s = tostring(s or ""):lower()
  return s:find("stein", 1, true) ~= nil or s:find("3d", 1, true) ~= nil
end

local function isBallName(s)
  s = tostring(s or ""):lower()
  return s:find("pinball", 1, true) ~= nil or s:find("progressball", 1, true) ~= nil
end

function M.ensureQuarkModes(G)
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
  end
  if type(G) ~= "table" then return 0 end
  if not M.isQuark() then return 0 end
  local patched = 0
  pcall(function()
    local osTable = G.OS_Table
    if type(osTable) == "table" then
      for _, osDef in pairs(osTable) do
        if type(osDef) == "table" and type(osDef.GameModes) == "table"
          and hasNatives(osDef.GameModes) then
          if not modeHas(osDef.GameModes, isSweeperName) then
            local e1 = { "minesweeper" }
            e1.__quarkAdded = true
            osDef.GameModes[#osDef.GameModes + 1] = e1
            patched = patched + 1
          end
          if not modeHas(osDef.GameModes, isDefenderName) then
            local e2 = { "defender" }
            e2.__quarkAdded = true
            osDef.GameModes[#osDef.GameModes + 1] = e2
            patched = patched + 1
          end
          if not modeHas(osDef.GameModes, isSteinName) then
            local e3 = { "progresstein", "demotimer" }
            e3.__quarkAdded = true
            osDef.GameModes[#osDef.GameModes + 1] = e3
            patched = patched + 1
          end
          if not modeHas(osDef.GameModes, isBallName) then
            local e4 = { "pinball" }
            e4.__quarkAdded = true
            osDef.GameModes[#osDef.GameModes + 1] = e4
            patched = patched + 1
          end
        end
      end
    end
  end)
  pcall(function()
    if type(G.Duty) ~= "table" then G.Duty = {} end
    if type(G.Duty.GameModesPurchased) ~= "table" then
      G.Duty.GameModesPurchased = {}
    end
    local purchased = G.Duty.GameModesPurchased
    local function has(id)
      for _, v in ipairs(purchased) do
        if v == id then return true end
      end
      return false
    end
    local function add(id)
      if not has(id) then
        purchased[#purchased + 1] = id
        patched = patched + 1
        pcall(function()
          if type(S.quarkPids) ~= "table" then S.quarkPids = {} end
          S.quarkPids[id] = true
        end)
      end
    end
    add("G3D")
    add("GPN")
    local osTable = G.OS_Table
    local allProds = nil
    if type(osTable) == "table" then
      if type(osTable.ALL) == "table" then
        allProds = osTable.ALL
      else
        allProds = osTable
      end
    end
    if type(allProds) == "table" then
      for pid, pdef in pairs(allProds) do
        if type(pid) == "string" and type(pdef) == "table" then
          local nm = ""
          pcall(function() nm = tostring(pdef.Name or ""):lower() end)
          if nm:find("sweep", 1, true) or nm:find("defend", 1, true)
            or nm:find("stein", 1, true) or nm:find("minesweep", 1, true)
            or nm:find("progress sweeper", 1, true)
            or nm:find("progress defender", 1, true)
            or nm:find("progressball", 1, true)
            or nm:find("pinball", 1, true) then
            add(pid)
          end
        end
      end
    end
  end)
  return patched
end

local function deepCopy(t, seen)
  if type(t) ~= "table" then return t end
  seen = seen or {}
  if seen[t] then return seen[t] end
  local c = {}
  seen[t] = c
  for k, v in pairs(t) do
    c[deepCopy(k, seen)] = deepCopy(v, seen)
  end
  return c
end

local function txtEl(text, x, y, extra)
  local p = { text = text, X = x or 5, Y = y or 5 }
  if type(extra) == "table" then
    for k, v in pairs(extra) do p[k] = v end
  end
  return { "TXT", p, 2 }
end

local function txtLinkEl(text, url, x, y, extra)
  local p = { text = text, X = x or 5, Y = y or 5, URL = url }
  if type(extra) == "table" then
    for k, v in pairs(extra) do p[k] = v end
  end
  return { "TXT", p, 2 }
end

local function styleEl()
  return { "STYLE", { Font = "SerifBold", TextColor = { [1] = 0, [2] = 0, [3] = 0 } }, 2 }
end

local function backEl()
  return { "BACK", { Color = { [1] = 255, [2] = 255, [3] = 255 } }, 2 }
end

local function buildMinimalPibeSite(installed, showDl)
  if showDl == nil then showDl = true end
  local els = {}
  els[#els + 1] = { "Title", { [1] = "Pibe" } }
  els[#els + 1] = { "Meta", { [1] = "pibe", [2] = "wine", [3] = "emulator", [4] = "baros", [5] = "computer" } }
  els[#els + 1] = styleEl()
  els[#els + 1] = txtEl("PIBE - Pibe Isn't BarOS Emulator", 5, 5, { size = 32 })
  els[#els + 1] = txtEl("Run Progress Computer modes (Relax, Normal, Hardcore) inside BarOS.", 5, 6, { Width = 6, Align = "left" })
  els[#els + 1] = txtEl("BarOS native. PC compatible.", 5, 7, { Width = 6, Align = "left" })
  if installed then
    els[#els + 1] = txtLinkEl("Uninstall Pibe", "ppp.pibe/uninstall", 5, 9)
  elseif showDl == false then
    els[#els + 1] = txtEl("Your favorite PC emulator.", 5, 9, { Width = 6, Align = "left" })
  else
    els[#els + 1] = txtLinkEl("Download Pibe", "ppp.pibe/download", 5, 9)
    els[#els + 1] = txtLinkEl("Mirror", "ppp.pibe/download", 5, 10)
  end
  els[#els + 1] = txtEl("(pb) Pibe project", 5, 16, { size = 20 })
  els[#els + 1] = backEl()
  return els
end

local function buildMinimalQuarkSite(installed, showDl)
  if showDl == nil then showDl = true end
  local els = {}
  els[#els + 1] = { "Title", { [1] = "Quark" } }
  els[#els + 1] = { "Meta", { [1] = "quark", [2] = "proton", [3] = "sweeper", [4] = "defender", [5] = "progresstein3d" } }
  els[#els + 1] = styleEl()
  els[#els + 1] = txtEl("QUARK - PC emulator", 5, 5, { size = 32 })
  els[#els + 1] = txtEl("Emulates Progress Sweeper, Progress Defender, Progresstein3d and Progressball.", 5, 6, { Width = 6, Align = "left" })
  if installed then
    els[#els + 1] = txtLinkEl("Uninstall Quark", "ppp.quark/uninstall", 5, 9)
  elseif showDl == false then
    els[#els + 1] = txtEl("Your favorite PC games emulator.", 5, 9, { Width = 6, Align = "left" })
  else
    els[#els + 1] = txtLinkEl("Download Quark", "ppp.quark/download", 5, 9)
    els[#els + 1] = txtLinkEl("Mirror", "ppp.quark/download", 5, 10)
  end
  els[#els + 1] = txtEl("(pb) Quark project", 5, 16, { size = 20 })
  els[#els + 1] = backEl()
  return els
end

local PIBE_OPTS = {
  name = "Pibe",
  title = "Pibe",
  banner = "pibe_banner",
  meta = { "pibe", "wine", "emulator", "baros", "computer" },
  headline = "Pibe",
  taglineUpper = "Your favorite PC emulator",
  tagline = "Your favorite PC emulator",
  getText = "Get the emulator!",
  bullets = {
    "- Run PC modes in BarOS",
    "- Relax, Normal, Hardcore",
    "- BarOS native",
    "- PC compatible",
  },
  downloadUrl = "ppp.pibe/download",
  mirrorUrl = "ppp.pibe/download",
  downloadText = "Download Pibe",
  mirrorText = "Mirror",
  uninstallText = "Uninstall Pibe",
  uninstallUrl = "ppp.pibe/uninstall",
  installedText = "Pibe INSTALLED. PC modes on BarOS.",
  footer = "(pb) Pibe project",
}

local QUARK_OPTS = {
  name = "Quark",
  title = "Quark",
  banner = "quark_banner",
  meta = { "quark", "proton", "sweeper", "defender", "progresstein3d" },
  headline = "Quark",
  taglineUpper = "Your favorite PC games emulator",
  tagline = "Your favorite PC games emulator",
  getText = "Get the emulator!",
  bullets = {
    "- Run PC modes in BarOS",
    "- Emulate Sweeper",
    "- Emulate Defender",
    "- Emulate Progresstein3d",
    "- Emulate Progressball",
    "- PC compatible",
  },
  downloadUrl = "ppp.quark/download",
  mirrorUrl = "ppp.quark/download",
  downloadText = "Download Quark",
  mirrorText = "Mirror",
  uninstallText = "Uninstall Quark",
  uninstallUrl = "ppp.quark/uninstall",
  installedText = "Quark INSTALLED. Sweeper+Defender+3d+Ball.",
  footer = "(pb) Quark project",
}

local function transformProgressilla(tmpl, o, installed, showDl)
  if showDl == nil then showDl = true end
  local site = deepCopy(tmpl)
  pcall(function()
    if type(site[1]) == "table" and site[1][1] == "Title" and type(site[1][2]) == "table" then
      site[1][2][1] = o.title
    end
  end)
  pcall(function()
    if type(site[2]) == "table" and site[2][1] == "Meta" then
      site[2][2] = { o.meta[1], o.meta[2], o.meta[3], o.meta[4], o.meta[5] }
    end
  end)
  local bulletIdx, priceIdx, dlY, keptFooter, keptLogo = 0, 0, nil, false, false
  local out = {}
  for _, el in ipairs(site) do
    local drop = false
    if type(el) == "table" and type(el[2]) == "table" then
      local typ, p = el[1], el[2]
      if typ == "IMG" and type(p.file) == "string" and p.file:lower():find("placeholder", 1, true) then
        drop = true
      elseif typ == "IMG" and type(p.file) == "string" and type(o.banner) == "string" then
        local f = p.file:lower()
        if f:find("pslogo", 1, true) then
          if keptLogo then drop = true else p.file = o.banner p.Width = 4 p.Height = 4 p.X = 2 p.Y = 6 keptLogo = true end
        elseif f:find("badgeps", 1, true) then
          drop = true
        end
      elseif typ == "TXT" and type(p.text) == "string" then
        local t = p.text
        if t:find("Progressilla Org") then
          if keptFooter then drop = true
          else p.text = o.footer keptFooter = true end
        elseif t:find("Progressilla") then
          if (p.size or 0) >= 30 then
            p.text = o.headline
          elseif t:find("Browser") then
            p.text = o.name .. " Emulator"
          else
            p.text = t:gsub("Progressilla", o.name)
          end
        elseif t == "Your favorite PREMIUM browser" then
          p.text = o.taglineUpper
        elseif t == "Your favorite premium browser" then
          p.text = o.tagline
        elseif t == "Get the premium browser!" then
          p.text = o.getText
        elseif t:sub(1, 2) == "- " then
          bulletIdx = bulletIdx + 1
          p.text = o.bullets[((bulletIdx - 1) % #o.bullets) + 1]
        end
      elseif typ == "IMG" and p.URL == "ftp.ps1" then
        if showDl == false then p.URL = nil else p.URL = o.downloadUrl end
      elseif typ == "PRICETAG" then
        priceIdx = priceIdx + 1
        local X, Y = p.X or 5, p.Y or 9
        if installed then
          if priceIdx == 1 then
            el[1] = "TXT"
            el[2] = { text = o.uninstallText, X = X, Y = Y, URL = o.uninstallUrl, size = 20, Width = 5, Align = "left" }
            el[3] = 2
            dlY = Y
          else
            el[1] = "TXT"
            el[2] = { text = o.footer, X = X, Y = Y, size = 16, Width = 5, Align = "left" }
            el[3] = 2
          end
        elseif showDl == false then
          drop = true
        elseif priceIdx == 1 then
          el[1] = "TXT"
          el[2] = { text = o.downloadText, X = X, Y = Y, URL = o.downloadUrl, size = 20, Width = 5, Align = "left" }
          el[3] = 2
          dlY = Y
        elseif priceIdx == 2 then
          local my = (dlY or (Y - 1)) + 1
          el[1] = "TXT"
          el[2] = { text = o.mirrorText, X = X, Y = my, URL = o.mirrorUrl, size = 16, Width = 5, Align = "left" }
          el[3] = 2
        else
          if keptFooter then drop = true
          else
            el[1] = "TXT"
            el[2] = { text = o.footer, X = X, Y = Y, size = 16, Width = 5, Align = "left" }
            el[3] = 2
            keptFooter = true
          end
        end
      end
    end
    if not drop then out[#out + 1] = el end
  end
  pcall(function()
    local function idxLink(url, text)
      for i, el in ipairs(out) do
        if type(el) == "table" and el[1] == "TXT" and type(el[2]) == "table"
          and el[2].URL == url and el[2].text == text then
          return i
        end
      end
      return nil
    end
    local function idxFoot()
      for i, el in ipairs(out) do
        if type(el) == "table" and el[1] == "TXT" and type(el[2]) == "table" and el[2].text == o.footer then
          return i
        end
      end
      return nil
    end
    local anchor = idxLink(o.downloadUrl, o.downloadText) or idxLink(o.uninstallUrl, o.uninstallText)
    local mir = idxLink(o.mirrorUrl, o.mirrorText)
    if anchor and mir and mir ~= anchor + 1 then
      local m = table.remove(out, mir)
      anchor = idxLink(o.downloadUrl, o.downloadText) or idxLink(o.uninstallUrl, o.uninstallText)
      table.insert(out, anchor + 1, m)
    end
    anchor = idxLink(o.downloadUrl, o.downloadText) or idxLink(o.uninstallUrl, o.uninstallText)
    mir = idxLink(o.mirrorUrl, o.mirrorText)
    local base = mir or anchor
    if base then
      local ax = (out[anchor][2].X) or 5
      local ay = (out[anchor][2].Y) or 8
      if mir then
        out[mir][2].X = ax
        out[mir][2].Y = ay + 1
      end
      local foot = idxFoot()
      if foot then
        local fy
        if mir then fy = out[mir][2].Y + 1 else fy = ay + 1 end
        local f = table.remove(out, foot)
        base = idxLink(o.mirrorUrl, o.mirrorText) or idxLink(o.downloadUrl, o.downloadText) or idxLink(o.uninstallUrl, o.uninstallText)
        table.insert(out, (base or 0) + 1, f)
        local nf = idxFoot()
        out[nf][2].X = 5
        out[nf][2].Y = fy
      end
    end
  end)
  return out
end

local function currentEra()
  local e = nil
  pcall(function()
    local G = getG()
    if type(G) == "table" and type(G.INI) == "table" then e = tonumber(G.INI.WebGeneration) end
  end)
  if e ~= 1 and e ~= 2 and e ~= 3 then e = 2 end
  return e
end
local function pinEra2(site)
  if type(site) ~= "table" then return site end
  local era = currentEra()
  local out = {}
  for _, el in ipairs(site) do
    if type(el) ~= "table" then
      out[#out + 1] = el
    else
      local tag = el[3]
      local bf = nil
      if el[1] == "IMG" and type(el[2]) == "table" and type(el[2].file) == "string" then
        bf = el[2].file:lower()
      end
      local badge = (bf == "pibe_banner" or bf == "quark_banner") or
        (el[1] == "IMG" and type(el[2]) == "table" and type(el[2].URL) == "string")
      if tag == nil or tag == 2 or (tag == 1 and badge) then
        if type(tag) == "number" then el[3] = era end
        out[#out + 1] = el
      end
    end
  end
  return out
end
local function buildPibeSite(installed, template)
  local showDl = M.isBarOSNow()
  if type(template) == "table" then
    local ok, res = pcall(transformProgressilla, template, PIBE_OPTS, installed == true, showDl)
    if ok and type(res) == "table" then return pinEra2(res) end
  end
  return pinEra2(buildMinimalPibeSite(installed, showDl))
end

local function buildQuarkSite(installed, template)
  local showDl = M.isBarOSNow()
  if type(template) == "table" then
    local ok, res = pcall(transformProgressilla, template, QUARK_OPTS, installed == true, showDl)
    if ok and type(res) == "table" then return pinEra2(res) end
  end
  return pinEra2(buildMinimalQuarkSite(installed, showDl))
end

M._transform = transformProgressilla
M._pibeOpts = PIBE_OPTS
M._quarkOpts = QUARK_OPTS

local function forceEra2(site)
  if type(site) ~= "table" then return site end
  local out, era2 = {}, {}
  for _, el in ipairs(site) do
    if type(el) == "table" and el[3] == 2 then era2[#era2 + 1] = el end
  end
  if #era2 == 0 then return site end
  for _, el in ipairs(site) do
    if not (type(el) == "table" and el[3] == 3) then out[#out + 1] = el end
  end
  for _, el in ipairs(era2) do
    local cp = deepCopy(el)
    cp[3] = 3
    out[#out + 1] = cp
  end
  return out
end

M.forceEra2 = forceEra2

local function tryWrapInet()
  local ok, inet = pcall(require, "inet")
  if not ok or type(inet) ~= "table" then
    pcall(function() print("PIBE net no inet") end)
    return false
  end
  if type(inet.GetSite) ~= "function" then
    pcall(function() print("PIBE net no GetSite") end)
    return false
  end
  if inet.__pibe_wrapped then return true end
  local orig = inet.GetSite
  local function getTemplate()
    if type(S.progressillaTemplate) == "table" then return S.progressillaTemplate end
    local t = nil
    pcall(function()
      local ok2, res = pcall(orig, "ppp.progressilla")
      if ok2 and type(res) == "table" then t = res end
    end)
    if type(t) == "table" then S.progressillaTemplate = deepCopy(t) end
    return S.progressillaTemplate
  end
  pcall(getTemplate)
  inet.GetSite = function(url)
    local n = M.normalizeUrl(url)
    if n == "ppp.pibe" or n == "ppp.pibe/" then
      pcall(function() print("PIBE serve pibe") end)
      return buildPibeSite(M.isPibe(), getTemplate())
    end
    if n == "ppp.pibe/download" or n == "ppp.pibe/install" then
      M.installPibe()
      return buildPibeSite(true, getTemplate())
    end
    if n == "ppp.pibe/uninstall" or n == "ppp.pibe/remove" then
      M.uninstallPibe()
      return buildPibeSite(false, getTemplate())
    end
    if n == "ppp.quark" or n == "ppp.quark/" then
      pcall(function() print("PIBE serve quark") end)
      return buildQuarkSite(M.isQuark(), getTemplate())
    end
    if n == "ppp.quark/download" or n == "ppp.quark/install" then
      M.installQuark()
      return buildQuarkSite(true, getTemplate())
    end
    if n == "ppp.quark/uninstall" or n == "ppp.quark/remove" then
      M.uninstallQuark()
      return buildQuarkSite(false, getTemplate())
    end
    local r = nil
    local ook, res = pcall(orig, url)
    if ook then r = res end
    if (n == "ppp.progressilla/homepage" or n == "ppp.progressilla") and type(r) == "table" then
      pcall(function() r = forceEra2(r) end)
    end
    return r
  end
  inet.__pibe_wrapped = true
  S.inet_wrapped = true
  pcall(function() print("PIBE net wrapped ok") end)
  pcall(function()
    if debug and debug.getupvalue then
      for i = 1, 20 do
        local okg, _, uv = pcall(debug.getupvalue, orig, i)
        if okg and type(uv) == "table" and uv["ppp.pbay"] ~= nil then
          S.siteTable = uv
          uv[M.PIBE_SITE] = buildPibeSite(M.isPibe(), getTemplate())
          uv[M.QUARK_SITE] = buildQuarkSite(M.isQuark(), getTemplate())
          break
        end
      end
    end
  end)
  pcall(function()
    if S.siteTable then
      S.siteTable[M.PIBE_SITE] = buildPibeSite(M.isPibe(), getTemplate())
      S.siteTable[M.QUARK_SITE] = buildQuarkSite(M.isQuark(), getTemplate())
    end
  end)
  return true
end

local function resultsPageFor(engine)
  if engine == 2 then return "ppp.poodle/results" end
  if engine == 3 then return "ppp.ping/results" end
  return "ppp.searchoo/results"
end

local function tryWrapSearch()
  local ok, inet = pcall(require, "inet")
  if not ok or type(inet) ~= "table" then return false end
  if type(inet.Search) ~= "function" then return false end
  if inet.__pq_search_wrapped then return true end
  local origSearch = inet.Search
  inet.Search = function(q, engine, extra)
    local r1 = nil
    pcall(function() r1 = origSearch(q, engine, extra) end)
    pcall(function()
      local nq = M.normalizeQuery(q)
      if nq == "" then return end
      local wantPibe = M.queryMatches(nq, M.PIBE_KEYWORDS)
      local wantQuark = M.queryMatches(nq, M.QUARK_KEYWORDS)
      if not (wantPibe or wantQuark) then return end
      local page = resultsPageFor(engine)
      local site = nil
      pcall(function() site = inet.GetSite(page) end)
      if type(site) ~= "table" then return end
      local function hasUrl(u)
        for _, el in ipairs(site) do
          if type(el) == "table" and type(el[2]) == "table" and el[2].URL == u then
            return true
          end
        end
        return false
      end
      local function maxY()
        local m = 8
        for _, el in ipairs(site) do
          if type(el) == "table" and type(el[2]) == "table" and type(el[2].Y) == "number" then
            if el[2].Y > m then m = el[2].Y end
          end
        end
        return m
      end
      local function countResults()
        local c = 0
        for _, el in ipairs(site) do
          if type(el) == "table" and el[1] == "TXT" and type(el[2]) == "table" and el[2].URL then
            c = c + 1
          end
        end
        return c
      end
      if wantPibe and not hasUrl(M.PIBE_SITE) then
        local n = countResults() + 1
        local y = maxY() + 1
        site[#site + 1] = { "TXT", { text = n .. ". Pibe - " .. M.PIBE_SITE, X = 5.5, Y = y, Align = "left", URL = M.PIBE_SITE }, 3 }
      end
      if wantQuark and not hasUrl(M.QUARK_SITE) then
        local n = countResults() + 1
        local y = maxY() + 1
        site[#site + 1] = { "TXT", { text = n .. ". Quark - " .. M.QUARK_SITE, X = 5.5, Y = y, Align = "left", URL = M.QUARK_SITE }, 3 }
      end
    end)
    return r1
  end
  inet.__pq_search_wrapped = true
  S.search_wrapped = true
  return true
end

local function tryWrapDownloads()
  local G = nil
  pcall(function() G = getG() end)
  if type(G) ~= "table" then return false end
  if type(G.Duty) ~= "table" or type(G.Duty.Progressnet) ~= "table" then return false end
  local pn = G.Duty.Progressnet
  if type(pn.AddDownload) ~= "function" then return false end
  if pn.__pibe_wrapped then return true end
  local orig = pn.AddDownload
  pn.AddDownload = function(a0, a1)
    local s = tostring(a0 or ""):lower()
    if s == "ftp.pibe" or s == "pibe" then
      M.installPibe()
      return true
    end
    if s == "ftp.quark" or s == "quark" then
      M.installQuark()
      return true
    end
    local ok, r = pcall(orig, a0, a1)
    return r
  end
  pn.__pibe_wrapped = true
  S.dl_wrapped = true
  return true
end

local function screenH()
  local h = nil
  pcall(function()
    if display then
      h = display.contentHeight or display.pixelHeight
    end
  end)
  h = tonumber(h) or 0
  if h <= 0 then h = 768 end
  return h
end

local function isModeBtn(o)
  if type(o) ~= "table" then return false end
  local id = nil
  pcall(function() id = o.ID end)
  if id ~= "custom2" then return false end
  local hasTxt = false
  pcall(function() hasTxt = o.IconText ~= nil end)
  return hasTxt == true
end

local function scanModeGrid()
  local groups, order = {}, {}
  pcall(function()
    if not (display and display.getCurrentStage) then return end
    local st = display.getCurrentStage()
    local function walk(o, d)
      if o == nil or d > 12 then return end
      if isModeBtn(o) then
        local par = nil
        pcall(function() par = o.parent end)
        local k = tostring(par)
        local g = groups[k]
        if not g then
          g = { parent = par, btns = {} }
          groups[k] = g
          order[#order + 1] = k
        end
        g.btns[#g.btns + 1] = o
      end
      local nk = 0
      pcall(function() nk = o.numChildren or 0 end)
      for i = 1, (nk or 0) do
        local ch = nil
        pcall(function() ch = o[i] end)
        if ch ~= nil then walk(ch, d + 1) end
      end
    end
    walk(st, 0)
  end)
  return groups
end

local function wrapBtnFunc(btn, st)
  pcall(function()
    if type(btn) ~= "table" or btn.__pqWrap then return end
    local targets = {}
    pcall(function()
      if type(btn.Hover) == "table" and type(btn.Hover.Func) == "function" then
        targets[#targets + 1] = { t = btn.Hover, k = "Func" }
      end
    end)
    pcall(function()
      if type(btn.Func) == "function" then
        targets[#targets + 1] = { t = btn, k = "Func" }
      end
    end)
    for _, w in ipairs(targets) do
      local orig = w.t[w.k]
      w.t[w.k] = function(...)
        local sup = false
        pcall(function() sup = st.suppressNext == true end)
        if sup then
          pcall(function() st.suppressNext = false end)
          return
        end
        return orig(...)
      end
    end
    if #targets > 0 then btn.__pqWrap = true end
  end)
end

local function attachScroll(g, nModes)
  local cont = g.parent
  if type(cont) ~= "table" then return false end
  local ys = {}
  for _, b in ipairs(g.btns) do
    local y = nil
    pcall(function() y = b.y end)
    if type(y) == "number" then ys[#ys + 1] = y end
  end
  if #ys == 0 then return false end
  local mn, mx = ys[1], ys[1]
  for _, y in ipairs(ys) do
    if y < mn then mn = y end
    if y > mx then mx = y end
  end
  local overflow = math.max(0, (mx - mn) - screenH() * 0.75)
  if overflow <= 0 then return false end
  local baseY = 0
  pcall(function() baseY = cont.y or 0 end)
  local st = { baseY = baseY, minY = baseY - overflow, n = #g.btns,
    suppressNext = false, startY = nil, contY = nil, dragged = false }
  S.scroll = S.scroll or {}
  S.scroll[tostring(cont)] = st
  for _, b in ipairs(g.btns) do
    wrapBtnFunc(b, st)
    pcall(function()
      if b.addEventListener and not b.__pqTouch then
        b.__pqTouch = true
        b:addEventListener("touch", function(ev)
          if type(ev) ~= "table" then return false end
          if ev.phase == "began" then
            st.suppressNext = false
            st.startY, st.contY, st.dragged = tonumber(ev.y) or 0, nil, false
            pcall(function() st.contY = cont.y or 0 end)
          elseif ev.phase == "moved" then
            if st.startY ~= nil then
              local y = tonumber(ev.y) or st.startY
              if math.abs(y - st.startY) > 14 and not st.dragged then
                st.dragged = true
              end
              if st.dragged then
                local ny = (st.contY or 0) + (y - st.startY)
                if ny < st.minY then ny = st.minY end
                if ny > st.baseY then ny = st.baseY end
                pcall(function() cont.y = ny end)
              end
            end
          else
            if st.dragged then
              st.suppressNext = true
            end
            st.startY, st.contY, st.dragged = nil, nil, false
          end
          return false
        end)
      end
    end)
  end
  return true
end

function M.ensureScroll(G)
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
  end
  if type(G) ~= "table" then return 0 end
  local n = 0
  pcall(function()
    local gm = G.OS_Table and G.OS_Current and G.OS_Table[G.OS_Current]
    gm = gm and gm.GameModes
    if type(gm) == "table" then n = #gm end
  end)
  if n <= 9 then return 0 end
  local groups = scanModeGrid()
  local done = 0
  for _, g in pairs(groups) do
    if #g.btns == n then
      local alive = false
      pcall(function()
        alive = g.parent ~= nil and (g.parent.numChildren or 0) >= 0
      end)
      if alive then
        local key = tostring(g.parent)
        S.scroll = S.scroll or {}
        local st = S.scroll[key]
        local cur = 0
        pcall(function()
          for _, b in ipairs(g.btns) do
            if b.__pqTouch then cur = cur + 1 end
          end
        end)
        if not st or cur ~= #g.btns then
          if attachScroll(g, n) then done = done + 1 end
        else
          done = done + 1
        end
      end
    end
  end
  return done
end

M.NAV_NAMES = { pibe = "Pibe", quark = "Quark", back = "Back" }

M.AUTO_REOPEN = true

M.VIEW_DEBUG = true
M.VIEW_LOG = "pqview.log"

local function vlog(...)
  if M.VIEW_DEBUG ~= true then return end
  local nargs = select("#", ...)
  local args = { ... }
  local msg = nil
  pcall(function()
    local parts = {}
    for i = 1, nargs do
      parts[#parts + 1] = tostring(args[i])
    end
    msg = table.concat(parts, " ")
  end)
  if msg == nil then return end
  pcall(function()
    local f = io.open(M.VIEW_LOG, "a")
    if not f then return end
    local sz = 0
    pcall(function() sz = f:seek("end") or 0 end)
    if sz > 200000 then f:close() return end
    local ts = ""
    pcall(function() ts = os.date("[%H:%M:%S] ") or "" end)
    f:write(tostring(ts) .. msg .. "\n")
    f:close()
  end)
end

M.vlog = vlog

local function dumpButton(b)
  local info = "?"
  pcall(function()
    local parts = {}
    local n = 0
    for k, v in pairs(b) do
      n = n + 1
      if n > 30 then break end
      local ts = type(v)
      if ts == "string" or ts == "number" or ts == "boolean" then
        local s = tostring(v)
        if #s > 40 then s = s:sub(1, 40) end
        parts[#parts + 1] = tostring(k) .. "=" .. s
      else
        parts[#parts + 1] = tostring(k) .. "[" .. ts .. "]"
      end
    end
    local it = nil
    pcall(function() it = b.IconText and b.IconText.text end)
    local ups = {}
    if debug and debug.getupvalue then
      local fns = {}
      if type(b.Func) == "function" then fns[#fns + 1] = b.Func end
      if type(b.Hover) == "table" and type(b.Hover.Func) == "function" then
        fns[#fns + 1] = b.Hover.Func
      end
      for _, fn in ipairs(fns) do
        for i = 1, 40 do
          local _, v = debug.getupvalue(fn, i)
          if v == nil then break end
          if type(v) == "string" then ups[#ups + 1] = v end
          if #ups > 20 then break end
        end
      end
    end
    info = "keys{" .. table.concat(parts, ",") .. "} icontext="
      .. tostring(it) .. " ups{" .. table.concat(ups, "|") .. "}"
  end)
  return info
end

M.dumpButton = dumpButton

local function gmList(G)
  local gm = nil
  pcall(function()
    if type(G) ~= "table" then return end
    local osTable = G.OS_Table
    local cur = G.OS_Current
    if type(osTable) == "table" and cur ~= nil then
      local osDef = osTable[cur]
      if type(osDef) == "table" and type(osDef.GameModes) == "table" then
        gm = osDef.GameModes
      end
    end
  end)
  return gm
end

local function entryFlag(e)
  if type(e) ~= "table" then return nil end
  local nav = nil
  pcall(function() nav = e.__pqNav end)
  if type(nav) == "string" and M.NAV_NAMES[nav] then
    return "nav-" .. nav
  end
  local p, q = false, false
  pcall(function() p = e.__pibeAdded == true end)
  pcall(function() q = e.__quarkAdded == true end)
  if p then return "pibe" end
  if q then return "quark" end
  return "native"
end

local function classByName(gm, name)
  if type(gm) ~= "table" or type(name) ~= "string" then return nil end
  local want = name:lower()
  local found = nil
  pcall(function()
    for _, e in ipairs(gm) do
      if type(e) == "table" and type(e[1]) == "string" then
        if e[1]:lower() == want then found = entryFlag(e) break end
      end
    end
  end)
  return found
end

M.classByName = classByName

local function nonNilCount(gm)
  local n = 0
  if type(gm) == "table" then
    pcall(function()
      for _, e in ipairs(gm) do
        if type(e) == "table" and type(e[1]) == "string" then n = n + 1 end
      end
    end)
  end
  return n
end

local function nameSetOf(gm)
  local set = {}
  pcall(function()
    for _, e in ipairs(gm) do
      if type(e) == "table" and type(e[1]) == "string" then
        set[e[1]:lower()] = true
      end
    end
  end)
  return set
end

local function splitLive(gm)
  local natives, pibe, quark, navs = {}, {}, {}, {}
  pcall(function()
    for _, e in ipairs(gm) do
      if type(e) == "table" and type(e[1]) == "string" then
        local f = entryFlag(e)
        if f == "pibe" then pibe[#pibe + 1] = e
        elseif f == "quark" then quark[#quark + 1] = e
        elseif f ~= nil and f:sub(1, 4) == "nav-" then
          if f ~= "nav-back" then navs[#navs + 1] = e end
        else natives[#natives + 1] = e end
      end
    end
  end)
  return natives, pibe, quark, navs
end

function M.ensureNavModes(G)
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
  end
  if type(G) ~= "table" then return 0 end
  local osTable = nil
  pcall(function() osTable = G.OS_Table end)
  if type(osTable) ~= "table" then return 0 end
  local added = 0
  pcall(function()
    S.stash = S.stash or {}
    for pid, osDef in pairs(osTable) do
      if type(osDef) == "table" and type(osDef.GameModes) == "table" then
        local gm = osDef.GameModes
        local natives, pibe, quark = splitLive(gm)

        if #natives > 0 then
          local st = S.stash[tostring(pid)] or {}
          local hasP = #pibe > 0
            or (type(st.pibe) == "table" and #st.pibe > 0)
          local hasQ = #quark > 0
            or (type(st.quark) == "table" and #st.quark > 0)
          local function want(name, flag)
            if hasModeEntry(gm, name) then return end
            local e = { name }
            e.__pqNav = flag
            gm[#gm + 1] = e
            added = added + 1
          end
          if hasP and M.isPibe() then want(M.NAV_NAMES.pibe, "pibe") end
          if hasQ and M.isQuark() then want(M.NAV_NAMES.quark, "quark") end
        end
      end
    end
  end)
  return added
end

function M.removeNavEntries(G, which)
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
  end
  if type(G) ~= "table" then return 0 end
  local osTable = nil
  pcall(function() osTable = G.OS_Table end)
  if type(osTable) ~= "table" then return 0 end
  local removed = 0
  pcall(function()
    for _, osDef in pairs(osTable) do
      if type(osDef) == "table" and type(osDef.GameModes) == "table" then
        local gm = osDef.GameModes
        for i = #gm, 1, -1 do
          local e = gm[i]
          if type(e) == "table" then
            local nav = nil
            pcall(function() nav = e.__pqNav end)
            if type(nav) == "string"
              and (which == "all" or nav == which) then
              table.remove(gm, i)
              removed = removed + 1
            end
          end
        end
        local hasP, hasQ = false, false
        for _, e in ipairs(gm) do
          if type(e) == "table" then
            local f = entryFlag(e)
            if f == "pibe" then hasP = true end
            if f == "quark" then hasQ = true end
          end
        end
        if not hasP and not hasQ then
          for i = #gm, 1, -1 do
            local e = gm[i]
            if type(e) == "table" then
              local back = false
              pcall(function() back = e.__pqNav == "back" end)
              if back then
                table.remove(gm, i)
                removed = removed + 1
              end
            end
          end
        end
      end
    end
  end)
  return removed
end

function M.modeButtonName(btn, nameSet)
  if type(btn) ~= "table" or type(nameSet) ~= "table" then return nil end
  local found = nil
  pcall(function()
    if not (debug and debug.getupvalue) then return end
    local cands = {}
    if type(btn.Func) == "function" then cands[#cands + 1] = btn.Func end
    if type(btn.Hover) == "table" and type(btn.Hover.Func) == "function" then
      cands[#cands + 1] = btn.Hover.Func
    end
    for _, fn in ipairs(cands) do
      for i = 1, 32 do
        local _, v = debug.getupvalue(fn, i)
        if v == nil then break end
        if type(v) == "string" and nameSet[v:lower()] then
          found = v
          break
        end
      end
      if found then break end
    end
  end)
  return found
end

local function scanModeGridLoose()
  local groups = {}
  pcall(function()
    if not (display and display.getCurrentStage) then return end
    local st = display.getCurrentStage()
    local function isBtn(o)
      if type(o) ~= "table" then return false end
      if o.__pqNav then return false end
      local id = nil
      pcall(function() id = o.ID end)
      if id == "custom2" then return false end
      local txt = nil
      pcall(function() txt = o.IconText end)
      if type(txt) ~= "table" then return false end
      local f = nil
      pcall(function()
        if type(o.Func) == "function" then f = o.Func end
      end)
      if f == nil then
        pcall(function()
          if type(o.Hover) == "table" and type(o.Hover.Func) == "function" then
            f = o.Hover.Func
          end
        end)
      end
      return f ~= nil
    end
    local function walk(o, d)
      if o == nil or d > 12 then return end
      if isBtn(o) then
        local par = nil
        pcall(function() par = o.parent end)
        local k = tostring(par)
        local g = groups[k]
        if not g then
          g = { parent = par, btns = {}, loose = true }
          groups[k] = g
        end
        g.btns[#g.btns + 1] = o
      end
      local nk = 0
      pcall(function() nk = o.numChildren or 0 end)
      for i = 1, (nk or 0) do
        local ch = nil
        pcall(function() ch = o[i] end)
        if ch ~= nil then walk(ch, d + 1) end
      end
    end
    walk(st, 0)
  end)
  return groups
end

local function findModeGrid(gm)
  if type(gm) ~= "table" then return nil end
  local nameSet = nameSetOf(gm)
  local want = nonNilCount(gm)
  local strictN, looseN = 0, 0
  local verbose = ((S.frame or 0) % 900 == 0)
  local detail = {}
  local function pick(groups, tag)
    if type(groups) ~= "table" then return nil end
    local best, bestMapped = nil, -1
    for _, g in pairs(groups) do
      if type(g) == "table" and type(g.btns) == "table" and #g.btns > 0 then
        local mapped = 0
        for _, b in ipairs(g.btns) do
          if M.modeButtonName(b, nameSet) then mapped = mapped + 1 end
        end
        local exact = (mapped == #g.btns and #g.btns == want)
        detail[#detail + 1] = tag .. ":btns=" .. #g.btns
          .. " mapped=" .. mapped .. " par=" .. tostring(g.parent)
        if verbose or exact then
          vlog("grid?", tag, "btns=" .. #g.btns, "mapped=" .. mapped, "want=" .. want)
        end
        if exact then
          return g
        end
        if mapped == #g.btns and mapped > bestMapped and mapped >= 2 then
          best, bestMapped = g, mapped
        end
      end
    end
    return best
  end
  local groups = scanModeGrid()
  if type(groups) == "table" then
    for _ in pairs(groups) do strictN = strictN + 1 end
  end
  local g = pick(groups, "strict")
  if g ~= nil then
    vlog("grid! strict want=" .. want)
    return g
  end
  local loose = scanModeGridLoose()
  if type(loose) == "table" then
    for _ in pairs(loose) do looseN = looseN + 1 end
  end
  local foundLoose = pick(loose, "loose")
  if foundLoose ~= nil then
    vlog("grid! loose want=" .. want .. " [" .. table.concat(detail, " ") .. "]")
    return foundLoose
  end
  if verbose or (strictN + looseN) > 0 then
    vlog("nogrid strict=" .. strictN, "loose=" .. looseN,
      "[" .. table.concat(detail, " ") .. "]")
  end

  S.dumpCount = S.dumpCount or {}
  local dk = tostring(display and display.getCurrentStage)
  if (S.dumpCount[dk] or 0) < 1 then
    S.dumpCount[dk] = (S.dumpCount[dk] or 0) + 1
    pcall(function()
      local shown = 0
      local function walk(o, d)
        if shown >= 3 or o == nil or d > 12 then return end
        local txt = nil
        pcall(function() txt = o.IconText end)
        if type(o) == "table" and type(txt) == "table" and not o.__pqNav then
          vlog("btn? " .. dumpButton(o))
          shown = shown + 1
        end
        local nk = 0
        pcall(function() nk = o.numChildren or 0 end)
        for i = 1, (nk or 0) do
          local ch = nil
          pcall(function() ch = o[i] end)
          if ch ~= nil then walk(ch, d + 1) end
          if shown >= 3 then return end
        end
      end
      if display and display.getCurrentStage then
        walk(display.getCurrentStage(), 0)
      end
    end)
  end
  return foundLoose
end

M.findModeGrid = findModeGrid

local function livePage(gm)
  local page = "baros"
  pcall(function()
    local natives, pibe, quark = splitLive(gm)
    if #natives > 0 then page = "baros"
    elseif #pibe > 0 then page = "pibe"
    elseif #quark > 0 then page = "quark" end
  end)
  return page
end

M.livePage = livePage

local function closeModesWindow(G)
  local closed = false
  pcall(function()
    if type(G) ~= "table" then return end
    local ui = G.UI
    if type(ui) ~= "table" then return end
    local win = ui.GameModesWindow
    if type(win) ~= "table" then return end
    local cb = win.CloseButton
    if type(cb) ~= "table" then return end
    local fn = cb.Func
    if type(fn) ~= "function" then return end
    fn(cb)
    closed = true
  end)
  return closed
end

M.closeModesWindow = closeModesWindow

function M.swapPage(G, target)
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
  end
  if type(G) ~= "table" then return "nog" end
  local gm = gmList(G)
  if type(gm) ~= "table" then return "nogm" end
  target = tostring(target or "")
  if target ~= "pibe" and target ~= "quark" and target ~= "baros" then
    return "badview"
  end
  if target == "pibe" and not M.isPibe() then return "off" end
  if target == "quark" and not M.isQuark() then return "off" end
  local natives, pibe, quark, navs = splitLive(gm)

  S.stash = S.stash or {}
  local osKey = tostring(G.OS_Current)
  local cur = S.stash[osKey]
  if type(cur) ~= "table" then cur = {} S.stash[osKey] = cur end
  if #natives > 0 then cur.natives = natives end
  if #pibe > 0 then cur.pibe = pibe end
  if #quark > 0 then cur.quark = quark end
  local st = cur
  local set = nil
  if target == "pibe" then
    set = st.pibe
    if type(set) ~= "table" or #set == 0 then set = pibe end
  elseif target == "quark" then
    set = st.quark
    if type(set) ~= "table" or #set == 0 then set = quark end
  else

    set = st.natives
    if type(set) ~= "table" or #set == 0 then set = natives end
  end
  if type(set) ~= "table" or #set == 0 then
    local back = (S.stash[osKey] or {}).natives
    if type(back) ~= "table" or #back == 0 then return "emptyset" end
    set = back
    target = "baros"
  end

  local keepNavs = {}
  if target == "baros" then
    for _, e in ipairs(navs) do
      local f = entryFlag(e)
      if f == "nav-pibe" and M.isPibe() then keepNavs[#keepNavs + 1] = e end
      if f == "nav-quark" and M.isQuark() then keepNavs[#keepNavs + 1] = e end
    end
  else
    local v = { M.NAV_NAMES.back }
    v.__pqNav = "back"
    keepNavs[1] = v
  end

  pcall(function()
    for i = #gm, 1, -1 do table.remove(gm, i) end
    for _, e in ipairs(set) do gm[#gm + 1] = e end
    for _, e in ipairs(keepNavs) do gm[#gm + 1] = e end
  end)

  if target == "baros" then
    pcall(function() M.ensureNavModes(G) end)
  end
  vlog("swap -> " .. target .. " modos=" .. #set .. " nav=" .. #keepNavs)
  local closed = closeModesWindow(G)
  vlog("swap close=" .. tostring(closed))

  if closed and M.AUTO_REOPEN then
    pcall(function()
      local fn = G.Loadgame
      if type(fn) ~= "function" then
        vlog("swap reopen without Loadgame")
        return
      end
      local function reopen()
        local ok = false
        pcall(function()
          fn()
          ok = true
        end)
        vlog("swap reopen loadgame=" .. tostring(ok))
      end
      if timer and timer.performWithDelay then
        timer.performWithDelay(500, reopen)
      else
        reopen()
      end
    end)
  end
  return target
end

function M.pruneMainPages(G)
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
  end
  if type(G) ~= "table" then return 0 end
  local osTable = nil
  pcall(function() osTable = G.OS_Table end)
  if type(osTable) ~= "table" then return 0 end
  local pruned = 0
  pcall(function()
    S.stash = S.stash or {}
    for pid, osDef in pairs(osTable) do
      if type(osDef) == "table" and type(osDef.GameModes) == "table" then
        local gm = osDef.GameModes
        local natives, pibe, quark, navs = splitLive(gm)
        if #natives > 0 and (#pibe > 0 or #quark > 0) then
          S.stash[tostring(pid)] = { natives = natives, pibe = pibe, quark = quark }
          local keepNavs = {}
          for _, e in ipairs(navs) do
            local f = entryFlag(e)
            if f == "nav-pibe" and M.isPibe() then keepNavs[#keepNavs + 1] = e end
            if f == "nav-quark" and M.isQuark() then keepNavs[#keepNavs + 1] = e end
          end
          for i = #gm, 1, -1 do table.remove(gm, i) end
          for _, e in ipairs(natives) do gm[#gm + 1] = e end
          for _, e in ipairs(keepNavs) do gm[#gm + 1] = e end
          pruned = pruned + 1
        end
      end
    end
  end)
  if pruned > 0 then vlog("prune pages=" .. pruned) end
  return pruned
end

local function healSwap(G)
  pcall(function()
    if type(G) ~= "table" then return end
    local gm = gmList(G)
    if type(gm) ~= "table" then return end
    local natives, pibe, quark, navs = splitLive(gm)
    if #natives == 0 and #pibe == 0 and #quark == 0 then
      local osKey = tostring(G.OS_Current)
      local st = S.stash and S.stash[osKey]
      local back = type(st) == "table" and st.natives or nil
      if type(back) == "table" and #back > 0 then
        for i = #gm, 1, -1 do table.remove(gm, i) end
        for _, e in ipairs(back) do gm[#gm + 1] = e end
        for _, e in ipairs(navs) do
          local f = entryFlag(e)
          if f == "nav-pibe" and M.isPibe() then gm[#gm + 1] = e end
          if f == "nav-quark" and M.isQuark() then gm[#gm + 1] = e end
        end
        vlog("healswap restored natives")
      end
    end
  end)
end

M.healSwap = healSwap

local function resolveNavName(btn)
  local nm = nil
  pcall(function()
    nm = M.modeButtonName(btn, { pibe = true, quark = true, back = true })
  end)
  if type(nm) == "string" then
    local l = nm:lower()
    if l == "pibe" or l == "quark" or l == "back" then return l end
  end
  pcall(function()
    local t = btn.IconText and btn.IconText.text
    if type(t) == "string" then
      local l = t:lower()
      if l == "pibe" or l == "quark" or l == "back" then
        nm = l
      end
    end
  end)
  if nm == "pibe" or nm == "quark" or nm == "back" then return nm end
  return nil
end

M.resolveNavName = resolveNavName

local function wrapSwap(btn, nav)
  if type(btn) ~= "table" then return end
  if btn.__pqSwapWrap then return end
  local targets = {}
  pcall(function()
    if type(btn.Hover) == "table" and type(btn.Hover.Func) == "function" then
      targets[#targets + 1] = { t = btn.Hover, k = "Func" }
    end
  end)
  pcall(function()
    if type(btn.Func) == "function" then
      targets[#targets + 1] = { t = btn, k = "Func" }
    end
  end)
  if #targets == 0 then return end
  for _, w in ipairs(targets) do
    w.t[w.k] = function(...)
      local G = nil
      pcall(function() G = getG() end)
      if type(G) ~= "table" then return end
      local gm = gmList(G)
      if type(gm) ~= "table" then return end
      local page = livePage(gm)
      local target = nav
      if nav == "back" or page == nav then target = "baros" end
      local res = "err"
      pcall(function() res = M.swapPage(G, target) end)
      vlog("tap " .. nav .. " page=" .. page .. " -> " .. tostring(res))
      return
    end
  end
  btn.__pqSwapWrap = true
end

M.wrapSwap = wrapSwap

function M.ensureSwapWrap(G)
  if type(G) ~= "table" then
    pcall(function() G = getG() end)
  end
  if type(G) ~= "table" then return "nog" end
  local done = 0
  pcall(function()
    local pibeOk, quarkOk = M.isPibe(), M.isQuark()
    local function handle(groups)
      local n = 0
      if type(groups) ~= "table" then return n end
      for _, g in pairs(groups) do
        if type(g) == "table" and type(g.btns) == "table" then
          for _, b in ipairs(g.btns) do
            local nav = resolveNavName(b)
            if nav ~= nil and not b.__pqSwapWrap then
              if (nav == "pibe" and pibeOk)
                or (nav == "quark" and quarkOk)
                or (nav == "back" and (pibeOk or quarkOk)) then
                wrapSwap(b, nav)
                if b.__pqSwapWrap then n = n + 1 end
              end
            end
          end
        end
      end
      return n
    end
    done = done + handle(scanModeGrid())
    if done == 0 then
      done = done + handle(scanModeGridLoose())
    end
  end)
  return done
end

local function onFrame()
  S.frame = (S.frame or 0) + 1
  if S.frame % 30 == 0 then
    pcall(function()
      local G = getG()
      if type(G) ~= "table" then return end
      M.ensureSwapWrap(G)

      M.pruneMainPages(G)
    end)
  end
  if S.frame % 90 ~= 0 then return end
  if S.frame % 1800 == 0 then
    vlog("tick frame=" .. S.frame)
  end
  pcall(function()
    local G = getG()
    if type(G) == "table" then healSwap(G) end
  end)
  pcall(tryWrapInet)
  pcall(tryWrapSearch)
  pcall(tryWrapDownloads)
  pcall(function()
    if S.siteTable then
      local ip, iq = M.isPibe(), M.isQuark()
      if S.lastPibe ~= ip or S.lastQuark ~= iq or S.sitesDirty then
        S.siteTable[M.PIBE_SITE] = buildPibeSite(ip, S.progressillaTemplate)
        S.siteTable[M.QUARK_SITE] = buildQuarkSite(iq, S.progressillaTemplate)
        S.lastPibe, S.lastQuark, S.sitesDirty = ip, iq, false
      end
    end
  end)
  local G = nil
  pcall(function() G = getG() end)
  if type(G) ~= "table" then return end
  if M.isPibe() then
    pcall(function() M.ensureGameModes(G) end)
    pcall(function() M.ensureCorrectors(G) end)
  end
  if M.isQuark() then
    pcall(function() M.ensureQuarkModes(G) end)
  end
  pcall(function() M.ensureNavModes(G) end)
  pcall(function() M.pruneMainPages(G) end)
end

function M.install()
  pcall(function()
    if M.VIEW_DEBUG ~= true then return end
    local f = io.open(M.VIEW_LOG, "w")
    if f then f:write("pqview start " .. tostring(M.id) .. "\n") f:close() end
  end)
  pcall(function()
    local rp = saveRecord(M.PIBE_SAVE)
    if rp ~= nil then
      _G.__PIBE_INSTALLED = rp
    else
      local G = getG()
      if type(G) == "table" and type(G.INI) == "table" and G.INI.PibeInstalled == true then
        _G.__PIBE_INSTALLED = true
      else
        _G.__PIBE_INSTALLED = false
      end
    end
  end)
  pcall(function()
    local rq = saveRecord(M.QUARK_SAVE)
    if rq ~= nil then
      _G.__QUARK_INSTALLED = rq
    else
      local G = getG()
      if type(G) == "table" and type(G.INI) == "table" and G.INI.QuarkInstalled == true then
        _G.__QUARK_INSTALLED = true
      else
        _G.__QUARK_INSTALLED = false
      end
    end
  end)
  pcall(tryWrapInet)
  pcall(tryWrapSearch)
  pcall(tryWrapDownloads)
  pcall(function()
    local G = getG()
    if type(G) == "table" and type(G.INI) == "table" then
      local rp, rq = nil, nil
      pcall(function() rp = saveRecord(M.PIBE_SAVE) end)
      pcall(function() rq = saveRecord(M.QUARK_SAVE) end)
      if rp == false then G.INI.PibeInstalled = nil end
      if rq == false then G.INI.QuarkInstalled = nil end
    end
  end)
  pcall(function()
    local G = getG()
    if type(G) == "table" then
      if M.isPibe() then
        M.ensureGameModes(G)
        M.ensureCorrectors(G)
      end
      if M.isQuark() then
        M.ensureQuarkModes(G)
      end
      pcall(function() M.ensureNavModes(G) end)

      pcall(function() M.removeNavEntries(G, "back") end)

      pcall(function() M.pruneMainPages(G) end)
    end
  end)
  pcall(function()
    if Runtime and Runtime.addEventListener and not S.hooked then
      Runtime:addEventListener("enterFrame", onFrame)
      S.hooked = true
      vlog("install ok, onFrame registered")
    elseif S.hooked then
      vlog("install ok (onFrame already registered)")
    else
      vlog("install WITHOUT Runtime/addEventListener!")
    end
  end)
  pcall(function() _G.__PIBE_QUARK = M end)
  return true
end

function M.selftest()
  local svViewDebug = M.VIEW_DEBUG
  M.VIEW_DEBUG = false
  assert(M.normalizeUrl("pb://ppp.pibe") == "ppp.pibe", "pb prefix pibe")
  assert(M.normalizeUrl("PPP.PIBE") == "ppp.pibe", "case pibe")
  assert(M.normalizeUrl("pb://ppp.quark") == "ppp.quark", "pb prefix quark")
  assert(M.normalizeUrl("  ppp.pibe/download  ") == "ppp.pibe/download", "trim download")

  local G = {
    OS_Table = {
      BAR11 = { BAR = true, GameModes = { { "RelaxShine" }, { "Shine" } } },
      P95 = { PC = true, GameModes = { { "Relax" }, { "Normal" } } },
    },
    Mode = {
      Normal = { REDCorrector = 20, PinkChance = 100, SpeedMultiplier = 1 },
      Relax = { REDCorrector = 10, PinkRate = 50 },
    },
    Duty = { GameModesPurchased = {} },
    INI = {},
  }
  _G.__PIBE_INSTALLED = nil
  _G.__QUARK_INSTALLED = nil

  assert(M.isPibe() == false, "pibe off initially")
  local n0 = M.ensureGameModes(G)
  assert(n0 == 0, "no pibe no patch")
  local c0 = M.ensureCorrectors(G)
  assert(c0 == 0, "no pibe no correctors")

  _G.__PIBE_INSTALLED = true
  local n1 = M.ensureGameModes(G)
  assert(n1 == 3, "pibe adds 3 to BAR, got " .. tostring(n1))
  assert(hasModeEntry(G.OS_Table.BAR11.GameModes, "Relax"), "BAR Relax")
  assert(hasModeEntry(G.OS_Table.BAR11.GameModes, "Normal"), "BAR Normal")
  assert(hasModeEntry(G.OS_Table.BAR11.GameModes, "Hardcore"), "BAR Hardcore")
  assert(#G.OS_Table.P95.GameModes == 2, "PC untouched")

  local redBefore = G.Mode.Normal.REDCorrector
  local pinkBefore = G.Mode.Normal.PinkChance
  local c1 = M.ensureCorrectors(G)
  assert(c1 >= 2, "correctors patched")
  assert(G.Mode.Normal.REDCorrector == redBefore * 1.05, "red +5%")
  assert(G.Mode.Normal.PinkChance == pinkBefore * 1.03, "pink +3%")
  local c2 = M.ensureCorrectors(G)
  assert(G.Mode.Normal.REDCorrector == redBefore * 1.05, "red idempotent")
  assert(c2 == 0 or G.Mode.Normal.REDCorrector == redBefore * 1.05, "no double")

  local q0 = M.ensureQuarkModes(G)
  assert(q0 == 0, "no quark no patch")
  _G.__QUARK_INSTALLED = true
  local q1 = M.ensureQuarkModes(G)
  assert(q1 >= 3, "quark adds modes")
  local foundSweep, foundDef, foundStein = false, false, false
  for _, e in ipairs(G.OS_Table.BAR11.GameModes) do
    if type(e[1]) == "string" then
      local s = e[1]:lower()
      if s == "minesweeper" then foundSweep = true end
      if s == "defender" then foundDef = true end
      if s:find("stein", 1, true) then foundStein = true end
    end
  end
  assert(foundSweep, "sweeper unlocked")
  assert(foundDef, "defender unlocked")
  assert(foundStein, "stein unlocked")
  local hasG3D = false
  for _, v in ipairs(G.Duty.GameModesPurchased) do
    if v == "G3D" then hasG3D = true end
  end
  assert(hasG3D, "G3D purchased")

  local siteP = buildPibeSite(false)
  assert(type(siteP) == "table" and #siteP >= 5, "pibe site built")
  local hasDl = false
  for _, el in ipairs(siteP) do
    if type(el) == "table" and type(el[2]) == "table" and el[2].URL == "ppp.pibe/download" then
      hasDl = true
    end
  end
  assert(hasDl, "pibe download link")

  local siteQ = buildQuarkSite(false)
  assert(type(siteQ) == "table" and #siteQ >= 5, "quark site built")
  local hasQ = false
  for _, el in ipairs(siteQ) do
    if type(el) == "table" and type(el[2]) == "table" and el[2].URL == "ppp.quark/download" then
      hasQ = true
    end
  end
  assert(hasQ, "quark download link")

  assert(#M.PIBE_KEYWORDS == 5, "pibe 5 keywords")
  assert(#M.QUARK_KEYWORDS == 5, "quark 5 keywords")
  for _, kw in ipairs({ "pibe", "wine", "emulator", "baros", "computer" }) do
    assert(M.queryMatches(kw, M.PIBE_KEYWORDS), "pibe kw " .. kw)
  end
  for _, kw in ipairs({ "quark", "proton", "sweeper", "defender", "progresstein3d" }) do
    assert(M.queryMatches(kw, M.QUARK_KEYWORDS), "quark kw " .. kw)
  end
  assert(M.queryMatches("WINE", M.PIBE_KEYWORDS), "case wine")
  assert(M.queryMatches("pb://ppp.pibe", M.PIBE_KEYWORDS) or M.normalizeQuery("pb://ppp.pibe") == "pibe", "pb query norm")
  assert(not M.queryMatches("xyzqwerty", M.PIBE_KEYWORDS), "no false positive pibe")
  assert(not M.queryMatches("xyzqwerty", M.QUARK_KEYWORDS), "no false positive quark")
  local metaP = siteP[2]
  assert(metaP and metaP[1] == "Meta" and #metaP[2] == 5, "pibe meta 5")
  local metaQ = siteQ[2]
  assert(metaQ and metaQ[1] == "Meta" and #metaQ[2] == 5, "quark meta 5")

  local fakeTmpl = {
    { "Title", { [1] = "Progressila premium browser", [2] = 4 } },
    { "Meta", { [1] = "browser", [2] = "progressilla" } },
    { "IMG", { file = "pslogo1", X = 2, Y = 5, Width = 2, Height = 2 }, 1 },
    { "TXT", { text = "Progressilla 2.0", X = 6.25, Y = 4.25, size = 36 }, 2 },
    { "TXT", { text = "Your favorite premium browser", X = 6.25, Y = 5, size = 20 }, 2 },
    { "TXT", { text = "- Secure browsing", X = 6.25, Y = 6, size = 16 }, 2 },
    { "TXT", { text = "- Fast page rendering", X = 6.25, Y = 7, size = 16 }, 2 },
    { "TXT", { text = "- Download list", X = 6.25, Y = 8, size = 16 }, 2 },
    { "TXT", { text = "- History", X = 6.25, Y = 9, size = 16 }, 2 },
    { "TXT", { text = "- Tabs", X = 6.25, Y = 10, size = 16 }, 2 },
    { "TXT", { text = "- Secure browsing", X = 6.25, Y = 11, size = 16 }, 2 },
    { "PRICETAG", { PriceCore = 512, FuncD = "BuyBrowser", X = 3, Y = 8, Align = "left" }, 1 },
    { "PRICETAG", { PriceCore = 512, FuncD = "BuyBrowser", X = 3, Y = 9.5, Align = "left" }, 2 },
    { "PRICETAG", { PriceCore = 512, FuncD = "BuyBrowser", X = 3, Y = 10, Align = "left" }, 2 },
    { "IMG", { file = "bplaceholder", X = 5, Y = 9.5, Width = 8, Height = 2 }, 2 },
    { "IMG", { file = "badgeps", XP = 0.5, Y = 11, Width = 2, Height = 1, URL = "ftp.ps1" }, 1 },
    { "TXT", { text = "(pb)2000 - Progressilla Org", X = 5, Y = 15, size = 16 }, 2 },
    { "BACK", { Color = { [1] = 255, [2] = 255, [3] = 255 } }, 3 },
  }
  local tp = M._transform(fakeTmpl, M._pibeOpts, false)
  assert(tp[1][2][1] == "Pibe", "tmpl title pibe")
  assert(tp[2][2][1] == "pibe" and #tp[2][2] == 5, "tmpl meta pibe")
  local gotHead, gotDl, gotMirror, gotFoot = false, false, false, false
  local bulletsSeen = {}
  local dlY, mirY, mirCount = nil, nil, 0
  for _, el in ipairs(tp) do
    if type(el) == "table" and type(el[2]) == "table" then
      if el[1] == "TXT" and el[2].text == "Pibe" then gotHead = true end
      if el[1] == "TXT" and el[2].URL == "ppp.pibe/download" and el[2].text == "Download Pibe" then gotDl = true dlY = el[2].Y end
      if el[1] == "TXT" and el[2].text == "Mirror" and el[2].URL == "ppp.pibe/download" then gotMirror = true mirY = el[2].Y mirCount = mirCount + 1 end

      if el[1] == "TXT" and el[2].text == "(pb) Pibe project" then gotFoot = true end
      if el[1] == "TXT" and type(el[2].text) == "string" and el[2].text:sub(1, 2) == "- " then
        bulletsSeen[#bulletsSeen + 1] = el[2].text
      end
      if el[1] == "IMG" and type(el[2].file) == "string" and el[2].file:lower():find("placeholder", 1, true) then
        error("placeholder not removed", 0)
      end
      if type(el[2].text) == "string" then
        assert(not el[2].text:find("Wine", 1, true), "no wine")
        assert(not el[2].text:find("%+5%%"), "no percent")
        assert(not el[2].text:find("2%.0"), "no 2.0")
        assert(not el[2].text:find("%(instant%)"), "no instant")
        assert(not el[2].text:find("Instant download", 1, true), "no instant bullet")
      end
      assert(el[1] ~= "PRICETAG", "no price left")
    end
  end
  assert(gotHead and gotDl and gotMirror and gotFoot, "tmpl pibe full")
  assert(mirCount == 1, "single mirror")
  assert(dlY ~= nil and mirY == dlY + 1, "mirror below download")
  local dlIdx, mirIdx, footIdx, footN, footX, footY = nil, nil, nil, 0, nil, nil
  for i, el in ipairs(tp) do
    if type(el) == "table" and type(el[2]) == "table" then
      if el[1] == "TXT" and el[2].URL == "ppp.pibe/download" and el[2].text == "Download Pibe" and not dlIdx then dlIdx = i end
      if el[1] == "TXT" and el[2].text == "Mirror" and not mirIdx then mirIdx = i end
      if el[1] == "TXT" and el[2].text == "(pb) Pibe project" then
        footN = footN + 1
        if not footIdx then footIdx = i footX = el[2].X footY = el[2].Y end
      end
    end
  end
  assert(footN == 1, "footer unico, achou " .. tostring(footN))
  assert(mirIdx == dlIdx + 1, "mirror grudado")
  assert(footIdx == mirIdx + 1, "footer grudado")
  assert(footX == 5, "footer alinhado")
  assert(footY == mirY + 1, "footer em fluxo")
  assert(#bulletsSeen == 6, "6 bullets mapped")
  assert(bulletsSeen[1] == "- Run PC modes in BarOS", "bullet1 in")
  assert(bulletsSeen[5] == "- Run PC modes in BarOS", "same eras")
  assert(bulletsSeen[6] == "- Relax, Normal, Hardcore", "cycle 6")
  assert(bulletsSeen[2] == "- Relax, Normal, Hardcore", "bullet2")
  local hasIMG = false
  for _, el in ipairs(tp) do if el[1] == "IMG" then hasIMG = true end end
  assert(hasIMG, "tmpl keeps images")
  local tpI = M._transform(fakeTmpl, M._pibeOpts, true)
  local unBtn, unInst = false, false
  for _, el in ipairs(tpI) do
    if el[1] == "TXT" and el[2].URL == "ppp.pibe/uninstall" then unBtn = true end
    if el[1] == "TXT" and type(el[2].text) == "string" and el[2].text:find("INSTALLED") then unInst = true end
  end
  assert(unBtn, "tmpl uninstall button")
  assert(not unInst, "no INSTALLED tagline")
  local tq = M._transform(fakeTmpl, M._quarkOpts, false)
  assert(tq[1][2][1] == "Quark", "tmpl title quark")
  local qDl, qB1, qTag = false, nil, false
  for _, el in ipairs(tq) do
    if el[1] == "TXT" and el[2].URL == "ppp.quark/download" then qDl = true end
    if el[1] == "TXT" and type(el[2].text) == "string" and el[2].text:sub(1, 2) == "- " and not qB1 then
      qB1 = el[2].text
    end
    if el[1] == "TXT" and el[2].text == "Your favorite PC games emulator" then qTag = true end
    if type(el[2]) == "table" and type(el[2].text) == "string" then
      assert(not el[2].text:find("Proton", 1, true), "no proton")
      assert(not el[2].text:find("Unlock", 1, true), "no unlock")
    end
  end
  assert(qDl, "tmpl quark download")
  assert(qB1 == "- Run PC modes in BarOS", "quark bullet1 in")
  assert(qTag, "quark games tagline")

  _G.G = { OS_Table = { P95 = { PC = true, GameModes = { { "Normal" } } } }, OS_Current = "P95" }
  assert(M.isBarOSNow() == false, "PC is not BarOS")
  local tpPC = M._transform(fakeTmpl, M._pibeOpts, false, false)
  for _, el in ipairs(tpPC) do
    if type(el) == "table" and type(el[2]) == "table" then
      assert(el[2].URL ~= "ppp.pibe/download" and el[2].URL ~= "ftp.pibe", "no download outside BarOS")
      if type(el[2].text) == "string" then
        assert(not el[2].text:find("not available", 1, true) and not el[2].text:find("Not available", 1, true), "no message")
      end
    end
  end
  _G.G = { OS_Table = { BAR11 = { BAR = true, GameModes = { { "Shine" } } } }, OS_Current = "BAR11" }
  assert(M.isBarOSNow() == true, "BAR e BarOS")
  _G.G = nil

  local G2 = {
    OS_Table = {
      BAR11 = { BAR = true, GameModes = { { "RelaxShine" }, { "Shine" } } },
    },
    Mode = {
      Normal = { REDCorrector = 20, PinkChance = 100 },
    },
    Duty = {
      GameModesPurchased = {},
      ProgressnetHistory = { "ppp.pibe", "ppp.pibe/download", "ppp.searchoo" },
      ProgressnetHistoryPos = 3,
    },
    INI = {},
  }
  _G.G = G2
  _G.__PIBE_INSTALLED = true
  _G.__QUARK_INSTALLED = true
  assert(M.ensureGameModes(G2) == 3, "g2 pibe modes")
  assert(M.ensureCorrectors(G2) >= 2, "g2 correctors")
  assert(M.ensureQuarkModes(G2) >= 3, "g2 quark modes")
  assert(G2.Mode.Normal.REDCorrector == 21, "g2 red applied")
  assert(#G2.OS_Table.BAR11.GameModes == 8, "g2 2+3+3 modes")
  assert(M.uninstallPibe() == true, "uninstall pibe")
  assert(M.isPibe() == false, "pibe fora")
  assert(G2.Mode.Normal.REDCorrector == 20, "red reverted")
  assert(G2.Mode.Normal.PinkChance == 100, "pink revertido")
  assert(#G2.OS_Table.BAR11.GameModes == 5, "pibe modes removed, quark stays")
  assert(G2.INI.PibeInstalled == nil, "ini limpo")
  for _, u in ipairs(G2.Duty.ProgressnetHistory) do
    assert(u ~= "ppp.pibe/download", "historico limpo pibe")
  end
  assert(M.uninstallQuark() == true, "uninstall quark")
  assert(M.isQuark() == false, "quark fora")
  assert(#G2.OS_Table.BAR11.GameModes == 2, "tudo revertido")
  local stillG3D = false
  for _, v in ipairs(G2.Duty.GameModesPurchased) do if v == "G3D" then stillG3D = true end end
  assert(not stillG3D, "G3D removido")
  for _, u in ipairs(G2.Duty.ProgressnetHistory) do
    assert(u ~= "ppp.pibe/download", "historico limpo final")
  end
  local sU = buildPibeSite(false)
  local hasUn = false
  for _, el in ipairs(sU) do
    if type(el) == "table" and type(el[2]) == "table" and el[2].URL == "ppp.pibe/uninstall" then hasUn = true end
  end
  assert(not hasUn, "no uninstall when not installed")
  _G.G = nil

  local G3 = {
    OS_Table = {
      BAR11 = { BAR = true, GameModes = { { "RelaxShine" }, { "Shine" } } },
    },
    Mode = {
      Normal = { REDCorrector = 20, PinkChance = 100 },
    },
    Duty = { GameModesPurchased = {} },
    INI = {},
  }
  _G.G = G3
  _G.__PIBE_INSTALLED = nil
  _G.__QUARK_INSTALLED = nil
  S.quarkPids = {}
  assert(M.install() == true, "clean boot installs loader")
  assert(M.isPibe() == false, "boot does not install pibe alone")
  assert(M.isQuark() == false, "boot does not install quark alone")
  assert(#G3.OS_Table.BAR11.GameModes == 2, "boot does not touch gamemodes")
  assert(G3.Mode.Normal.REDCorrector == 20, "boot does not touch correctors")
  assert(G3.Duty.GameModesPurchased[1] == nil, "boot purchases nothing")
  _G.G = nil
  S.quarkPids = {}

  local G4 = {
    OS_Table = {
      BAR11 = { BAR = true, GameModes = { { "RelaxShine" }, { "Shine" } } },
    },
    Mode = { Normal = { REDCorrector = 20 } },
    Duty = { GameModesPurchased = {} },
    INI = { PibeInstalled = true },
  }
  _G.G = G4
  _G.__PIBE_INSTALLED = nil
  _G.__QUARK_INSTALLED = nil
  pcall(function()
    local f = io.open(M.PIBE_SAVE, "w")
    if f then f:write("0") f:close() end
  end)
  assert(M.isPibe() == false, "opt-out vence INI velho")
  assert(M.install() == true, "boot com opt-out ok")
  assert(M.isPibe() == false, "opt-out boot installs nothing")
  assert(#G4.OS_Table.BAR11.GameModes == 2, "opt-out does not touch gamemodes")
  _G.__PIBE_INSTALLED = true
  assert(M.isPibe() == true, "flag de sessao ainda vale")
  assert(M.install() == true, "reload resync ok")
  assert(M.isPibe() == false, "resync limpa flag velha com opt-out")
  assert(G4.INI.PibeInstalled == nil, "resync limpa INI morto")
  pcall(function() os.remove(M.PIBE_SAVE) end)
  G4.INI.PibeInstalled = true
  assert(M.isPibe() == true, "no file, legit INI restores")
  G4.INI.PibeInstalled = nil
  pcall(function() os.remove(M.PIBE_SAVE) end)
  assert(M.isPibe() == false, "no record, default off")
  _G.G = nil
  S.quarkPids = {}

  do
    local svDisplay, svG = display, _G.G
    local function fakeGroup()
      local g = { numChildren = 0 }
      function g:insert(o)
        self.numChildren = self.numChildren + 1
        self[self.numChildren] = o
        if type(o) == "table" then o.parent = self end
      end
      return g
    end
    local stage = fakeGroup()
    display = { getCurrentStage = function() return stage end }
    local tapped, closedWins, reopened = {}, {}, {}
    local function fakeBtn(name, x, y)
      local nm = name
      return { ID = "custom2", IconText = { text = name }, x = x, y = y,
        isVisible = true, __name = name,
        Func = function() tapped[#tapped + 1] = nm return nm end }
    end
    local GV = {
      OS_Current = "BAR11",
      OS_Table = { BAR11 = { BAR = true, GameModes = {
        { "Arcade" }, { "Relax" }, { "Normal" },
        { "minesweeper" }, { "defender" },
      } } },
      UI = {},
    }
    local gm = GV.OS_Table.BAR11.GameModes
    gm[3].__pibeAdded = true
    gm[4].__quarkAdded = true
    gm[5].__quarkAdded = true
    GV.UI.GameModesWindow = { CloseButton = { Func = function(self)
      closedWins[#closedWins + 1] = self
    end } }
    GV.Loadgame = function()
      reopened[#reopened + 1] = true
    end
    local cont = fakeGroup()
    stage:insert(cont)
    local btns = {
      fakeBtn("Arcade", 0, 0), fakeBtn("Relax", 100, 0),
      fakeBtn("Normal", 200, 0), fakeBtn("minesweeper", 0, 60),
      fakeBtn("Defender", 100, 60),
    }
    for _, b in ipairs(btns) do cont:insert(b) end
    _G.G = GV
    _G.__PIBE_INSTALLED = true
    _G.__QUARK_INSTALLED = true
    assert(M.ensureNavModes(GV) == 2, "nav registrado")
    assert(not hasModeEntry(gm, "Back"), "no back")
    assert(M.classByName(gm, "Pibe") == "nav-pibe", "classe nav")

    local bPibe = fakeBtn("Pibe", 200, 60)
    local bQuark = fakeBtn("Quark", 0, 120)
    cont:insert(bPibe)
    cont:insert(bQuark)
    assert(M.ensureSwapWrap(GV) == 2, "2 navs wrapped")
    assert(bPibe.__pqSwapWrap == true, "pibe wrapped")
    assert(M.resolveNavName(bPibe) == "pibe", "resolve upvalue")
    local bLbl = { ID = "outro", IconText = { text = "Quark" },
      Func = function() end }
    assert(M.resolveNavName(bLbl) == "quark", "resolve rotulo")
    assert(M.resolveNavName(btns[1]) == nil, "native is not nav")
    assert(M.livePage(gm) == "baros", "baros page")

    local function rebuildCont()
      local c = fakeGroup()
      stage:insert(c)
      local bs = {}
      for _, e in ipairs(gm) do
        if type(e) == "table" and type(e[1]) == "string" then
          local b = fakeBtn(e[1], 0, 0)
          c:insert(b)
          bs[#bs + 1] = b
        end
      end
      return c, bs
    end
    local function findBtn(bs, nm)
      for _, b in ipairs(bs) do
        if b.__name and b.__name:lower() == nm then return b end
      end
      return nil
    end

    tapped = {}
    bPibe.Func()
    assert(#tapped == 0, "nav does not start mode")
    assert(#gm == 2, "swapped list")
    assert(gm[1][1] == "Normal", "only pibe")
    assert(gm[2][1] == "Back" and gm[2].__pqNav == "back", "fresh back")
    assert(#closedWins == 1, "closed screen")
    assert(#reopened == 1, "reopened alone via loadgame")
    assert(M.livePage(gm) == "pibe", "pibe page")

    local cont2, bs2 = rebuildCont()
    assert(M.ensureSwapWrap(GV) == 1, "back wrapped")
    local bBack = findBtn(bs2, "back")
    assert(bBack ~= nil and bBack.__pqSwapWrap == true, "back caught")

    local gmRef = gm
    tapped = {}
    bBack.Func()
    assert(#tapped == 0, "back does not start mode")
    assert(gm == gmRef, "mesma tabela")
    assert(#gm == 4, "principal limpa")
    assert(gm[1][1] == "Arcade" and gm[2][1] == "Relax", "natives")
    assert(gm[3][1] == "Pibe" and gm[4][1] == "Quark", "navs at end")
    assert(M.livePage(gm) == "baros", "baros page again")

    local cont3, bs3 = rebuildCont()
    assert(M.ensureSwapWrap(GV) >= 1, "quark re-wrapped")
    local bQuark2 = findBtn(bs3, "quark")
    assert(bQuark2 ~= nil, "quark reopened")
    bQuark2.Func()
    assert(#gm == 3, "quark list")
    assert(gm[1][1] == "minesweeper" and gm[2][1] == "defender", "so quark")
    assert(gm[3][1] == "Back", "back on quark")
    assert(M.livePage(gm) == "quark", "quark page")

    local cont4, bs4 = rebuildCont()
    assert(M.ensureSwapWrap(GV) >= 1, "back re-wrapped")
    local bBack2 = findBtn(bs4, "back")
    assert(bBack2 ~= nil, "back reopened")
    assert(M.resolveNavName({ IconText = { text = "Back" },
      Func = function() end }) == "back", "back in english")
    bBack2.Func()
    assert(#gm == 4 and gm[1][1] == "Arcade", "voltou")
    assert(M.livePage(gm) == "baros", "baros final")

    _G.__PIBE_INSTALLED = nil
    _G.__QUARK_INSTALLED = nil
    local n0 = #gm
    assert(M.swapPage(GV, "quark") == "off", "no install off")
    assert(#gm == n0, "list intact")
    _G.G = nil
    assert(M.swapPage(nil, "pibe") == "nog", "no G nog")
    _G.__PIBE_INSTALLED = true
    _G.__QUARK_INSTALLED = true

    assert(M.closeModesWindow({}) == false, "no window false")
    assert(M.closeModesWindow(GV) == true, "fecha ok")

    for i = #gm, 1, -1 do table.remove(gm, i) end
    gm[#gm + 1] = { "Quark" }
    gm[1].__pqNav = "quark"
    M.healSwap(GV)
    assert(#gm == 3, "heal restored")
    assert(gm[1][1] == "Arcade" and gm[2][1] == "Relax", "natives on heal")
    assert(gm[3][1] == "Quark", "nav kept on heal")

    local GL = { OS_Table = { X = { GameModes = {
      { "A" }, { "Pibe" }, { "Back" },
    } } } }
    GL.OS_Table.X.GameModes[2].__pqNav = "pibe"
    GL.OS_Table.X.GameModes[3].__pqNav = "back"
    assert(M.removeNavEntries(GL, "pibe") == 2, "tira pibe+back orfao")
    assert(not hasModeEntry(GL.OS_Table.X.GameModes, "Back"), "back pruned")
    assert(M.removeNavEntries(GL, "all") == 0, "nada restante")

    local GP = {
      OS_Current = "BAR11",
      OS_Table = { BAR11 = { BAR = true, GameModes = {
        { "Arcade" }, { "Normal" }, { "defender" }, { "Pibe" }, { "Quark" },
      } } },
    }
    local gp = GP.OS_Table.BAR11.GameModes
    gp[2].__pibeAdded = true
    gp[3].__quarkAdded = true
    gp[4].__pqNav = "pibe"
    gp[5].__pqNav = "quark"
    _G.__PIBE_INSTALLED = true
    _G.__QUARK_INSTALLED = true
    assert(M.pruneMainPages(GP) == 1, "podou 1")
    assert(#gp == 3, "only natives+navs")
    assert(gp[1][1] == "Arcade" and gp[2][1] == "Pibe"
      and gp[3][1] == "Quark", "pruned order")
    assert(M.swapPage(GP, "pibe") == "pibe", "pibe do stash")
    assert(#gp == 2 and gp[1][1] == "Normal", "pibe page")
    assert(gp[2][1] == "Back" and gp[2].__pqNav == "back", "fresh back")
    assert(M.pruneMainPages(GP) == 0, "open page untouched")

    local nq0 = #gp
    M.ensureGameModes(GP)
    M.ensureQuarkModes(GP)
    M.ensureNavModes(GP)
    assert(#gp == nq0, "subpage intact")
    assert(not hasModeEntry(gp, "minesweeper")
      and not hasModeEntry(gp, "defender"), "no mixing")

    assert(M.swapPage(GP, "baros") == "baros", "volta")
    local GQ = {
      OS_Current = "BAR11",
      OS_Table = { BAR11 = { BAR = true, GameModes = { { "Arcade" } } } },
    }
    _G.__PIBE_INSTALLED = true
    _G.__QUARK_INSTALLED = true
    assert(M.ensureGameModes(GQ) == 3, "ensure completa na principal")
    local nq = M.ensureQuarkModes(GQ)
    assert(nq >= 3, "quark completa na principal")
    assert(hasModeEntry(GQ.OS_Table.BAR11.GameModes, "minesweeper")
      and hasModeEntry(GQ.OS_Table.BAR11.GameModes, "defender")
      and hasModeEntry(GQ.OS_Table.BAR11.GameModes, "progresstein"),
      "3 modos quark")
    _G.__PIBE_INSTALLED = nil
    _G.__QUARK_INSTALLED = nil
    _G.G = svG
    display = svDisplay
  end

  _G.__PIBE_INSTALLED = nil
  _G.__QUARK_INSTALLED = nil
  pcall(function() os.remove(M.PIBE_SAVE) end)
  pcall(function() os.remove(M.QUARK_SAVE) end)
  M.VIEW_DEBUG = svViewDebug
  return "PIBE_QUARK_OK pibe3+red5+pink3+quark3+sites+search5+progrbase+modeview"
end

pcall(function() _G.__PIBE_QUARK = _G.__PIBE_QUARK or M end)

return M
