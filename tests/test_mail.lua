local loadfile = dofile("tests/load_locales.lua")
local B={db={mail={recipients={alchemy='Legacy'},recipientsByFaction={Horde={alchemy='Alt',leatherworking='Alt'}}}},Message=function() end}
assert(loadfile('Modules/MailMaterials.lua'))('Foreverbuddy',B)
assert(loadfile('Modules/Mail.lua'))('Foreverbuddy',B)
local M=B.Mail
assert(#M.groups==8 and M.groups[8][1]=='bank')
local found={}
for _,g in ipairs(M.groups) do found[g[1]]=true end
assert(not found.inscription and not found.jewelcrafting and not found.mining and not found.herbalism)
local counts = {0, 0, 0, 0, 0, 0, 0}
local bankOnly = 0
for id, mask in pairs(B.MailMaterials) do
    local matches = 0
    for i = 1, 7 do
        local group = M.groups[i]
        assert(M.Matches(group, id) == (group[3] == mask))
        if M.Matches(group, id) then
            counts[i] = counts[i] + 1
            matches = matches + 1
        end
        assert(not M.Matches(group, 999999999) and not M.Matches(group, nil))
    end
    assert(M.Matches(M.groups[8], id) and matches <= 1)
    if matches == 0 then bankOnly = bankOnly + 1 end
end
for _, count in ipairs(counts) do assert(count > 0) end
assert(bankOnly > 0 and not M.Matches(M.groups[8], 999999999) and not M.Matches(M.groups[8], nil))

local function stack(itemID, count)
    return {itemID = itemID, stackCount = count or 1}
end

local events, sent, draft, bags = {}, {}, {}, {}
local cursor, money, cod, onAttach, pickupOverride
local visited
function CreateFrame()
    return {RegisterEvent = function() end, SetScript = function(_, key, script) events[key] = script end}
end
SlashCmdList = {}
C_Container = {
    GetContainerNumSlots = function(bag)
        visited[bag] = true
        return bags[bag] and bags[bag].size or 0
    end,
    GetContainerItemInfo = function(bag, slot) return bags[bag][slot] end,
    PickupContainerItem = function(bag, slot)
        cursor = pickupOverride or bags[bag][slot]
        bags[bag][slot] = nil
    end,
}
function GetSendMailItem(index)
    local item = draft[index]
    if item and not item.hidden then
        return 'Item', item.itemID, 123, item.stackCount, 1
    end
end
function HasSendMailItem(index) return draft[index] ~= nil end
function ClickSendMailItemButton(index)
    assert(cursor and not draft[index])
    draft[index], cursor = cursor, nil
    if onAttach then onAttach(index) end
end
function GetSendMailMoney() return money end
function GetSendMailCOD() return cod end
function GetCursorInfo()
    if cursor then return 'item', cursor.itemID end
end
function ClearCursor() cursor = nil end
function GetMoney() return 10000 end
function UnitName() return 'Main' end
function InCombatLockdown() return false end
function SendMail(recipient)
    sent[#sent + 1] = {recipient = recipient, items = draft}
end
local faction = 'Horde'
function UnitFactionGroup() return faction end
function UnitFullName() return 'Main', 'Family' end
B.LoadMail()
local openPanel = M.Open
M.Open = function() end

local function event(name) events.OnEvent(nil, name) end
local function reset()
    event('MAIL_CLOSED')
    event('MAIL_SHOW')
    sent, draft, bags, visited = {}, {}, {}, {}
    cursor, money, cod, onAttach, pickupOverride = nil, nil, nil, nil, nil
end
local function assertDraft(index, itemID, count)
    local item = sent[#sent].items[index]
    assert(item and item.itemID == itemID and item.stackCount == (count or 1))
end

M.Start(M.groups[1]); assert(#sent == 0 and not events.OnUpdate)
reset()
faction = 'Alliance'; M.Start(M.groups[1]); assert(#sent == 0 and not events.OnUpdate)
faction = 'Horde'

-- Every recipient gets only its own allowlisted materials, including with a mixed bag.
local samples = {765, 3470, 4359, 2934, 2589, 10940, 723}
local blocked = {2770, 2840, 12809, 2320, 8153}
for i, group in ipairs(M.groups) do
    B.db.mail.recipientsByFaction.Horde[group[1]] = group[1] .. ' Alt'
    reset()
    local bag = {size = #samples + #blocked + 1, [1] = stack(999999999)}
    for slot, id in ipairs(samples) do bag[slot + 1] = stack(id, slot) end
    for slot, id in ipairs(blocked) do bag[#samples + slot + 1] = stack(id) end
    bags[0] = bag
    M.Start(group)
    assert(#sent == 1 and sent[1].recipient == group[1] .. ' Alt')
    if i <= #samples then
        assertDraft(1, samples[i], i)
        assert(not draft[2])
    else
        for slot, id in ipairs(samples) do assertDraft(slot, id, slot) end
        for slot = 1, #blocked do assertDraft(#samples + slot, blocked[slot]) end
        assert(#draft == 12 and bags[0][1].itemID == 999999999)
    end
end

-- Separate stacks, holes, skipped slots and the actual attachment limit.
reset()
NUM_BAG_SLOTS = 4
ATTACHMENTS_MAX_SEND = 2
Enum = {BagIndex = {ReagentBag = 7}}
bags[0] = {size = 7, [1] = stack(2934, 3), [3] = stack(2934, 19),
    [4] = {itemID = 2934, stackCount = 4, isBound = true},
    [5] = {itemID = 2934, stackCount = 5, isLocked = true},
    [6] = stack(2770), [7] = stack(2318, 2)}
bags[7] = {size = 1, stack(8170, 8)}
M.Start(M.groups[4])
assert(#sent == 1 and events.OnUpdate)
assertDraft(1, 2934, 3)
assertDraft(2, 2934, 19)
M.Start(M.groups[4]); assert(#sent == 1)
draft = {}
event('MAIL_SEND_SUCCESS')
events.OnUpdate(nil, .5); assert(#sent == 1)
events.OnUpdate(nil, .5); assert(#sent == 2)
assertDraft(1, 2318, 2)
assertDraft(2, 8170, 8)
assert(not visited[5] and not visited[6] and visited[7])
draft = {}
event('MAIL_SEND_SUCCESS')
events.OnUpdate(nil, 1); assert(#sent == 2 and not events.OnUpdate)

reset()
Enum, ATTACHMENTS_MAX_SEND = nil, nil
bags[5] = {size = 1, stack(2934)}
M.Start(M.groups[4]); assert(#sent == 1 and visited[5])
event('MAIL_FAILED'); assert(not events.OnUpdate)
reset()
bags[0] = {size = 1, stack(2934)}
M.Start(M.groups[4])
events.OnUpdate(nil, 16); assert(#sent == 1 and not events.OnUpdate)
reset()
bags[0] = {size = 1, stack(2934)}
M.Start(M.groups[4])
event('PLAYER_REGEN_DISABLED'); assert(#sent == 1 and not events.OnUpdate)
event('MAIL_CLOSED'); M.Start(M.groups[4]); assert(#sent == 1 and not events.OnUpdate)

local function rejectsDraft(setup)
    reset()
    bags[0] = {size = 2, stack(2934, 4), stack(2318)}
    setup()
    M.Start(M.groups[4])
    assert(#sent == 0 and not events.OnUpdate)
end
rejectsDraft(function() draft[12] = {hidden = true} end)
assert(draft[12])
rejectsDraft(function() money = 1 end)
rejectsDraft(function() cod = 1 end)
rejectsDraft(function() cursor = stack(2770) end)
assert(cursor.itemID == 2770)
rejectsDraft(function() pickupOverride = stack(2770, 4) end)
assert(not cursor and not draft[1])
rejectsDraft(function() onAttach = function() draft[1] = stack(2770, 4) end end)
rejectsDraft(function() onAttach = function() draft[1].stackCount = 1 end end)
rejectsDraft(function() onAttach = function() draft[1].hidden = true end end)
rejectsDraft(function() onAttach = function() draft[12] = stack(2770) end end)
rejectsDraft(function()
    onAttach = function(index)
        if index == 2 then draft[1] = stack(2770, 4) end
    end
end)
rejectsDraft(function() onAttach = function() cod = 1 end end)

-- A draft that still has attachments after a success event must not be resent.
reset()
bags[0] = {size = 2, stack(2934), stack(2318)}
ATTACHMENTS_MAX_SEND = 1
M.Start(M.groups[4]); assert(#sent == 1)
event('MAIL_SEND_SUCCESS')
events.OnUpdate(nil, 1)
assert(#sent == 1 and not events.OnUpdate and bags[0][2].itemID == 2318)
ATTACHMENTS_MAX_SEND, NUM_BAG_SLOTS = nil, nil
event('MAIL_CLOSED')
print('PASS: all mail recipients, exclusive routing, mixed bags, stack integrity, drafts and batching')

-- Exercise the actual positioning path with an existing panel.
UIParent={}
MailFrame={GetFrameStrata=function() return 'HIGH' end,
 GetFrameLevel=function() return 4 end,GetHeight=function() return 450 end}
local panel={StopMovingOrSizing=function() end,ClearAllPoints=function() end,
 SetParent=function(self,v) self.parent=v end,SetFrameStrata=function() end,
 SetFrameLevel=function() end,SetHeight=function(self,v) self.height=v end,
 SetPoint=function(self,...) self.anchor={...} end,Show=function(self) self.shown=true end,
 Hide=function(self) self.shown=false end}
M.panel=panel; M.Open=openPanel
M.Open(); assert(panel.parent==UIParent and not panel.docked)
events.OnEvent(nil,'MAIL_SHOW')
assert(panel.parent==MailFrame and panel.docked and panel.height==450)
assert(panel.anchor[1]=='TOPLEFT' and panel.anchor[3]=='TOPRIGHT')
events.OnEvent(nil,'MAIL_CLOSED'); assert(not panel.shown)
M.Open(); assert(panel.parent==UIParent and not panel.docked and panel.height==430)
print('PASS: mail docks at mailbox, closes with mailbox, and undocks for settings')
