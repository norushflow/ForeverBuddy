local _, Buddy = ...
local B=Buddy.Bars

local flushQueued,loadQueued,retryQueued=false,false,false

function Buddy.LoadBars()
    B.db=Buddy.db.bars
    B.db.library=B.Table(B.db.library) and B.db.library or {}
    if B.db.automatic==nil then B.db.automatic=true end
    B.dirty={};B.ready=false;B.note="Wartet auf Anmeldung"
    B.class,B.spec=nil,nil
    B.ignoreUntil=0

    function B.Profile()
        local class,spec,guid,name,label=B.Context()
        local shelf=class and B.db.library[class]
        return B.Table(shelf) and shelf[spec] or nil,class,spec,guid,name,label
    end
    function B.SetNote(text)
        B.note=text
        if B.RefreshMenu then B.RefreshMenu() end
    end
    function B.Update()
        if B.RefreshMenu then B.RefreshMenu() end
    end
    function B.RowText()
        return "Aktionsleisten · Automatik "..((B.db and B.db.automatic) and "AN" or "AUS")
    end

    local function stamp(profile,name)
        if B.Text(name) then profile.editor=name end
        local timestamp=B.Call(GetServerTime)
        if B.Number(timestamp) then profile.changed=timestamp end
    end

    function B.Save(announce)
        local reason=B.Reason()
        if reason then B.SetNote(reason);if announce then Buddy.Message(reason) end;return false end
        if B.busy or not B.ready then
            B.SetNote("Leisten werden noch eingelesen")
            if announce then Buddy.Message("Leisten werden noch eingelesen") end
            return false
        end
        local previous,class,spec,_,name,label=B.Profile()
        if not class then
            B.SetNote("Keine Klasse erkannt")
            if announce then Buddy.Message("Keine Klasse erkannt") end
            return false
        end
        local actions, unreadable, ignored = {}, {}, 0
        for _,slot in ipairs(B.slots) do
            local entry,slotReason=B.Read(slot)
            if entry then
                if entry.action=="ignored" then
                    ignored=ignored+1
                else
                    actions[slot]=entry
                end
            else
                unreadable[#unreadable+1]=slot..(slotReason and (" · "..slotReason) or "")
            end
        end
        if #unreadable==#B.slots then
            B.SetNote("Speichern abgebrochen: kein Leistenplatz lesbar")
            if announce then Buddy.Message("Speichern abgebrochen: kein Leistenplatz lesbar") end
            return false
        end
        local notes={}
        if #unreadable>0 then
            local shown={}
            for index=1,math.min(#unreadable,5) do shown[index]=unreadable[index] end
            notes[#notes+1]=#unreadable..(#unreadable==1 and " Platz nicht lesbar (" or " Plätze nicht lesbar (")
                ..table.concat(shown,", ")..(#unreadable>5 and ", ..." or "")..")"
        end
        if ignored>0 then
            notes[#notes+1]=ignored..(ignored==1 and " allgemeines Makro ignoriert" or " allgemeine Makros ignoriert")
        end
        local clicks=B.ReadClickBindings()
        if not clicks then
            clicks=B.Table(previous) and previous.clickBindings or nil
            notes[#notes+1]=clicks and "Klickzauber nicht lesbar; bisherige Belegung bleibt gespeichert"
                or "Klickzauber konnten nicht gespeichert werden"
        end
        local details=#notes>0 and (" · "..table.concat(notes," · ")) or ""
        local profile={actions=actions,clickBindings=clicks}
        stamp(profile,name)
        B.db.library[class]=B.Table(B.db.library[class]) and B.db.library[class] or {}
        B.db.library[class][spec]=profile
        B.dirty={}
        B.clicksDirty=nil
        B.SetNote("Vorlage gespeichert"..details)
        if announce then Buddy.Message("Vorlage für "..(label or tostring(spec)).." gespeichert"..details) end
        return true
    end

    function B.Flush()
        if not B.db.automatic or not B.ready or B.busy or B.pending then return end
        if not next(B.dirty) and not B.clicksDirty then return end
        local reason=B.Reason()
        if reason then B.SetNote(reason);return end
        local profile,class,spec,_,name=B.Profile()
        if not class or class~=B.class or spec~=B.spec
            or not B.Table(profile) or not B.Table(profile.actions) then
            B.dirty={};return
        end
        local changed=false
        if B.clicksDirty then
            local clicks=B.ReadClickBindings()
            if clicks then profile.clickBindings=clicks;changed=true;B.clicksDirty=nil end
        end
        for slot in pairs(B.dirty) do
            local entry=B.Read(slot)
            if B.Table(entry) and entry.action=="ignored" then
                -- Accountweite Makros werden nicht gespeichert. Ein alter
                -- Eintrag für diesen Platz darf beim nächsten Laden nicht
                -- wieder über die aktuelle Leiste geschrieben werden.
                if profile.actions[slot]~=nil then
                    profile.actions[slot]=nil
                    changed=true
                end
            elseif B.Table(entry) and entry.action~="keep" then
                profile.actions[slot]=entry
                changed=true
            end
        end
        B.dirty={}
        if changed then
            stamp(profile,name)
            B.SetNote("Änderungen automatisch gespeichert")
        end
    end

    function B.Apply(announce)
        local profile,class,spec,_,_,label=B.Profile()
        if not class then
            B.pending=nil;B.SetNote("Keine Klasse erkannt");return false
        end
        if not B.Table(profile) or not B.Table(profile.actions) then
            B.pending=nil;B.SetNote("Keine Vorlage für diese Klasse");return false
        end
        local reason=B.Reason()
        if reason then
            B.pending=true;B.SetNote(reason)
            if announce then Buddy.Message(reason.."; Laden wird nachgeholt") end
            return false
        end
        if B.busy then return false end
        if not B.APIs() then
            B.SetNote("Leisten-API fehlt; nichts geändert")
            if announce then Buddy.Message("Leisten-API fehlt; nichts geändert") end
            return false
        end
        if not B.CursorFree() then
            B.SetNote("Mauszeiger ist belegt; nichts geändert")
            if announce then Buddy.Message("Mauszeiger ist belegt; nichts geändert") end
            return false
        end
        B.pending=nil;B.busy=true;B.dirty={};B.clicksDirty=nil
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
        -- Wurde das Laden durch Kampfbeginn abgebrochen, am Kampfende fortsetzen.
        if not ok and B.Reason() then B.pending=true end
        -- Eigene oder verzögerte Slot-Ereignisse dürfen die Vorlage nicht
        -- sofort wieder zurückschreiben.
        B.ignoreUntil=B.Now()+1.5
        if ok then
            local details={}
            if not clicksLoaded then details[#details+1]="Klickzauber konnten nicht geladen werden" end
            if #missingMacros>0 then
                local shown={}
                for index=1,math.min(#missingMacros,5) do shown[index]=missingMacros[index] end
                details[#details+1]="fehlende Charakter-Makros: "..table.concat(shown,", ")
                    ..(#missingMacros>5 and ", ..." or "")
            end
            if ignored>0 then
                details[#details+1]=ignored..(ignored==1 and " allgemeines Makro ignoriert" or " allgemeine Makros ignoriert")
            end
            local summary=changed.." Plätze geladen, "..skipped.." ausgelassen"
                ..(#details>0 and (" · "..table.concat(details," · ")) or "")
            B.SetNote(summary)
            if announce then Buddy.Message("Vorlage geladen: "..summary) end
        else
            B.SetNote("Laden unterbrochen; Leisten prüfen und erneut laden")
            if announce then Buddy.Message("Laden unterbrochen; Leisten prüfen und erneut laden") end
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
            if B.pending and not B.busy then B.Apply(false) end
            if next(B.dirty) or B.clicksDirty then B.QueueFlush(0) end
        end)
    end

    local function loadContext()
        local _,class,spec=B.Profile()
        B.class,B.spec=class,spec
        B.loadedOnce=true
        B.ready=true
        B.dirty={}
        if not class then
            B.SetNote("Keine Klasse erkannt")
        elseif B.db.automatic then
            B.Apply(false)
        else
            B.SetNote("Automatik aus")
        end
    end

    function B.QueueLoad(delay)
        if loadQueued then return end
        loadQueued=true
        C_Timer.After(delay or 1,function()
            loadQueued=false
            if B.db then loadContext() end
        end)
    end

    function B.SetAutomatic(enabled)
        B.db.automatic=enabled and true or false
        B.pending=nil;B.dirty={};B.clicksDirty=nil
        B.SetNote(B.db.automatic and "Automatik an" or "Automatik aus")
        if B.db.automatic then B.QueueLoad(.3) end
    end

    function B.Status()
        local profile,_,_,_,_,label=B.Profile()
        local state=B.db.automatic and "Automatik AN" or "Automatik AUS"
        local suffix=B.Table(profile) and "Vorlage vorhanden" or "keine Vorlage"
        return state,label or "Keine Klasse erkannt",suffix,B.Table(profile) and profile or nil
    end

    -- Kompakte Bedienung im bestehenden Buddy-Menü; kein eigenes Fenster.
    B.MENU_HEIGHT=96
    function B.BuildMenu(parent,top)
        local box=CreateFrame("Frame",nil,parent,"BackdropTemplate")
        box:SetPoint("TOPLEFT",22,top);box:SetSize(346,B.MENU_HEIGHT)
        Buddy.Style.Inset(box)
        local title=box:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        title:SetPoint("TOPLEFT",10,-8);title:SetText("Aktionsleisten-Vorlagen")
        B.menuStatus=box:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        B.menuStatus:SetPoint("TOPLEFT",10,-27);B.menuStatus:SetWidth(326)
        B.menuStatus:SetJustifyH("LEFT")
        B.menuNote=box:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
        B.menuNote:SetPoint("TOPLEFT",10,-45);B.menuNote:SetWidth(326)
        B.menuNote:SetJustifyH("LEFT")
        local save=Buddy.Style.Button(CreateFrame("Button",nil,box,"UIPanelButtonTemplate"))
        save:SetSize(150,24);save:SetPoint("BOTTOMLEFT",10,10);save:SetText("Vorlage speichern")
        save:SetScript("OnClick",function() B.Save(true) end)
        local load=Buddy.Style.Button(CreateFrame("Button",nil,box,"UIPanelButtonTemplate"))
        load:SetSize(150,24);load:SetPoint("BOTTOMRIGHT",-10,10);load:SetText("Vorlage laden")
        load:SetScript("OnClick",function() B.Apply(true) end)
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
            B.clicksDirty=true
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
            B.QueueLoad(1.5)
        elseif event=="PLAYER_ENTERING_WORLD" then
            if not B.loadedOnce and not loadQueued then B.QueueLoad(.5) end
        elseif event=="ACTIONBAR_SLOT_CHANGED" then
            if not B.db.automatic or not B.ready or B.busy or B.pending then return end
            if B.Now()<B.ignoreUntil then return end
            local _,class,spec=B.Profile()
            if class~=B.class or spec~=B.spec then B.QueueLoad(1);return end
            if B.ValidSlot(arg) then
                B.dirty[arg]=true
                B.QueueFlush()
            end
        elseif event=="PLAYER_REGEN_ENABLED" or event=="CURSOR_CHANGED"
            or event=="UPDATE_OVERRIDE_ACTIONBAR" or event=="UPDATE_VEHICLE_ACTIONBAR"
            or event=="UPDATE_POSSESS_BAR" or event=="UPDATE_SHAPESHIFT_FORM"
            or event=="UPDATE_BONUS_ACTIONBAR" then
            if not B.busy and (B.pending or next(B.dirty) or B.clicksDirty) then B.QueueRetry() end
        elseif event=="PLAYER_LOGOUT" then
            B.Flush()
        end
    end)
    for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD",
        "ACTIONBAR_SLOT_CHANGED","PLAYER_REGEN_ENABLED","CURSOR_CHANGED","UPDATE_OVERRIDE_ACTIONBAR",
        "UPDATE_VEHICLE_ACTIONBAR","UPDATE_POSSESS_BAR","UPDATE_SHAPESHIFT_FORM",
        "UPDATE_BONUS_ACTIONBAR","PLAYER_LOGOUT"}) do
        B.events:RegisterEvent(event)
    end
end
