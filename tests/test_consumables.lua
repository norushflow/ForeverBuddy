local frames, bags, requested = {}, {}, {}
local combat, mouseDown = false, false
local cursorX, cursorY = 100, 100
local function noop() end
local methods = {}
function methods:SetScript(key, script) self.scripts[key] = script end
function methods:GetScript(key) return self.scripts[key] end
function methods:RegisterEvent(key) self.events[key] = true end
function methods:SetShown(value) assert(not combat); self.shown = value end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:SetSize() assert(not combat) end
function methods:ClearAllPoints() assert(not combat) end
function methods:SetPoint(point, _, _, x, y)
    assert(not combat)
    self.point, self.x, self.y = point, x, y
end
function methods:GetLeft() return self.x end
function methods:GetBottom() return self.y end
function methods:GetFrameLevel() return rawget(self, "frameLevel") or 1 end
function methods:SetFrameLevel(level) self.frameLevel = level end
function methods:GetEffectiveScale() return 1 end
function methods:SetAttribute(key, value) assert(not combat); self.attributes[key] = value end
function methods:SetText(value) self.text = value end
function methods:SetCooldown(start, duration) self.duration = duration end
function methods:SetDesaturated(value) self.desaturated = value end
function methods:SetOwner(owner) self.owner = owner end
function methods:IsOwned(owner) return self.owner == owner end
function methods:SetHyperlink(link) self.link = link end
local function object()
    return setmetatable({scripts = {}, events = {}, attributes = {}},
        {__index = function(_, key) return methods[key] or noop end})
