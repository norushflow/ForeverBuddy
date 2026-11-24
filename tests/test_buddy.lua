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
 assert(not ForeverbuddyRotationBar and SlashCmdList.BUDDYROTATION)
 local listeners=0
 for _,f in ipairs(frames) do
  if f.events.PLAYER_REGEN_ENABLED then
   listeners=listeners+1
   assert(f.events.ADDON_LOADED and f.events.PLAYER_REGEN_DISABLED)
  else assert(next(f.events)==nil and not f.scripts.OnUpdate) end
 end
 assert(listeners==1)
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
function UnitRace() return 'Nachtelf', 'NightElf' end
function GetProfessions() return nil,nil end
local itemLevels = {[5]=3, [6]=4, [7]=5, [8]=5, [16]=5}
function GetInventoryItemID(_, slot) return itemLevels[slot] and slot end
function GetInventoryItemLink(_, slot) return itemLevels[slot] and tostring(slot) end
C_Item = C_Item or {}
function C_Item.GetDetailedItemLevelInfo(link) return itemLevels[tonumber(link)] end
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
assert(characters.rows[1].cells[3].text=='Nachtelf','localized race label')
assert(Buddy.db.characters.chars['Realm-Buddy'].race=='Nachtelf','race is saved')
assert(Buddy.db.characters.chars['Realm-Buddy'].ilvl==4, 'average counts only equipped items')
assert(characters.rows[1].cells[1].text=='Buddy Realm','full name must include secondary name')
for i=1,20 do Buddy.db.characters.chars['alt'..i]={name='Alt'..i,realm='Realm',class='MAGE',level=i,playtime_sec=i*60} end
characters.Render();assert(characters.height==630,'row cap at twelve')
characters.scroll.offset=9
Buddy.db.characters.filters.class='HUNTER'
characters.Render();assert(characters.scroll.offset==0 and characters.rows[1]:IsShown(),'filter clamps scroll offset')
Buddy.db.characters.filters.class='WARRIOR'
characters.Render();assert(characters.empty:IsShown(),'empty filter state')
characters.clearBtn.scripts.OnClick();assert(not characters.empty:IsShown())
Buddy.db.characters.chars.alt1.faction='Horde'
characters.factionButtons[2].scripts.OnClick()
assert(Buddy.db.characters.filters.faction=='Horde' and characters.rows[1].cells[1].text=='Alt1 Realm' and not characters.rows[2]:IsShown(), 'Horde filter')
characters.factionButtons[1].scripts.OnClick()
assert(Buddy.db.characters.filters.faction=='Alliance' and characters.rows[1].cells[1].text=='Buddy Realm' and not characters.rows[2]:IsShown(), 'Alliance filter')
characters.factionButtons[1].scripts.OnClick()
assert(not Buddy.db.characters.filters.faction, 'click again clears faction')
characters.factionButtons[2].scripts.OnClick()
characters.clearBtn.scripts.OnClick()
assert(not Buddy.db.characters.filters.faction, 'reset clears faction')
Buddy.db.characters.chars.alt1.level=2
characters.headers[7].scripts.OnClick();assert(Buddy.db.characters.sort.key=='level' and Buddy.db.characters.sort.asc)
assert(characters.rows[1].cells[1].text=='Alt1 Realm' and characters.rows[2].cells[1].text=='Alt2 Realm',
    'numeric ties keep alphabetical ordering')
characters.headers[1].scripts.OnClick()
assert(characters.rows[1].cells[1].text=='Buddy Realm' and characters.rows[2].cells[1].text=='Alt9 Realm',
    'name sorting keeps descending lexical ordering')
