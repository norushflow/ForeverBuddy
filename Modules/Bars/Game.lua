local _, Buddy = ...
local L = Buddy.L
local B = {}; Buddy.Bars = B

-- Geschützte Werte niemals indexieren, vergleichen oder formatieren.
function B.Public(v) return not (issecretvalue and issecretvalue(v)) end
function B.Number(v) return B.Public(v) and type(v)=="number" and v==v end
function B.Text(v) return B.Public(v) and type(v)=="string" and v~="" end
function B.Table(v) return B.Public(v) and type(v)=="table" end
function B.Call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c=pcall(fn,...)
    if ok and B.Public(a) and B.Public(b) and B.Public(c) then return a,b,c end
end
function B.Context()
    local label,class=B.Call(UnitClass,"player")
    if not B.Text(class) then return end
    local name,realm=B.Call(UnitFullName,"player")
    if not B.Text(realm) then realm=B.Call(GetRealmName) end
    return class,B.Text(name) and (name..(B.Text(realm) and ("-"..realm) or "")) or nil,
        B.Text(label) and label or class
end

-- Alle Leistenplätze 1-180: Hauptleiste mit beiden Seiten, Leisten 2-5,
-- Klassen-/Haltungsleisten 73-120 sowie Leisten 6-8 (145-180). Besitz- und
-- reservierte Plätze 121-144 werden mitgespeichert, aber nie geschrieben.
local clientMax=180
if B.Number(NUM_ACTIONBAR_SLOTS) and NUM_ACTIONBAR_SLOTS>=1 then
    clientMax=math.min(180,math.floor(NUM_ACTIONBAR_SLOTS))
