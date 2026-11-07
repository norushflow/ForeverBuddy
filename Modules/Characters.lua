local addonName, Buddy = ...
function Buddy.LoadCharacters()
local AltMiniDB = Buddy.db.characters
-- Account character snapshots and overview.

AltMiniDB = AltMiniDB or {}
AltMiniDB.chars   = AltMiniDB.chars or {}
AltMiniDB.sort    = AltMiniDB.sort or { key = "level", asc = false }
AltMiniDB.filters = AltMiniDB.filters or { class = nil, prof = nil }

-- ---------------- Config ----------------
local FONT_PATH  = STANDARD_TEXT_FONT
local FONT_SIZE  = 14
local ROW_H      = 30
local LIST_ROWS    = 12 -- Zeilenpool; sichtbar sind je nach Datenmenge 5…12
local LIST_TOP = 226

-- Tab State
local CURRENT_TAB = 1

-- Filter bar layout
local ICON_Y_OFFSET   = -105
local ICON_SIZE       = 24
local ICON_GAP        = 6

local CLASS_LABEL_X   = 24
local CLASS_ICONS_X   = 106


local LOGO_PATH = "Interface\\AddOns\\Foreverbuddy\\Media\\BuddyIcon"

-- ---------------- Utils ----------------
local function SafeStr(x) if issecretvalue and issecretvalue(x) then return "—" end;return (x and x ~= "" and x) or "—" end
local function SafeNum(x) if issecretvalue and issecretvalue(x) then return 0 end;x = tonumber(x);return x or 0 end
local function Round1(x) return math.floor((x * 10) + 0.5) / 10 end

local function MakeFS(parent)
local fs = parent:CreateFontString(nil, "OVERLAY")
fs:SetFont(FONT_PATH, FONT_SIZE, "")
fs:SetJustifyH("LEFT")
fs:SetTextColor(1,1,1)
return fs
end

local function GetClassColorRGB(classTag)
if RAID_CLASS_COLORS and classTag and RAID_CLASS_COLORS[classTag] then
local c = RAID_CLASS_COLORS[classTag]
return c.r, c.g, c.b
end
if C_ClassColor and classTag then
local cc = C_ClassColor.GetClassColor(classTag)
if cc then return cc.r, cc.g, cc.b end
end
return 1, 1, 1
end

local function SecToDH(sec)
sec = SafeNum(sec)
if sec <= 0 then return "—" end
local d = math.floor(sec / 86400)
local h = math.floor((sec % 86400) / 3600)
return string.format("%dd %dh", d, h)
end

local function SecToDHM(sec)
sec = SafeNum(sec)
local d = math.floor(sec / 86400)
local rem = sec % 86400
local h = math.floor(rem / 3600)
rem = rem % 3600
local m = math.floor(rem / 60)
return string.format("%dd %dh %dm", d, h, m)
end

-- ---------------- Stable character key ----------------
local CURRENT_KEY

local function BuildCurrentKey()
local name, realm = UnitFullName("player")
if not name then name = UnitName("player") or "Unknown" end
if not realm or realm == "" then realm = GetRealmName() or "UnknownRealm" end
return realm .. "-" .. name
end

local function EnsureDBForCurrent()
if not CURRENT_KEY then CURRENT_KEY = BuildCurrentKey() end
AltMiniDB.chars[CURRENT_KEY] = AltMiniDB.chars[CURRENT_KEY] or {}
return AltMiniDB.chars[CURRENT_KEY]
end

-- ---------------- Professions ----------------
local function Public(value)
return not (issecretvalue and issecretvalue(value))
end
local professionsReady=false
local function UpdateProfessions(c, skillChanged)
local ok,p1,p2=pcall(GetProfessions)
if not ok or not Public(p1) or not Public(p2) then return end
local values={}
for slot=1,2 do
local index
-- Ein leerer erster Slot ist zulässig.
if slot==1 then index=p1 else index=p2 end
if index~=nil then
 if type(index)~="number" then return end
 local success,name,icon,level,maximum=pcall(GetProfessionInfo,index)
 if not success or not Public(name) or type(name)~="string" or name==""
     or not Public(icon) or not Public(level) or not Public(maximum)
     or type(level)~="number" or type(maximum)~="number" then return end
 values[slot]={name,icon,level,maximum}
