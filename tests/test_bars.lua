local loadfile = dofile("tests/load_locales.lua")
-- Vertrags-/Zustandstests für die Aktionsleisten-Vorlagen.
-- Kein Client, keine Taint-Simulation: geprüft werden Guards, Profile und Ereignisfluss.
local secret=setmetatable({},{__tostring=function() error('secret formatted') end})
function issecretvalue(v) return rawequal(v,secret) end

local queue={}
local now=10
function GetTime() return now end
C_Timer={After=function(_,fn) queue[#queue+1]=fn end}
local function drain()
    local count=0
    while #queue>0 do
        local fn=table.remove(queue,1);fn();count=count+1
        assert(count<300,'timer loop')
    end
end

local methods={}
function methods:SetChecked(value) self.checked=value end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function methods:RegisterEvent(k) self.events[k]=true end
function methods:UnregisterEvent(k) self.events[k]=nil end
function methods:IsShown() return self.shown end
function methods:SetShown(v) self.shown=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetText(v) self.text=v end
function methods:GetText() return self.text end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:SetJustifyH(v) self.justify=v end
function methods:SetFrameStrata(v) self.strata=v end
function methods:SetFrameLevel(v) self.level=v end
function methods:GetWidth() return self.width or 100 end
function methods:GetHeight() return self.height or 24 end
function methods:CreateTexture() return setmetatable({scripts={},events={},points={},shown=true},{__index=function(_,k) return methods[k] or function() end end}) end
function methods:CreateFontString() return setmetatable({scripts={},events={},points={},shown=true},{__index=function(_,k) return methods[k] or function() end end}) end
local frames={}
local function object()
    local f=setmetatable({scripts={},events={},points={},shown=true},{__index=function(_,k) return methods[k] or function() end end})
    frames[#frames+1]=f
    return f
end
function CreateFrame() return object() end
UIParent=object();UISpecialFrames={};SlashCmdList={}

local popup
StaticPopupDialogs={}
function StaticPopup_Show(key,prompt,_,data)
    popup={key=key,prompt=prompt,data=data}
end
local function answerPopup(accept)
    local current=assert(popup,'confirmation is open')
    popup=nil
    if accept then StaticPopupDialogs[current.key].OnAccept(nil,current.data) end
end

local function fire(event,arg)
    for _,frame in ipairs(frames) do
        if frame.events[event] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame,event,arg)
        end
    end
end

-- Forever hat keine Spezialisierungs-API.
local class="HUNTER"
function UnitClass() return class=="HUNTER" and "Jäger" or class,class end
function UnitGroupRolesAssigned() error("role must be selected manually") end
function UnitLevel() return 5 end
function UnitGUID() return "Player-1-ABC" end
function UnitFullName() return "Buddy","Realm" end
function GetRealmName() return "Realm" end
local clicks={{type=1,actionID=133,button="LeftButton",modifiers=0}}
C_ClickBindings={
    GetProfileInfo=function() return clicks end,
    SetProfileByInfo=function(info) clicks=info end,
    ResetCurrentProfile=function() clicks={} end,
}
function hooksecurefunc(api,key,hook)
    local original=api[key]
    api[key]=function(...) original(...);hook(...) end
end
function GetServerTime() return 1000 end

local combat,bonus=false,false
function InCombatLockdown() return combat end
function HasBonusActionBar() return bonus end
function HasVehicleActionBar() return false end
function HasOverrideActionBar() return false end
function HasTempShapeshiftActionBar() return false end
function HasPossessBar() return false end
function HasAlternateActionBar() return false end
NUM_ACTIONBAR_SLOTS=180

-- Aktionsleistenmodell: Pickup/Place bewegen nur den Cursor.
local bar,cursor={},nil
local macroIndexes={Raid=1,Extra=19,Heal=20}
local function clone(entry)
    if not entry then return end
    return {action=entry.action,value=entry.value}
end
function GetActionInfo(slot)
    local entry=bar[slot]
    if not entry then return end
    if entry.action=="macro" then return "macro",entry.index or macroIndexes[entry.value] end
    if entry.action=="equipmentset" then return "equipmentset",entry.value end
    return entry.action,entry.value
end
function PickupAction(slot)
    cursor=clone(bar[slot]);bar[slot]=nil
    fire("ACTIONBAR_SLOT_CHANGED",slot)
end
function PlaceAction(slot)
    if not cursor then return end
    bar[slot]=clone(cursor);cursor=nil
    fire("ACTIONBAR_SLOT_CHANGED",slot)
end
function ClearCursor() cursor=nil end
function GetCursorInfo() return cursor end

local known={[100]=true,[1943]=true,[133]=true}
C_Spell={PickupSpell=function(id)
    if known[id] then cursor={action="spell",value=id} end
end}
C_Item={PickupItem=function(id) cursor={action="item",value=id} end}
local macroNames={[1]="Raid",[19]="Extra",[20]="Heal"}
local macroBodies={[19]="/cast Test", [20]="/cast Heal"}
local characterMacros=2
function GetNumMacros() return 1,characterMacros end
function GetMacroInfo(index) return macroNames[index],134400,macroBodies[index] end
function CreateMacro(name,icon,body,perCharacter)
    assert(perCharacter and not combat and icon==134400)
    characterMacros=characterMacros+1
    local index=MAX_ACCOUNT_MACROS+characterMacros
    macroNames[index],macroBodies[index]=name,body
    return index
end
function PickupMacro(index)
    local name=macroNames[index]
    if name then cursor={action="macro",index=index,value=name} end
end
MAX_ACCOUNT_MACROS=18

local setIDs={Raid=5}
local setNames={[5]="Raid"}
C_EquipmentSet={
    GetEquipmentSetID=function(name) return setIDs[name] end,
    GetEquipmentSetInfo=function(id) return setNames[id] end,
    PickupEquipmentSet=function(id)
        local name=setNames[id]
        if name then cursor={action="equipmentset",value=name} end
    end,
}
Enum={ClickBindingType={Macro=2},SpellBookSpellBank={Player=0,Pet=1},SpellBookItemType={Spell=1,Flyout=4}}
C_SpellBook={
    IsSpellKnownOrInSpellBook=function(id) return known[id]==true end,
    GetNumSpellBookSkillLines=function() return 1 end,
    GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=2} end,
    GetSpellBookItemInfo=function(slot)
        if slot==1 then return {itemType=4,actionID=999} end
        return {itemType=1,actionID=100}
    end,
    PickupSpellBookItem=function(slot)
        if slot==1 then cursor={action="flyout",value=999} end
    end,
}

local messages={}
local Buddy={db={bars={}},char={actions={PALADIN={actions={[1]={action="spell",value=1943}}}}},loaded={}}
function Buddy.Message(text) messages[#messages+1]=text end
local toggled=false
function Buddy.Toggle() toggled=true end
assert(loadfile('Style.lua'))('Foreverbuddy',Buddy)
assert(loadfile('Modules/Bars/Game.lua'))('Foreverbuddy',Buddy)
assert(loadfile('Modules/Bars/Main.lua'))('Foreverbuddy',Buddy)
Buddy.LoadBars()
local B=Buddy.Bars
assert(B and #B.slots==180 and B.slots[1]==1 and B.slots[120]==120 and B.slots[121]==121
    and B.slots[180]==180,'supported slot list covers all action slots')
assert(B.ValidSlot(1) and B.ValidSlot(72) and B.ValidSlot(120) and B.ValidSlot(121)
    and B.ValidSlot(144) and B.ValidSlot(145) and B.ValidSlot(180) and not B.ValidSlot(181)
    and not B.ValidSlot(0) and not B.ValidSlot(1.5),'slot boundaries end at the last action slot')
assert(B.Settable(120) and not B.Settable(121) and not B.Settable(144) and B.Settable(145)
    and not B.Settable(181),'possess and reserved slots are read-only')

-- Anmeldung ohne Vorlage darf keinen Fehler erzeugen.
fire('PLAYER_LOGIN');drain()
assert(B.ready and B.db.automatic==true,'login establishes context and enables automatic mode')
local backup=Buddy.char.actions.HUNTER
assert(backup and backup.actions[120].action=='empty' and backup.clickBindings[1].actionID==133,
    'login backs up bars and clicks at level 5 without specialization or role')
assert(Buddy.char.actions.PALADIN.actions[1].value==1943,'login preserves other classes')

-- Ausgangsbelegung speichern. Platz 4 ist ein Charaktermakro, Platz 13 ein
-- accountweites Makro, das vollständig ignoriert werden muss.
bar[1]={action="spell",value=133}
bar[2]={action="item",value=5512}
bar[4]={action="macro",index=19,value="Extra"}
bar[5]={action="flyout",value=999}
bar[6]={action="unknown",value=1}
bar[7]={action="equipmentset",value="Raid"}
bar[13]={action="macro",index=1,value="Raid"}
assert(B.Save(true),'explicit save succeeds')
local profile=Buddy.db.bars.library.HUNTER.default
assert(profile and profile.actions[1].value==133 and profile.actions[2].value==5512,'spell and item saved')
assert(profile.actions[3].action=='empty' and profile.actions[4].value=='Extra','empty and character macro saved')
assert(profile.actions[13]==nil,'account macro is not stored')
assert(not B.note:find('nicht lesbar'),'account macro is not reported as unreadable')
assert(B.note:find('allgemeines Makro ignoriert'),'account macro is reported as ignored')
assert(profile.actions[5].action=='flyout' and profile.actions[7].value=='Raid','flyout and equipment set saved')
assert(profile.actions[6].action=='keep','unknown action type is never stored as empty')
assert(profile.specialization==nil and profile.editor=='Buddy-Realm','profile metadata')
assert(messages[#messages]:find('gespeichert'),'save announces success')

-- Makrobereich: 1..18 accountweit, ab 19 charakterspezifisch.
assert(B.MacroScope(1)=='account' and B.MacroScope(18)=='account'
    and B.MacroScope(19)=='character' and B.MacroScope(20)=='character'
    and B.MacroScope(0)==nil and B.MacroScope(1.5)==nil,
    'macro scope uses the account/character boundary')
local ignoredEntry=select(1,B.Read(13))
assert(ignoredEntry and ignoredEntry.action=='ignored','account macro read is marked ignored')
local numMacros=GetNumMacros
GetNumMacros=function() error('blocked') end
local stillIgnored=select(1,B.Read(13))
assert(stillIgnored and stillIgnored.action=='ignored','account scope does not depend on macro counts')
GetNumMacros=numMacros
ClearCursor()
assert(not B.Pick({action='macro',value='Raid'}) and cursor==nil,
    'account macro is never picked as a replacement')
assert(B.Pick({action='macro',value='Extra'}) and cursor and cursor.index==19,
    'character macro is picked from the character range')
ClearCursor()

-- Geschütztes Makro-Icon/Text darf den Makronamen nicht mit verwerfen.
local macroInfo=GetMacroInfo
GetMacroInfo=function(index) return macroNames[index],secret,"/run" end
local macroEntry=select(1,B.Read(4))
assert(macroEntry and macroEntry.action=='macro' and macroEntry.value=='Extra',
    'macro name is read although icon and text are secret')
GetMacroInfo=macroInfo

-- Bevorzugt wird die aktuelle C_Macro-API, der GetMacroInfo-Rückfall bleibt.
C_Macro={GetMacroName=function(index) return macroNames[index] end}
local cmacroEntry=select(1,B.Read(4))
assert(cmacroEntry and cmacroEntry.value=='Extra','C_Macro.GetMacroName is used when available')
C_Macro=nil

-- Automatisches Speichern eines geänderten Platzes.
now=now+5
bar[1]={action="spell",value=100}
fire('ACTIONBAR_SLOT_CHANGED',1);drain()
assert(backup.actions[1].value==100,'changed slot is saved automatically')

-- Kampf und Sonderleiste verschieben das Speichern, ohne zu verlieren.
combat=true
bar[9]={action="spell",value=1943}
fire('ACTIONBAR_SLOT_CHANGED',9);drain()
assert(backup.actions[9].action=='empty','no profile write during combat')
combat=false;now=now+5
fire('PLAYER_REGEN_ENABLED');drain()
assert(backup.actions[9].value==1943,'pending change is saved after combat')

bonus=true
bar[3]={action="spell",value=133}
fire('ACTIONBAR_SLOT_CHANGED',3);drain()
assert(backup.actions[3].action=='empty','no profile write during a special bar')
bonus=false;now=now+5
fire('UPDATE_BONUS_ACTIONBAR');drain()
assert(backup.actions[3].value==133,'pending change is saved after leaving the special bar')

-- Vorlage laden: verfügbare Typen wiederherstellen, leere Plätze leeren,
-- unbekannte und nicht verfügbare Einträge auslassen.
bar[1]={action="spell",value=1943}
bar[2]=nil
bar[3]={action="spell",value=100}
bar[4]=nil
bar[5]=nil
bar[6]={action="unknown",value=1}
bar[7]=nil
bar[8]={action="spell",value=100}
bar[12]={action="spell",value=100}
profile.actions[8]={action="spell",value=777} -- auf diesem Charakter nicht erlernbar
now=now+5
local ok=B.Apply(true)
assert(ok,'profile applies')
assert(bar[1].value==133 and bar[2].value==5512,'spell and item restored')
assert(bar[3]==nil and bar[12]==nil,'saved spell restored; empty profile slot clears the bar slot')
assert(bar[4].value=='Extra' and bar[5].action=='flyout','macro and flyout restored')
assert(bar[7].action=='equipmentset' and bar[7].value=='Raid','equipment set restored by name')
assert(bar[6].action=='unknown','unsupported entry left untouched')
assert(bar[8].value==100,'unavailable spell skipped without touching the slot')
assert(B.note:find('8 Plätze geladen') and B.note:find('2 ausgelassen'),'apply summary counts changed/skipped')
assert(profile.actions[8].value==777,'skipped entry stays in the profile')
assert(profile.actions[1].value==133,'apply does not overwrite its own profile')

-- Alte Vorlagen mit accountweiten Makros bleiben ladbar: die Einträge werden
-- übersprungen, vorhandene Aktionen bleiben stehen. Fehlende Charaktermakros
-- werden dagegen einzeln genannt.
profile.actions[13]={action="macro",value="Raid"}
profile.actions[14]={action="macro",value="Gelöscht"}
bar[13]={action="spell",value=100}
bar[14]={action="spell",value=1943}
now=now+5
assert(B.Apply(true),'profile with account and missing macros still applies')
assert(bar[13].value==100,'account macro entry does not overwrite the existing action')
assert(bar[14].value==1943,'missing character macro entry does not overwrite the existing action')
assert(B.note:find('3 ausgelassen') and B.note:find('fehlende Charakter%-Makros: Gelöscht'),
    'missing character macro is reported by name')
assert(B.note:find('1 allgemeines Makro ignoriert'),'account macro is counted as ignored, not skipped')
assert(not B.note:find('Raid'),'account macro name is not reported as missing')
profile.actions[13]=nil
profile.actions[14]=nil

-- Automatisches Speichern entfernt einen alten Charaktermakro-Eintrag, sobald
-- der Platz durch ein accountweites Makro ersetzt wird.
now=now+5
bar[15]={action="macro",index=20,value="Heal"}
fire('ACTIONBAR_SLOT_CHANGED',15);drain()
assert(backup.actions[15].value=="Heal",'character macro is saved automatically')
now=now+5
bar[15]={action="macro",index=1,value="Raid"}
fire('ACTIONBAR_SLOT_CHANGED',15);drain()
assert(backup.actions[15]==nil,'account macro removes the old stored entry')
now=now+5
bar[15]=nil
fire('ACTIONBAR_SLOT_CHANGED',15);drain()
assert(backup.actions[15] and backup.actions[15].action=='empty','empty slot is stored again')

-- Spezialisierungsereignisse haben keinen Einfluss auf die gemeinsame Vorlage.
now=now+5
fire('PLAYER_SPECIALIZATION_CHANGED','player');drain()
assert(B.Profile()==profile)

-- Klickzauber werden kopiert, wiederhergestellt und automatisch gespeichert.
assert(profile.clickBindings[1].actionID==133 and profile.clickBindings~=clicks)
clicks[1].actionID=1943
assert(profile.clickBindings[1].actionID==133,'client mutation does not alter saved clicks')
assert(B.Apply(true) and clicks[1].actionID==133,'click bindings restored with bars')
assert(clicks~=profile.clickBindings,'apply passes a copy')
C_ClickBindings.SetProfileByInfo({{type=1,actionID=100,button="RightButton",modifiers=2}});drain()
assert(backup.clickBindings[1].actionID==100,'click-only edit automatically saved')
combat=true
C_ClickBindings.SetProfileByInfo({});drain()
assert(#backup.clickBindings==1,'click changes wait during combat')
combat=false
fire('PLAYER_REGEN_ENABLED');drain()
assert(#backup.clickBindings==0,'empty click profile saved after combat')
C_ClickBindings.SetProfileByInfo({{type=1,actionID=100,button="RightButton",modifiers=0}});drain()
C_ClickBindings.ResetCurrentProfile();drain()
assert(#backup.clickBindings==0,'reset automatically saved')
clicks={{type=1,actionID=133,button="LeftButton",modifiers=0}}
assert(B.Apply(true) and clicks[1].actionID==133,'automatic changes leave the template intact')
local clickAPI=C_ClickBindings
C_ClickBindings=nil
assert(B.Apply(true) and B.note:find('Klickzauber konnten nicht geladen'),
    'missing click API reports partial load while bars still load')
C_ClickBindings=clickAPI
local oldClicks=profile.clickBindings
profile.clickBindings=nil
clicks={{type=1,actionID=133,button="LeftButton",modifiers=0}}
assert(B.Apply(true) and #clicks==1,'legacy profile leaves clicks alone')
profile.clickBindings=oldClicks
assert(not B.CopyClickBindings({{type=1,actionID=secret,button="LeftButton",modifiers=0}}),
    'secret click data is rejected')
assert(not B.CopyClickBindings({[2]={type=1,actionID=133,button="LeftButton",modifiers=0}}),
    'sparse click data is rejected')

-- Automatik aus: keine automatischen Schreibläufe; Einschalten lädt erneut.
B.menuButton=Buddy.Style.Button(object())
B.SetAutomatic(false)
assert(B.menuButton.text=='Aktionsleisten · Automatik AUS','menu row reflects state')
now=now+5
bar[1]={action="spell",value=1943}
fire('ACTIONBAR_SLOT_CHANGED',1);drain()
assert(backup.actions[1].value==133,'automatic off leaves the backup untouched')
B.SetAutomatic(true);drain()
assert(B.menuButton.text=='Aktionsleisten · Automatik AN' and bar[1].value==1943 and backup.actions[1].value==1943,
    'enabling automatic mode backs up the current layout')

-- Menübereich im bestehenden Fenster.
local fittedHeight
local menuHeight=B.BuildMenu(object(),-100,function(height) fittedHeight=height end)
assert(menuHeight==B.MENU_HEIGHT and B.menuStatus.text:find('Automatik AN')
    and B.menuStatus.text:find('Jäger'),'inline menu shows state and specialization')
assert(B.menuNote.text==B.note,'inline menu shows the last note')
B.menuStatus.GetStringHeight=function() return 22 end
B.menuNote.GetStringHeight=function() return 44 end
B.RefreshMenu()
assert(B.menu.height==168 and fittedHeight==168,'wrapped text grows the inline menu and hub together')
local saveButton,loadButton
for _,frame in ipairs(frames) do
    if frame.text=='Vorlage speichern' then saveButton=frame end
    if frame.text=='Vorlage laden' then loadButton=frame end
end
assert(saveButton and loadButton and B.roleCheckboxes.TANK and B.roleCheckboxes.HEALER
    and B.roleCheckboxes.DAMAGER,'all inline controls exist')
-- Kommandos
messages={}
SlashCmdList.FOREVERBUDDYBARS('status')
assert(messages[#messages]:find('Automatik AN') and messages[#messages]:find('Vorlage vorhanden'))
SlashCmdList.FOREVERBUDDYBARS('')
assert(toggled,'command without argument opens the central menu')

-- Belegter Cursor, fehlende API und Kampf blockieren das Laden sauber.
cursor={action='spell',value=1}
assert(not B.Apply(true) and B.note:find('Mauszeiger'),'occupied cursor blocks apply')
ClearCursor()
local place=PlaceAction
PlaceAction=nil
local missing=not B.Apply(true)
assert(missing and B.note:find('Leisten%-API fehlt'),'missing API blocks apply')
PlaceAction=place
combat=true;bar[1]={action="spell",value=1943}
assert(not B.Apply(true) and B.pending and B.note:find('Kampfende'),'apply is deferred in combat')
combat=false;now=now+5
fire('PLAYER_REGEN_ENABLED');drain()
assert(not B.pending and bar[1].value==133,'deferred apply resumes after combat')

-- Kampfbeginn mitten im Laden: der Rest wird nach dem Kampfende nachgeholt.
local expected=Buddy.db.bars.library.HUNTER.default.actions[2]
bar[1]={action="spell",value=1};bar[2]={action="spell",value=2}
local realPlace=PlaceAction;local placeCalls=0
PlaceAction=function(slot)
    placeCalls=placeCalls+1
    if placeCalls==1 then combat=true end
    return realPlace(slot)
end
assert(not B.Apply(true) and B.pending,'apply interrupted by combat is queued')
PlaceAction=realPlace
combat=false;now=now+5
assert(bar[2].value==2,'interrupted apply stops before the remaining slots')
fire('PLAYER_REGEN_ENABLED');drain()
assert(not B.pending and bar[2].action==expected.action and bar[2].value==expected.value,
    'interrupted apply completes after combat')

-- Klassen-/Haltungsleisten werden geladen, Besitz-/reservierte Plätze nur gespeichert.
bar[73]={action="spell",value=100};bar[121]={action="spell",value=7}
assert(B.Save(true),'save covers class and possess slots')
local saved=Buddy.db.bars.library.HUNTER.default
assert(saved.actions[73].value==100,'class bar slot is saved')
assert(saved.actions[121].value==7 and not B.Settable(121),'possess slot is stored but read-only')
bar[73]={action="spell",value=5}
assert(B.Apply(true) and bar[73].value==100,'class bar slot is loaded')
assert(bar[121].value==7,'possess slot is never written')

-- Geheime Werte: weder Speichern noch automatisches Speichern verwenden sie.
local before=Buddy.db.bars.library.HUNTER.default
bar[10]={action="secret",value=secret}
assert(B.Save(true),'save skips a secret slot instead of aborting')
local saved=Buddy.db.bars.library.HUNTER.default
assert(saved and saved~=before and saved.actions[10]==before.actions[10],'secret slot retains its previous value')
assert(saved.actions[1] and saved.actions[1].value==133,'other slots are still saved')
assert(B.note:find('nicht lesbar') and B.note:find('10') and B.note:find('geschützter Wert'),'note names the unreadable slot and reason')
bar[10]=nil
now=now+5
bar[10]={action="secret",value=secret}
fire('ACTIONBAR_SLOT_CHANGED',10);drain()
assert(Buddy.db.bars.library.HUNTER.default==saved,'automatic save ignores secret slot data')
bar[10]=nil
local getInfo=GetActionInfo
GetActionInfo=function() error('blocked') end
assert(not B.Save(true) and B.note:find('kein Leistenplatz lesbar'),'save aborts when no slot is readable')
GetActionInfo=getInfo

-- Ein Lesefehler darf die zuletzt gespeicherten Klickzauber nicht löschen.
local retained=saved.clickBindings
local readClicks=C_ClickBindings.GetProfileInfo
C_ClickBindings.GetProfileInfo=function() error('unavailable') end
assert(B.Save(true) and B.Profile().clickBindings==retained,'failed read preserves click bindings')
assert(B.note:find('Klickzauber nicht lesbar'),'failed read reported')
saved=B.Profile()
C_ClickBindings.GetProfileInfo=readClicks

-- Anmeldung mit vorhandener Vorlage lädt automatisch.
now=now+5
bar[1]={action="spell",value=1943}
B.ready=false
fire('PLAYER_LOGIN');drain()
assert(B.ready and bar[1].value==1943 and backup.actions[1].value==1943,'login backs up instead of applying the manual template')

-- Logout schreibt einen noch offenen automatischen Änderungsstand.
now=now+5
bar[11]={action="spell",value=100}
fire('ACTIONBAR_SLOT_CHANGED',11);drain()
assert(backup.actions[11].value==100,'last change saved before logout')
assert(B.events.events.PLAYER_LOGOUT and not B.events.events.PLAYER_SPECIALIZATION_CHANGED
    and B.events.events.ACTIONBAR_SLOT_CHANGED,'required events are registered')

print('PASS: bar profiles, automatic save/load, click bindings, guards, secrets and inline menu')

-- Manuelle Auswahl und gemeinsame Vorlagen funktionieren bereits auf Stufe 5.
local function clickRole(role)
    local check=B.roleCheckboxes[role]
    check.checked=not check.checked -- UICheckButtonTemplate schaltet vor OnClick um.
    check:GetScript('OnClick')(check)
    assert(Buddy.char.barRole==role and B.Role()==role)
    for key,button in pairs(B.roleCheckboxes) do
        assert(button.checked==(key==role),'exactly one role is checked')
    end
end
local function setLayout(value)
    bar[120]={action='spell',value=value}
    C_ClickBindings.SetProfileByInfo({{type=1,actionID=value,button='RightButton',modifiers=2}})
    drain()
end
local function expectLayout(value)
    assert(bar[120].value==value and clicks[1].actionID==value,'bars and native clicks match')
end
local saveRole=saveButton:GetScript('OnClick')
local loadRole=loadButton:GetScript('OnClick')
assert(not saveRole() and not loadRole() and not popup and B.note:find('Rolle auswählen'))
for _,entry in ipairs({{'TANK',100},{'HEALER',133},{'DAMAGER',1943}}) do
    clickRole(entry[1]);setLayout(entry[2])
    assert(saveRole() and not popup,('new role template is saved immediately: '..tostring(B.note)))
end
local hunter=Buddy.db.bars.library.HUNTER
assert(hunter.default==saved,'legacy class template remains independently available')
clickRole('DAMAGER')
setLayout(100)
saveRole()
assert(popup.prompt:find('Schaden') and hunter.DAMAGER.actions[120].value==1943)
answerPopup(false)
assert(hunter.DAMAGER.actions[120].value==1943,'cancelled overwrite keeps template')
saveRole();answerPopup(true)
assert(hunter.DAMAGER.actions[120].value==100,'confirmed overwrite saves layout')
local beforeDamage=hunter.DAMAGER
local readRoleClicks=C_ClickBindings.GetProfileInfo
C_ClickBindings.GetProfileInfo=function() error('temporarily unavailable') end
saveRole();answerPopup(true)
assert(hunter.DAMAGER==beforeDamage,'unreadable click bindings preserve the whole role template')
C_ClickBindings.GetProfileInfo=readRoleClicks

class='PALADIN'
clickRole('TANK');setLayout(133)
assert(not loadRole() and not popup and B.note:find('Keine Vorlage für diese Rolle'))
assert(saveRole())
assert(Buddy.db.bars.library.PALADIN.TANK.actions[120].value==133
    and hunter.TANK.actions[120].value==100,'the same role is independent across classes')
assert(Buddy.char.actions.PALADIN.actions[120].value==133)
class='HUNTER'
Buddy.db.bars.roleSync=true -- Einstellung aus älterer Version.
clickRole('HEALER')
fire('PLAYER_ROLES_ASSIGNED');drain()
assert(not B.events.events.PLAYER_ROLES_ASSIGNED)
setLayout(1943)
clickRole('TANK');expectLayout(1943)
clickRole('HEALER');expectLayout(1943)
loadRole();expectLayout(1943)
answerPopup(false);expectLayout(1943)
loadRole();clickRole('TANK');answerPopup(true);expectLayout(1943)
clickRole('HEALER')
combat=true
loadRole();answerPopup(true);expectLayout(1943)
assert(B.pending)
combat=false
fire('PLAYER_REGEN_ENABLED');drain()
expectLayout(133)
assert(not B.pending and backup.actions[120].value==133)

-- Gleiche Klasse, anderer Charakter: Rollenwahl bleibt lokal, Vorlage ist gemeinsam.
bar[4]={action='macro',value='Extra'}
bar[5]={action='macro',value='Raid'}
clicks={
    {type=2,actionID=19,button='LeftButton',modifiers=0},
    {type=2,actionID=1,button='MiddleButton',modifiers=0},
}
saveRole();answerPopup(true)
assert(hunter.HEALER.actions[4].macroBody=="/cast Test")
assert(hunter.HEALER.actions[5]==nil and #hunter.HEALER.clickBindings==1
    and hunter.HEALER.clickBindings[1].actionID==0)
local originalChar=Buddy.char
Buddy.char={actions={}}
B.RefreshMenu()
assert(not B.Role() and not B.roleCheckboxes.HEALER.checked)
clickRole('HEALER')
macroNames[19],macroBodies[19]='Other','/cast Other'
bar[4]=nil
clicks={{type=2,actionID=1,button='MiddleButton',modifiers=0}}
loadRole();answerPopup(true);drain()
assert(bar[4].value=='Extra' and macroBodies[21]=='/cast Test' and characterMacros==3)
assert(clicks[1].actionID==1 and clicks[2].actionID==21,'click macros use the destination macro index')
loadRole();answerPopup(true)
assert(characterMacros==3,'loading again reuses the restored macro')
clickRole('DAMAGER')
Buddy.char=originalChar
B.RefreshMenu()
assert(B.Role()=='HEALER' and B.roleCheckboxes.HEALER.checked,'original character retains its selection')

print('PASS: manual roles at level 5, confirmations, class and character isolation, native clicks and macros')
