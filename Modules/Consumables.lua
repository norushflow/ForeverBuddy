local _, Buddy = ...
local L = Buddy.L
local SIZE, STEP, INSET, COLUMNS = 30, 34, 6, 7
local HEADER = 24

-- Forever exposes item use descriptions, but no numeric food-restoration field.
local function foodRecovery(link)
    local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
    if not data or not data.lines then return 0 end
    local best = 0
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" and not (issecretvalue and issecretvalue(text)) then
            text = text:lower()
            if text:find("restor", 1, true) or text:find("wieder", 1, true) then
                for _, resource in ipairs({"health", "gesundheit", "mana"}) do
                    local amount, percent = text:match("([%d.,]+)(%%?)%s*[%a%s]*%f[%a]" .. resource .. "%f[%A]")
                    if amount then
                        local value = percent == "%" and tonumber((amount:gsub(",", ".")))
                            or tonumber((amount:gsub("[.,]", ""))) or 0
                        if percent == "%" then
                            local maximum
                            if resource == "mana" then maximum = UnitPowerMax and UnitPowerMax("player", 0)
                            else maximum = UnitHealthMax and UnitHealthMax("player") end
                            if type(maximum) == "number" and not (issecretvalue and issecretvalue(maximum)) then
                                value = value * maximum / 100
                            end
                        end
                        best = math.max(best, value)
                    end
                end
            end
        end
    end
    return best
end