end
end
-- Unvollständige Abfragen überschreiben keinen gespeicherten Snapshot.
-- Leere Slots nur nach einer Skill-Änderung in einer bereits geladenen Sitzung löschen.
local clearMissing=skillChanged and professionsReady
for slot=1,2 do
 local value=values[slot]
 local key="prof"..slot
 if value then
  c[key.."_name"],c[key.."_icon"],c[key.."_lvl"],c[key.."_max"]=unpack(value,1,4)
 elseif clearMissing then
  c[key.."_name"],c[key.."_icon"],c[key.."_lvl"],c[key.."_max"]="—",nil,0,0
 end
end
if values[1] or values[2] then professionsReady=true end
end

local function FormatProf(name, lvl)
name = SafeStr(name)
lvl = SafeNum(lvl)
if name == "—" then return "—" end
if lvl <= 0 then return name end
return string.format("%s %d", name, lvl)
end

-- ---------------- Rest% / iLvl ----------------
local function GetItemLevel()
local _, equipped = GetAverageItemLevel()
return math.floor(SafeNum(equipped) + 0.5)
end

local function GetRestedXPNow()
local rested = (GetXPExhaustion and GetXPExhaustion()) or 0
return SafeNum(rested)
end

local function GetRestXPPercent()
local maxXP = SafeNum(UnitXPMax("player"))
if maxXP <= 0 then return 0 end
local rested = GetRestedXPNow()
if rested <= 0 then return 0 end
return (rested / maxXP) * 100
end

local function EstimateRestedXPPercent(char)
local xpmax = SafeNum(char.xpmax)
if xpmax <= 0 then return 0 end

local rested = SafeNum(char.rested_xp)
local ts = SafeNum(char.rested_ts)
rested = math.max(0, rested)
if ts <= 0 then return Round1((rested / xpmax) * 100) end

local elapsed = math.max(0, time() - ts)
local days = elapsed / 86400
local grown = days * 0.15 * xpmax

local cap = 1.5 * xpmax
local est = math.min(cap, rested + grown)

return Round1((est / xpmax) * 100)
end

-- ---------------- Update char snapshot ----------------
local function UpdateCharCore(skillChanged, loggingOut)
local c = EnsureDBForCurrent()

local name, realm = UnitFullName("player")
if not name then name = UnitName("player") or "?" end
if not realm or realm == "" then realm = GetRealmName() or "?" end

c.realm   = realm
c.name    = name
c.class   = select(2, UnitClass("player")) or "?"
c.faction = UnitFactionGroup("player") or "?"

if not loggingOut then UpdateProfessions(c, skillChanged) end

c.level   = SafeNum(UnitLevel("player"))
c.ilvl    = SafeNum(GetItemLevel())

c.xpmax = SafeNum(UnitXPMax("player"))
c.rested_xp = SafeNum(GetRestedXPNow())
c.rested_ts = time()

c.restxp_pct = Round1(GetRestXPPercent())
c.updated = time()
end

-- ---------------- Playtime ----------------
local function RequestPlaytime()
if RequestTimePlayed then RequestTimePlayed() end
end

local function OnTimePlayedMsg(totalSeconds)
local c = EnsureDBForCurrent()
c.playtime_sec = SafeNum(totalSeconds)
c.updated = time()
end

local function GetAccountPlaytimeSeconds()
local total = 0
for _, c in pairs(AltMiniDB.chars) do
total = total + SafeNum(c.playtime_sec)
end
return total
end

-- ---------------- Statistics ----------------
local function GetClassStats()
local stats = {}
for _, c in pairs(AltMiniDB.chars) do
if c.class and c.playtime_sec then
stats[c.class] = (stats[c.class] or 0) + SafeNum(c.playtime_sec)
end
end
local sortedStats = {}
for classTag, seconds in pairs(stats) do
table.insert(sortedStats, { class = classTag, time = seconds })
end
table.sort(sortedStats, function(a, b) return a.time > b.time end)
return sortedStats
end