end
function methods:CreateTexture() return object() end
function CreateFrame(kind, _, parent, template)
    assert(not combat)
    local frame = object()
    frame.kind, frame.parent, frame.template = kind, parent, template
    frames[#frames + 1] = frame
    return frame
end
function InCombatLockdown() return combat end
function IsMouseButtonDown(button) return button == "LeftButton" and mouseDown end
function GetCursorPosition() return cursorX, cursorY end
UIParent, GameTooltip, SlashCmdList = object(), object(), {}
GameTooltip.Show = noop
GameTooltip.Hide = function(self) self.owner = false end
Enum = {BagIndex = {ReagentBag = 5}}
local types = {[10] = {0, 5, 1}, [20] = {0, 1, 2}, [30] = {0, 7, 3},
    [40] = {0, 0}, [50] = {7, 0, 5}, [70] = {0, 5, 7}}
C_Item = {
    GetItemInfoInstant = function(id)
        local item = types[id] or {}
        return nil, nil, nil, nil, 123, item[1], item[2]
    end,
    GetItemSpell = function(id) return nil, types[id][3] end,
    RequestLoadItemDataByID = function(id) requested[id] = (requested[id] or 0) + 1 end,
}
C_TooltipInfo = {GetHyperlink = function(link)
    local texts = {["link:10"] = "Use: Restores 300 health and 200 mana over 20 sec.",
        ["link:70"] = "Benutzen: Stellt 1.392 Gesundheit im Verlauf von 30 Sek. wieder her."}
    return {lines = {{leftText = texts[link]}}}
end}
local cooldown = 5
C_Container = {
    GetContainerNumSlots = function(bag) return #(bags[bag] or {}) end,
    GetContainerItemInfo = function(bag, slot) return bags[bag][slot] end,
    GetItemCooldown = function(id) return 100, id == 20 and cooldown or 0, 1 end,
}
local function stack(id, count)
    return {itemID = id, stackCount = count, hyperlink = "link:" .. id}
end
bags[0] = {stack(10, 3), stack(20, 1), stack(40, 1), stack(50, 1), stack(60, 1)}
bags[1] = {stack(10, 4)}
bags[5] = {stack(20, 2)}
local messages = 0
local Buddy = {
    L = setmetatable({}, {__index = function(_, key) return key end}),
    char = {consumables = {food = {x = 50, y = 200}}},
    Message = function() messages = messages + 1 end,
    Foreign = function(frame, action) action(frame) end,
    CreateConsumablesLock = function(parent, _, onClick)
        local button = CreateFrame("Button", nil, parent)
        button:SetScript("OnClick", onClick)
        return button
    end,
    consumablesMenuLock = {},
    SetConsumablesLockIcon = function(button, editing) button.editing = editing end,
    Style = {Border = function() return {object()} end, Color = {}, Text = function(parent) local text = object(); text.parent = parent; return text end,
        Button = function(frame) return frame end, Icon = function(frame) return frame end},
}
assert(loadfile("Modules/Consumables.lua"))("Foreverbuddy", Buddy)
Buddy.LoadConsumables()
local events = frames[1]
local function event(name, ...)
    assert(events.events[name])
    events.scripts.OnEvent(events, name, ...)
end
event("PLAYER_ENTERING_WORLD")
local function buttons()
    local result = {}
    for _, frame in ipairs(frames) do
        if frame.template == "SecureActionButtonTemplate" and frame.shown then
            result[#result + 1] = frame
        end
    end
    return result
end
local visible = buttons()
assert(#visible == 2)
local food, potion = unpack(visible)
assert(food.parent ~= potion.parent)
assert(food.attributes.type == "item" and food.attributes.item == "item:10")
assert(potion.attributes.item == "item:20" and potion.cooldown.duration == 5)
assert(food.count.text == 7 and potion.count.text == 3 and requested[60] == 1)
assert(food.count.parent.parent == food and food.count.parent ~= food.cooldown)
assert(food.count.parent:GetFrameLevel() > food.cooldown:GetFrameLevel())
assert(food.parent.x == 50 and food.parent.y == 134 and food.parent.point == "BOTTOMLEFT" and not food.parent.handle.shown)
food.scripts.OnEnter(food)
assert(GameTooltip.owner == food and GameTooltip.link == "link:10")
food.scripts.OnLeave(food)
assert(not GameTooltip.owner)

SlashCmdList.FOREVERBUDDYCONSUMABLES()
local handle = food.parent.handle
assert(handle.shown and food.parent.lock.shown and Buddy.consumablesMenuLock.editing)
assert(food.parent.editBorder[1].shown)
handle.scripts.OnMouseDown(handle, "RightButton")
assert(not handle.scripts.OnUpdate)
mouseDown = true
handle.scripts.OnMouseDown(handle, "LeftButton")
cursorX, cursorY = 130, -34
handle.scripts.OnUpdate()
assert(Buddy.char.consumables.food.x == 80 and Buddy.char.consumables.food.y == 0 and Buddy.char.consumables.food.bottom)
mouseDown = false
handle.scripts.OnUpdate()
assert(not handle.scripts.OnUpdate)
mouseDown = true
handle.scripts.OnMouseDown(handle, "LeftButton")
handle.scripts.OnMouseUp(handle, "LeftButton")
mouseDown = false
assert(not handle.scripts.OnUpdate)
food.parent.lock.scripts.OnClick()
assert(not handle.shown and not food.parent.lock.shown and not Buddy.consumablesMenuLock.editing)
assert(food.parent.point == "BOTTOMLEFT" and food.parent.y == 0)
assert(food.parent.editBorder[1].shown == false)

combat = true
event("PLAYER_REGEN_DISABLED")
bags[0], bags[1], bags[5] = {stack(30, 4), stack(60, 1)}, {}, {stack(20, 1)}
types[60] = {0, 1, 6}
event("GET_ITEM_INFO_RECEIVED", 60, true)
event("BAG_UPDATE_DELAYED")
cooldown = 1
event("BAG_UPDATE_COOLDOWN")
assert(#buttons() == 2 and food.attributes.item == "item:10")
assert(food.count.text == 0 and food.icon.desaturated)
assert(potion.count.text == 1 and potion.cooldown.duration == 1)
SlashCmdList.FOREVERBUDDYCONSUMABLES()
assert(messages == 1 and not handle.shown)
combat = false
event("PLAYER_REGEN_ENABLED")
visible = buttons()
assert(not food.parent.shown and not food.attributes.item and #visible == 3)
assert(visible[1].attributes.item == "item:20" and visible[2].attributes.item == "item:30"
    and visible[3].attributes.item == "item:60")
SlashCmdList.FOREVERBUDDYCONSUMABLES()
assert(food.parent.shown and food.parent.handle.shown and #buttons() == 3)
food.parent.lock.scripts.OnClick()
bags[0] = {stack(10, 1), stack(70, 2)}
event("BAG_UPDATE_DELAYED")
assert(food.attributes.item == "item:70" and food.count.text == 2,
    "stronger food sorts left of lower item IDs")
print("PASS: consumable groups, bag totals, cooldown, item cache, tooltip, movement, lock and combat layout")
