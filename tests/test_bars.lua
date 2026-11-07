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

local function fire(event,arg)
    for _,frame in ipairs(frames) do
        if frame.events[event] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame,event,arg)
        end
    end
end

-- Umgebung: eine Spielfigur mit zwei Spezialisierungen.
local specIndex=1
local specs={[1]={2544,"Überleben"},[2]={2533,"Treffsicherheit"}}
function UnitClass() return "Jäger","HUNTER" end
function UnitGUID() return "Player-1-ABC" end
function UnitFullName() return "Buddy","Realm" end
function GetRealmName() return "Realm" end
function GetSpecialization() return specIndex end
function GetSpecializationInfo(index)
    local entry=specs[index]
    if entry then return entry[1],entry[2],"Beschreibung",1 end
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
function GetNumMacros() return 1,2 end
function GetMacroInfo(index) return macroNames[index] end
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
Enum={SpellBookSpellBank={Player=0,Pet=1},SpellBookItemType={Spell=1,Flyout=4}}
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
local Buddy={db={bars={}},loaded={}}
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
assert(B.note:find('Keine Vorlage'),'missing profile reported in menu note')
assert(B.class=='HUNTER' and B.spec==2544)

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
local profile=Buddy.db.bars.library.HUNTER[2544]
assert(profile and profile.actions[1].value==133 and profile.actions[2].value==5512,'spell and item saved')
assert(profile.actions[3].action=='empty' and profile.actions[4].value=='Extra','empty and character macro saved')
assert(profile.actions[13]==nil,'account macro is not stored')
assert(not B.note:find('nicht lesbar'),'account macro is not reported as unreadable')
assert(B.note:find('allgemeines Makro ignoriert'),'account macro is reported as ignored')
assert(profile.actions[5].action=='flyout' and profile.actions[7].value=='Raid','flyout and equipment set saved')
assert(profile.actions[6].action=='keep','unknown action type is never stored as empty')
assert(profile.specialization=='Überleben' and profile.editor=='Buddy-Realm','profile metadata')
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
assert(profile.actions[1].value==100,'changed slot is saved automatically')

-- Kampf und Sonderleiste verschieben das Speichern, ohne zu verlieren.
combat=true
bar[9]={action="spell",value=1943}
fire('ACTIONBAR_SLOT_CHANGED',9);drain()
assert(profile.actions[9].action=='empty','no profile write during combat')
combat=false;now=now+5
fire('PLAYER_REGEN_ENABLED');drain()
assert(profile.actions[9].value==1943,'pending change is saved after combat')

bonus=true
bar[3]={action="spell",value=133}
fire('ACTIONBAR_SLOT_CHANGED',3);drain()
assert(profile.actions[3].action=='empty','no profile write during a special bar')
bonus=false;now=now+5
fire('UPDATE_BONUS_ACTIONBAR');drain()
assert(profile.actions[3].value==133,'pending change is saved after leaving the special bar')

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
assert(bar[1].value==100 and bar[2].value==5512,'spell and item restored')
assert(bar[3].value==133 and bar[12]==nil,'saved spell restored; empty profile slot clears the bar slot')
assert(bar[4].value=='Extra' and bar[5].action=='flyout','macro and flyout restored')
assert(bar[7].action=='equipmentset' and bar[7].value=='Raid','equipment set restored by name')
assert(bar[6].action=='unknown','unsupported entry left untouched')
assert(bar[8].value==100,'unavailable spell skipped without touching the slot')
assert(B.note:find('7 Plätze geladen') and B.note:find('2 ausgelassen'),'apply summary counts changed/skipped')
assert(profile.actions[8].value==777,'skipped entry stays in the profile')
assert(profile.actions[1].value==100,'apply does not overwrite its own profile')

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
assert(profile.actions[15].value=="Heal",'character macro is saved automatically')
now=now+5
bar[15]={action="macro",index=1,value="Raid"}
fire('ACTIONBAR_SLOT_CHANGED',15);drain()
assert(profile.actions[15]==nil,'account macro removes the old stored entry')
now=now+5
bar[15]=nil
fire('ACTIONBAR_SLOT_CHANGED',15);drain()
assert(profile.actions[15] and profile.actions[15].action=='empty','empty slot is stored again')