-- ---------------- Sort / Filter ----------------
local function EnsureFilters()
AltMiniDB.filters = AltMiniDB.filters or { class = nil, prof = nil }
return AltMiniDB.filters
end

local function GetSortState()
AltMiniDB.sort = AltMiniDB.sort or { key = "level", asc = false }
return AltMiniDB.sort
end

local function ToggleSort(key)
local s = GetSortState()
if s.key == key then
s.asc = not s.asc
else
s.key = key
s.asc = false
end
end

local function MatchesFilters(c)
local flt = EnsureFilters()
if flt.class and c.class ~= flt.class then return false end
if flt.prof then
local p1 = c.prof1_name
local p2 = c.prof2_name
if p1 ~= flt.prof and p2 ~= flt.prof then return false end
end
return true
end

-- ---------------- UI ----------------
local ui

local COLS = {
{ key="realm",        title="Realm",     w=130 },
{ key="name",         title="Name",      w=120 },
{ key="class",        title="Klasse",    w=110 },
{ key="faction",      title="Fraktion",  w=90  },
{ key="prof1",        title="Beruf 1",   w=180 },
{ key="prof2",        title="Beruf 2",   w=180 },
{ key="level",        title="Lvl",       w=55  },
{ key="ilvl",         title="iLvl",      w=65  },
{ key="restxp_pct",   title="Erholt %",    w=80  },
{ key="playtime_sec", title="Spielzeit",  w=110 },
}

local function GetCellValueForSort(c, key)
if key == "prof1" then return FormatProf(c.prof1_name, c.prof1_lvl) end
if key == "prof2" then return FormatProf(c.prof2_name, c.prof2_lvl) end
return c[key]
end

local function BuildSortedList()
local t = {}
for _, c in pairs(AltMiniDB.chars) do
if c and c.name and c.realm and MatchesFilters(c) then
table.insert(t, c)
end
end

local s = GetSortState()
local sortKey = s.key
local asc = s.asc

table.sort(t, function(a, b)
local av = GetCellValueForSort(a, sortKey)
local bv = GetCellValueForSort(b, sortKey)

local isNum = (sortKey == "level" or sortKey == "ilvl" or sortKey == "restxp_pct" or sortKey == "playtime_sec")
if isNum then
av, bv = SafeNum(av), SafeNum(bv)
if av == bv then
local ar, br = a.realm or "", b.realm or ""
if ar == br then return (a.name or "") < (b.name or "") end
return ar < br
end
if asc then return av < bv else return av > bv end
else
av, bv = tostring(SafeStr(av)), tostring(SafeStr(bv))
if av == bv then
local ar, br = a.realm or "", b.realm or ""
if ar == br then return (a.name or "") < (b.name or "") end
return ar < br
end
if asc then return av < bv else return av > bv end
end
end)

return t
end

local CLASS_TEX = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local function CreateIconButton(parent, size, iconTex, onClick)
local b = CreateFrame("Button", nil, parent)
b:SetSize(size, size)

local bg = b:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.35)

local t = b:CreateTexture(nil, "ARTWORK")
t:SetAllPoints()
b.icon = t
if iconTex then t:SetTexture(iconTex) end

local hl = b:CreateTexture(nil, "HIGHLIGHT")
hl:SetAllPoints()
hl:SetColorTexture(1,1,1,0.08)

local border = b:CreateTexture(nil, "OVERLAY")
border:SetAllPoints()
border:SetColorTexture(1,1,1,0.10)
b.border = border

b:SetScript("OnClick", onClick)
b:SetScript("OnEnter", function(self)
 Buddy.Foreign(GameTooltip, function()
 GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
 GameTooltip:AddLine(self.profName or (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[self.classTag]) or self.classTag or "Filter")
 GameTooltip:AddLine("Klicken zum Filtern; erneut klicken zum Aufheben",0.7,0.75,0.8)
 GameTooltip:Show()
 end)
end)
b:SetScript("OnLeave", Buddy.HideTooltip)
return b
end

