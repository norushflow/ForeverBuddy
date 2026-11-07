local _, Buddy = ...
local M={windows={}, generation=0}
Buddy.Meters=M
local ROWS=5
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function record(v) return public(v) and type(v)=="table" end
local function number(v) return public(v) and type(v)=="number" end
-- Geheime Zahlen unverändert an Widgets geben, nie in Lua vergleichen/rechnen.
local function widgetNumber(v)
    if public(v) and type(v)~="number" then return 0 end
    return v
end
local function report(message) if Buddy.Message then Buddy.Message(message) end end
local function nativeEnabled()
    if not C_CVar or type(C_CVar.GetCVarBool)~="function" then return nil end
    local ok,value=pcall(C_CVar.GetCVarBool,"damageMeterEnabled")
    if ok and public(value) and type(value)=="boolean" then return value end
end
local function available()
    return C_DamageMeter and type(C_DamageMeter.GetCombatSessionFromType)=="function"
        and Enum and Enum.DamageMeterType and Enum.DamageMeterSessionType
end
local function shown()
    return M.db.active and M.windows[1] and M.windows[1]:IsShown()
end
function M.Clear(window,message)
    for _,row in ipairs(window.rows) do row:Hide() end
    window.note:SetText(message);window.note:Show()
end
function M.Paint(window,session)
    if not record(session) or not record(session.combatSources) then
        M.Clear(window,"Daten derzeit nicht verfügbar");return
    end
    local sources=session.combatSources
    local count=#sources
    window.offset=math.max(0,math.min(window.offset,math.max(0,count-ROWS)))
    if count==0 then M.Clear(window,"Noch keine Kampfdaten");return end
    window.note:Hide()
    local maximum=widgetNumber(session.maxAmount)
    if number(maximum) and maximum<=0 then maximum=1 end
    for i,row in ipairs(window.rows) do
        local index=window.offset+i
        local source=sources[index]
        if record(source) then
            row:SetMinMaxValues(0,maximum)
            row:SetValue(widgetNumber(source.totalAmount))
            row.rank:SetText(index..".")
            -- Namen dürfen secret sein; keine Namensvergleiche, Verkettung oder Sortierung.
            row.name:SetText(source.name)
            row.amount:SetFormattedText("%.0f",widgetNumber(source.totalAmount))
            row.rate:SetFormattedText("%.0f/s",widgetNumber(source.amountPerSecond))
            local class=source.classFilename
            local color
            if public(class) and type(class)=="string" and RAID_CLASS_COLORS then color=RAID_CLASS_COLORS[class] end
            if color then row:SetStatusBarColor(color.r,color.g,color.b,.38)
            else row:SetStatusBarColor(.55,.43,.12,.38) end
            row:Show()
        else row:Hide() end
    end
end
function M.Refresh()
    if not shown() then return end
    if not available() then
        for _,w in ipairs(M.windows) do M.Clear(w,"Schadensdaten-API nicht verfügbar") end
        return
    end
    local sessionType=M.db.overall and Enum.DamageMeterSessionType.Overall or Enum.DamageMeterSessionType.Current
    for _,w in ipairs(M.windows) do
        w.segment:SetText(M.db.overall and "Gesamt" or "Aktuell")
        local ok,data=pcall(C_DamageMeter.GetCombatSessionFromType,sessionType,w.kind)
        if ok then M.Paint(w,data) else M.Clear(w,"Daten derzeit nicht verfügbar") end
    end
end
function M.Schedule()
    if not shown() or M.queued then return end
    M.queued=true
    local generation=M.generation
    C_Timer.After(.2,function()
        if generation~=M.generation then return end
        M.queued=nil;M.Refresh()
    end)
end
local function font(parent,template)
    local text=parent:CreateFontString(nil,"OVERLAY",template or "GameFontHighlightSmall")
    text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",template and 14 or 13,"")
    text:SetShadowColor(0,0,0,1);text:SetShadowOffset(1,-1)
    return text