characters.tab2.scripts.OnClick();assert(characters.headers[1].text.text=='Klasse' and characters.rows[1].cells[1].text=='Magier')
characters.tab1.scripts.OnClick();assert(characters.headers[1].text.text=='Vor- und Nachname -' and characters.scroll.offset==0)
print('PASS: character layout, localization, row cap, filtering, empty state, sorting and tabs')
-- Berufssnapshot: fehlende Login-/Logoutdaten dürfen gespeicherte Berufe nicht löschen.
local charEvents
for _,f in ipairs(frames) do if f.events.SKILL_LINES_CHANGED then charEvents=f end end
assert(charEvents)
local c=Buddy.db.characters.chars['Realm-Buddy']
local originalItemLevel = C_Item.GetDetailedItemLevelInfo
C_Item.GetDetailedItemLevelInfo = function() return nil end
charEvents.scripts.OnEvent(charEvents,'PLAYER_LOGIN')
assert(c.ilvl==4, 'incomplete item data preserves saved average')
C_Item.GetDetailedItemLevelInfo = originalItemLevel
local xpReads, restedReads = 0, 0
local originalXPMax = UnitXPMax
function UnitXPMax() xpReads=xpReads+1; return 1000 end
function GetXPExhaustion() restedReads=restedReads+1; return 123 end
charEvents.scripts.OnEvent(charEvents,'PLAYER_LOGIN')
assert(xpReads==1 and restedReads==1 and c.xpmax==1000 and c.rested_xp==123 and c.restxp_pct==12.3,
    'rested percentage is rounded from a single XP snapshot')
UnitXPMax, GetXPExhaustion = originalXPMax, nil
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