local function SetButtonActive(btn, active)
if active then
btn.border:SetColorTexture(.78, .78, .78, 0.25)
else
btn.border:SetColorTexture(1, 1, 1, 0)
end
end

local function GetUniqueProfessions()
local profs = {}
for _, c in pairs(AltMiniDB.chars) do
if c and c.prof1_name and c.prof1_name ~= "—" then
profs[c.prof1_name] = c.prof1_icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
if c and c.prof2_name and c.prof2_name ~= "—" then
profs[c.prof2_name] = c.prof2_icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
end
return profs
end

local function CreateUI()
ui = CreateFrame("Frame", "ForeverbuddyCharactersFrame", UIParent, "BackdropTemplate")

ui:SetFrameStrata("DIALOG")
ui:SetFrameLevel(100)

ui:SetSize(1260, 450)
ui:SetClampedToScreen(true)
ui:SetScale(math.min(1, (UIParent:GetWidth() - 40) / 1260, (UIParent:GetHeight() - 40) / 630))
ui:SetPoint("CENTER")
ui:SetMovable(true)
ui:EnableMouse(true)
ui:RegisterForDrag("LeftButton")
ui:SetScript("OnDragStart", ui.StartMoving)
ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
ui:Hide()

Buddy.Style.Window(ui,nil,.90)
local accent = ui:CreateTexture(nil, "ARTWORK")
accent:SetColorTexture(0.93, 0.78, 0.44, 0.7)
accent:SetPoint("TOPLEFT", 0, 0); accent:SetPoint("TOPRIGHT", 0, 0); accent:SetHeight(2)
local logo = ui:CreateTexture(nil, "ARTWORK")
logo:SetTexture(LOGO_PATH); logo:SetSize(38,38); logo:SetPoint("TOPLEFT",20,-16)
local subtitle = MakeFS(ui)
subtitle:SetPoint("TOPLEFT",70,-42); subtitle:SetText("Deine Charaktere auf einen Blick")
subtitle:SetTextColor(0.62,0.69,0.73)
ui.summary = MakeFS(ui)
ui.summary:SetPoint("BOTTOMLEFT",24,16); ui.summary:SetTextColor(0.62,0.69,0.73)
ui.empty = MakeFS(ui)
ui.empty:SetPoint("TOP",0,-LIST_TOP-40); ui.empty:SetText("Keine Charaktere für diese Filter gefunden.")
ui.empty:SetTextColor(0.62,0.69,0.73); ui.empty:Hide()
UISpecialFrames[#UISpecialFrames+1] = "ForeverbuddyCharactersFrame"

local function StyleTab(button)
    button.fill = button:CreateTexture(nil,"BACKGROUND")
    button.fill:SetAllPoints()
    button.line = button:CreateTexture(nil,"ARTWORK")
    button.line:SetPoint("BOTTOMLEFT"); button.line:SetPoint("BOTTOMRIGHT"); button.line:SetHeight(2)
    button.line:SetColorTexture(0.93,0.78,0.44,1)
end

-- Tabs
ui.tab1 = Buddy.Style.Button(CreateFrame("Button", nil, ui, "UIPanelButtonTemplate"))
ui.tab1:SetSize(140, 30)
StyleTab(ui.tab1)
ui.tab1:SetPoint("TOPLEFT", 20, -65)
ui.tab1:SetText("Übersicht")
ui.tab1:SetScript("OnClick", function() CURRENT_TAB = 1; FauxScrollFrame_SetOffset(ui.scroll, 0); if ui.Render then ui.Render() end end)

ui.tab2 = Buddy.Style.Button(CreateFrame("Button", nil, ui, "UIPanelButtonTemplate"))
ui.tab2:SetSize(180, 30)
StyleTab(ui.tab2)
ui.tab2:SetPoint("LEFT", ui.tab1, "RIGHT", 5, 0)
ui.tab2:SetText("Klassen-Statistik")
ui.tab2:SetScript("OnClick", function() CURRENT_TAB = 2; FauxScrollFrame_SetOffset(ui.scroll, 0); if ui.Render then ui.Render() end end)

-- Title
ui.title = MakeFS(ui)
ui.title:SetPoint("TOPLEFT", 70, -19)
ui.title:SetFont(FONT_PATH, 18, "")
ui.title:SetTextColor(.78,.78,.78)
ui.title:SetText("Foreverbuddy · Charaktere")

-- Account Playtime (top-right)
ui.accountPlaytime = MakeFS(ui)
ui.accountPlaytime:SetPoint("TOPRIGHT", -58, -22)
ui.accountPlaytime:SetTextColor(0.76,0.81,0.83)
ui.accountPlaytime:SetJustifyH("RIGHT")
ui.accountPlaytime:SetText("Erfasste Spielzeit: 0d 0h 0m")

local close = CreateFrame("Button", nil, ui, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -4, -4)

local refresh = Buddy.Style.Button(CreateFrame("Button", nil, ui, "UIPanelButtonTemplate"))
refresh:SetSize(110, 24)
refresh:SetPoint("TOPRIGHT", -24, -66)
refresh:SetText("Aktualisieren")

-- Filter bar background
local filterBg = CreateFrame("Frame", nil, ui, "BackdropTemplate")
filterBg:SetPoint("TOPLEFT", 20, -99)
filterBg:SetPoint("TOPRIGHT", -24, -99)
filterBg:SetHeight(78)
Buddy.Style.Inset(filterBg)

-- Clear filters (right side)
ui.clearBtn = Buddy.Style.Button(CreateFrame("Button", nil, ui, "UIPanelButtonTemplate"))
ui.clearBtn:SetSize(145, 24)
ui.clearBtn:SetPoint("TOPRIGHT", -32, -106)
ui.clearBtn:SetText("Filter zurücksetzen")
ui.clearBtn:SetScript("OnClick", function()
local flt = EnsureFilters()
flt.class, flt.prof = nil, nil
if ui and ui.Render then ui.Render() end
end)

-- Labels in filter bar
ui.classLabel = MakeFS(ui)
ui.classLabel:SetPoint("TOPLEFT", CLASS_LABEL_X, -111)
ui.classLabel:SetText("Klasse:")

-- Class icons
ui.classButtons = {}
local classOrder = {
"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST",
"SHAMAN","MAGE","WARLOCK","DRUID"
}

local available = {}
for _, tag in ipairs(classOrder) do available[tag] = true end
if AltMiniDB.filters.class and not available[AltMiniDB.filters.class] then
    AltMiniDB.filters.class = nil
end

local x = CLASS_ICONS_X
for _, classTag in ipairs(classOrder) do
local btn = CreateIconButton(ui, ICON_SIZE, CLASS_TEX, function()
local flt = EnsureFilters()
if flt.class == classTag then flt.class = nil else flt.class = classTag end
if ui and ui.Render then ui.Render() end
end)
btn:SetPoint("TOPLEFT", x, ICON_Y_OFFSET)
btn.classTag = classTag

if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classTag] then
local c = CLASS_ICON_TCOORDS[classTag]
btn.icon:SetTexCoord(c[1], c[2], c[3], c[4])
else
btn.icon:SetTexCoord(0,1,0,1)
end

