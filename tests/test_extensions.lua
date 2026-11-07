-- Vertrags-/Zustandstests; keine echte Blizzard- oder Taint-Simulation.
local B={db={meters={}}}
local queue,frames={},{}
local secret=setmetatable({},{__tostring=function() error('secret formatted') end})
function issecretvalue(v) return rawequal(v,secret) end
local combat=false
function InCombatLockdown() return combat end
C_Timer={After=function(_,fn) queue[#queue+1]=fn end}
local function drain()
    local count=0
    while #queue>0 do local fn=table.remove(queue,1);fn();count=count+1;assert(count<100,'timer loop') end
end
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:HookScript(k,v) self.scripts[k]=v end
-- Ereignisnamen aus Blizzards TransmogDocumentation.lua, keine beliebigen Strings.
local transmogEvents={TRANSMOG_COLLECTION_UPDATED=true,
    TRANSMOG_COLLECTION_SOURCE_ADDED=true,TRANSMOG_COLLECTION_SOURCE_REMOVED=true}
function methods:RegisterEvent(k)
    if k:match("^TRANSMOG_") then assert(transmogEvents[k],"unknown event: "..k) end
    self.events[k]=true
end
function methods:IsForbidden() return rawget(self,"forbidden") or false end
function methods:IsShown() return self.shown end
function methods:SetShown(v) self.shown=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetText(v) self.text=v end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:SetFrameStrata(v) self.strata=v end
function methods:SetFrameLevel(v) self.level=v end
function methods:ClearAllPoints() self.points={} end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
local function object()
    return setmetatable({scripts={},events={},points={},shown=true},{__index=function(_,k) return methods[k] or function() end end})
end
function methods:CreateFontString() return object() end
function methods:CreateTexture() return object() end
function CreateFrame(_,name) local f=object();frames[#frames+1]=f;if name then _G[name]=f end;return f end
UIParent=object();GameTooltip=object();UISpecialFrames={};SlashCmdList={}
local zone,difficulty=77,2
function GetInstanceInfo() return 'Testdungeon',zone and 'party' or 'none',difficulty,'Heroisch',nil,nil,nil,zone end
local selected,encounter,filter,spec,slot,diff=99,123,8,42,7,1
EncounterJournal=object();EncounterJournal.shown=false;EncounterJournal.instanceID=99;EncounterJournal.encounterID=123
function EJ_GetLootFilter() return filter,spec end
function EJ_GetDifficulty() return diff end
function EJ_SetLootFilter(c,s) filter,spec=c,s end
function EJ_SetDifficulty(d) diff=d end
function EJ_SelectInstance(id) selected=id;encounter=nil end
function EJ_SelectEncounter(id) encounter=id end
local reads,throw,missing=0,false,false
local items={
 {itemID=1,link='item:1',name='Schwert'},
 {itemID=2,link='item:2',name='Selbe Optik'},
 {itemID=3,link='item:3',name='Helm'},
 {itemID=4,link='item:4',name='Ring'},
}
local function list()
 if filter==1 then return {items[1],items[3]} end
 if filter==2 then return {items[2],items[3]} end
 return items
end
function EJ_GetNumLoot() return #list() end
C_EncounterJournal={
 GetInstanceForGameMap=function(map) return map==77 and 11 or 12 end,
 GetSlotFilter=function() return slot end,SetSlotFilter=function(v) slot=v end,ResetSlotFilter=function() slot=15 end,
 GetBaseDifficultyID=function(d) return d end,InstanceHasDifficultyID=function() return true end,
 GetLootInfoByIndex=function(i)
  reads=reads+1;assert(selected==11 or selected==12);assert(slot==15 and spec==0)
  if throw then error('synthetic read failure') end
  local row=list()[i]
  if missing and row.itemID==3 then return {itemID=3,name='Helm'} end
  return row
 end,
}
local requests,collectionReads=0,0
local collected={[10]=true,[20]=false}
C_Item={IsItemDataCachedByID=function(id) return not (missing and id==3) end,
 RequestLoadItemDataByID=function() requests=requests+1 end,
 GetItemInfoInstant=function(id) return id,nil,nil,id==4 and 'INVTYPE_FINGER' or 'INVTYPE_HEAD',nil,4 end}
C_TransmogCollection={GetItemInfo=function(link)
 if link=='item:1' or link=='item:2' then return 10,100 end
 if link=='item:3' then return 20,200 end
 end,
 GetAppearanceInfoBySource=function(source) collectionReads=collectionReads+1;return {appearanceIsCollected=collected[source/10]} end}
function GetNumClasses() return 2 end
C_CreatureInfo={GetClassInfo=function(id) return {classID=id,className=id==1 and 'Krieger' or 'Paladin'} end}
assert(loadfile('Style.lua'))('Foreverbuddy',B)
assert(loadfile('Modules/Transmog.lua'))('Foreverbuddy',B)
B.LoadTransmog();local T=B.Transmog
assert(T.events.events.TRANSMOG_COLLECTION_SOURCE_ADDED and T.events.events.TRANSMOG_COLLECTION_SOURCE_REMOVED)
assert(T.events.scripts.OnEvent and SlashCmdList.FOREVERBUDDYTRANSMOG,'initialization completed')
T.events.scripts.OnEvent(nil,'PLAYER_ENTERING_WORLD');drain()
assert(T.result.total==2 and T.result.collected==1,'duplicates count once; rings excluded')
assert(T.badge.text:find('50.0 %%'),'percentage')
assert(collectionReads==2,'one collection lookup per appearance')
assert(selected==99 and encounter==123 and filter==8 and spec==42 and slot==7 and diff==1,'journal restored')
local before=reads;T.Toggle();drain()
assert(reads-before==4,'class lookup only on opening')
local lines=T.BuildLines()
assert(#lines==4 and lines[1].heading:find('Krieger') and lines[3].heading:find('Paladin'),'missing helm in both class groups')
T.Toggle();T.Toggle();drain();assert(reads-before==4,'reuse class cache')
assert(T.panel.level==100 and T.panel.strata=='DIALOG')
combat=true;before=reads;T.Update();drain();assert(reads==before,'no combat reads')
assert(T.badge.text:find('50.0 %%'),'keep cached percent in combat')
combat=false;EncounterJournal.shown=true;T.retryLoot=true;T.Update();drain();assert(reads==before,'open journal untouched')
EncounterJournal:Hide();drain();assert(reads>before,'resume on journal close')
throw=true;local rows=T.ReadLoot(0);assert(not rows)
assert(selected==99 and encounter==123 and filter==8 and spec==42 and slot==7 and diff==1,'restore even after read error');throw=false
missing=true;T.retryLoot=true;T.attempts=0;T.Update();drain()
assert(T.result.pending[3] and not T.badge.text:find('100'),'no false complete state')
assert(requests==1 and T.attempts==3 and #queue==0,'bounded retries, one item request')
missing=false;T.events.scripts.OnEvent(nil,'ITEM_DATA_LOAD_RESULT',3);drain();assert(T.result.total==2 and not next(T.result.pending))
collected[20]=true;before=reads;T.events.scripts.OnEvent(nil,'TRANSMOG_COLLECTION_UPDATED');drain()
assert(reads==before and T.result.collected==2,'collection event reuses loot cache')
collected[20]=false;T.events.scripts.OnEvent(nil,'TRANSMOG_COLLECTION_SOURCE_REMOVED',200);drain()
assert(T.result.collected==1 and reads==before,'source removal updates cached collection')
collected[20]=true;T.events.scripts.OnEvent(nil,'TRANSMOG_COLLECTION_SOURCE_ADDED',200);drain()
assert(T.result.collected==2 and reads==before,'source addition updates cached collection')
local saved=items[1].link;items[1].link=secret;T.retryLoot=true;T.Update();drain();assert(T.result.pending[1],'secret link never used');items[1].link=saved
zone=nil;T.events.scripts.OnEvent(nil,'PLAYER_ENTERING_WORLD');drain()
assert(not T.badge:IsShown() and not T.panel:IsShown() and not T.loot,'leave clears active instance')
before=reads;T.events.scripts.OnEvent(nil,'TRANSMOG_COLLECTION_UPDATED');drain();assert(reads==before and #queue==0)
zone=77;difficulty=1;T.events.scripts.OnEvent(nil,'PLAYER_ENTERING_WORLD');drain();assert(T.context.key=='77:1','difficulty cache reset')
print('PASS: transmog deduplication, classes, cache, journal restoration, partial data, secrets, combat and exit')
