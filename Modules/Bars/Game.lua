local _, Buddy = ...
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
function B.Now()
    local value=B.Call(GetTime)
    return B.Number(value) and value or 0
end
function B.Context()
    local _,class = B.Call(UnitClass,"player")
    local index=B.Call(GetSpecialization)
    if not B.Text(class) or not B.Number(index) then return end
    local spec,label=B.Call(GetSpecializationInfo,index)
    local guid=B.Call(UnitGUID,"player")
    local name,realm=B.Call(UnitFullName,"player")
    if not B.Number(spec) or not B.Text(guid) or not B.Text(name) then return end
    if not B.Text(realm) then realm=B.Call(GetRealmName) end
    return class,spec,guid,name..(B.Text(realm) and ("-"..realm) or ""),B.Text(label) and label or tostring(spec)
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
    if B.Call(InCombatLockdown)~=false then return "Wartet auf Kampfende" end
    for _,name in ipairs({"HasVehicleActionBar","HasOverrideActionBar","HasTempShapeshiftActionBar",
        "HasPossessBar","HasBonusActionBar"}) do
        local check=_G[name]
        if type(check)=="function" and B.Call(check)==true then return "Sonderleiste aktiv" end
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

function B.Read(slot)
    if type(GetActionInfo)~="function" then return nil,"API fehlt" end
    local ok,kind,id=pcall(GetActionInfo,slot)
    if not ok then return nil,"Abfrage fehlgeschlagen" end
    if not B.Public(kind) or not B.Public(id) then return nil,"geschützter Wert" end
    if kind==nil then return {action="empty"} end
    if kind=="spell" or kind=="item" or kind=="flyout" then
        if B.Number(id) and id>0 then return {action=kind,value=id} end
        return nil,"ungültige Kennung"
    elseif kind=="macro" then
        if not B.Number(id) then return nil,"Makro ungültig" end
        local scope=B.MacroScope(id)
        -- Accountweite Makros werden vollständig ignoriert: kein Speichern,
        -- kein Wiederherstellen und keine Meldung als fehlendes Makro.
        if scope=="account" then return {action="ignored"} end
        if scope~="character" then return nil,"Makro nicht gefunden" end
        local name=macroName(id)
        if B.Text(name) then return {action="macro",value=name} end
        return nil,"Makro nicht gefunden"
    elseif kind=="equipmentset" then
        local name
        if B.Text(id) then name=id
        elseif B.Number(id) then
            local infoName=B.Call(C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo,id)
            if B.Text(infoName) then name=infoName end
        end
        if name then return {action="equipmentset",value=name} end
        return nil,"Ausrüstungsset nicht gefunden"
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
        local index,scope=B.MacroLookup(value)
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