ui.classButtons[#ui.classButtons+1] = btn
x = x + ICON_SIZE + ICON_GAP
end

-- Profession label
ui.profLabel = MakeFS(ui)
ui.profLabel:SetPoint("TOPLEFT", CLASS_LABEL_X, -149)
ui.profLabel:SetText("Berufe:")

-- Profession icons (dynamic)
ui.profButtons = {}
ui.profAnchorX = CLASS_ICONS_X
ui.profY = -143

-- Selected filter text
ui.filterLabel = MakeFS(ui)
ui.filterLabel:SetWidth(1180)
ui.filterLabel:SetTextColor(0.68,0.75,0.78)
ui.filterLabel:SetText("")
ui.filterLabel:Hide()

-- Column header bar
local headerBg = CreateFrame("Frame", nil, ui, "BackdropTemplate")
headerBg:SetPoint("TOPLEFT", 20, -194)
headerBg:SetPoint("TOPRIGHT", -24, -194)
headerBg:SetHeight(28)
Buddy.Style.Inset(headerBg)

-- Clickable headers
ui.headers = {}
local hx = 24
for i, col in ipairs(COLS) do
local btn = CreateFrame("Button", nil, ui)
btn:SetPoint("TOPLEFT", hx, -197)
btn:SetSize(col.w, 22)
btn.colKey = col.key

btn.text = MakeFS(btn)
btn.text:SetAllPoints()
btn.text:SetJustifyH("LEFT")
btn.text:SetTextColor(0.92,0.80,0.54)

btn:SetScript("OnClick", function()
if CURRENT_TAB ~= 1 then return end
ToggleSort(btn.colKey)
if ui and ui.Render then ui.Render() end
end)

ui.headers[i] = btn
hx = hx + col.w + 8
end

-- Scroll list
local sf = CreateFrame("ScrollFrame", "ForeverbuddyCharactersScrollFrame", ui, "FauxScrollFrameTemplate")
ui.scroll = sf
sf:SetPoint("TOPLEFT", 20, -LIST_TOP)
sf:SetPoint("BOTTOMRIGHT", -28, 42)

ui.rows = {}
for i = 1, LIST_ROWS do
local row = CreateFrame("Button", nil, ui)
row:SetHeight(ROW_H)
row:SetPoint("TOPLEFT", 24, -LIST_TOP - (i-1)*ROW_H)
row:SetPoint("TOPRIGHT", -28, -LIST_TOP - (i-1)*ROW_H)

local bg = row:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
if i % 2 == 0 then bg:SetColorTexture(0.25,0.22,0.16,0.30) else bg:SetColorTexture(0.08,0.07,0.06,0.24) end

local hl = row:CreateTexture(nil, "HIGHLIGHT")
hl:SetAllPoints()
hl:SetColorTexture(0.93,0.78,0.44,0.10)

row.cells = {}
local cx = 0
for c = 1, #COLS do
local col = COLS[c]
local fsCell = MakeFS(row)
fsCell:SetPoint("LEFT", row, "LEFT", cx, 0)
fsCell:SetWidth(col.w)
row.cells[c] = fsCell
cx = cx + col.w + 8
end

ui.rows[i] = row
end

-- Render helpers
local function UpdateHeaderTexts()
local s = GetSortState()
for i, col in ipairs(COLS) do
local btn = ui.headers[i]
local arrow = ""
if s.key == col.key then arrow = s.asc and " +" or " -" end
btn.text:SetText(col.title .. arrow)
end
end

local function RebuildProfessionButtons()
local profs = GetUniqueProfessions()
local names = {}
for name in pairs(profs) do table.insert(names, name) end
table.sort(names)

for _, b in pairs(ui.profButtons) do b:Hide() end

local px = ui.profAnchorX
local py = ui.profY
local sizeP = ICON_SIZE
local gapP  = ICON_GAP

for i, profName in ipairs(names) do
local btn = ui.profButtons[i]
if not btn then
btn = CreateIconButton(ui, sizeP, nil, function(self)
local flt = EnsureFilters()
if flt.prof == self.profName then flt.prof = nil else flt.prof = self.profName end
if ui and ui.Render then ui.Render() end
end)
ui.profButtons[i] = btn
end

btn.profName = profName
btn.icon:SetTexture(profs[profName] or "Interface\\Icons\\INV_Misc_QuestionMark")
btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
btn:ClearAllPoints()
btn:SetPoint("TOPLEFT", px, py)
btn:Show()

px = px + sizeP + gapP
end

end

local function UpdateFilterVisuals()
local flt = EnsureFilters()

for _, b in ipairs(ui.classButtons) do
SetButtonActive(b, flt.class == b.classTag)
end
for _, b in ipairs(ui.profButtons) do
if b:IsShown() then
SetButtonActive(b, flt.prof == b.profName)
end
end

if not flt.class and not flt.prof then return nil end

local parts = {}
if flt.class then table.insert(parts, "Klasse=" .. flt.class) end
if flt.prof  then table.insert(parts, "Beruf=" .. flt.prof) end
return " (" .. table.concat(parts, " | ") .. ")"
end

-- Main Render
local function Render()
for index, tab in ipairs({ui.tab1,ui.tab2}) do
    local selected = index == CURRENT_TAB
    tab.line:SetShown(selected)
    tab.fill:SetColorTexture(0.65,0.5,0.2,selected and .15 or 0)
    tab:GetFontString():SetTextColor(selected and .9 or 0.65,selected and .9 or 0.71,selected and .9 or 0.74)
end
ui.accountPlaytime:SetText("Erfasste Spielzeit: " .. SecToDHM(GetAccountPlaytimeSeconds()))

if CURRENT_TAB == 1 then
-- Show Overview elements
filterBg:Show()
headerBg:Show()
ui.classLabel:Show()
ui.profLabel:Show()
ui.clearBtn:Show()
for _, b in ipairs(ui.classButtons) do b:Show() end
for _, b in ipairs(ui.headers) do b:Show() end

UpdateHeaderTexts()
RebuildProfessionButtons()
local selectedText = UpdateFilterVisuals()

if selectedText then
ui.filterLabel:ClearAllPoints()
ui.filterLabel:SetPoint("TOPLEFT", ui, "TOPLEFT", 24, -178)
ui.filterLabel:SetText(selectedText)
ui.filterLabel:Show()
else
ui.filterLabel:SetText("")
ui.filterLabel:Hide()
end

local data = BuildSortedList()
local total = #data
local rowsVisible = math.max(5, math.min(LIST_ROWS, total))
ui:SetHeight(LIST_TOP + rowsVisible * ROW_H + 44)
ui.summary:SetText(total .. " Charaktere · Spaltenüberschrift zum Sortieren anklicken")
ui.empty:SetShown(total == 0)
for i=rowsVisible+1,#ui.rows do ui.rows[i]:Hide() end
FauxScrollFrame_Update(sf, total, rowsVisible, ROW_H)

local offset = math.max(0, math.min(FauxScrollFrame_GetOffset(sf), math.max(0, total - rowsVisible)))
FauxScrollFrame_SetOffset(sf, offset)
local currentCharTable = AltMiniDB.chars[CURRENT_KEY]

for i = 1, rowsVisible do
local idx = i + offset
local row = ui.rows[i]
local c = data[idx]

if c then
row:Show()
local flt = EnsureFilters()
local p1_name, p1_lvl = c.prof1_name, c.prof1_lvl
local p2_name, p2_lvl = c.prof2_name, c.prof2_lvl
if flt.prof and p2_name == flt.prof and p1_name ~= flt.prof then
p1_name, p1_lvl, p2_name, p2_lvl = p2_name, p2_lvl, p1_name, p1_lvl
end

for colIdx, col in ipairs(COLS) do
local cell = row.cells[colIdx]
local key = col.key
local v

if key == "prof1" then
v = FormatProf(p1_name, p1_lvl)
elseif key == "prof2" then
v = FormatProf(p2_name, p2_lvl)
elseif key == "restxp_pct" then
if c == currentCharTable then
v = string.format("%.1f%%", SafeNum(c.restxp_pct))
else
local est = EstimateRestedXPPercent(c)
v = "~" .. string.format("%.1f%%", SafeNum(est))
end
elseif key == "playtime_sec" then
v = SecToDH(c.playtime_sec)
else
v = c[key]
if key == "class" then v = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class]) or v end
end

