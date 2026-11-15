local addonName, Buddy = ...
local L = Buddy.L
local herbs, minerals = 2383, 2580
local ticker, pending, trackingButton, blockEvents

local function readTracking()
    local indices, active, other = {}, {}, false
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(index)
        if info and info.type == "spell" then
            if info.spellID == herbs or info.spellID == minerals then
                indices[info.spellID] = index
                active[info.spellID] = info.active
            elseif info.active then
                other = true
            end
        end
    end
    return indices, active, other
end

local function stopTracking(message)
    if ticker then ticker:Cancel() end
    ticker, pending = nil, nil
    if blockEvents then blockEvents:UnregisterAllEvents() end
    trackingButton:SetText(L["Kräuter / Erz: Aus"])
    if message then Buddy.Message(message) end
end

local function switchTracking()
    if InCombatLockdown() then return end
    if UnitIsDeadOrGhost("player") then
        pending = nil
        return
    end
    local ok, indices, active, other = pcall(readTracking)
    if not ok then
        stopTracking(L["Minimap-Suche ist in diesem Client nicht verfügbar."])
    elseif not indices[herbs] or not indices[minerals] then
        stopTracking(L["Kräuter- und Erzsuche müssen beide erlernt sein."])
    elseif active[herbs] and active[minerals] then
        stopTracking(L["Beide Sucharten sind aktiv."])
    elseif other then
        stopTracking(L["Eine andere Suchart ist aktiv."])
    elseif pending and not active[pending] then
        stopTracking(L["Suchwechsel gestoppt. Der Client hat den Wechsel nicht bestätigt."])
    else
        pending = active[herbs] and minerals or herbs
        local accepted, result = pcall(C_Minimap.SetTracking, indices[pending], true)
        if ticker and (not accepted or result == false) then
            stopTracking(L["Suchwechsel gestoppt. Der Client hat den Wechsel nicht bestätigt."])
        end
    end
end

local function toggleTracking()
    if ticker then
        stopTracking()
        return
    end
    if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo and C_Minimap.SetTracking
        and C_Timer and C_Timer.NewTicker) then
        Buddy.Message(L["Minimap-Suche ist in diesem Client nicht verfügbar."])
        return
    end
    if not blockEvents then
        blockEvents = CreateFrame("Frame")
        blockEvents:SetScript("OnEvent", function(_, _, name, action)
            if name == addonName and type(action) == "string" and action:find("SetTracking", 1, true) then
                stopTracking(L["Suchwechsel gestoppt. Der Client hat den Wechsel nicht bestätigt."])
            end
        end)
    end
    blockEvents:RegisterEvent("ADDON_ACTION_BLOCKED")
    blockEvents:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    trackingButton:SetText(L["Kräuter / Erz: An"])
    ticker = C_Timer.NewTicker(3, switchTracking)
end

local function readCVar(name)
    local ok, value = pcall(C_CVar.GetCVar, name)
    if ok and not (issecretvalue and issecretvalue(value)) and type(value) == "string" then return value end
end

local function writeCVar(name, value)
    local ok, written = pcall(C_CVar.SetCVar, name, value)
    return ok and written ~= false and readCVar(name) == value
end

local function toggleHighlight(button)
    if InCombatLockdown() then
        Buddy.Message(L["Bitte das Kampfende abwarten."])
        return
    end
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then
        Buddy.Message(L["Hervorhebung ist in diesem Client nicht verfügbar."])
        return
    end

    local saved = Buddy.char.gatherHighlight
    if type(saved) == "table" then
        for name, change in pairs(saved) do
            local current = readCVar(name)
            if (current and current ~= change.applied) or writeCVar(name, change.previous) then
                saved[name] = nil
            end
        end
        if next(saved) then
            Buddy.Message(L["Einige Hervorhebungsoptionen konnten nicht zurückgesetzt werden."])
            return
        end
        Buddy.char.gatherHighlight = false
        button:SetText(L["Hervorhebung: Aus"])
        return
    end

    local anyInput = Enum and Enum.SoftTargetEnableFlags and Enum.SoftTargetEnableFlags.Any
    local desired = {}
    if anyInput then desired.softTargetInteract = tostring(anyInput) end
    desired.SoftTargetIconInteract = "1"
    desired.SoftTargetIconGameObject = "1"
    desired.SoftTargetLowPriorityIcons = "1"
    desired.outlineModeShowLootEffectWhenDisabled = "1"
    -- Open up the narrow default arc without reducing a wider player setting.
    if readCVar("SoftTargetInteractArc") == "0" then desired.SoftTargetInteractArc = "1" end
    if IsOutlineModeSupported and IsOutlineModeSupported() then desired.Outline = "3" end

    saved = {}
    local applied, partial
    for name, value in pairs(desired) do
        local previous = readCVar(name)
        if previous == value then
            applied = true
        elseif previous and writeCVar(name, value) then
            saved[name] = {previous = previous, applied = value}
            applied = true
        else
            partial = true
        end
    end
    if applied then
        Buddy.char.gatherHighlight = saved
        button:SetText(L["Hervorhebung: An"])
    end
    if not applied or partial then
        Buddy.Message(L["Der Client unterstützt nur einen Teil der Hervorhebungsoptionen."])
    end
end

function Buddy.InitializeGatherHighlight()
    if Buddy.char.gatherHighlight == nil then
        toggleHighlight({SetText = function() end})
    end
end

function Buddy.BuildGatherMenu(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(346, 26)
    local function addButton(point, label, onClick)
        local button = Buddy.Style.Button(CreateFrame("Button", nil, row, "UIPanelButtonTemplate"))
        button:SetSize(169, 26)
        button:SetPoint(point)
        button:SetText(label)
        button:SetScript("OnClick", onClick)
        return button
    end
    trackingButton = addButton("LEFT", L["Kräuter / Erz: Aus"], toggleTracking)
    addButton("RIGHT", type(Buddy.char.gatherHighlight) == "table"
        and L["Hervorhebung: An"] or L["Hervorhebung: Aus"], toggleHighlight)
    return row
end