-- Rested XP regression: logout API teardown used to erase every offline snapshot.
local originalTime, originalName, originalLevel = time, UnitFullName, UnitLevel
local originalXP, originalRest, originalResting, originalMaxLevel = UnitXPMax, GetXPExhaustion, IsResting, GetMaxPlayerLevel
local originalSecret, originalAfter = issecretvalue, C_Timer.After
local oldChars, oldFilters, oldSort = Buddy.db.characters.chars, Buddy.db.characters.filters, Buddy.db.characters.sort
Buddy.db.characters.chars={}
Buddy.db.characters.filters={}
Buddy.db.characters.sort={key='name',asc=true}
local now, playerName, playerLevel, xpmax, rested, inInn = 10000000, 'Buddy', 20, 1000, 200, true
local reads, queue, secret = 0, {}, {}
time=function() return now end
UnitFullName=function() return playerName,'Realm' end
UnitLevel=function() return playerLevel end
UnitXPMax=function() reads=reads+1;return xpmax end
GetXPExhaustion=function() reads=reads+1;return rested end
IsResting=function() return inInn end
GetMaxPlayerLevel=function() return 60 end
issecretvalue=function(value) return value==secret end
C_Timer.After=function(_,fn) queue[#queue+1]=fn end
local function fire(event,unit)
 charEvents.scripts.OnEvent(charEvents,event,unit)
 while #queue>0 do table.remove(queue,1)() end
end
local function restedText(name)
 characters.Render()
 for _,row in ipairs(characters.rows) do
  if row:IsShown() and row.cells[1].text==name..' Realm' then return row.cells[9].text end
 end
 error('missing character row: '..name)
end
fire('PLAYER_LOGIN')
local first=Buddy.db.characters.chars['Realm-Buddy']
assert(first.xpmax==1000 and first.rested_xp==200 and first.rested_inn==true)
assert(restedText('Buddy')=='20.0%','current character uses live XP')
local sampleTime=first.rested_ts
now=now+8*3600
xpmax,rested,playerLevel,inInn=0,nil,0,false
reads=0
fire('PLAYER_LOGOUT')
assert(reads==0,'logout must not query cleared XP APIs')
assert(first.xpmax==1000 and first.rested_xp==200 and first.restxp_pct==20 and first.level==20,
 'logout erased the last valid XP snapshot')
assert(first.rested_ts==sampleTime and first.rested_logout==now and first.rested_inn==true,
 'logout must retain snapshot and location, with a separate offline start')
playerName,playerLevel,xpmax,rested='Second',20,1000,0
fire('PLAYER_LOGIN')
assert(restedText('Buddy')=='~20.0%','online time must not be counted as offline rest')
now=now+86400
assert(restedText('Buddy')=='~35.0%','one offline day in an inn adds 15 percentage points')
assert(restedText('Second')=='0.0%','current character must never receive estimated offline XP')
assert(first.rested_xp==200 and first.rested_ts==sampleTime,'render must not compound or overwrite snapshots')
-- Early login data and secret values preserve the snapshot; entering world retries it.
playerName,xpmax='Buddy',0
fire('PLAYER_LOGIN')
assert(first.rested_xp==200 and first.rested_ts==sampleTime and first.rested_logout~=nil,
 'incomplete login overwrote the offline snapshot')
fire('PLAYER_LOGOUT')
assert(first.rested_logout==sampleTime+8*3600,'failed login must not reset offline accrual')
xpmax,rested,inInn=1000,350,true
fire('PLAYER_ENTERING_WORLD')
assert(first.rested_xp==350 and first.rested_ts==now and first.rested_logout==nil)
local goodTime=now
now=now+60
xpmax=secret
fire('PLAYER_XP_UPDATE','player')
assert(first.rested_xp==350 and first.rested_ts==goodTime)
xpmax,rested=1000,secret
fire('UPDATE_EXHAUSTION')
assert(first.rested_xp==350 and first.rested_ts==goodTime)
rested=nil
fire('UPDATE_EXHAUSTION')
assert(first.rested_xp==0 and restedText('Buddy')=='0.0%','nil exhaustion with valid XP is genuinely zero')
inInn=false
fire('PLAYER_UPDATE_RESTING')
assert(first.rested_inn==false,'leaving an inn must update the saved rest rate')
fire('PLAYER_LOGOUT')
playerName,rested='Second',0
fire('PLAYER_LOGIN')
now=now+86400
assert(restedText('Buddy')=='~3.8%','one day outside an inn uses the quarter rate')
-- Unknown/corrupt snapshots, caps, clock skew and sorting use the same displayed value.
local function alt(name,amount,inn,age)
 local value={name=name,realm='Realm',class='HUNTER',level=20,xpmax=1000,
  rested_xp=amount,rested_ts=now-(age or 86400),rested_inn=inn,restxp_pct=0}
 Buddy.db.characters.chars['Realm-'..name]=value
 return value
end
Buddy.db.characters.chars={['Realm-Second']=Buddy.db.characters.chars['Realm-Second']}
local zero=alt('Zero',0,true)
assert(restedText('Zero')=='~15.0%','offline accrual must start even at zero rested XP')
local missing=alt('Missing',0,true);missing.xpmax=0
assert(restedText('Missing')=='—','missing XP is unknown, not a false zero')
local unknown=alt('Unknown',250,nil)
assert(restedText('Unknown')=='~25.0%','old snapshots without a rest location must not invent accrual')
local future=alt('Future',100,true,-86400)
assert(restedText('Future')=='~10.0%','clock skew cannot subtract rested XP')
local cap=alt('Cap',0,true,20*86400)
assert(restedText('Cap')=='~150.0%','base estimate stops at the normal cap')
local bonus=alt('Bonus',1800,true)
assert(restedText('Bonus')=='~180.0%','observed bonuses above the base cap must survive')
Buddy.db.characters.sort={key='restxp_pct',asc=false}
characters.Render()
assert(characters.rows[1].cells[1].text=='Bonus Realm' and characters.rows[2].cells[1].text=='Cap Realm',
 'rested sorting must use estimates, not stale stored percentages')
assert(zero.rested_xp==0 and cap.rested_xp==0,'repeated rendering changed saved values')
playerLevel,xpmax=60,0
fire('PLAYER_XP_UPDATE','player')
assert(restedText('Second')=='—','level-capped characters must not gain fictitious rest')
Buddy.db.characters.chars, Buddy.db.characters.filters, Buddy.db.characters.sort=oldChars,oldFilters,oldSort
time,UnitFullName,UnitLevel=originalTime,originalName,originalLevel
UnitXPMax,GetXPExhaustion,IsResting,GetMaxPlayerLevel=originalXP,originalRest,originalResting,originalMaxLevel
issecretvalue,C_Timer.After=originalSecret,originalAfter
fire('PLAYER_LOGIN')
print('PASS: rested XP survives logout/login, tracks rest location, estimates offline time and sorts correctly')
-- Zentrale Tooltip-Hilfe überspringt nicht zugängliche Blizzard-Frames.
local oldHide=GameTooltip.Hide
GameTooltip.IsForbidden=function() return true end
GameTooltip.Hide=function() error('forbidden tooltip touched') end
assert(pcall(Buddy.HideTooltip))
GameTooltip.IsForbidden=function() return false end;GameTooltip.Hide=oldHide
print('PASS: shared tooltip guard')

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