cell:SetText(SafeStr(v))
if key == "class" or key == "name" then
local r,g,b = GetClassColorRGB(c.class)
cell:SetTextColor(r,g,b)
else
cell:SetTextColor(0.83,0.87,0.89)
end
end
else
row:Hide()
end
end

else
-- Hide Overview elements for Stats Tab
filterBg:Hide()
headerBg:Show()
ui.classLabel:Hide()
ui.profLabel:Hide()
ui.clearBtn:Hide()
ui.filterLabel:Hide()
for _, b in ipairs(ui.classButtons) do b:Hide() end
for _, b in ipairs(ui.profButtons) do b:Hide() end
for i, b in ipairs(ui.headers) do
 b:SetShown(i <= 2)
 b.text:SetText(i == 1 and "Klasse" or "Spielzeit")
end

local stats = GetClassStats()
local total = #stats
local rowsVisible = math.max(5, math.min(LIST_ROWS, total))
ui:SetHeight(LIST_TOP + rowsVisible * ROW_H + 44)
ui.summary:SetText(total .. " Klassen · Erfasste Spielzeit pro Klasse")
ui.empty:SetShown(total == 0)
for i=rowsVisible+1,#ui.rows do ui.rows[i]:Hide() end
FauxScrollFrame_Update(sf, total, rowsVisible, ROW_H)
local offset = math.max(0, math.min(FauxScrollFrame_GetOffset(sf), math.max(0, total - rowsVisible)))
FauxScrollFrame_SetOffset(sf, offset)

