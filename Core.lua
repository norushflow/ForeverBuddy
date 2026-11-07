local addonName, Buddy = ...
Buddy.modules = {
    {key="characters", name="Charaktere", loader="LoadCharacters", command="FOREVERBUDDYCHARS"},
    {key="transmog", name="Dungeon-Transmog", loader="LoadTransmog", command="FOREVERBUDDYTRANSMOG"},
    {key="meters", name="Schaden und Heilung", loader="LoadMeters", command="FOREVERBUDDYMETERS"},
    {key="bars", name="Aktionsleisten", loader="LoadBars", command="FOREVERBUDDYBARS", argument="status"},
}
function Buddy.Foreign(frame, action)
    if (issecretvalue and issecretvalue(frame)) or not frame then return false end
    return pcall(function()
        local forbidden = frame:IsForbidden()
        if (issecretvalue and issecretvalue(forbidden)) or forbidden then error("forbidden") end
        return action(frame)
    end)
end
function Buddy.HideTooltip()
    Buddy.Foreign(GameTooltip, function(tooltip) tooltip:Hide() end)
end
function Buddy.Message(text) print("|cffd0d0d0Foreverbuddy:|r " .. text) end
function Buddy.OpenModule(module)
    if not Buddy.loaded[module.key] then Buddy.Message("Modul aktivieren und die Oberfläche neu laden."); return end
    if module.key == "bars" then
        if Buddy.Bars and Buddy.Bars.SetAutomatic then
            Buddy.Bars.SetAutomatic(not Buddy.db.bars.automatic)
        end
    else
        local handler = SlashCmdList[module.command]
        if handler then handler(module.argument or "") end
    end