end
function M.Create()
    if M.windows[1] then return end
    for index,title in ipairs({"Schaden","Heilung"}) do
        local w=CreateFrame("Frame","ForeverbuddyMeter"..index,UIParent,"BackdropTemplate")
        M.windows[index]=w;w:Hide();w:SetSize(260,195)
        w:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",index==1 and -272 or -2,47)
        w:SetClampedToScreen(true);w:SetFrameStrata("MEDIUM")
        Buddy.Style.Window(w,27)
        w.title=font(w,"GameFontNormal");w.title:SetPoint("TOPLEFT",8,-8);w.title:SetText(title)
        local switch=Buddy.Style.Button(CreateFrame("Button",nil,w,"UIPanelButtonTemplate"))
        switch:SetSize(78,22);switch:SetPoint("TOPRIGHT",-6,-3);w.segment=switch
        switch:SetScript("OnClick",function()
            M.db.overall=not M.db.overall
            for _,other in ipairs(M.windows) do other.offset=0 end
            M.Refresh()
        end)
        w.note=font(w);w.note:SetPoint("CENTER");w.note:SetWidth(240)
        w.rows={};w.offset=0
        for i=1,ROWS do
            local row=CreateFrame("StatusBar",nil,w)
            row:SetSize(248,30);row:SetPoint("TOPLEFT",6,-29-(i-1)*31)
            row:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            local background=row:CreateTexture(nil,"BACKGROUND")
            background:SetAllPoints(row);background:SetColorTexture(.06,.045,.015,.35)
            local line=row:CreateTexture(nil,"OVERLAY")
            line:SetPoint("BOTTOMLEFT");line:SetPoint("BOTTOMRIGHT");line:SetHeight(1)
            line:SetColorTexture(.78,.78,.78,.28)
            row.rank=font(row);row.rank:SetPoint("LEFT",3,0);row.rank:SetWidth(20)
            row.name=font(row);row.name:SetPoint("LEFT",24,0);row.name:SetWidth(112)
            row.name:SetJustifyH("LEFT");row.name:SetWordWrap(false)
            row.amount=font(row);row.amount:SetPoint("TOPRIGHT",-4,-1);row.amount:SetWidth(100);row.amount:SetJustifyH("RIGHT")
            row.rate=font(row);row.rate:SetPoint("BOTTOMRIGHT",-4,1);row.rate:SetWidth(100);row.rate:SetJustifyH("RIGHT")
            row:Hide();w.rows[i]=row
        end
        w:EnableMouseWheel(true)
        w:SetScript("OnMouseWheel",function(_,delta)
            w.offset=math.max(0,w.offset-delta*3);M.Refresh()
        end)
    end
end
function M.SyncVisibility(silent)
    -- Keine CVar-Schreibzugriffe bei Login, Ereignissen oder gespeicherter Aktivierung.
    local active, native = M.db.active, nativeEnabled()
    local enable=active and native==false and available()
    if enable then
        M.Create()
        M.windows[1].kind=Enum.DamageMeterType.DamageDone
        M.windows[2].kind=Enum.DamageMeterType.HealingDone
        for _,w in ipairs(M.windows) do w:Show() end
        M.Schedule()
    else
        M.generation=M.generation+1;M.queued=nil
        for _,w in ipairs(M.windows) do w:Hide() end
        -- Hat der Benutzer Blizzards Anzeige wieder eingeschaltet, gilt das eigene
        -- Modul als aus. Sonst würde der nächste /fb meter ausschalten statt einschalten.
        if active and native==true then
            M.db.active=false
            if not silent then report("Blizzards Anzeige ist wieder aktiv; /fb meter schaltet sie erneut aus.") end
        end
    end
end
function M.Toggle()
    if InCombatLockdown() then report("Bitte zum Umschalten das Kampfende abwarten.");return end
    if not available() then report("Blizzards Schadensdaten-API ist nicht verfügbar.");return end
    if not C_CVar or type(C_CVar.SetCVar)~="function" or nativeEnabled()==nil then
        report("Blizzard-Systemeinstellung nicht verfügbar.");return
    end
    local target=not M.db.active
    -- Wie bei EUI: eigene Fenster, Blizzards Daten-API bleibt bei ausgeschalteter nativer UI nutzbar.
    -- Nur diese ausdrückliche Bedienung darf die native Anzeige ausschalten.
    local ok=pcall(C_CVar.SetCVar,"damageMeterEnabled","0")
    if not ok or nativeEnabled()~=false then report("Blizzard hat die Änderung nicht übernommen.");return end
    M.db.active=target
    M.SyncVisibility()
    report(target and "Schaden und Heilung eingeschaltet: unten rechts. Mausrad: weitere Spieler."
        or "Schaden und Heilung ausgeschaltet.")
end
function Buddy.LoadMeters()
    M.db=Buddy.db.meters;M.db.arrange=nil
    M.db.active=M.db.active==true
    M.db.overall=M.db.overall==true
    local e=CreateFrame("Frame");M.events=e
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","DAMAGE_METER_COMBAT_SESSION_UPDATED",
        "DAMAGE_METER_CURRENT_SESSION_UPDATED","DAMAGE_METER_RESET","PLAYER_REGEN_ENABLED","CVAR_UPDATE"}) do e:RegisterEvent(event) end
    e:SetScript("OnEvent",function(_,event,name)
        if event=="PLAYER_ENTERING_WORLD" then M.SyncVisibility(true)
        elseif event=="CVAR_UPDATE" then
            if public(name) and name=="damageMeterEnabled" then M.SyncVisibility() end
        else
            if event=="DAMAGE_METER_CURRENT_SESSION_UPDATED" or event=="DAMAGE_METER_RESET" then
                for _,w in ipairs(M.windows) do w.offset=0 end
            end
            M.Schedule()
        end
    end)
    SLASH_FOREVERBUDDYMETERS1="/fbmeter"
    SlashCmdList.FOREVERBUDDYMETERS=M.Toggle
end
