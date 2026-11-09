local _, Buddy = ...
local L = Buddy.L
local T = {}
Buddy.Transmog = T
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v) return public(v) and type(v)=="number" end
local function text(v) return public(v) and type(v)=="string" end
local function record(v) return public(v) and type(v)=="table" end
local function foreign(frame, fn)
    if not public(frame) or not frame then return false end
    return pcall(function()
        local forbidden=frame:IsForbidden()
        if not public(forbidden) or forbidden then error("forbidden") end
        return fn(frame)
    end)
end
local function journalAvailable()
    if not EncounterJournal then return true end
    local ok, hidden = foreign(EncounterJournal,function(f) local shown=f:IsShown();return public(shown) and not shown end)
    return ok and public(hidden) and hidden
end
local function current()
    if not GetInstanceInfo then return end
    local name, kind, difficulty, difficultyName, _, _, _, map = GetInstanceInfo()
    if not text(kind) or (kind~="party" and kind~="raid") or not number(map) or not number(difficulty) then return end
    return {name=text(name) and name or L["Instanz"], difficulty=difficulty,
        difficultyName=text(difficultyName) and difficultyName or tostring(difficulty), map=map,
        key=map..":"..difficulty}
end
local function status(message)
    T.status=message
    if T.Render then T.Render() end
end

-- Jede kurze Journaltransaktion stellt Auswahl und Filter vor der Rückgabe wieder her.
-- Keine Auswahl bleibt über einen Timerwechsel hinweg bestehen.
function T.ReadLoot(classID)
    if InCombatLockdown() or not journalAvailable() then return nil,L["Journal geöffnet oder Kampf aktiv."] end
    local J=C_EncounterJournal
    if not J or not J.GetInstanceForGameMap or not EJ_GetLootFilter or not EJ_GetDifficulty then
        return nil,L["Dungeonjournal nicht verfügbar."]
    end
    local id=J.GetInstanceForGameMap(T.context.map)
    if not number(id) or id<=0 then return nil,L["Für diese Instanz gibt es keinen Journaleintrag."] end
    local oldClass,oldSpec=EJ_GetLootFilter()
    local oldDifficulty,oldSlot=EJ_GetDifficulty(),J.GetSlotFilter()
    if not number(oldClass) or not number(oldSpec) or not number(oldDifficulty) or not number(oldSlot) then
        return nil,L["Journalfilter derzeit nicht lesbar."]
    end
    local oldInstance,oldEncounter
    if EncounterJournal then
        local ok,a,b=foreign(EncounterJournal,function(f) return f.instanceID,f.encounterID end)
        if not ok then return nil,L["Journal derzeit nicht lesbar."] end
        oldInstance=number(a) and a>0 and a or nil
        oldEncounter=number(b) and b>0 and b or nil
    end
    local rows={}
    T.scanning=true
    local ok,err=pcall(function()
        EJ_SelectInstance(id)
        local difficulty=T.context.difficulty
        if J.GetBaseDifficultyID then
            local base=J.GetBaseDifficultyID(difficulty)
            if number(base) and base>0 then difficulty=base end
        end
        local valid=J.InstanceHasDifficultyID(difficulty)
        if not public(valid) or not valid then error(L["Schwierigkeit nicht im Journal verfügbar."]) end
        EJ_SetDifficulty(difficulty)
        EJ_SetLootFilter(classID,0)
        J.ResetSlotFilter()
        local count=EJ_GetNumLoot()
        if not number(count) or count<0 or count>5000 then error(L["Beuteliste nicht lesbar."]) end
        if count==0 then rows.incomplete=true end
        for i=1,count do
            local item=J.GetLootInfoByIndex(i)
            if record(item) and number(item.itemID) then
                rows[#rows+1]={id=item.itemID,link=text(item.link) and item.link or nil,
                    name=text(item.name) and item.name or (L["Gegenstand "]..item.itemID),
                    boss=number(item.encounterID) and item.encounterID or nil}
            else rows.incomplete=true end
        end
    end)
    -- Getrennte pcall-Aufrufe: ein Fehler darf die übrige Wiederherstellung nicht verhindern.
    local restored=true
    local function restore(fn,...) if not pcall(fn,...) then restored=false end end
    if oldInstance then restore(EJ_SelectInstance,oldInstance) end
    restore(EJ_SetDifficulty,oldDifficulty)
    if oldEncounter then restore(EJ_SelectEncounter,oldEncounter) end
    restore(EJ_SetLootFilter,oldClass,oldSpec)
    restore(J.SetSlotFilter,oldSlot)
    T.scanning=false
    if not ok or not restored then return nil,text(err) and err or L["Journal konnte nicht gelesen werden."] end
    return rows