for i = 1, rowsVisible do
local idx = i + offset
local row = ui.rows[i]
local s = stats[idx]

if s then
row:Show()
for colIdx = 1, #COLS do
local cell = row.cells[colIdx]
if colIdx == 1 then
cell:SetText((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[s.class]) or s.class)
local r,g,b = GetClassColorRGB(s.class)
cell:SetTextColor(r,g,b)
elseif colIdx == 2 then
cell:SetText(SecToDHM(s.time))
cell:SetTextColor(0.83,0.87,0.89)
else
cell:SetText("")
end
end
else
row:Hide()
end
end
end
end

sf:SetScript("OnVerticalScroll", function(_, delta)
FauxScrollFrame_OnVerticalScroll(sf, delta, ROW_H, Render)
end)

refresh:SetScript("OnClick", function()
UpdateCharCore()
RequestPlaytime()
Render()
end)

ui.Render = Render
end

-- ---------------- Window toggle ----------------
local function ToggleUI()
if not ui then CreateUI() end
if ui:IsShown() then
ui:Hide()
else
UpdateCharCore()
RequestPlaytime()
ui:Show()
ui:Raise()
if ui.Render then ui.Render() end
end
end

SLASH_FOREVERBUDDYCHARS1 = "/fbchars"
SLASH_FOREVERBUDDYCHARS2 = "/foreverbuddychars"
SlashCmdList["FOREVERBUDDYCHARS"] = ToggleUI

