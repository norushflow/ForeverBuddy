local loadfile = dofile("tests/load_locales.lua")
local B={db={mail={recipients={alchemy='Legacy'},recipientsByFaction={Horde={alchemy='Alt',leatherworking='Alt'}}}},Message=function() end}
assert(loadfile('Modules/MailMaterials.lua'))('Foreverbuddy',B)
assert(loadfile('Modules/Mail.lua'))('Foreverbuddy',B)
local M=B.Mail
assert(#M.groups==8 and M.groups[8][1]=='bank')
local found={}
for _,g in ipairs(M.groups) do found[g[1]]=true end
assert(not found.inscription and not found.jewelcrafting and not found.mining and not found.herbalism)
local counts={0,0,0,0,0,0,0}; local multi=0
for id in pairs(B.MailMaterials) do
    local n=0
    for i=1,7 do if M.Matches(M.groups[i],id) then counts[i]=counts[i]+1; n=n+1 end end
    assert(M.Matches(M.groups[8],id)); if n>1 then multi=multi+1 end
end
for _,n in ipairs(counts) do assert(n>0) end
assert(multi>0 and not M.Matches(M.groups[8],999999999) and not M.Matches(M.groups[8],nil))
assert(M.Matches(M.groups[4],2934) and M.Matches(M.groups[8],2934), 'ruined leather scraps must match leatherworking and bank')
local events, sent, attached, items={},0,{},{{itemID=765},{itemID=765,isBound=true},{itemID=765,isLocked=true}}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function(_,k,v) events[k]=v end} end
SlashCmdList={}
C_Container={GetContainerNumSlots=function(b) return b==(bagUnderTest or 0) and #items or 0 end,
GetContainerItemInfo=function(_,s) return items[s] end,
PickupContainerItem=function(b,s) attached.pick=s; attached.bag=b end}
function GetSendMailItem(i) return attached[i] end
function ClickSendMailItemButton(i) attached[i]=true end
function GetSendMailMoney() return 0 end
GetSendMailCOD=GetSendMailMoney
function GetCursorInfo() end
function GetMoney() return 10000 end
function UnitName() return 'Main' end
function InCombatLockdown() return false end
function SendMail(recipient) assert(recipient=='Alt'); sent=sent+1 end
local faction='Horde'
function UnitFactionGroup() return faction end
function UnitFullName() return 'Main','Family' end
B.LoadMail(); local openPanel=M.Open; M.Open=function() end
M.Start(M.groups[1]); assert(sent==0 and not events.OnUpdate)
events.OnEvent(nil,'MAIL_SHOW'); faction='Alliance'; M.Start(M.groups[1]); assert(sent==0 and not events.OnUpdate)
faction='Horde'; M.Start(M.groups[1]); assert(sent==1 and attached[1] and not attached[2] and events.OnUpdate)
M.Start(M.groups[1]); assert(sent==1)
events.OnEvent(nil,'MAIL_FAILED'); assert(sent==1 and not events.OnUpdate)
attached={}; M.Start(M.groups[1]); assert(sent==2)
attached={}; events.OnEvent(nil,'MAIL_SEND_SUCCESS')
events.OnUpdate(nil,.5); assert(sent==2)
events.OnUpdate(nil,.5); assert(sent==3)
items={}; attached={}; events.OnEvent(nil,'MAIL_SEND_SUCCESS')
events.OnUpdate(nil,1); assert(sent==3 and not events.OnUpdate)
items={{itemID=765}}; M.Start(M.groups[1]); assert(sent==4)
events.OnUpdate(nil,16); assert(sent==4 and not events.OnUpdate)
attached={}; M.Start(M.groups[1]); assert(sent==5)
events.OnEvent(nil,'PLAYER_REGEN_DISABLED'); assert(sent==5 and not events.OnUpdate)
attached={}; M.Start(M.groups[1]); assert(sent==6)
events.OnEvent(nil,'MAIL_CLOSED'); M.Start(M.groups[1]); assert(sent==6 and not events.OnUpdate)
items={{itemID=2934},{itemID=2934,isBound=true},{itemID=2934,isLocked=true}}
attached={}; events.OnEvent(nil,'MAIL_SHOW'); M.Start(M.groups[4])
assert(sent==7 and attached[1] and not attached[2] and attached.pick==1,
    'ruined leather scraps should be attached for leatherworking while bound and locked stacks are excluded')
events.OnEvent(nil,'MAIL_FAILED')
-- Material bag 5 can exist beyond the four normal equipped bag slots.
NUM_BAG_SLOTS=4; Enum={BagIndex={ReagentBag=5}}; bagUnderTest=5
items={{itemID=2934}}; attached={}; M.Start(M.groups[4])
assert(sent==8 and attached[1] and attached.bag==5, 'search the dedicated reagent bag')
events.OnEvent(nil,'MAIL_FAILED'); Enum=nil; attached={}; M.Start(M.groups[4])
assert(sent==9 and attached.bag==5, 'search the reagent bag even if its enum is unavailable')
events.OnEvent(nil,'MAIL_FAILED'); events.OnEvent(nil,'MAIL_CLOSED')
bagUnderTest=nil; Enum=nil; NUM_BAG_SLOTS=nil
print('PASS: mail groups, guards, batching, idle cleanup, failure, timeout and completion')

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
