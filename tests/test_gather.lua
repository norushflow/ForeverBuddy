local B = {char = {}, Style = {Button = function(button) return button end}}
B.L = setmetatable({}, {__index = function(_, key) return key end})
B.Message = function(message) B.message = message end

local buttons, eventFrame = {}, nil
function CreateFrame(kind, _, parent)
    local frame = {
        SetSize = function() end,
        SetPoint = function() end,
        SetText = function(self, text) self.text = text end,
        SetScript = function(self, script, func) self[script] = func end,
        RegisterEvent = function() end,
        UnregisterAllEvents = function() end,
    }
    if kind == "Button" then
        buttons[#buttons + 1] = frame
    elseif not parent then
        eventFrame = frame
    end
    return frame
end

local timer, combat, dead
C_Timer = {NewTicker = function(seconds, tick)
    assert(seconds == 3)
    timer = {tick = tick, Cancel = function(self) self.cancelled = true end}
    return timer
end}
InCombatLockdown = function() return combat end
UnitIsDeadOrGhost = function() return dead end

local herbs = {spellID = 2383, type = "spell", active = true}
local ore = {spellID = 2580, type = "spell", active = false}
local entries = {herbs, {type = "other", active = true}, ore}
local mode, calls = "exclusive", 0
C_Minimap = {
    GetNumTrackingTypes = function() return #entries end,
    GetTrackingInfo = function(index) return entries[index] end,
    SetTracking = function(index, on)
        assert(on and entries[index].type == "spell")
        calls = calls + 1
        if mode == "blocked" then
            eventFrame.OnEvent(eventFrame, "ADDON_ACTION_BLOCKED", "Foreverbuddy", "C_Minimap.SetTracking()")
        elseif mode ~= "ignored" then
            entries[index].active = true
            if mode == "exclusive" then
                local previous = entries[index] == herbs and ore or herbs
                previous.active = false
            end
        end
    end,
}

Enum = {SoftTargetEnableFlags = {Any = 3}}
IsOutlineModeSupported = function() return true end
local cvars = {
    softTargetInteract = "1", Outline = "2", SoftTargetIconGameObject = "0", SoftTargetIconInteract = "1",
    SoftTargetLowPriorityIcons = "0", SoftTargetInteractArc = "0", outlineModeShowLootEffectWhenDisabled = "0",
}
local writes = 0
C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, value)
        writes = writes + 1
        if name == "Outline" then return false end
        cvars[name] = value
        if name ~= "SoftTargetLowPriorityIcons" then return true end
    end,
}

assert(loadfile("Modules/Gather.lua"))("Foreverbuddy", B)
B.BuildGatherMenu({})
local tracking, highlight = unpack(buttons)
assert(writes == 0 and not timer)
B.InitializeGatherHighlight()
assert(type(B.char.gatherHighlight)=="table" and writes>0, "highlight enabled by default")
highlight.OnClick(highlight)
assert(B.char.gatherHighlight==false)
local beforeInit=writes
B.InitializeGatherHighlight()
assert(writes==beforeInit and B.char.gatherHighlight==false, "disabled preference persists")

tracking.OnClick()
combat = true
timer.tick()
combat, dead = false, true
timer.tick()
assert(calls == 0, "skip tracking writes in combat and while dead")
dead = false
timer.tick()
assert(ore.active and not herbs.active and entries[2].active)
entries[1], entries[3] = entries[3], entries[1]
timer.tick()
assert(herbs.active and not ore.active, "spell IDs must survive tracking index changes")
tracking.OnClick()
assert(timer.cancelled)

mode = "both"
tracking.OnClick()
timer.tick()
timer.tick()
assert(herbs.active and ore.active and timer.cancelled, "stop when both are active")

herbs.active, mode = false, "ignored"
tracking.OnClick()
timer.tick()
local before = calls
timer.tick()
assert(timer.cancelled and calls == before, "stop without retries when the client ignores a write")

mode = "blocked"
tracking.OnClick()
timer.tick()
assert(timer.cancelled, "stop on protected action event")

entries = {herbs}
tracking.OnClick()
before = calls
timer.tick()
assert(timer.cancelled and calls == before, "both skills are required")

highlight.OnClick(highlight)
assert(cvars.softTargetInteract == "3" and cvars.SoftTargetIconGameObject == "1" and cvars.Outline == "2")
assert(cvars.SoftTargetLowPriorityIcons == "1" and cvars.SoftTargetInteractArc == "1"
    and cvars.outlineModeShowLootEffectWhenDisabled == "1", "enable additional native visual indications")
assert(B.char.gatherHighlight.Outline == nil, "a rejected CVar must not be recorded as changed")
cvars.softTargetInteract = "2"
highlight.OnClick(highlight)
assert(cvars.softTargetInteract == "2" and cvars.SoftTargetIconGameObject == "0" and not B.char.gatherHighlight,
    "restore only settings still at the applied value")

assert(cvars.SoftTargetLowPriorityIcons == "0" and cvars.SoftTargetInteractArc == "0"
    and cvars.outlineModeShowLootEffectWhenDisabled == "0", "restore additional settings")
cvars.SoftTargetInteractArc = "2"
highlight.OnClick(highlight)
assert(cvars.SoftTargetInteractArc == "2", "keep a wider interact arc")

print("PASS: gathering tracking, client restrictions and reversible native highlighting")
