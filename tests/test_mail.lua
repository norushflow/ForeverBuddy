local B={db={mail={recipients={alchemy='Legacy'},recipientsByFaction={Horde={alchemy='Alt'}}}},Message=function() end}
assert(loadfile('Modules/Mail.lua'))('Foreverbuddy',B)
local M=B.Mail
assert(M.Matches(M.groups[1],7,9))
assert(not M.Matches(M.groups[1],2,9))
assert(not M.Matches(M.groups[1],7,5))
local events, sent, attached, items={},0,{},{{itemID=1},{itemID=2,isBound=true},{itemID=3,isLocked=true}}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function(_,k,v) events[k]=v end} end
SlashCmdList={}
C_Container={GetContainerNumSlots=function(b) return b==0 and #items or 0 end,
GetContainerItemInfo=function(_,s) return items[s] end,
PickupContainerItem=function(_,s) attached.pick=s end}
-- Forever no longer exports the old global GetItemInfo.
GetItemInfo=nil
C_Item={GetItemInfoInstant=function(id) return id,nil,nil,nil,nil,7,9 end}
local class,subclass=M.ItemClass(2589)
assert(class==7 and subclass==9)
C_Item.GetItemInfoInstant=nil
C_Item.GetItemInfo=function() return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,7,5 end
class,subclass=M.ItemClass(2589); assert(class==7 and subclass==5)
C_Item.GetItemInfo=nil
assert(M.ItemClass(2589)==nil)
C_Item.GetItemInfoInstant=function(id) return id,nil,nil,nil,nil,7,9 end
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
M.Start(M.groups[1]); assert(sent==0)
events.OnEvent(nil,'MAIL_SHOW'); faction='Alliance'; M.Start(M.groups[1]); assert(sent==0)
faction='Horde'; M.Start(M.groups[1]); assert(sent==1 and attached[1] and not attached[2])
M.Start(M.groups[1]); assert(sent==1)
events.OnEvent(nil,'MAIL_FAILED'); events.OnUpdate(nil,2); assert(sent==1)
attached={}; M.Start(M.groups[1]); assert(sent==2)
items={};attached={};events.OnEvent(nil,'MAIL_SEND_SUCCESS');events.OnUpdate(nil,2);assert(sent==2)
events.OnEvent(nil,'MAIL_CLOSED');M.Start(M.groups[1]);assert(sent==2)
print('PASS: mail groups, mailbox guard, bound/locked exclusions, busy guard, failure and completion')

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