-- ---------------- Events ----------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("SKILL_LINES_CHANGED")
ev:RegisterEvent("TIME_PLAYED_MSG")
ev:RegisterEvent("UPDATE_EXHAUSTION")
ev:RegisterEvent("PLAYER_XP_UPDATE")
ev:RegisterEvent("PLAYER_LOGOUT")
local updateQueued=false
local skillsChanged=false

ev:SetScript("OnEvent", function(_, event, a1)
if event == "PLAYER_LOGIN" then
CURRENT_KEY = BuildCurrentKey()
UpdateCharCore()

RequestPlaytime()
if ui and ui:IsShown() and ui.Render then ui.Render() end
return
end

if event == "TIME_PLAYED_MSG" then
OnTimePlayedMsg(a1)
if ui and ui:IsShown() and ui.Render then ui.Render() end
return
end

if event=="PLAYER_LOGOUT" then UpdateCharCore(false,true);return end
if event=="SKILL_LINES_CHANGED" then skillsChanged=true end
if event=="PLAYER_XP_UPDATE" and a1~="player" then return end
if not updateQueued then
 updateQueued=true
 C_Timer.After(.2,function()
  updateQueued=false
  local changed=skillsChanged;skillsChanged=false
  UpdateCharCore(changed)
  if ui and ui:IsShown() and ui.Render then ui.Render() end
 end)
end
end)
end