function Buddy.LoadConsumables()
    local containers = C_Container
    local getInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local getFullInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    local getSpell = C_Item and C_Item.GetItemSpell or GetItemSpell
    local requestInfo = C_Item and C_Item.RequestLoadItemDataByID
    local isCached = C_Item and C_Item.IsItemDataCachedByID
    local getCooldown = containers and containers.GetItemCooldown or GetItemCooldown
    local style = Buddy.Style
    local positions = Buddy.char.consumables
    if type(positions) ~= "table" then
        positions = {}
        Buddy.char.consumables = positions
    end
    local bars, stock, pending = {}, {}, {}
    local editing, ready = false, false
    local setEditing

    local function place(bar, x, y)
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    end

    local function stopDrag(bar)
        bar.handle:SetScript("OnUpdate", nil)
    end

    local function makeBar(key, title, defaultX)
        local bar = CreateFrame("Frame", nil, UIParent)
        bar:SetFrameStrata("MEDIUM")
        bar:SetClampedToScreen(true)
        bar.editBorder = style.Border(bar)
        bar.buttons, bar.active, bar.legacyPosition = {}, 0, false
        bar:SetSize(190, HEADER + INSET)
        local saved = positions[key]
        if type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number" then
            if saved.bottom then place(bar, saved.x, saved.y)
            else bar.legacyPosition = saved end
        else
            bar:SetPoint("BOTTOMLEFT", UIParent, "CENTER", defaultX, -160)
        end
        bar:Hide()

        local handle = CreateFrame("Frame", nil, bar)
        bar.handle = handle
        handle:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        handle:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -26, 0)
        handle:SetFrameLevel(bar:GetFrameLevel() + 2)
        handle:SetHeight(HEADER)
        handle:EnableMouse(true)
        local label = style.Text(handle, "small", style.Color.gold)
        label:SetPoint("LEFT", INSET, 0)
        label:SetText(title)
        handle:SetScript("OnMouseDown", function(_, mouseButton)
            if mouseButton ~= "LeftButton" or not editing or InCombatLockdown() then return end
            local scale = UIParent:GetEffectiveScale()
            local mouseX, mouseY = GetCursorPosition()
            local startX, startY = bar:GetLeft(), bar:GetBottom()
            if not startX or not startY then return end
            handle:SetScript("OnUpdate", function()
                if InCombatLockdown() or not IsMouseButtonDown("LeftButton") then
                    stopDrag(bar)
                    return
                end
                local x, y = GetCursorPosition()
                place(bar, startX + (x - mouseX) / scale, startY + (y - mouseY) / scale)
                positions[key] = {x = bar:GetLeft(), y = bar:GetBottom(), bottom = true}
            end)
        end)
        handle:SetScript("OnMouseUp", function(_, mouseButton)
            if mouseButton == "LeftButton" then stopDrag(bar) end
        end)
        local lock = Buddy.CreateConsumablesLock(bar, true, function() setEditing(false) end)
        bar.lock = lock
        lock:SetPoint("TOPRIGHT")
        handle:Hide()
        lock:Hide()
        return bar
    end

    local function makeButton(bar)
        local button = style.Icon(CreateFrame("Button", nil, bar, "SecureActionButtonTemplate"))
        button:SetSize(SIZE, SIZE)
        button:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
        button:SetAttribute("type", "item")
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 1, -1)
        button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        button.icon:SetTexCoord(.08, .92, .08, .92)
        button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints(button.icon)
        -- The client hides the cooldown frame when no cooldown is running.
        local countLayer = CreateFrame("Frame", nil, button)
        countLayer:SetAllPoints(button)
        countLayer:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
        countLayer:EnableMouse(false)
        button.count = style.Text(countLayer, 13, nil, "OUTLINE")
        button.count:SetPoint("BOTTOMRIGHT", -3, 2)
        button:SetScript("OnEnter", function(self)
            local item = stock[self.itemID]
            if not item then return end
            Buddy.Foreign(GameTooltip, function(tooltip)
                tooltip:SetOwner(self, "ANCHOR_RIGHT")
                tooltip:SetHyperlink(item.link or ("item:" .. self.itemID))
                tooltip:Show()
            end)
        end)
        button:SetScript("OnLeave", function(self)
            Buddy.Foreign(GameTooltip, function(tooltip)
                if tooltip:IsOwned(self) then tooltip:Hide() end
            end)
        end)
        return button
    end

    local function scan()
        local items, seen = {}, {}
        local lastBag = NUM_BAG_SLOTS or 4
        local reagentBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
        local function scanBag(bag)
            for slot = 1, containers.GetContainerNumSlots(bag) do
                local info = containers.GetContainerItemInfo(bag, slot)
                if info and info.itemID then
                    local id = info.itemID
                    local item = seen[id]
                    if item == nil then
                        local _, _, _, _, icon, class, subclass = getInfo(id)
                        local name, spellID
                        if class == 0 then name, spellID = getSpell(id) end
                        if class == 0 and (name or spellID) then
                            item = {id = id, group = subclass == 5 and 1 or 2,
                                icon = info.iconFileID or icon, link = info.hyperlink, count = 0}
                            if item.group == 1 then
                                local link = item.link or ("item:" .. id)
                                local level, required
                                if getFullInfo then level, required = select(4, getFullInfo(link)) end
                                item.level = level or 0
                                item.required = required or 0
                                item.recovery = foodRecovery(link)
                                if requestInfo and isCached and not isCached(id) and not pending[id] then
                                    pending[id] = true
                                    requestInfo(id)
                                end
                            end
                            items[id] = item
                        else
                            item = false
                            if requestInfo and not pending[id]
                                and (class == nil or (class == 0 and isCached and not isCached(id))) then
                                pending[id] = true
                                requestInfo(id)
                            end
                        end
                        seen[id] = item
                    end
                    if item then item.count = item.count + (info.stackCount or 1) end
                end
            end
        end
        for bag = 0, lastBag do scanBag(bag) end
        if reagentBag and reagentBag > lastBag then scanBag(reagentBag) end
        return items
    end

    local function updateVisuals()
        for _, bar in ipairs(bars) do
            for index = 1, bar.active do
                local button = bar.buttons[index]
                local item = stock[button.itemID]
                local start, duration, enabled
                if item then start, duration, enabled = getCooldown(button.itemID) end
                local usable = item and enabled ~= 0 and enabled ~= false
                button.icon:SetDesaturated(not usable)
                button.count:SetText(item and item.count or 0)
                button.cooldown:SetCooldown(usable and start or 0, usable and duration or 0)
            end
        end
    end

    local function layout()
        local groups = {{}, {}}
        for id, item in pairs(stock) do
            local group = groups[item.group]
            group[#group + 1] = id
        end
        for group, bar in ipairs(bars) do
            local ids = groups[group]
            if group == 1 then
                local playerLevel = UnitLevel and UnitLevel("player")
                if issecretvalue and issecretvalue(playerLevel) then playerLevel = nil end
                table.sort(ids, function(a, b)
                    local first, second = stock[a], stock[b]
                    if playerLevel then
                        local firstUsable = first.required <= playerLevel
                        local secondUsable = second.required <= playerLevel
                        if firstUsable ~= secondUsable then return firstUsable end
                    end
                    if first.recovery ~= second.recovery then return first.recovery > second.recovery end
                    if first.required ~= second.required then return first.required > second.required end
                    if first.level ~= second.level then return first.level > second.level end
                    return a < b
                end)
            else
                table.sort(ids)
            end
            local header = editing and HEADER or 0
            local width = 2 * INSET + math.min(#ids, COLUMNS) * STEP - (STEP - SIZE)
            local rows = math.ceil(#ids / COLUMNS)
            local itemHeight = rows * STEP + 2 * INSET - (STEP - SIZE)
            bar:SetSize(math.max(width, editing and 190 or SIZE + 2 * INSET), itemHeight + header)
            if bar.legacyPosition then
                local saved = bar.legacyPosition
                -- Earlier versions saved the top edge while the edit header was visible.
                local bottom = math.max(0, saved.y - itemHeight - HEADER)
                place(bar, saved.x, bottom)
                saved.y, saved.bottom = bottom, true
                bar.legacyPosition = false
            end
            for index, id in ipairs(ids) do
                local button = bar.buttons[index]
                if not button then
                    button = makeButton(bar)
                    bar.buttons[index] = button
                end
                if button.itemID ~= id then
                    button:GetScript("OnLeave")(button)
                    button.itemID = id
                    button:SetAttribute("item", "item:" .. id)
                    button.icon:SetTexture(stock[id].icon)
                end
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", INSET + ((index - 1) % COLUMNS) * STEP,
                    -header - INSET - math.floor((index - 1) / COLUMNS) * STEP)
                button:Show()
            end
            for index = #ids + 1, bar.active do
                local button = bar.buttons[index]
                button:GetScript("OnLeave")(button)
                button.itemID = nil
                button:SetAttribute("item", nil)
                button:Hide()
            end
            bar.active = #ids
            for _, edge in ipairs(bar.editBorder) do edge:SetShown(editing) end
            bar.handle:SetShown(editing)
            bar.lock:SetShown(editing)
            bar:SetShown(#ids > 0 or editing)
        end
    end

    local function refresh()
        stock = scan()
        -- Keep the secure item IDs and layout fixed in combat. Counts and cooldowns remain live.
        if not InCombatLockdown() then layout() end
        updateVisuals()
    end

    setEditing = function(value)
        if InCombatLockdown() then Buddy.Message(L["Bitte das Kampfende abwarten."]); return end
        if not ready then return end
        for _, bar in ipairs(bars) do stopDrag(bar) end
        editing = value
        Buddy.consumablesEditing = editing
        if Buddy.consumablesMenuLock then
            Buddy.SetConsumablesLockIcon(Buddy.consumablesMenuLock, editing)
        end
        refresh()
    end

    local supported = containers and containers.GetContainerNumSlots and containers.GetContainerItemInfo
        and getInfo and getSpell and getCooldown
    SlashCmdList.FOREVERBUDDYCONSUMABLES = function()
        if not supported then
            Buddy.Message(L["Verbrauchsgüterleisten sind in diesem Client nicht verfügbar."])
            return
        end
        setEditing(not editing)
    end
    if not supported then return end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:RegisterEvent("BAG_UPDATE_COOLDOWN")
    events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event, itemID, success)
        if event == "PLAYER_REGEN_DISABLED" then
            for _, bar in ipairs(bars) do stopDrag(bar) end
            return
        end
        if not ready then
            if InCombatLockdown() then return end
            bars[1] = makeBar("food", L["Essen und Trinken"], -250)
            bars[2] = makeBar("usable", L["Verbrauchsgüter"], 15)
            ready = true
        end
        if event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
            updateVisuals()
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            if pending[itemID] then
                pending[itemID] = nil
                if success then refresh() end
            end
        else
            refresh()
        end
    end)
end
