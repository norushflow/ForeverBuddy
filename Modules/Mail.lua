local _, Buddy = ...
local L = Buddy.L
local M = {}
Buddy.Mail = M
-- Trade-goods subclasses; overlapping materials go only to the selected profession.
M.groups = {
    {"alchemy", L["Alchemie"], {[9]=true}},
    {"inscription", L["Inschriftenkunde"], {[9]=true,[16]=true}},
    {"blacksmith", L["Schmiedekunst"], {[7]=true}},
    {"engineering", L["Ingenieurskunst"], {[7]=true,[1]=true}},
    {"jewelcrafting", L["Juwelierskunst"], {[4]=true,[7]=true}},
    {"leatherworking", L["Lederverarbeitung"], {[6]=true}},
    {"tailoring", L["Schneiderei"], {[5]=true}},
    {"enchanting", L["Verzauberkunst"], {[12]=true}},
    {"cooking", L["Kochkunst"], {[8]=true}},
}
function M.Matches(group, class, subclass)
    return class == 7 and group[3][subclass] == true
end
-- Instant classification does not require the full item tooltip to be cached.
function M.ItemClass(itemID)
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if type(instant)=="function" then
        local _,_,_,_,_,class,subclass = instant(itemID)
        return class,subclass
    end
    local full = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(full)=="function" then
        local _,_,_,_,_,_,_,_,_,_,_,class,subclass = full(itemID)
        return class,subclass
    end