end
B.limit=clientMax
B.slots={}
for slot=1,clientMax do B.slots[#B.slots+1]=slot end
function B.ValidSlot(slot)
    return B.Number(slot) and slot%1==0 and slot>=1 and slot<=B.limit
end
-- Besitz-/reservierte Plätze sind nicht setzbar: nur lesen, nie schreiben.
function B.Settable(slot)
    return B.ValidSlot(slot) and (slot<=120 or slot>=145)
end

-- Speichern und Laden nur außerhalb von Kampf und Sonderleisten.
function B.Reason()
    if B.Call(InCombatLockdown)~=false then return L["Wartet auf Kampfende"] end
    for _,name in ipairs({"HasVehicleActionBar","HasOverrideActionBar","HasTempShapeshiftActionBar",
        "HasPossessBar","HasBonusActionBar"}) do
        local check=_G[name]
        if type(check)=="function" and B.Call(check)==true then return L["Sonderleiste aktiv"] end
    end
end
function B.Blocked() return B.Reason() end
function B.CursorFree()
    if type(GetCursorInfo)~="function" then return false end
    local ok,cursor=pcall(GetCursorInfo)
    return ok and B.Public(cursor) and cursor==nil
end
function B.ClearCursor()
    if type(ClearCursor)=="function" then pcall(ClearCursor) end
end
function B.APIs()
    return type(GetActionInfo)=="function" and type(PickupAction)=="function"
        and type(PlaceAction)=="function" and type(ClearCursor)=="function"
        and type(GetCursorInfo)=="function"
end

-- Makrobereiche des aktuellen Clients: 1..MAX_ACCOUNT_MACROS sind accountweit,
-- direkt danach folgen ausschließlich die Makros dieses Charakters. Die Grenze
-- kommt aus der Client-Konstante; fehlt sie, wird kein Makro gespeichert oder
-- geladen, statt versehentlich ein allgemeines Makro zu übernehmen.
local macroBase
function B.MacroBase()
    if macroBase then return macroBase end
    local base=B.Number(MAX_ACCOUNT_MACROS) and MAX_ACCOUNT_MACROS
    local constants=Constants
    if not base and B.Table(constants) and B.Table(constants.MacroConsts) then
        local value=constants.MacroConsts.MAX_ACCOUNT_MACROS
        if B.Number(value) then base=value end
    end
    if base and base>=1 then macroBase=base;return base end
end

-- "account" = accountweit und damit zu ignorieren, "character" = zulässig.
-- Die Zuordnung folgt ausschließlich der Client-Grenze; die Anzahl vorhandener
-- Makros wird erst beim Namensabgleich benötigt.
function B.MacroScope(index)
    if not B.Number(index) or index<1 or index%1~=0 then return end
    local base=B.MacroBase()
    if not base then return end
    return index<=base and "account" or "character"
end

-- Nur den Makronamen lesen. Bevorzugt die aktuelle C_Macro-API; GetMacroInfo
-- bleibt als Rückfall, weil dort geschützte Icon-/Textwerte den Namen nicht
-- mit verwerfen dürfen.
local function macroName(index)
    local api=C_Macro
    if B.Table(api) and type(api.GetMacroName)=="function" then
        local ok,name=pcall(api.GetMacroName,index)
        if ok and B.Text(name) then return name end
    end
    if type(GetMacroInfo)~="function" then return end
    local ok,name=pcall(GetMacroInfo,index)
    if ok and B.Text(name) then return name end
end

local function macroEntry(index,includeBody)
    local name=macroName(index)
    if not name then return end
    local entry={action="macro",value=name}
    if includeBody then
        local _,icon,body=B.Call(GetMacroInfo,index)
        if type(body)~="string" or not (B.Number(icon) or B.Text(icon)) then return end
        entry.macroBody=body
        entry.macroIcon=icon
    end
    return entry
end

function B.Read(slot,includeMacroBody)
    if type(GetActionInfo)~="function" then return nil,L["API fehlt"] end
    local ok,kind,id=pcall(GetActionInfo,slot)
    if not ok then return nil,L["Abfrage fehlgeschlagen"] end
    if not B.Public(kind) or not B.Public(id) then return nil,L["geschützter Wert"] end
    if kind==nil then return {action="empty"} end
    if kind=="spell" or kind=="item" or kind=="flyout" then
        if B.Number(id) and id>0 then return {action=kind,value=id} end
        return nil,L["ungültige Kennung"]
    elseif kind=="macro" then
        if not B.Number(id) then return nil,L["Makro ungültig"] end
        local scope=B.MacroScope(id)
        -- Accountweite Makros werden vollständig ignoriert: kein Speichern,
        -- kein Wiederherstellen und keine Meldung als fehlendes Makro.
        if scope=="account" then return {action="ignored"} end
        if scope~="character" then return nil,L["Makro nicht gefunden"] end
        local entry=macroEntry(id,includeMacroBody)
        if entry then return entry end
        return nil,L["Makro nicht gefunden"]
    elseif kind=="equipmentset" then
        local name
        if B.Text(id) then name=id
        elseif B.Number(id) then
            local infoName=B.Call(C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo,id)
            if B.Text(infoName) then name=infoName end
        end
        if name then return {action="equipmentset",value=name} end
        return nil,L["Ausrüstungsset nicht gefunden"]
    else
        -- Unbekannte Typen niemals als leer speichern und beim Laden überspringen.
        return {action="keep"}
    end
end

-- Sucht ausschließlich im Charakterbereich. Ein accountweites Makro wird nie
-- als Ersatz verwendet, auch wenn es denselben Namen hat.
function B.MacroLookup(name)
    if not B.Text(name) then return end
    local base=B.MacroBase()
    local account,character=B.Call(GetNumMacros)
    if not base or not B.Number(account) or not B.Number(character) then return nil,"api" end
    local found
    for n=1,character do
        local index=base+n
        if macroName(index)==name then
            if found then return nil,"ambiguous" end
            found=index
        end
    end
    if found then return found,"character" end
    for n=1,math.min(account,base) do
        if macroName(n)==name then return nil,"account" end
    end
    return nil,"missing"
end

local function resolveMacro(entry,allowCreate)
    local index,scope=B.MacroLookup(entry.value)
    if entry.macroBody==nil then return index,scope end
    if not B.Text(entry.value) or not B.Public(entry.macroBody) or type(entry.macroBody)~="string"
        or not (B.Number(entry.macroIcon) or B.Text(entry.macroIcon)) then return end
    if index then
        local _,_,body=B.Call(GetMacroInfo,index)
        if body==entry.macroBody then return index end
        return nil,"conflict"
    end
    if allowCreate and (scope=="missing" or scope=="account") and not B.Reason() then
        local created=B.Call(CreateMacro,entry.value,entry.macroIcon,entry.macroBody,true)
        if B.MacroScope(created)=="character" then return created end
    end
    return nil,scope
end

local function flyoutIndex(id)
    local api=C_SpellBook
    local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local kind=Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
    if not api or bank==nil or kind==nil then return end
    local count=B.Call(api.GetNumSpellBookSkillLines)
    if not B.Number(count) or count<0 or count>100 then return end
    for line=1,count do
        local info=B.Call(api.GetSpellBookSkillLineInfo,line)
        if B.Table(info) and B.Number(info.itemIndexOffset) and B.Number(info.numSpellBookItems)
            and info.numSpellBookItems>=0 and info.numSpellBookItems<=1000 then
            for slot=info.itemIndexOffset+1,info.itemIndexOffset+info.numSpellBookItems do
                local entry=B.Call(api.GetSpellBookItemInfo,slot,bank)
                if B.Table(entry) and B.Public(entry.itemType) and entry.itemType==kind
                    and B.Number(entry.actionID) and entry.actionID==id then return slot,bank end
            end
        end
    end
end

function B.Pick(entry)
    if not B.Table(entry) or not B.Text(entry.action) then return false end
    local kind,value=entry.action,entry.value
    if kind=="spell" and B.Number(value) then
        local known=B.Call(C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook,value)
        if known~=true then return false end
        if not C_Spell or type(C_Spell.PickupSpell)~="function" then return false end
        pcall(C_Spell.PickupSpell,value)
    elseif kind=="item" and B.Number(value) and C_Item and type(C_Item.PickupItem)=="function" then
        pcall(C_Item.PickupItem,value)
    elseif kind=="macro" and B.Text(value) then
        local index,scope=resolveMacro(entry,true)
        if not index then return false,scope end
        if type(PickupMacro)~="function" then return false,"api" end
        pcall(PickupMacro,index)
    elseif kind=="equipmentset" and B.Text(value) then
        local id=B.Call(C_EquipmentSet and C_EquipmentSet.GetEquipmentSetID,value)
        if not B.Number(id) or type(C_EquipmentSet.PickupEquipmentSet)~="function" then return false end
        pcall(C_EquipmentSet.PickupEquipmentSet,id)
    elseif kind=="flyout" and B.Number(value) then
        local slot,bank=flyoutIndex(value)
        if not slot or type(C_SpellBook.PickupSpellBookItem)~="function" then return false end
        pcall(C_SpellBook.PickupSpellBookItem,slot,bank)
    else return false end
    local ok,cursor=pcall(GetCursorInfo)
    return ok and B.Public(cursor) and cursor~=nil
end

-- Native Klickzauber: nur öffentliche, vollständige Daten übernehmen.
-- Eine Kopie verhindert, dass der Client die gespeicherte Vorlage verändert.
function B.CopyClickBindings(info)
    if not B.Table(info) then return end
    local result={}
    for index,entry in pairs(info) do
        if not B.Number(index) or index<1 or index%1~=0 or not B.Table(entry)
            or not B.Number(entry.type) or not B.Number(entry.actionID)
            or not B.Text(entry.button) or not B.Number(entry.modifiers) then return end
        result[index]={type=entry.type,actionID=entry.actionID,
            button=entry.button,modifiers=entry.modifiers}
    end
    for index=1,#result do if not result[index] then return end end
    local count=0
    for _ in pairs(result) do count=count+1 end
    if count~=#result then return end
    return result
end
local function isClickMacro(binding)
    return Enum and Enum.ClickBindingType and binding.type==Enum.ClickBindingType.Macro
end

function B.ReadClickBindings(shared)
    local info=B.CopyClickBindings(B.Call(C_ClickBindings and C_ClickBindings.GetProfileInfo))
    if not info or not shared then return info end
    local result={}
    for _,binding in ipairs(info) do
        if isClickMacro(binding) then
            local scope=B.MacroScope(binding.actionID)
            if scope=="character" then
                binding.macro=macroEntry(binding.actionID,true)
                if not binding.macro then return end
                binding.actionID=0 -- Makroindizes sind nur auf dem Quellcharakter gültig.
            elseif scope~="account" then return end
            if binding.macro then result[#result+1]=binding end
        else
            result[#result+1]=binding
        end
    end
    return result
end

local function sharedClickBindings(profile,info)
    local current=B.ReadClickBindings()
    if not current then return end
    local result,protected,previous={},{},{}
    local function chord(binding)
        return binding.button..":"..binding.modifiers
    end
    for _,binding in ipairs(current) do
        local key=chord(binding)
        previous[key]=binding
        if isClickMacro(binding) and B.MacroScope(binding.actionID)~="character" then
            protected[key]=true
            result[#result+1]=binding
        end
    end
    -- Neue Makros können die laufenden Makroindizes verändern. Erst anlegen,
    -- dann alle Klickbelegungen mit ihren endgültigen Indizes aufbauen.
    for index,binding in ipairs(info) do
        local macro=profile.clickBindings[index].macro
        if isClickMacro(binding) and not protected[chord(binding)] and B.Table(macro) then
            resolveMacro(macro,true)
        end
    end
    current=B.ReadClickBindings()
    if not current then return end
    for _,binding in ipairs(current) do previous[chord(binding)]=binding end
    local complete=true
    for index,binding in ipairs(info) do
        local key=chord(binding)
        if not protected[key] then
            if isClickMacro(binding) then
                local macro=profile.clickBindings[index].macro
                binding.actionID=B.Table(macro) and resolveMacro(macro,false) or nil
                if not binding.actionID then
                    complete=false
                    if previous[key] then result[#result+1]=previous[key] end
                end
            end
            if binding.actionID then result[#result+1]=binding end
        end
    end
    return result,complete
end

function B.ApplyClickBindings(profile,shared)
    -- Alte Vorlagen ohne Klickzauber verändern die aktuelle Belegung nicht.
    if profile.clickBindings==nil then return true end
    local info=B.CopyClickBindings(profile.clickBindings)
    if not info then return false end
    if not C_ClickBindings or type(C_ClickBindings.SetProfileByInfo)~="function" then return false end
    if B.Reason() then return false end
    local complete=true
    if shared then info,complete=sharedClickBindings(profile,info) end
    if not info or B.Reason() then return false end
    return pcall(C_ClickBindings.SetProfileByInfo,info) and complete
end
