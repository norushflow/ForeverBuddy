local _, Buddy = ...
local L = Buddy.L
local B=Buddy.Bars

local flushQueued,initialBackupQueued,retryQueued=false,false,false
local roleLabels={TANK="Tank",HEALER="Heiler",DAMAGER="Schaden"}

function B.Role()
    local role=B.Call(UnitGroupRolesAssigned,"player")
    return roleLabels[role] and role or nil
end

function Buddy.LoadBars()
    B.db=Buddy.db.bars
    B.db.library=B.Table(B.db.library) and B.db.library or {}
    if B.db.automatic==nil then B.db.automatic=true end
    Buddy.char.actions=B.Table(Buddy.char.actions) and Buddy.char.actions or {}
    B.ready=false;B.note=L["Wartet auf Anmeldung"]

    function B.Profile(role)
        local class,name,label=B.Context()
        local shelf=class and B.db.library[class]
        local key=role or "default"
        if role then label=(label or "").." · "..L[roleLabels[role]] end
        return B.Table(shelf) and shelf[key] or nil,class,key,name,label
    end
    function B.SetNote(text)
        B.note=text
        if B.RefreshMenu then B.RefreshMenu() end
    end
    function B.Update()
        if B.RefreshMenu then B.RefreshMenu() end
    end
    function B.RowText()
        return L["Aktionsleisten · Automatik "]..((B.db and B.db.automatic) and L["AN"] or L["AUS"])
    end

    local function stamp(profile,name)
        if B.Text(name) then profile.editor=name end
        local timestamp=B.Call(GetServerTime)
        if B.Number(timestamp) then profile.changed=timestamp end
    end

    function B.Save(announce,role)
        local reason=B.Reason()
        if reason then B.SetNote(reason);if announce then Buddy.Message(reason) end;return false end
        if B.busy or not B.ready then
            B.SetNote(L["Leisten werden noch eingelesen"])
            if announce then Buddy.Message(L["Leisten werden noch eingelesen"]) end
            return false
        end
        local previous,class,key,name,label=B.Profile(role)
        if not class then
            B.SetNote(L["Keine Klasse erkannt"])
            if announce then Buddy.Message(L["Keine Klasse erkannt"]) end
            return false
        end
        local actions, unreadable, ignored = {}, {}, 0
        if B.Table(previous) and B.Table(previous.actions) then
            for slot,entry in pairs(previous.actions) do actions[slot]=entry end
        end
        for _,slot in ipairs(B.slots) do
            local entry,slotReason=B.Read(slot)
            if not entry then
                unreadable[#unreadable+1]=slot..(slotReason and (" · "..slotReason) or "")
            elseif entry.action=="ignored" then
                ignored=ignored+1
                actions[slot]=nil
            elseif entry.action~="keep" or actions[slot]==nil then
                actions[slot]=entry
            end
        end
        if #unreadable==#B.slots then
            B.SetNote(L["Speichern abgebrochen: kein Leistenplatz lesbar"])
            if announce then Buddy.Message(L["Speichern abgebrochen: kein Leistenplatz lesbar"]) end
            return false
        end
        local notes={}
        if #unreadable>0 then
            local shown={}
            for index=1,math.min(#unreadable,5) do shown[index]=unreadable[index] end
            notes[#notes+1]=#unreadable..(#unreadable==1 and L[" Platz nicht lesbar ("] or L[" Plätze nicht lesbar ("])
                ..table.concat(shown,", ")..(#unreadable>5 and ", ..." or "")..")"
        end
        if ignored>0 then
            notes[#notes+1]=ignored..(ignored==1 and L[" allgemeines Makro ignoriert"] or L[" allgemeine Makros ignoriert"])
        end
        local clicks=B.ReadClickBindings()
        if not clicks and role then
            B.SetNote(L["Klickzauber konnten nicht gespeichert werden"])
            if announce then Buddy.Message(B.note) end
            return false
        end
        if not clicks then
            clicks=B.Table(previous) and previous.clickBindings or nil
            notes[#notes+1]=clicks and L["Klickzauber nicht lesbar; bisherige Belegung bleibt gespeichert"]
                or L["Klickzauber konnten nicht gespeichert werden"]
        end
        local details=#notes>0 and (" · "..table.concat(notes," · ")) or ""
        local profile={actions=actions,clickBindings=clicks}
        stamp(profile,name)
        B.db.library[class]=B.Table(B.db.library[class]) and B.db.library[class] or {}
        B.db.library[class][key]=profile
        B.SetNote(L["Vorlage gespeichert"]..details)
        if announce then Buddy.Message(L["Vorlage für "]..(label or tostring(key))..L[" gespeichert"]..details) end
        return true
    end

    function B.Flush()
        if not B.db.automatic or not B.ready or B.busy or B.pending or not B.dirty then return end
        local reason=B.Reason()
        if reason then B.SetNote(reason);return end
        local class,name=B.Context()
        if not class then return end
        local storage=Buddy.char.actions
        local profile=storage[class]
        if not B.Table(profile) then profile={} end
        local actions=B.Table(profile.actions) and profile.actions or {}
        local readable=false
        for _,slot in ipairs(B.slots) do
            local entry=B.Read(slot)
            if entry and entry.action~="keep" then
                readable=true
                actions[slot]=entry.action~="ignored" and entry or nil
            end
        end
        local clicks=B.ReadClickBindings()
        if clicks then profile.clickBindings=clicks end
        if readable or clicks then
            profile.actions=actions
            storage[class]=profile
            stamp(profile,name)
        end
        B.dirty=not readable or (C_ClickBindings and not clicks) or false
    end

    function B.SaveRole()
        local role=B.Role()
        if role then return B.Save(true,role) end
        B.SetNote(L["Keine Rolle zugewiesen"])
        return false
    end

    function B.Apply(announce,role)
        B.pending=nil
        local profile,class=B.Profile(role)
        if not class then
            B.SetNote(L["Keine Klasse erkannt"]);return false
        end
        if not B.Table(profile) or not B.Table(profile.actions) then
            B.SetNote(role and L["Keine Vorlage für diese Rolle"] or L["Keine Vorlage für diese Klasse"]);return false
        end
        local request={class=class,role=role,automatic=not announce and role~=nil}
        local reason=B.Reason()
        if reason then
            B.pending=request;B.SetNote(reason)
            if announce then Buddy.Message(reason..L["; Laden wird nachgeholt"]) end
            return false
        end
        if B.busy then return false end
        if not B.APIs() then
            B.SetNote(L["Leisten-API fehlt; nichts geändert"])
            if announce then Buddy.Message(L["Leisten-API fehlt; nichts geändert"]) end
            return false
        end
        if not B.CursorFree() then
            if request.automatic then B.pending=request end
            B.SetNote(L["Mauszeiger ist belegt; nichts geändert"])
            if announce then Buddy.Message(L["Mauszeiger ist belegt; nichts geändert"]) end
            return false
        end
        B.busy=true
        local skipped,changed,ignored=0,0,0
        local clicksLoaded=true
        local missingMacros={}
        local ok=pcall(function()
            B.ClearCursor()
            for _,slot in ipairs(B.slots) do
                -- Ein Kampfbeginn während des Ladens bricht ab; der Rest wird
                -- nicht mit falschen Cursor-/Leistenoperationen fortgesetzt.
                if B.Reason() then error("barrier") end
                local entry=profile.actions[slot]
                if not B.Table(entry) or not B.Text(entry.action) then
                    -- Kein Eintrag: Platz bleibt unangetastet und wird nicht
                    -- als ausgelassen gezählt.
                elseif entry.action=="keep" then
                    skipped=skipped+1
                elseif entry.action=="ignored" then
                    ignored=ignored+1
                else
                    local macroScope
                    if entry.action=="macro" and B.Text(entry.value) then
                        macroScope=select(2,B.MacroLookup(entry.value))
                    end
                    if entry.action=="macro" and macroScope=="account" then
                        -- Accountweite Makros werden weder geladen noch als
                        -- fehlend gezählt; der vorhandene Platz bleibt stehen.
                        ignored=ignored+1
                    elseif not B.Settable(slot) then
                        -- Besitz-/reservierte Plätze: gespeichert, aber nie geschrieben.
                        if entry.action~="empty" then skipped=skipped+1 end
                    else
                        local current=B.Read(slot)
                        if not current then
                            skipped=skipped+1
                        elseif current.action==entry.action and current.value==entry.value then
                            -- Unveränderte Plätze brauchen keine Cursor-/Leistenoperation.
                        elseif entry.action=="empty" then
                            PickupAction(slot);B.ClearCursor();changed=changed+1
                        elseif B.Pick(entry) then
                            PlaceAction(slot);B.ClearCursor();changed=changed+1
                        else
                            B.ClearCursor();skipped=skipped+1
                            if entry.action=="macro" and macroScope=="missing" then
                                missingMacros[#missingMacros+1]=entry.value
                            end
                        end
                    end
                end
            end
            if B.Reason() then error("barrier") end
            clicksLoaded=B.ApplyClickBindings(profile)
        end)
        B.ClearCursor()
        B.busy=false
        if not ok and B.Reason() then B.pending=request end
        B.dirty=true
        B.QueueFlush()
        if ok then
            local details={}
            if not clicksLoaded then details[#details+1]=L["Klickzauber konnten nicht geladen werden"] end
            if #missingMacros>0 then
                local shown={}
                for index=1,math.min(#missingMacros,5) do shown[index]=missingMacros[index] end
                details[#details+1]=L["fehlende Charakter-Makros: "]..table.concat(shown,", ")
                    ..(#missingMacros>5 and ", ..." or "")
            end
            if ignored>0 then
                details[#details+1]=ignored..(ignored==1 and L[" allgemeines Makro ignoriert"] or L[" allgemeine Makros ignoriert"])
            end
            local summary=changed..L[" Plätze geladen, "]..skipped..L[" ausgelassen"]
                ..(#details>0 and (" · "..table.concat(details," · ")) or "")
            B.SetNote(summary)
            if announce then Buddy.Message(L["Vorlage geladen: "]..summary) end
        else
            B.SetNote(L["Laden unterbrochen; Leisten prüfen und erneut laden"])
            if announce then Buddy.Message(L["Laden unterbrochen; Leisten prüfen und erneut laden"]) end
        end
        return ok
    end

    function B.QueueFlush(delay)
        if flushQueued then return end
        flushQueued=true
        C_Timer.After(delay or .5,function()
            flushQueued=false
            B.Flush()
        end)
    end

    function B.QueueRetry(delay)
        if retryQueued then return end
        retryQueued=true
        C_Timer.After(delay or .5,function()
            retryQueued=false
            local pending=B.pending
            if pending and not B.busy then
                B.pending=nil
                if pending.class==B.Context() and (not pending.automatic
                    or (B.db.roleSync and pending.role==B.Role())) then
                    B.Apply(not pending.automatic,pending.role)
                end
            end
            if B.dirty then B.QueueFlush(0) end
        end)
    end

    local function updateRole()
        local role=B.Role()
        if role==B.role then return end
        B.role=role
        if B.pending and B.pending.automatic then B.pending=nil end
        if role and B.db.roleSync then B.Apply(false,role) end
        if B.dirty then B.QueueFlush() end
        B.Update()
    end

    function B.QueueInitialBackup(delay)
        if initialBackupQueued then return end
        initialBackupQueued=true
        C_Timer.After(delay or 1,function()
            initialBackupQueued=false
            B.role=B.Role()
            B.ready=true
            B.dirty=true
            B.SetNote(B.db.automatic and L["Automatik an"] or L["Automatik aus"])
            B.Flush()
        end)
    end

    function B.SetAutomatic(enabled)
        B.db.automatic=enabled and true or false
        B.SetNote(B.db.automatic and L["Automatik an"] or L["Automatik aus"])
        if B.db.automatic then B.dirty=true;B.QueueFlush() end
    end

    function B.SetRoleSync(enabled)
        B.db.roleSync=enabled and true or false
        if not enabled and B.pending and B.pending.automatic then
            B.pending=nil
            B.QueueFlush()
        end
        B.Update()
    end

    function B.Status()
        local profile,_,_,_,label=B.Profile()
        local state=B.db.automatic and L["Automatik AN"] or L["Automatik AUS"]
        local suffix=B.Table(profile) and L["Vorlage vorhanden"] or L["keine Vorlage"]
        return state,label or L["Keine Klasse erkannt"],suffix,B.Table(profile) and profile or nil
    end

    -- Kompakte Bedienung im bestehenden Buddy-Menü; kein eigenes Fenster.
    B.MENU_HEIGHT=152
    function B.BuildMenu(parent,top)
        local box=CreateFrame("Frame",nil,parent,"BackdropTemplate")
        box:SetPoint("TOPLEFT",22,top);box:SetSize(346,B.MENU_HEIGHT)
        Buddy.Style.Inset(box)
        local title=box:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        title:SetPoint("TOPLEFT",10,-8);title:SetText(L["Aktionsleisten-Vorlagen"])
        B.menuStatus=box:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        B.menuStatus:SetPoint("TOPLEFT",10,-27);B.menuStatus:SetWidth(326)
        B.menuStatus:SetJustifyH("LEFT")
        B.menuNote=box:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
        B.menuNote:SetPoint("TOPLEFT",10,-45);B.menuNote:SetWidth(326)
        B.menuNote:SetJustifyH("LEFT")
        local save=Buddy.Style.Button(CreateFrame("Button",nil,box,"UIPanelButtonTemplate"))
        save:SetSize(150,24);save:SetPoint("BOTTOMLEFT",10,66);save:SetText(L["Vorlage speichern"])
        save:SetScript("OnClick",function() B.Save(true) end)
        local load=Buddy.Style.Button(CreateFrame("Button",nil,box,"UIPanelButtonTemplate"))
        load:SetSize(150,24);load:SetPoint("BOTTOMRIGHT",-10,66);load:SetText(L["Vorlage laden"])
        load:SetScript("OnClick",function() B.Apply(true) end)
        local roleSave=Buddy.Style.Button(CreateFrame("Button",nil,box,"UIPanelButtonTemplate"))
        roleSave:SetSize(326,24);roleSave:SetPoint("BOTTOMLEFT",10,38)
        roleSave:SetText(L["Vorlage nach Rolle speichern"])
        roleSave:SetScript("OnClick",B.SaveRole)
        local sync=CreateFrame("CheckButton",nil,box,"UICheckButtonTemplate")
        sync:SetSize(24,24);sync:SetPoint("BOTTOMLEFT",10,10)
        local syncLabel=box:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        syncLabel:SetPoint("LEFT",sync,"RIGHT",2,0)
        syncLabel:SetText(L["Synchronisierung nach Rolle"])
        sync:SetScript("OnClick",function(self) B.SetRoleSync(self:GetChecked()) end)
        B.syncCheckbox=sync
        B.menu=box
        B.RefreshMenu()
        return B.MENU_HEIGHT
    end
    function B.RefreshMenu()
        if B.menuButton and B.RowText then B.menuButton:SetText(B.RowText()) end
        if not B.menu then return end
        local state,label,suffix,profile=B.Status()
        local editor=B.Table(profile) and B.Text(profile.editor) and (" · "..profile.editor) or ""
        B.menuStatus:SetText(state.." · "..label.." · "..suffix..editor)
        B.menuNote:SetText(B.note or "")
        B.syncCheckbox:SetChecked(B.db.roleSync==true)
    end

    function B.Command(input)
        local command=(input or ""):lower():match("^%s*(.-)%s*$")
        if command=="speichern" or command=="save" then B.Save(true)
        elseif command=="laden" or command=="apply" then B.Apply(true)
        elseif command=="an" or command=="on" then B.SetAutomatic(true)
        elseif command=="aus" or command=="off" then B.SetAutomatic(false)
        elseif command=="status" then
            local state,label,suffix=B.Status()
            Buddy.Message(state.." · "..label.." · "..suffix)
        else Buddy.Toggle() end
    end
    SlashCmdList.FOREVERBUDDYBARS=B.Command
    SLASH_FOREVERBUDDYBARS1="/fbbars"

    if C_ClickBindings and type(hooksecurefunc)=="function" then
        local function clicksChanged()
            if not B.db.automatic or not B.ready or B.busy or B.pending then return end
            B.dirty=true
            B.QueueFlush()
        end
        for _,method in ipairs({"SetProfileByInfo","ResetCurrentProfile"}) do
            if type(C_ClickBindings[method])=="function" then
                hooksecurefunc(C_ClickBindings,method,clicksChanged)
            end
        end
    end

    B.events=CreateFrame("Frame")
    B.events:SetScript("OnEvent",function(_,event,arg)
        if event=="PLAYER_LOGIN" then
            B.QueueInitialBackup(1.5)
        elseif event=="PLAYER_ENTERING_WORLD" then
            if not B.ready and not initialBackupQueued then B.QueueInitialBackup(.5) end
        elseif event=="ACTIONBAR_SLOT_CHANGED" then
            if not B.db.automatic or not B.ready or B.busy or B.pending then return end
            if B.ValidSlot(arg) or arg==0 then
                B.dirty=true
                B.QueueFlush()
            end
        elseif event=="PLAYER_ROLES_ASSIGNED" or event=="ROLE_CHANGED_INFORM" or event=="GROUP_ROSTER_UPDATE" then
            if B.ready then updateRole() end
        elseif event=="PLAYER_REGEN_ENABLED" or event=="CURSOR_CHANGED"
            or event=="UPDATE_OVERRIDE_ACTIONBAR" or event=="UPDATE_VEHICLE_ACTIONBAR"
            or event=="UPDATE_POSSESS_BAR" or event=="UPDATE_SHAPESHIFT_FORM"
            or event=="UPDATE_BONUS_ACTIONBAR" then
            if not B.busy and (B.pending or B.dirty) then B.QueueRetry() end
        elseif event=="PLAYER_LOGOUT" then
            B.dirty=true
            B.Flush()
        end
    end)
    for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD",
        "ACTIONBAR_SLOT_CHANGED","PLAYER_REGEN_ENABLED","CURSOR_CHANGED","UPDATE_OVERRIDE_ACTIONBAR",
        "UPDATE_VEHICLE_ACTIONBAR","UPDATE_POSSESS_BAR","UPDATE_SHAPESHIFT_FORM",
        "UPDATE_BONUS_ACTIONBAR","PLAYER_LOGOUT"}) do
        B.events:RegisterEvent(event)
    end
    for _,event in ipairs({"PLAYER_ROLES_ASSIGNED","ROLE_CHANGED_INFORM","GROUP_ROSTER_UPDATE"}) do
        pcall(B.events.RegisterEvent,B.events,event)
    end
end