end
function Buddy.LoadMail()
    local style = Buddy.Style
    local db = Buddy.db.mail
    -- Legacy recipients have no faction information: retain them for reference,
    -- but never silently assign them to either faction.
    db.recipientsByFaction = type(db.recipientsByFaction)=="table" and db.recipientsByFaction or {}
    local function recipients()
        local faction = UnitFactionGroup("player")
        if faction ~= "Alliance" and faction ~= "Horde" then return nil end
        db.recipientsByFaction[faction] = db.recipientsByFaction[faction] or {}
        return db.recipientsByFaction[faction], faction
    end
    local C = C_Container
    local events = CreateFrame("Frame")
    local active, opened, pending, delay, timeout
    local function note(text) Buddy.Message(text) end
    local function stop(text)
        if active then events:SetScript("OnUpdate", nil) end
        active, pending, delay, timeout = nil, nil, nil, nil
        if text then note(text) end
    end
    local function occupied()
        for i=1,(ATTACHMENTS_MAX_SEND or 12) do
            if GetSendMailItem(i) then return true end
        end
        return false
    end
    local function clean()
        return not occupied() and (GetSendMailMoney() or 0)==0 and (GetSendMailCOD() or 0)==0
    end
    local function batch()
        if not opened or InCombatLockdown() then stop(L["Versand beendet: Mailbox geschlossen oder Kampf."]); return end
        if not clean() or GetCursorInfo() then stop(L["Bitte den Briefentwurf und den Mauszeiger zuerst leeren."]); return end
        if not ((C_Item and (C_Item.GetItemInfoInstant or C_Item.GetItemInfo))
            or GetItemInfoInstant or GetItemInfo) then
            stop(L["Gegenstandsdaten sind in diesem Client nicht verfügbar."]); return
        end
        local n=0
        for bag=0,(NUM_BAG_SLOTS or 4) do
            for slot=1,C.GetContainerNumSlots(bag) do
                local info=C.GetContainerItemInfo(bag,slot)
                if info and not info.isLocked and not info.isBound then
                    local class,subclass = M.ItemClass(info.itemID)
                    if M.Matches(active.group,class,subclass) then
                        C.PickupContainerItem(bag,slot)
                        ClickSendMailItemButton(n+1)
                        if GetCursorInfo() then ClearCursor(); stop(L["Anhang konnte nicht hinzugefügt werden."]); return end
                        if not GetSendMailItem(n+1) then stop(L["Anhang nicht bestätigt. Bitte Brief prüfen."]); return end
                        n=n+1
                        if n >= (ATTACHMENTS_MAX_SEND or 12) then break end
                    end
                end
            end
            if n >= (ATTACHMENTS_MAX_SEND or 12) then break end
        end
        if n==0 then stop(L["Versand abgeschlossen. Keine weiteren passenden, versendbaren Materialien gefunden."]); return end
        if GetMoney() < n*30 then stop(L["Nicht genügend Gold für das Porto. Anhänge bleiben im Entwurf."]); return end
        pending,timeout=true,0
        SendMail(active.recipient,L["Materialien: "]..active.group[2],L["Gesendet mit ForeverBuddy"])
    end
    local function updateSend(_, elapsed)
        if timeout then
            timeout = timeout + elapsed
            if timeout > 15 then
                stop(L["Keine Versandbestätigung. Bitte Mailbox prüfen; kein automatischer Wiederholungsversuch."])
            end
        end
        if delay then
            delay = delay + elapsed
            if delay >= 1 then
                delay = nil
                batch()
            end
        end
    end
    function M.Start(group)
        if active then note(L["Versand läuft bereits."]); return end
        if not opened then note(L["Bitte zuerst eine Mailbox öffnen."]); return end
        if not C or not C.GetContainerItemInfo then note(L["Die Taschen-Schnittstelle ist nicht verfügbar."]); return end
        local list=recipients()
        if not list then note(L["Bitte zuerst eine Fraktion wählen."]); return end
        local recipient=(list[group[1]] or ""):match("^%s*(.-)%s*$")
        if recipient=="" then note(L["Bitte einen Empfänger für "]..group[2]..L[" eintragen."]); return end
        local first,last=UnitFullName("player")
        local ownName=(first or UnitName("player") or "")..(last and last~="" and (" "..last) or "")
        if recipient:lower()==ownName:lower() then note(L["Bitte einen anderen Charakter als Empfänger wählen."]); return end
        active={group=group,recipient=recipient}
        events:SetScript("OnUpdate", updateSend)
        batch()
    end
    function M.Open()
        local list, faction=recipients()
        if not list then note(L["Bitte zuerst eine Fraktion wählen."]); return end
        if not M.panel then
            local p=CreateFrame("Frame","ForeverbuddyMailPanel",UIParent,"BackdropTemplate")
            M.panel=p
            p:SetSize(500,430); p:SetPoint("CENTER"); p:SetFrameStrata("DIALOG")
            p:SetClampedToScreen(true); p:SetMovable(true); p:EnableMouse(true)
            p:RegisterForDrag("LeftButton")
            p:SetScript("OnDragStart",function(self) if not self.docked then self:StartMoving() end end)
            p:SetScript("OnDragStop",p.StopMovingOrSizing)
            style.Window(p,69)
            local title=style.Text(p,"title")
            title:SetPoint("TOPLEFT",18,-25); title:SetText(L["Berufspost · "]..(faction=="Alliance" and L["Allianz"] or "Horde"))
            local hint=style.Text(p,"small",style.Color.muted)
            hint:SetPoint("TOPLEFT",18,-49); hint:SetWidth(464); hint:SetJustifyH("LEFT")
            hint:SetText(L["Vorname Nachname · Empfänger gelten nur für diese Fraktion."])
            local close=style.Close(CreateFrame("Button",nil,p,"UIPanelCloseButton")); close:SetPoint("TOPRIGHT",-3,-3)
            for index,group in ipairs(M.groups) do
                local g=group
                local y=-80-(index-1)*32
                local label=style.Text(p,"body",style.Color.gold)
                label:SetPoint("TOPLEFT",18,y-7); label:SetText(g[2])
                local edit=style.EditBox(CreateFrame("EditBox",nil,p,"InputBoxTemplate"))
                edit:SetSize(190,26); edit:SetPoint("TOPLEFT",190,y); edit:SetAutoFocus(false)
                edit:SetMaxLetters(80); edit:SetText(list[g[1]] or "")
                edit:SetScript("OnTextChanged",function(self) list[g[1]]=self:GetText() end)
                edit:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
                edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
                local send=style.Button(CreateFrame("Button",nil,p,"UIPanelButtonTemplate"))
                send:SetSize(85,26); send:SetPoint("TOPLEFT",395,y); send:SetText(L["Senden"])
                send:SetScript("OnClick",function() edit:ClearFocus(); M.Start(g) end)
            end
            local cancel=style.Button(CreateFrame("Button",nil,p,"UIPanelButtonTemplate"))
            cancel:SetSize(180,26); cancel:SetPoint("BOTTOM",0,15); cancel:SetText(L["Versand stoppen"])
            cancel:SetScript("OnClick",function() stop(L["Weitere Briefe gestoppt. Ein bereits gesendeter Brief bleibt versendet."]) end)
            UISpecialFrames[#UISpecialFrames+1]="ForeverbuddyMailPanel"
        end
        local p=M.panel
        p:StopMovingOrSizing()
        p:ClearAllPoints()
        if opened and MailFrame then
            p.docked=true
            p:SetParent(MailFrame)
            p:SetFrameStrata(MailFrame:GetFrameStrata())
            p:SetFrameLevel(MailFrame:GetFrameLevel()+1)
            p:SetHeight(math.max(410,MailFrame:GetHeight()))
            p:SetPoint("TOPLEFT",MailFrame,"TOPRIGHT",4,0)
        else
            p.docked=false
            p:SetParent(UIParent)
            p:SetFrameStrata("DIALOG")
            p:SetHeight(430)
            p:SetPoint("CENTER",UIParent,"CENTER",0,0)
        end
        p:Show()
    end
    for _,event in ipairs({"MAIL_SHOW","MAIL_CLOSED","MAIL_SEND_SUCCESS","MAIL_FAILED","PLAYER_REGEN_DISABLED"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent",function(_,event)
        if event=="MAIL_SHOW" then opened=true; M.Open()
        elseif event=="MAIL_CLOSED" then opened=false; stop(); if M.panel then M.panel:Hide() end
        elseif event=="PLAYER_REGEN_DISABLED" then stop()
        elseif active and pending then
            if event=="MAIL_SEND_SUCCESS" then pending=nil; timeout=nil; delay=0
            elseif event=="MAIL_FAILED" then stop(L["Versand fehlgeschlagen. Bitte Empfänger und Brief prüfen."]) end
        end
    end)
    SLASH_FOREVERBUDDYMAIL1="/fbmail"
    SlashCmdList.FOREVERBUDDYMAIL=M.Open
end