end

-- Nur echte Vorlagen zählen. Ringe, Schmuckstücke, Rezepte etc. zählen nicht.
local nonVisual={INVTYPE_NECK=true,INVTYPE_FINGER=true,INVTYPE_TRINKET=true}
function T.Resolve(rows)
    local result={items={},appearances={},pending={},unresolved=0,total=0,collected=0,incomplete=rows.incomplete}
    local links={}
    for _,row in ipairs(rows) do
        local key=row.link or row.id
        local item=links[key]
        if not item then
            item={row=row};links[key]=item
            local cached=C_Item.IsItemDataCachedByID(row.id)
            if not public(cached) or not cached or not row.link then
                result.pending[row.id]=true
                if public(cached) and not cached and not T.requested[row.id] then
                    T.requested[row.id]=true;C_Item.RequestLoadItemDataByID(row.id)
                end
            else
                local appearance,source=C_TransmogCollection.GetItemInfo(row.link)
                if number(appearance) and appearance>0 and number(source) and source>0 then
                    item.appearance=appearance
                    local entry=result.appearances[appearance]
                    if not entry then
                        local info=C_TransmogCollection.GetAppearanceInfoBySource(source)
                        local known=record(info) and public(info.appearanceIsCollected) and type(info.appearanceIsCollected)=="boolean"
                        entry={collected=known and info.appearanceIsCollected or false}
                        if not known then result.pending[row.id]=true end
                        result.appearances[appearance]=entry
                        result.total=result.total+1
                        if entry.collected then result.collected=result.collected+1 end
                    end
                    item.collected=entry.collected
                else
                    local _,_,_,slot,_,class=C_Item.GetItemInfoInstant(row.id)
                    if not text(slot) or not number(class) then
                        result.pending[row.id]=true
                    elseif not nonVisual[slot] and (slot~="" or class==4) then
                        -- Tokens/fehlende Zuordnung werden nicht als gesammelt ausgegeben.
                        result.unresolved=result.unresolved+1;item.unresolved=true
                    end
                end
            end
            if item.appearance or item.unresolved then result.items[#result.items+1]=item end
        end
    end
    return result
end

function T.RefreshCollection()
    if not T.loot then return end
    local ok,result=pcall(T.Resolve,T.loot)
    if not ok then status(L["Sammlungsdaten derzeit nicht verfügbar."]);return end
    T.result=result
    if result.incomplete or next(result.pending) then status(L["Daten werden geladen …"])
    elseif result.total==0 then status(L["Keine direkt zugeordneten Vorlagen im Journal."])
    else status(nil) end
end

local function schedule(delay)
    if T.queued then return end
    T.queued=true
    C_Timer.After(delay or .15,function() T.queued=false;T.Update() end)
end
T.Schedule=schedule
function T.Update()
    local context=current()
    if not context then
        T.context=nil;T.loot=nil;T.result=nil;T.groups=nil;T.requested={}
        if T.badge then T.badge:Hide() end
        if T.panel then T.panel:Hide() end
        return
    end
    if not T.context or T.context.key~=context.key then
        T.context=context;T.loot=nil;T.result=nil;T.groups=nil;T.classIndex=nil;T.requested={};T.attempts=0
    end
    T.CreateBadge();T.badge:Show()
    if InCombatLockdown() then status(L["Aktualisierung nach dem Kampf"]);return end
    if not journalAvailable() then status(L["Aktualisierung nach Schließen des Journals"]);return end
    if not C_TransmogCollection or not C_Item then status(L["Transmog-API nicht verfügbar."]);return end
    if not T.loot or T.retryLoot then
        T.retryLoot=nil
        local rows,err=T.ReadLoot(0)
        if not rows then status(err);return end
        T.loot=rows;T.groups=nil;T.classIndex=nil
    end
    T.RefreshCollection()
    if T.result and (T.result.incomplete or next(T.result.pending)) and T.attempts<3 then
        T.attempts=T.attempts+1;T.retryLoot=true;schedule(.8)
    end
    if T.panel and T.panel:IsShown() and T.result then T.LoadNextClass() end
end

-- Klassenzuordnung erst beim Öffnen der Liste, ein Klassenfilter pro kurzem Durchlauf.
function T.LoadNextClass()
    local context=current()
    if not context or not T.context or context.key~=T.context.key then return end
    if InCombatLockdown() or not journalAvailable() then return end
    T.groups=T.groups or {}
    T.classes=T.classes or {}
    if #T.classes==0 then
        local count=GetNumClasses()
        if not number(count) or count>100 then return end
        for i=1,count do
            local info=C_CreatureInfo.GetClassInfo(i)
            if record(info) and number(info.classID) and text(info.className) then
                T.classes[#T.classes+1]={id=info.classID,name=info.className}
            end
        end
    end
    local index=T.classIndex or 1
    local class=T.classes[index]
    if not class then T.Render();return end
    local rows,err=T.ReadLoot(class.id)
    if not rows then status(err);return end
    local ids={}
    for _,row in ipairs(rows) do ids[row.id]=true end
    T.groups[class.id]=ids;T.classIndex=index+1
    T.Render()
    if T.classes[T.classIndex] then
        local key=T.context.key
        C_Timer.After(.05,function()
            if T.context and T.context.key==key and T.panel:IsShown() then T.LoadNextClass() end
        end)
    end
end

local function label(parent,value,x,y,width)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f:SetPoint("TOPLEFT",x,y);f:SetWidth(width);f:SetJustifyH("LEFT");f:SetText(value);return f
end
function T.CreateBadge()
    if T.badge then return end
    local b=Buddy.Style.Button(CreateFrame("Button","ForeverbuddyTransmogBadge",UIParent,"UIPanelButtonTemplate"))
    -- Rechts neben der mittigen Fußleistenuhr (100 Punkte breit), 12 Punkte Abstand.
    -- Eigener Bildschirmanker: keine Abhängigkeit oder Änderung am UI-Addon.
    T.badge=b;b:SetSize(230,28);b:SetPoint("BOTTOMLEFT",UIParent,"BOTTOM",62,5)
    b:SetFrameStrata("HIGH");b:SetClampedToScreen(true)
    b:SetScript("OnClick",function() T.Toggle() end)
end
function T.BuildLines()
    local lines={}
    if not T.result then return lines end
    local assigned={}
    for _,class in ipairs(T.classes or {}) do
        local ids=T.groups and T.groups[class.id]
        if ids then
            local group={}
            for _,item in ipairs(T.result.items) do
                if not item.collected and ids[item.row.id] then
                    group[#group+1]=item;assigned[item]=true
                end
            end
            if #group>0 then
                lines[#lines+1]={heading=class.name.." · "..#group}
                for _,item in ipairs(group) do lines[#lines+1]=item end
            end
        end
    end
    local other={}
    for _,item in ipairs(T.result.items) do if not item.collected and not assigned[item] then other[#other+1]=item end end
    if #other>0 then
        lines[#lines+1]={heading=L["Weitere / noch nicht zugeordnete Gegenstände"]}
        for _,item in ipairs(other) do lines[#lines+1]=item end
    end
    return lines
end
function T.Render()
    if not T.badge then return end
    local r=T.result
    local value="Transmog: …"
    if r and r.total>0 and not r.incomplete and not next(r.pending) then
        value=string.format("Transmog: %.1f %% (%d/%d)",r.collected/r.total*100,r.collected,r.total)
        if r.unresolved>0 then value=value.." *" end
    elseif r and r.total==0 and not next(r.pending) then value=L["Transmog: keine Vorlagen"] end
    if T.status and (not r or r.incomplete or next(r.pending)) then value="Transmog: …" end
    T.badge:SetText(value)
    if not T.panel or not T.panel:IsShown() then return end
    local context=T.context
    T.heading:SetText(context and (context.name.." · "..context.difficultyName) or L["Keine Dungeon-/Raidinstanz"])
    local loading=T.classes and T.classes[T.classIndex or 1]
    T.summary:SetText((T.status or value)..(loading and L["\nKlassenzuordnung wird geladen …"] or ""))
    local lines=T.BuildLines()
    T.offset=math.max(0,math.min(T.offset or 0,math.max(0,#lines-14)))
    for i,button in ipairs(T.rows) do
        local entry=lines[T.offset+i];button.entry=entry
        button:SetShown(entry~=nil)
        if entry then
            button.label:SetText(entry.heading and ("|cffd0d0d0"..entry.heading.."|r") or
                ((entry.row.link or entry.row.name)..(entry.unresolved and L["  [Zuordnung offen]"] or "")))
        end
    end
    T.page:SetText(#lines>0 and string.format(L["%d–%d / %d · Mausrad zum Scrollen"],T.offset+1,math.min(T.offset+14,#lines),#lines) or L["Keine fehlenden Vorlagen in den geladenen Daten."])
end
function T.Toggle()
    if not current() then Buddy.Message(L["Die Transmogübersicht ist innerhalb eines Dungeons oder Raids verfügbar."]);return end
    if not T.panel then
        local p=CreateFrame("Frame","ForeverbuddyTransmogFrame",UIParent,"BackdropTemplate")
        T.panel=p;p:SetSize(650,560);p:SetPoint("CENTER");p:SetFrameStrata("DIALOG");p:SetFrameLevel(100)
        p:SetClampedToScreen(true);p:SetMovable(true);p:EnableMouse(true);p:RegisterForDrag("LeftButton")
        p:SetScript("OnDragStart",p.StartMoving);p:SetScript("OnDragStop",p.StopMovingOrSizing)
        Buddy.Style.Window(p)
        label(p,L["|cffd0d0d0ForeverBuddy · Dungeon-Transmog|r"],20,-18,600)
        T.heading=label(p,"",20,-48,600);T.summary=label(p,"",20,-74,600)
        label(p,L["Accountweite Vorlagen · aktuelle Schwierigkeit · Klassen laut Journal\nMehrfachbeute zählt einmal. * Tokens/offene Zuordnungen zählen nicht zur Prozentzahl."],20,-118,610)
        T.rows={}
        for i=1,14 do
            local b=CreateFrame("Button",nil,p);b:SetSize(600,23);b:SetPoint("TOPLEFT",20,-167-(i-1)*23)
            b.label=label(b,"",0,0,600);b.label:SetHeight(22);b.label:SetWordWrap(false);T.rows[i]=b
            b:SetScript("OnClick",function(self)
                if self.entry and self.entry.row and self.entry.row.link and not InCombatLockdown() then
                    HandleModifiedItemClick(self.entry.row.link)
                end
            end)
            b:SetScript("OnEnter",function(self)
                if self.entry and self.entry.row and self.entry.row.link and not InCombatLockdown() then
                    foreign(GameTooltip,function(t) t:SetOwner(self,"ANCHOR_RIGHT");t:SetHyperlink(self.entry.row.link);t:Show() end)
                end
            end)
            b:SetScript("OnLeave",function() foreign(GameTooltip,function(t) t:Hide() end) end)
        end
        p:EnableMouseWheel(true);p:SetScript("OnMouseWheel",function(_,delta) T.offset=(T.offset or 0)-delta*3;T.Render() end)
        p:SetScript("OnHide",function() foreign(GameTooltip,function(t) t:Hide() end) end)
        T.page=label(p,"",20,-499,600)
        local refresh=Buddy.Style.Button(CreateFrame("Button",nil,p,"UIPanelButtonTemplate"))
        refresh:SetSize(180,24);refresh:SetPoint("BOTTOMRIGHT",-20,12);refresh:SetText(L["Neu einlesen"])
        refresh:SetScript("OnClick",function() T.retryLoot=true;T.attempts=0;schedule() end)
        local close=CreateFrame("Button",nil,p,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-3,-3)
        UISpecialFrames[#UISpecialFrames+1]="ForeverbuddyTransmogFrame"
    else T.panel:SetShown(not T.panel:IsShown()) end
    if T.panel:IsShown() then T.Render();schedule() end
end
function Buddy.LoadTransmog()
    T.requested={};T.attempts=0
    local e=CreateFrame("Frame");T.events=e
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","PLAYER_DIFFICULTY_CHANGED","PLAYER_REGEN_ENABLED",
        "PLAYER_REGEN_DISABLED","EJ_LOOT_DATA_RECIEVED","ITEM_DATA_LOAD_RESULT","TRANSMOG_COLLECTION_UPDATED",
        "TRANSMOG_COLLECTION_SOURCE_ADDED","TRANSMOG_COLLECTION_SOURCE_REMOVED","ADDON_LOADED"}) do e:RegisterEvent(event) end
    local function hookJournal()
        if EncounterJournal and not T.journalHook then
            local ok=foreign(EncounterJournal,function(f) f:HookScript("OnHide",function() if T.context then schedule() end end) end)
            T.journalHook=ok
        end
    end
    e:SetScript("OnEvent",function(_,event,id)
        if event=="ADDON_LOADED" then hookJournal();return end
        if event=="PLAYER_REGEN_DISABLED" then foreign(GameTooltip,function(t) t:Hide() end);return end
        if event=="EJ_LOOT_DATA_RECIEVED" or event=="ITEM_DATA_LOAD_RESULT" then
            if T.scanning or not T.result or not number(id) or not T.result.pending[id] then return end
            T.retryLoot=true
        elseif event:find("TRANSMOG") and not T.context then return end
        schedule()
    end)
    hookJournal()
    SLASH_FOREVERBUDDYTRANSMOG1="/fbtransmog"
    SlashCmdList.FOREVERBUDDYTRANSMOG=T.Toggle
end