end
function Buddy.Toggle()
    if not Buddy.panel then
        local panel = CreateFrame("Frame", "ForeverbuddyPanel", UIParent, "BackdropTemplate")
        Buddy.panel = panel
        local barsMenu = Buddy.loaded.bars and Buddy.Bars and Buddy.Bars.BuildMenu
        local barsExtra = barsMenu and (Buddy.Bars.MENU_HEIGHT + 24) or 0
        panel:SetSize(390, 158 + #Buddy.modules * 43 + barsExtra)
        panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG")
        panel:SetClampedToScreen(true)
        panel:SetMovable(true)
        panel:EnableMouse(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        Buddy.Style.Window(panel,72)
        local icon = panel:CreateTexture(nil,"ARTWORK")
        icon:SetTexture("Interface\\AddOns\\Foreverbuddy\\Media\\BuddyIcon")
        icon:SetSize(42,42); icon:SetPoint("TOPLEFT",16,-15)
        local title = panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        title:SetPoint("TOPLEFT",68,-21); title:SetText("Foreverbuddy")
        local sub = panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        sub:SetPoint("TOPLEFT",68,-44); sub:SetText("Dein Begleiter in Forever")
        local close = CreateFrame("Button",nil,panel,"UIPanelCloseButton")
        close:SetPoint("TOPRIGHT",-3,-3)
        for index,module in ipairs(Buddy.modules) do
            local entry = module
            local check = CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
            check:SetSize(28,28); check:SetPoint("TOPLEFT",19,-76-(index-1)*43)
            check:SetChecked(Buddy.db.enabled[entry.key])
            check:SetScript("OnClick",function(self)
                Buddy.db.enabled[entry.key] = self:GetChecked() and true or false
                Buddy.Message("Modulauswahl gespeichert. Mit /reload anwenden.")
            end)
            local button = Buddy.Style.Button(CreateFrame("Button",nil,panel,"UIPanelButtonTemplate"))
            button:SetSize(312,30); button:SetPoint("TOPLEFT",55,-76-(index-1)*43)
            if entry.key=="bars" then
                if Buddy.loaded.bars and Buddy.Bars then Buddy.Bars.menuButton=button end
                button:SetText(Buddy.loaded.bars and Buddy.Bars and Buddy.Bars.RowText and Buddy.Bars.RowText()
                    or "Aktionsleisten · Modul aus")
                button:SetScript("OnClick",function() Buddy.OpenModule(entry) end)
            else
                button:SetText(entry.name .. ((entry.key=="meters") and " ein / aus" or " öffnen"))
                button:SetScript("OnClick",function() Buddy.OpenModule(entry) end)
            end
        end
        local hintTop = -83-#Buddy.modules*43
        if barsMenu then
            Buddy.Bars.BuildMenu(panel,hintTop)
            hintTop = hintTop - (Buddy.Bars.MENU_HEIGHT + 10)
        end
        local hint = panel:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
        hint:SetPoint("TOPLEFT",22,hintTop); hint:SetWidth(346)
        hint:SetText("Häkchen: Modul beim Start laden. Änderungen mit /reload anwenden. Aktionsleisten-Vorlagen gelten je Klasse und Spezialisierung.")
        local reload = Buddy.Style.Button(CreateFrame("Button",nil,panel,"UIPanelButtonTemplate"))
        reload:SetSize(200,24); reload:SetPoint("BOTTOM",0,12)
        reload:SetText("Oberfläche neu laden")
        reload:SetScript("OnClick",function()
            if InCombatLockdown() then Buddy.Message("Bitte das Kampfende abwarten."); return end
            ReloadUI()
        end)
        UISpecialFrames[#UISpecialFrames+1] = "ForeverbuddyPanel"
    else Buddy.panel:SetShown(not Buddy.panel:IsShown()) end
end
function Buddy.CreateMinimap()
    local button = CreateFrame("Button","ForeverbuddyMinimapButton",Minimap)
    button:SetSize(32,32); button:SetFrameStrata("MEDIUM")
    local icon = button:CreateTexture(nil,"ARTWORK")
    icon:SetAllPoints(); icon:SetTexture("Interface\\AddOns\\Foreverbuddy\\Media\\BuddyIcon")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local function place()
        Buddy.Foreign(Minimap, function(map)
        local width, height = map:GetWidth(), map:GetHeight()
        if (issecretvalue and (issecretvalue(width) or issecretvalue(height)))
            or type(width)~="number" or type(height)~="number" then return end
        local angle = math.rad(Buddy.db.minimap.angle)
        button:ClearAllPoints()
        button:SetPoint("CENTER",Minimap,"CENTER",math.cos(angle)*(width/2+8),math.sin(angle)*(height/2+8))
        end)
    end
    button:RegisterForClicks("LeftButtonUp","RightButtonUp")
    button:SetScript("OnClick",function(_,mouse)
        if mouse=="RightButton" then Buddy.OpenModule(Buddy.modules[1]) else Buddy.Toggle() end
    end)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart",function(self)
        self:SetScript("OnUpdate",function()
            Buddy.Foreign(Minimap, function(map)
            local x,y = GetCursorPosition()
            local cx,cy = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            for _,value in ipairs({x,y,cx,cy,scale}) do
                if (issecretvalue and issecretvalue(value)) or type(value)~="number" then return end
            end
            if not x or not y or not cx or not cy or not scale or scale<=0 then return end
            Buddy.db.minimap.angle = math.deg(math.atan2(y/scale-cy,x/scale-cx))
            place()
            end)
        end)
    end)
    button:SetScript("OnDragStop",function(self) self:SetScript("OnUpdate",nil) end)
    button:SetScript("OnEnter",function(self)
        Buddy.Foreign(GameTooltip, function()
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:AddLine("Foreverbuddy",.78,.78,.78)
        GameTooltip:AddLine("Linksklick: Zentrale",1,1,1)
        GameTooltip:AddLine("Rechtsklick: Charaktere",1,1,1)
        GameTooltip:AddLine("Ziehen: Position ändern",.7,.7,.7)
        GameTooltip:Show()
        end)
    end)
    button:SetScript("OnLeave",Buddy.HideTooltip)
    place()
end

-- Install a per-frame callback only while opacity is actually changing.
function Buddy.FadeTo(frame,target)
    if not frame or frame.buddyAlphaTarget==target then return end
    frame.buddyAlphaTarget=target
    frame:SetScript("OnUpdate",function(self,elapsed)
        local current=self:GetAlpha()
        local goal=self.buddyAlphaTarget
        if math.abs(current-goal)<.003 then
            self:SetAlpha(goal);self:SetScript("OnUpdate",nil)
        else self:SetAlpha(current+(goal-current)*math.min(1,elapsed*10)) end
    end)
end
