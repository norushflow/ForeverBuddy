local loadfile = dofile("tests/load_locales.lua")
local B={db={meters={}},Message=function() end}
local messages=0;B.Message=function() messages=messages+1 end
local secret=setmetatable({}, {__tostring=function() error('secret formatted in Lua') end,
 __lt=function() error('secret comparison') end,__le=function() error('secret comparison') end,
 __add=function() error('secret arithmetic') end,__div=function() error('secret arithmetic') end})
function issecretvalue(v) return rawequal(v,secret) end
local combat=false
function InCombatLockdown() return combat end
local queue={}
C_Timer={After=function(_,fn) queue[#queue+1]=fn end,NewTicker=function() error('permanent polling') end}
local function drain() local n=0;while #queue>0 do local fn=table.remove(queue,1);fn();n=n+1;assert(n<30) end end
local methods={}
function methods:SetScript(k,v) assert(k~='OnUpdate');self.scripts[k]=v end
function methods:RegisterEvent(k) self.events[k]=true end
function methods:SetText(v) self.text=v end
function methods:SetFormattedText(fmt,v) self.format=fmt;self.value=v end
function methods:Hide() self.shown=false end
function methods:Show() self.shown=true end
function methods:IsShown() return self.shown end
function methods:SetPoint(...) self.point={...} end
function methods:SetMinMaxValues(a,b) self.minimum=a;self.maximum=b end
function methods:SetValue(v) self.value=v end
local object
function methods:CreateTexture() return object() end
function methods:CreateFontString() return object() end
object=function() return setmetatable({scripts={},events={},shown=true}, {__index=function(_,k)return methods[k] or function() end end}) end
local created=0
function CreateFrame(kind,name,parent,template)
 assert(not template or template=='UIPanelButtonTemplate' or template=='BackdropTemplate','no native meter templates')
 created=created+1;return object()
end
UIParent=object();SlashCmdList={};RAID_CLASS_COLORS={WARRIOR={r=1,g=.5,b=.2}}
local nativeAccess=0
local forbidden=setmetatable({}, {__index=function() nativeAccess=nativeAccess+1;error('native frame access') end,
 __newindex=function() nativeAccess=nativeAccess+1;error('native frame mutation') end})
DamageMeter=forbidden;DamageMeterSessionWindow1=forbidden;DamageMeterSessionWindow2=forbidden
C_AddOns={LoadAddOn=function() error('native addon load forbidden') end}
EventRegistry={RegisterCallback=function() error('native callback forbidden') end}
local enabled,writes,reject=true,0,false
C_CVar={GetCVarBool=function() return enabled end,SetCVar=function(key,value)
 assert(not combat and key=='damageMeterEnabled' and value=='0');writes=writes+1
 if not reject then enabled=false end
end}
Enum={DamageMeterType={DamageDone=0,HealingDone=2},DamageMeterSessionType={Current=1,Overall=0}}
local reads,fail=0,false
local sources={}
for i=1,12 do
 sources[i]=setmetatable({name='Player '..i,totalAmount=i*100,amountPerSecond=i*10,classFilename='WARRIOR'},
 {__index=function(_,k) if k=='sourceDisplayType' then error('secret display type must not be inspected') end end})
end
sources[1].name=secret;sources[1].totalAmount=secret;sources[1].amountPerSecond=secret;sources[1].classFilename=secret
local session={combatSources=sources,maxAmount=secret,durationSeconds=secret}
C_DamageMeter={GetCombatSessionFromType=function(segment,kind)
 assert(segment==0 or segment==1);assert(kind==0 or kind==2);reads=reads+1
 if fail then error('data unavailable') end
 return session
end}
assert(loadfile('Style.lua'))('Foreverbuddy',B)
assert(loadfile('Modules/Meters.lua'))('Foreverbuddy',B);B.LoadMeters();local M=B.Meters
M.events.scripts.OnEvent(nil,'PLAYER_ENTERING_WORLD');drain()
assert(reads==0 and writes==0 and #M.windows==0,'disabled module creates no windows/queries')
combat=true;M.Toggle();assert(writes==0);combat=false
reject=true;M.Toggle();assert(not M.db.active and #M.windows==0);reject=false
M.Toggle();drain()
assert(M.db.active and not enabled and #M.windows==2 and reads==2,'activation uses two independent API views')
assert(M.windows[1].point[4]==-272 and M.windows[2].point[4]==-2,'left damage, right healing')
assert(#M.windows[1].rows==5 and #M.windows[2].rows==5,'five visible rows per window')
local row=M.windows[1].rows[1]
assert(rawequal(row.maximum,secret) and rawequal(row.value,secret),'secret bar values passed through')
assert(rawequal(row.name.text,secret) and rawequal(row.amount.value,secret) and rawequal(row.rate.value,secret),'secret text passed directly to widgets')
local before=reads
for i=1,100 do M.events.scripts.OnEvent(nil,'DAMAGE_METER_COMBAT_SESSION_UPDATED',secret) end
assert(#queue==1,'bursts coalesced');drain();assert(reads==before+2)
combat=true;M.events.scripts.OnEvent(nil,'DAMAGE_METER_COMBAT_SESSION_UPDATED',secret);drain();combat=false
M.windows[1].scripts.OnMouseWheel(nil,-2)
assert(M.windows[1].offset==6 and M.windows[1].rows[1].name.text=='Player 7','scroll within bounded row pool')
local framesBefore=created
M.windows[1].segment.scripts.OnClick();assert(M.db.overall and created==framesBefore,'reuse rows on segment change')
M.Schedule();M.Toggle();before=reads;drain()
assert(not M.db.active and not M.windows[1]:IsShown() and reads==before,'pending work cancelled on disable')
for i=1,50 do M.events.scripts.OnEvent(nil,'DAMAGE_METER_COMBAT_SESSION_UPDATED') end
assert(#queue==0 and reads==before,'no hidden queries or timers')
M.Toggle();drain();assert(created==framesBefore,'re-enabling reuses frames')
session={combatSources={}};M.Refresh();assert(not M.windows[1].rows[1]:IsShown(),'empty clears stale data')
session=secret;M.Refresh();assert(not M.windows[1].rows[1]:IsShown(),'secret outer record not indexed')
session={combatSources=secret};M.Refresh();assert(not M.windows[1].rows[1]:IsShown(),'secret sources not iterated')
fail=true;M.Refresh();assert(not M.windows[1].rows[1]:IsShown(),'API error clears rows');fail=false
-- F-12: Wird Blizzards Anzeige von außen wieder eingeschaltet, gilt das eigene
-- Modul als aus. Sonst würde der nächste /fb meter ausschalten statt einschalten.
local oldWrites=writes;enabled=true
local beforeMessages=messages
M.events.scripts.OnEvent(nil,'CVAR_UPDATE','damageMeterEnabled');drain()
assert(not M.windows[1]:IsShown() and writes==oldWrites,'external native activation hides own windows without overriding setting')
assert(M.db.active==false,'external override clears the saved state')
assert(messages==beforeMessages+1,'external override is reported once')
M.windows[1]:Show()
M.Toggle();drain()
assert(M.db.active and not enabled and M.windows[1]:IsShown() and writes==oldWrites+1,'one toggle enables again instead of disabling')
-- Beim Login bleibt eine bestehende Überstimmung still und ohne CVar-Schreibzugriff.
M.db.active=true;enabled=true;beforeMessages=messages
M.events.scripts.OnEvent(nil,'PLAYER_ENTERING_WORLD');drain()
assert(messages==beforeMessages and M.db.active==false and not M.windows[1]:IsShown(),'startup override stays silent')
enabled=false;M.db.active=true;M.events.scripts.OnEvent(nil,'PLAYER_ENTERING_WORLD');drain()
assert(M.windows[1]:IsShown(),'saved active state restored without startup writes')
assert(nativeAccess==0,'native frames remain untouched')
print('PASS: two custom meters, secret widget passthrough, scrolling, session switching, batching, hidden idle, native isolation and explicit CVar control')
