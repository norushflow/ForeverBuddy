local loadfile = dofile("tests/load_locales.lua")
local frames={}
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function methods:RegisterEvent(e) self.events[e]=true end
function methods:UnregisterEvent(e) self.events[e]=nil end
function methods:UnregisterAllEvents() self.events={} end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetShown(v) self.shown=v end
function methods:IsShown() return self.shown end
function methods:SetFrameLevel(v) self.frameLevel=v end
function methods:SetFrameStrata(v) self.frameStrata=v end
function methods:SetText(v) self.text=v end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:GetWidth() return 140 end
function methods:GetHeight() return 140 end
function methods:GetEffectiveScale() return 1 end
function methods:GetCenter() return 100,100 end
local object
function methods:GetFontString() self.fontString=rawget(self,"fontString") or object(); return self.fontString end
function methods:SetHeight(v) self.height=v end
function methods:SetSize(w,h) self.width=w;self.height=h end
object = function()
 return setmetatable({events={},scripts={},shown=true},{__index=function(_,k) return methods[k] or function() end end})
end
function CreateFrame(_,name)
 local f=object();frames[#frames+1]=f;if name then _G[name]=f end;return f
end
function methods:CreateTexture() return object() end
function methods:CreateFontString() return object() end
UIParent=object();Minimap=object();GameTooltip=object();UISpecialFrames={};SlashCmdList={}
local tickers={}
local afterCalls=0
STANDARD_TEXT_FONT='font';C_Timer={After=function() afterCalls=afterCalls+1 end,NewTicker=function(_,fn) tickers[#tickers+1]=fn;return {Cancel=function() end} end}
local combat,inside=false,false
function InCombatLockdown() return combat end
function IsInInstance() return inside end
C_PartyInfo={IsDelveInProgress=function() return inside end}
function GetServerTime() return 1000 end
function date() return '12:00' end
function UnitClass() return 'Hunter','HUNTER' end
function GetClassColor() return 1,1,1 end
ForeverbuddyDB={clock={hidden=true},schedule={position={}},enabled={clock=true,schedule=true}}
if arg[1]=='disabled' then ForeverbuddyDB={enabled={characters=false,schedule=false,clock=false,delves=false,omnium=false,transmog=false,meters=false,bars=false,mail=false}} end
local Buddy={}
for line in io.lines('Foreverbuddy.toc') do
 if line:match('%.lua$') then assert(loadfile(''..line))('Foreverbuddy',Buddy) end
end
local init=frames[#frames]
init.scripts.OnEvent(init,'ADDON_LOADED','Foreverbuddy')
if arg[1]=='disabled' then
 assert(next(Buddy.loaded)==nil and not SlashCmdList.FOREVERBUDDYCHARS and not SlashCmdList.MIDNIGHTEVENTFEED and not SlashCmdList.TIEFENBEGLEITER and not SlashCmdList.FOREVERBUDDYBARS)
 init.scripts.OnEvent(init,'PLAYER_LOGIN')
 assert(ForeverbuddyMinimapButton)
 assert(afterCalls==0 and #tickers==0,'disabled modules must schedule no background work')
 for _,f in ipairs(frames) do
  assert(next(f.events)==nil and not f.scripts.OnUpdate,'disabled modules leave no event processing/polling')
 end
 print('PASS: disabled modules do not initialize; minimap remains available')
 return
end
assert(Buddy.loaded.characters and Buddy.loaded.bars)
assert(not Buddy.Tiefen and not Buddy.Omnium and not Buddy.LoadDelves and not Buddy.LoadOmnium)
assert(not Buddy.Schedule and not Buddy.LoadClock and not Buddy.LoadSchedule)
assert(not Buddy.db.clock and not Buddy.db.schedule and not Buddy.db.enabled.clock and not Buddy.db.enabled.schedule)
assert(not SlashCmdList.MIDNIGHTEVENTFEED and not ForeverbuddyClockFrame and not ForeverbuddySchedulePanel)
for _,f in ipairs(frames) do assert(not f.events.EVENT_SCHEDULER_UPDATE) end
local expected={characters=true,transmog=true,meters=true,bars=true,mail=true}
assert(#Buddy.modules==5)
for _,m in ipairs(Buddy.modules) do assert(expected[m.key] and type(Buddy[m.loader])=='function');expected[m.key]=nil end
assert(next(expected)==nil)
local originalOpen=Buddy.OpenModule
local aliases={chars='characters',transmog='transmog',meter='meters'}
for alias,key in pairs(aliases) do
 Buddy.OpenModule=function(m) assert(m.key==key) end
 SlashCmdList.FOREVERBUDDY(alias)
end
Buddy.OpenModule=originalOpen
init.scripts.OnEvent(init,'PLAYER_LOGIN')
assert(ForeverbuddyMinimapButton and not AltMiniMinimapButton)
ForeverbuddyMinimapButton.scripts.OnClick(ForeverbuddyMinimapButton,'LeftButton');assert(Buddy.panel:IsShown())
SlashCmdList.FOREVERBUDDY('');assert(not Buddy.panel:IsShown())
-- Character UI regression: compact sizing, filters, sorting and tab transitions.
function UnitFullName() return 'Buddy','Realm' end
function UnitFactionGroup() return 'Alliance' end
function GetProfessions() return nil,nil end
function GetAverageItemLevel() return 275,275 end
function UnitLevel() return 90 end
function UnitXPMax() return 0 end
function time() return 1000 end
function FauxScrollFrame_Update() end
function FauxScrollFrame_GetOffset(f) return rawget(f,"offset") or 0 end
function FauxScrollFrame_SetOffset(f,v) f.offset=v end
LOCALIZED_CLASS_NAMES_MALE={HUNTER='Jäger',MAGE='Magier'}
Buddy.db.characters.filters.class="EVOKER"
SlashCmdList.FOREVERBUDDYCHARS()
local characters=ForeverbuddyCharactersFrame
assert(Buddy.db.characters.filters.class == nil, 'stale Retail class filter is cleared')
local foreverClasses={WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,SHAMAN=true,MAGE=true,WARLOCK=true,DRUID=true}
assert(#characters.classButtons==9, 'nine Forever classes')
for _,button in ipairs(characters.classButtons) do
 assert(foreverClasses[button.classTag], 'unexpected class filter')
 foreverClasses[button.classTag]=nil
end
assert(next(foreverClasses)==nil)
assert(characters:IsShown() and characters.height==420,'compact character view')
assert(characters.rows[1].cells[2].text=='Jäger','localized class label')
assert(characters.rows[1].cells[1].text=='Buddy Realm','full name must include secondary name')
for i=1,20 do Buddy.db.characters.chars['alt'..i]={name='Alt'..i,realm='Realm',class='MAGE',level=i,playtime_sec=i*60} end
characters.Render();assert(characters.height==630,'row cap at twelve')
characters.scroll.offset=9
Buddy.db.characters.filters.class='HUNTER'
characters.Render();assert(characters.scroll.offset==0 and characters.rows[1]:IsShown(),'filter clamps scroll offset')
Buddy.db.characters.filters.class='WARRIOR'
characters.Render();assert(characters.empty:IsShown(),'empty filter state')
characters.clearBtn.scripts.OnClick();assert(not characters.empty:IsShown())
characters.headers[6].scripts.OnClick();assert(Buddy.db.characters.sort.key=='level' and Buddy.db.characters.sort.asc)
characters.tab2.scripts.OnClick();assert(characters.headers[1].text.text=='Klasse' and characters.rows[1].cells[1].text=='Magier')
characters.tab1.scripts.OnClick();assert(characters.headers[1].text.text=='Vor- und Nachname' and characters.scroll.offset==0)
print('PASS: character layout, localization, row cap, filtering, empty state, sorting and tabs')
-- Berufssnapshot: fehlende Login-/Logoutdaten dürfen gespeicherte Berufe nicht löschen.
local charEvents
for _,f in ipairs(frames) do if f.events.SKILL_LINES_CHANGED then charEvents=f end end
assert(charEvents)
local c=Buddy.db.characters.chars['Realm-Buddy']
c.prof1_name,c.prof1_lvl='Alchemie',70
c.prof2_name,c.prof2_lvl='Kräuterkunde',80
GetProfessions=function() return nil,nil end
charEvents.scripts.OnEvent(charEvents,'PLAYER_LOGIN')
assert(c.prof1_name=='Alchemie' and c.prof2_lvl==80,'login erased saved professions')
local professionQueue={}
local oldAfter=C_Timer.After
C_Timer.After=function(_,fn) professionQueue[#professionQueue+1]=fn end
local function skills()
 charEvents.scripts.OnEvent(charEvents,'SKILL_LINES_CHANGED')
 while #professionQueue>0 do table.remove(professionQueue,1)() end
end
GetProfessions=function() return 1,2 end
GetProfessionInfo=function(i) return i==1 and 'Alchemie' or 'Kräuterkunde',123,90,100 end
skills();assert(c.prof1_lvl==90 and c.prof2_lvl==90)
GetProfessionInfo=function(i) if i==1 then return 'Alchemie',123,95,100 end end
skills();assert(c.prof1_lvl==90 and c.prof2_lvl==90,'partial response overwrote snapshot')
GetProfessions=function() return nil,nil end
charEvents.scripts.OnEvent(charEvents,'PLAYER_LOGOUT')
assert(c.prof1_name=='Alchemie' and c.prof2_name=='Kräuterkunde','logout erased professions')
-- Beruf wechseln bzw. verlernen, auch bei leerem ersten Slot.
GetProfessions=function() return nil,2 end
GetProfessionInfo=function() return 'Bergbau',456,25,100 end
skills();assert(c.prof1_name=='—' and c.prof2_name=='Bergbau')
GetProfessions=function() return nil,nil end
skills();assert(c.prof2_name=='—','unlearning left a stale profession')
C_Timer.After=oldAfter
print('PASS: saved professions survive missing/partial data and logout; learning/unlearning updates')

-- Audit 1.0: Offline-Erholung beginnt auch bei null; gespeicherte Daten bleiben gleich.
local originalTime=time
function time() return 100000 end
Buddy.db.characters.filters={class='HUNTER'}
local offline={name='Offline',realm='Realm',class='HUNTER',level=20,xpmax=1000,
 rested_xp=0,rested_ts=time()-86400}
Buddy.db.characters.chars['Realm-Offline']=offline
SlashCmdList.FOREVERBUDDYCHARS()
local characters=ForeverbuddyCharactersFrame
if not characters:IsShown() then SlashCmdList.FOREVERBUDDYCHARS() end
characters.Render()
local found=false
for _,row in ipairs(characters.rows) do
 if row:IsShown() and row.cells[1].text=='Offline Realm' then
  assert(row.cells[8].text=='~15.0%','one day must add estimated rest from zero')
  found=true
 end
end
assert(found and offline.rested_xp==0,'estimate must not overwrite snapshot')
time=originalTime
-- Zentrale Tooltip-Hilfe überspringt nicht zugängliche Blizzard-Frames.
local oldHide=GameTooltip.Hide
GameTooltip.IsForbidden=function() return true end
GameTooltip.Hide=function() error('forbidden tooltip touched') end
assert(pcall(Buddy.HideTooltip))
GameTooltip.IsForbidden=function() return false end;GameTooltip.Hide=oldHide
print('PASS: zero-rested offline estimate and shared tooltip guard')

-- Menu items close the hub; the inline action bar controls stay accessible.
for _,module in ipairs(Buddy.modules) do
    local handler=SlashCmdList[module.command]
    local called=false
    SlashCmdList[module.command]=function() called=true end
    Buddy.panel:Show()
    Buddy.OpenModule(module)
    if module.key=="bars" then
        assert(Buddy.panel:IsShown(),"bars must keep the hub open")
    else
        assert(called and not Buddy.panel:IsShown(),"module must close the hub: "..module.key)
    end
    SlashCmdList[module.command]=handler
end
print('PASS: menu closes for modules and stays open for action bars')