-- Spezialisierungswechsel lädt automatisch die passende Vorlage.
now=now+5
specIndex=2
fire('PLAYER_SPECIALIZATION_CHANGED','player');drain()
assert(B.spec==2533 and B.note:find('Keine Vorlage'),'second specialization has no profile yet')
bar[1]={action="spell",value=1943}
assert(B.Save(true),'second specialization saves')
assert(Buddy.db.bars.library.HUNTER[2533].actions[1].value==1943)
now=now+5
specIndex=1
fire('PLAYER_SPECIALIZATION_CHANGED','player');drain()
assert(B.spec==2544 and bar[1].value==100,'returning to a specialization loads its profile')

-- Automatik aus: keine automatischen Schreibläufe; Einschalten lädt erneut.
B.menuButton=object()
B.SetAutomatic(false)
assert(B.menuButton.text=='Aktionsleisten · Automatik AUS','menu row reflects state')
now=now+5
bar[1]={action="spell",value=1943}
fire('ACTIONBAR_SLOT_CHANGED',1);drain()
assert(profile.actions[1].value==100,'automatic off leaves the profile untouched')
B.SetAutomatic(true);drain()
assert(B.menuButton.text=='Aktionsleisten · Automatik AN' and bar[1].value==100,
    'enabling automatic mode reloads the profile')

-- Menübereich im bestehenden Fenster.
local menuHeight=B.BuildMenu(object(),-100)
assert(menuHeight==B.MENU_HEIGHT and B.menuStatus.text:find('Automatik AN')
    and B.menuStatus.text:find('Überleben'),'inline menu shows state and specialization')
assert(B.menuNote.text==B.note,'inline menu shows the last note')
local saveButton,loadButton
for _,frame in ipairs(frames) do
    if frame.text=='Vorlage speichern' then saveButton=frame end
    if frame.text=='Vorlage laden' then loadButton=frame end
end
assert(saveButton and loadButton,'both inline buttons exist')
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
assert(not B.pending and bar[1].value==100,'deferred apply resumes after combat')

-- Kampfbeginn mitten im Laden: der Rest wird nach dem Kampfende nachgeholt.
local expected=Buddy.db.bars.library.HUNTER[2544].actions[2]
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
local saved=Buddy.db.bars.library.HUNTER[2544]
assert(saved.actions[73].value==100,'class bar slot is saved')
assert(saved.actions[121].value==7 and not B.Settable(121),'possess slot is stored but read-only')
bar[73]={action="spell",value=5}
assert(B.Apply(true) and bar[73].value==100,'class bar slot is loaded')
assert(bar[121].value==7,'possess slot is never written')

-- Geheime Werte: weder Speichern noch automatisches Speichern verwenden sie.
local before=Buddy.db.bars.library.HUNTER[2544]
bar[10]={action="secret",value=secret}
assert(B.Save(true),'save skips a secret slot instead of aborting')
local saved=Buddy.db.bars.library.HUNTER[2544]
assert(saved and saved~=before and saved.actions[10]==nil,'secret slot is not stored')
assert(saved.actions[1] and saved.actions[1].value==100,'other slots are still saved')
assert(B.note:find('nicht lesbar') and B.note:find('10') and B.note:find('geschützter Wert'),'note names the unreadable slot and reason')
bar[10]=nil
now=now+5
bar[10]={action="secret",value=secret}
fire('ACTIONBAR_SLOT_CHANGED',10);drain()
assert(Buddy.db.bars.library.HUNTER[2544]==saved,'automatic save ignores secret slot data')
bar[10]=nil
local getInfo=GetActionInfo
GetActionInfo=function() error('blocked') end
assert(not B.Save(true) and B.note:find('kein Leistenplatz lesbar'),'save aborts when no slot is readable')
GetActionInfo=getInfo

-- Anmeldung mit vorhandener Vorlage lädt automatisch.
now=now+5
bar[1]={action="spell",value=1943}
B.ready=false
fire('PLAYER_LOGIN');drain()
assert(B.ready and bar[1].value==100,'login loads an existing profile')

-- Logout schreibt einen noch offenen automatischen Änderungsstand.
now=now+5
bar[11]={action="spell",value=100}
fire('ACTIONBAR_SLOT_CHANGED',11);drain()
assert(saved.actions[11].value==100,'last change saved before logout')
assert(B.events.events.PLAYER_LOGOUT and B.events.events.PLAYER_SPECIALIZATION_CHANGED
    and B.events.events.ACTIONBAR_SLOT_CHANGED,'required events are registered')

print('PASS: bar profiles, automatic save/load, spec switching, guards, secrets and inline menu')
