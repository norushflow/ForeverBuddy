local _, Buddy = ...
local Bars = Buddy.Bars
local de = GetLocale() == "deDE"
local function tr(german, english) return de and german or english end
local panel, title, nameBox, hint
local controls = {rows={}, actions={}, mouseovers={}}
local draft, editing, spells, resetMode
local leftPage, rightPage = 1, 1
local draw
local function records()
    Buddy.char.rotations = Buddy.char.rotations or {}
    return Buddy.char.rotations
end

local function spellList()
    local list, seen = {}, {}
    local function add(name, icon)
        if name and not seen[name] then
            seen[name] = true
            list[#list + 1] = {name = name, icon = icon}
        end
    end
    local api = C_SpellBook
    if api and api.GetNumSpellBookSkillLines then
        local bank = Enum.SpellBookSpellBank.Player
        for line = 1, api.GetNumSpellBookSkillLines() do
            local info = api.GetSpellBookSkillLineInfo(line)
            if info and (not info.offSpecID or info.offSpecID == 0) then
                for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = api.GetSpellBookItemInfo(slot, bank)
                    if item and item.itemType == Enum.SpellBookItemType.Spell and not item.isPassive then
                        add(item.name, item.iconID)
                    end
                end
            end
        end
    elseif GetNumSpellTabs then
        for line = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(line)
            for slot = offset + 1, offset + count do
                if GetSpellBookItemInfo(slot, "spell") == "SPELL" and not IsPassiveSpell(slot, "spell") then
                    add(GetSpellBookItemName(slot, "spell"), GetSpellBookItemTexture(slot, "spell"))
                end
            end
        end
    end
    table.sort(list, function(a,b) return a.name < b.name end)
    return list
end

local function start(index)
    editing, draft, spells = index, {}, spellList()
    local old = records()[index]
    resetMode=old and old.resetMode or "none"
    if old then
        for i, step in ipairs(old.steps) do draft[i] = step end
    end
    leftPage, rightPage = 1, 1
    nameBox:SetText(old and old.label or "")
    draw()
end

local runners = {}
local questionIcon = 134400
local tooltipLine = "#showtooltip\n"
local actionBars = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button",
}
local iconLayers = {}
local refreshPending

local function normalizedMacroBody(body)
    if Bars.Text(body) then return (body:gsub("\r\n","\n"):gsub("%s+$","")) end
end

local function queueIconRefresh()
    if refreshPending or not C_Timer then return end
    refreshPending = true
    C_Timer.After(0, function()
        refreshPending = false
        local getText = C_ActionBar and C_ActionBar.GetActionText or GetActionText
        local getTexture = C_ActionBar and C_ActionBar.GetActionTexture or GetActionTexture
        local macroRunners = {}
        for _, prefix in ipairs(actionBars) do
            for slot = 1, 12 do
                local button = _G[prefix .. slot]
                if button and not button:IsForbidden() then
                    local icon = button.icon or button.Icon
                    local action = button.action
                    if not Bars.Number(action) then action = button:GetAttribute("action") end
                    local texture
                    if icon and Bars.Number(action) then
                        local runner = macroRunners[action]
                        if runner == nil then
                            local kind, index = Bars.Call(GetActionInfo, action)
                            if kind == "macro" then
                                local name = Bars.Call(getText, action)
                                if Bars.Text(name) then
                                    local candidate = runners[name]
                                    index = candidate and candidate.rotationBody and Bars.MacroLookup(name) or nil
                                end
                                if Bars.Number(index) then
                                    local actual, _, body = Bars.Call(GetMacroInfo, index)
                                    runner = actual and runners[actual]
                                    if not (runner and runner.rotationBody and
                                        runner.rotationBody == normalizedMacroBody(body)) then
                                        runner = nil
                                    end
                                end
                            end
                            macroRunners[action] = runner or false
                        end
                        if runner then
                            if runner.rotationBody:sub(1, #tooltipLine) == tooltipLine then
                                -- A native once-per-target opener takes precedence while WoW reports its icon.
                                texture = Bars.Call(getTexture, action)
                            end
                            if not texture or texture == questionIcon then
                                local step = runner:GetAttribute("next")
                                texture = runner.rotationIcons[step]
                            end
                        end
                    end
                    local layer = iconLayers[button]
                    if texture then
                        -- Blizzard may repaint its own texture during the same click.
                        if not layer then
                            layer = button:CreateTexture(nil, "ARTWORK", nil, 1)
                            layer:SetAllPoints(icon)
                            layer:SetTexCoord(icon:GetTexCoord())
                            iconLayers[button] = layer
                        end
                        layer:SetTexture(texture)
                        layer:SetVertexColor(icon:GetVertexColor())
                        layer:Show()
                    elseif layer then
                        layer:Hide()
                    end
                end
            end
        end
    end)
end

local quietUntil
local cooldownErrors = {
    ERR_ABILITY_COOLDOWN = true,
    ERR_SPELL_COOLDOWN = true,
}

local function isCooldownError(errorType, message)
    if Bars.Number(errorType) and GetGameMessageInfo then
        local name = GetGameMessageInfo(errorType)
        if Bars.Text(name) and cooldownErrors[name] then return true end
    end
    return Bars.Text(message) and
        (message == ERR_ABILITY_COOLDOWN or message == ERR_SPELL_COOLDOWN)
end

local function installCooldownFilter()
    local frame = UIErrorsFrame
    if not frame or frame:IsForbidden() or frame:IsProtected() or InCombatLockdown() then return end
    local onEvent = frame:GetScript("OnEvent")
    if not onEvent then return end
    frame:SetScript("OnEvent", function(self, event, errorType, message, ...)
        if event == "UI_ERROR_MESSAGE" and quietUntil and GetTime() <= quietUntil and
            isCooldownError(errorType, message) then
            return
        end
        return onEvent(self, event, errorType, message, ...)
    end)
end

local function mouseoverOptions(steps)
    local options = {}
    local api = C_Spell
    local helpful = api and api.IsSpellHelpful or IsHelpfulSpell
    local harmful = api and api.IsSpellHarmful or IsHarmfulSpell
    for i, step in ipairs(steps) do
        if step.mouseover == true then
            local help = Bars.Call(helpful, step.name)
            local harm = Bars.Call(harmful, step.name)
            local condition = help and "[@mouseover,help,nodead]" or ""
            if harm then condition = condition .. "[@mouseover,harm,nodead]" end
            if condition ~= "" then options[i] = condition end
        end
    end
    return options
end

local function castSequence(steps, options, once, resetTarget)
    local names, condition = {}
    for i, step in ipairs(steps) do
        if (not not step.oncePerTarget) == once then
            local current = options[i] or ""
            if condition and condition ~= current then
                if not resetTarget then return end
                return nil, once
                    and tr("Bei 1×/Ziel brauchen alle Zauber dieselbe Zielbedingung.",
                        "Once-per-target spells must share the same targeting condition.")
                    or tr("Bei Zielwechsel brauchen alle wiederholten Zauber dieselbe Zielbedingung.",
                        "With Target reset, repeating spells must share the same targeting condition.")
            end
            condition = current
            for _ = 1, once and 1 or (step.repeats or 1) do
                names[#names + 1] = step.name
            end
        end
    end
    if #names == 0 or (not resetTarget and condition == "") then return end
    if once then names[#names + 1] = "null" end
    if condition ~= "" then condition = condition .. "[] " end
    local reset = resetTarget and "reset=target " or ""
    return "/castsequence " .. condition .. reset .. table.concat(names, ", ")
end

local function launcher(key, steps, mode, options)
    local opening, problem = castSequence(steps, options, true, true)
    if problem then return nil, problem end
    local lines = {opening}
    local cycle
    if mode == "target" then
        cycle, problem = castSequence(steps, options, false, true)
        if problem then return nil, problem end
    elseif mode == "none" then
        -- A shared mouseover condition lets WoW advance only after each successful cast.
        cycle = castSequence(steps, options, false, false)
        if cycle and #cycle + (opening and #opening + 1 or 0) > 255 then cycle = nil end
    end
    if cycle then
        lines[#lines + 1] = cycle
    elseif mode ~= "target" then
        for _, step in ipairs(steps) do
            if not step.oncePerTarget then
                lines[#lines + 1] = "/click ForeverBuddySequence" .. key
                break
            end
        end
    end
    local body = table.concat(lines,"\n")
    -- Leave room for existing sequences that already reach the macro limit.
    local quietBody = "/brq\n"..body
    if #quietBody<=255 then body=quietBody end
    if #body>255 then
        return nil,tr("Folge zu lang für ein Makro.", "Sequence exceeds the macro length limit.")
    end
    if (opening or cycle) and #body + #tooltipLine <= 255 then
        body = tooltipLine .. body
    end
    return body
end

local function configure(key, steps, mode, options)
    local runner = runners[key]
    if not runner then
        runner = CreateFrame("Button","ForeverBuddySequence"..key,UIParent,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
        runner:RegisterForClicks("LeftButtonUp")
        runner:SetAttribute("useOnKeyDown",false)
        runner.RefreshRotationIcon = queueIconRefresh
        SecureHandlerWrapScript(runner,"OnClick",runner,[[
            local count = self:GetAttribute("count")
            if not count or count == 0 then return end
            local step = self:GetAttribute("next") or 1
            self:SetAttribute("spell",self:GetAttribute("step"..step))
            local condition = self:GetAttribute("mouseover"..step)
            local unit
            if condition then unit = SecureCmdOptionParse(condition .. " mouseover") end
            self:SetAttribute("unit", unit)
            self:SetAttribute("next",step % count + 1)
            self:CallMethod("RefreshRotationIcon")
        ]])
        runner:SetAttribute("_onstate-rotationcombat",[[
            if newstate == "out" and self:GetAttribute("resetCombat") then
                self:SetAttribute("next",1)
                self:CallMethod("RefreshRotationIcon")
            end
        ]])

        runners[key]=runner
    end
    if mode=="combat" and not runner.combatDriver then
        RegisterStateDriver(runner,"rotationcombat","[combat] in; out")
        runner.combatDriver=true
    end
    runner:SetAttribute("resetCombat",mode=="combat")
    runner.rotationIcons = {}
    local count=0
    for i,step in ipairs(steps) do
        if not step.oncePerTarget then
            for attempt=1,step.repeats or 1 do
                count=count+1
                runner:SetAttribute("step"..count,step.name)
                runner:SetAttribute("mouseover"..count,options[i])
                runner.rotationIcons[count] = step.icon or questionIcon
            end
        end
    end
    runner:SetAttribute("count",count)
    runner:SetAttribute("spell",count>0 and runner:GetAttribute("step1") or nil)
    runner:SetAttribute("unit",nil)
    runner:SetAttribute("next",1)
    runner:SetAttribute("type",count>0 and "spell" or nil)
end

local function macroBody(index)
    return normalizedMacroBody(select(3,GetMacroInfo(index)))
end

local function applySequence(record, body, options)
    local key, steps, mode = record.key, record.steps, record.resetMode
    if not body then
        options = mouseoverOptions(steps)
        local problem
        body, problem = launcher(key, steps, mode, options)
        if not body then return nil, problem end
    end
    -- Existing action-bar macros must have a live target even before the
    -- character macro list is available during login.
    if mode~="target" then configure(key,steps,mode,options) end
    local index, scope = Bars.MacroLookup(key)
    local dynamic = body:sub(1, #tooltipLine) == tooltipLine
    local icon = dynamic and questionIcon or steps[1].icon or questionIcon
    local actual=index and macroBody(index)
    local ok=index and actual==body
    local previous=normalizedMacroBody(record.body)
    if not ok and index and actual==previous then
        ok=pcall(EditMacro,index,key,icon,body)
    elseif scope=="missing" then
        ok=pcall(CreateMacro,key,icon,body,true)
    end
    index=Bars.MacroLookup(key)
    if not ok or not index or macroBody(index)~=body then
        return nil,tr("Makro prüfen: freier Platz oder manuelle Änderung.","Check macro space or external edits.")
    end
    local runner = runners[key]
    if runner then
        local click = "/click ForeverBuddySequence" .. key
        runner.rotationBody = body:sub(-#click) == click and body or nil
        queueIconRefresh()
    end
    return body
end

local function sync(record, body, options)
    local ok,body,problem=pcall(applySequence,record,body,options)
    if ok and body then record.body=body end
    if not ok then return tostring(body) end
    return problem
end

local function restoreSequences()
    if InCombatLockdown() then return end
    for _,record in ipairs(records()) do
        local problem=sync(record)
        if problem then print("BuddyRotation ("..record.label.."): "..problem) end
    end
end

local function save()
    if InCombatLockdown() then return end
    local label = nameBox:GetText():match("^%s*(.-)%s*$")
    if label == "" or #draft == 0 then
        hint:SetText(tr("Name und Zauber fehlen?", "Enter a name and choose a spell."))
        return
    end
    local old = records()[editing]
    local serial = Buddy.char.rotationSerial or 0
    local key = old and old.key
    if not key then
        repeat
            serial = serial + 1
            key = "BuddyRot" .. serial
            local _, scope = Bars.MacroLookup(key)
            if scope == "api" or not scope then return hint:SetText("Macro API?") end
        until scope == "missing"
    end
    local options = mouseoverOptions(draft)
    local body, problem = launcher(key, draft, resetMode, options)
    if not body then
        hint:SetText(problem)
        return
    end
    local record={label=label,steps=draft,key=key,resetMode=resetMode,body=old and old.body}
    records()[editing or (#records()+1)]=record
    Buddy.char.rotationSerial=serial
    problem=sync(record,body,options)
    draft,editing,leftPage=nil,nil,1
    draw()
    hint:SetText(tr("Gespeichert: ","Saved: ")..label..(problem and (" — "..problem) or ""))

end

local function requestDelete()
    local record = records()[editing]
    if not record or InCombatLockdown() then return end
    local dialog = "FOREVERBUDDY_DELETE_ROTATION"
    StaticPopupDialogs[dialog] = StaticPopupDialogs[dialog] or {
        text = tr("Folge „%s“ löschen?", "Delete sequence “%s”?"),
        button1 = DELETE, button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, target)
            if InCombatLockdown() or records()[editing] ~= target then return end
            local index, scope = Bars.MacroLookup(target.key)
            if scope == "api" or scope == "ambiguous" then
                hint:SetText(tr("Makro konnte nicht geprüft werden.", "Could not verify the macro."))
                return
            end
            if index and scope=="character" and select(3,GetMacroInfo(index))==target.body then
                local ok = pcall(DeleteMacro,index)
                if not ok or Bars.MacroLookup(target.key) then
                    hint:SetText(tr("Makro konnte nicht gelöscht werden.", "Could not delete the macro."))
                    return
                end
            end
            configure(target.key,{},nil,{})
            table.remove(records(),editing)
            editing,draft,leftPage=nil,nil,1
            draw()
        end,
    }
    StaticPopup_Show(dialog,record.label,nil,record)
end

local used = {rows=0,actions=0,mouseovers=0}
local paperTitle, nameLabel
local function lettering(parent, font)
    return parent:CreateFontString(nil,"OVERLAY",font)
end
local function mouseoverCheckbox(y, i, step)
    used.mouseovers = used.mouseovers + 1
    local checkbox = controls.mouseovers[used.mouseovers]
    if not checkbox then
        checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        checkbox:SetSize(24, 24)
        checkbox:SetHitRectInsets(0, -60, 0, 0)
        local label = lettering(checkbox, "GameFontNormalSmall")
        label:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
        label:SetTextColor(.18,.10,.045)
        label:SetShadowOffset(0,0)
        label:SetText("Mouseover")
        controls.mouseovers[used.mouseovers] = checkbox
    end
    checkbox:ClearAllPoints()
    checkbox:SetPoint("TOPLEFT", 528, -y - 4)
    checkbox:SetChecked(step.mouseover == true)
    checkbox:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            self:SetChecked(step.mouseover == true)
            return
        end
        local updated = {}
        for key, value in pairs(step) do updated[key] = value end
        updated.mouseover = self:GetChecked() == true
        draft[i] = updated
        draw()
    end)
    checkbox:Show()
end
local function button(x,y,w,label,click,drag,kind)
    local row = kind=="paper" or kind=="step"
    local pool = row and "rows" or "actions"
    used[pool]=used[pool]+1
    local b=controls[pool][used[pool]]
    if not b then
        b=CreateFrame("Button",nil,panel,(not row) and "UIPanelButtonTemplate" or nil)
        if row then
            b.text=lettering(b,"GameFontNormal")
            b.text:SetTextColor(.18,.10,.045)
            b.text:SetShadowOffset(0,0)
            b.text:SetPoint("LEFT",4,0)
            b.text:SetPoint("RIGHT",-4,0)
            b.text:SetJustifyH("LEFT")
            b.text:SetWordWrap(false)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        end

        controls[pool][used[pool]]=b
    end
    if row then b.text:SetText(label) else b:SetText(label) end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT",x,-y)
    b:SetSize(w,32)
    if kind=="counter" then b:RegisterForClicks("LeftButtonUp","RightButtonUp")
    else b:RegisterForClicks("LeftButtonUp") end
    if kind=="counter" then
        b:SetScript("OnClick",nil)
        b:SetScript("OnMouseUp",function(self,mouse)
            if self:IsMouseOver() and (mouse=="LeftButton" or mouse=="RightButton") then click(self,mouse) end
        end)
    else
        b:SetScript("OnMouseUp",nil)
        b:SetScript("OnClick",click)
    end
    if drag then b:RegisterForDrag("LeftButton") else b:RegisterForDrag() end
    b:SetScript("OnDragStart",drag)
    b:Show()
end

local function page(list,n,x,setPage,render)
    local pages = math.max(1,math.ceil(#list/8))
    n = math.min(n,pages)
    for row=1,8 do
        local i=(n-1)*8+row
        if list[i] then render(i,list[i],88+(row-1)*36) end
    end
    if n>1 then button(x,384,36,"<",function() setPage(n-1) draw() end) end
    if n<pages then button(x+40,384,36,">",function() setPage(n+1) draw() end) end
end

local function caption(step)
    return ("|T%s:24|t  %s"):format(step.icon or 134400,step.name)
end

draw = function()
    for pool,buttons in pairs(controls) do
        used[pool]=0
        for _,b in ipairs(buttons) do b:Hide() end
    end
    title:SetShown(draft~=nil)
    nameLabel:SetShown(draft~=nil)
    nameBox:SetShown(draft~=nil)
    paperTitle:SetText(draft and tr("Zauber","Spells") or tr("Meine Folgen","My sequences"))
    hint:SetTextColor(.22,.13,.06)
    hint:SetText("")
    if not draft then
        page(records(),leftPage,18,function(n) leftPage=n end,function(i,record,y)
            button(18,y,490,caption({name=record.label,icon=record.steps[1].icon}),function() start(i) end,function()
                if InCombatLockdown() then return end
                local index=Bars.MacroLookup(record.key)
                if index then PickupMacro(index) end
            end,"paper")
        end)
        button(18,425,230,tr("+ Neue Folge","+ New sequence"),function() start(nil) end,nil,"paper")
        hint:SetText(tr("Folge in die Aktionsleiste ziehen","Drag a sequence onto your action bar"))
        return
    end
    local modes={{"none",tr("Aus","Off")},{"combat",tr("Kampf","Combat")},{"target",tr("Zielwechsel","Target")}}
    local x=12
    for _,option in ipairs(modes) do
        local mode,label=option[1],option[2]
        local width=mode=="target" and 96 or 58
        if mode==resetMode then
            label="|TInterface\\Buttons\\UI-CheckBox-Check:16:16|t"..label
        end
        button(x,43,width,label,function()
            if InCombatLockdown() then return end
            resetMode=mode
            draw()
        end)
        x=x+width+1
    end
    if resetMode=="target" then
        hint:SetText(tr("Zielwechsel: Nächster Schritt nach erfolgreichem Zauber.","Target reset: advance after a successful spell."))
    elseif resetMode=="combat" then
        hint:SetText(tr("Kampf: Nach Kampfende beginnt die Folge wieder bei Schritt 1.",
            "Combat: The sequence resets to step 1 when combat ends."))
    end
    page(spells,leftPage,12,function(n) leftPage=n end,function(_,spell,y)
        button(12,y,201,caption(spell),function()
            draft[#draft+1]=spell
            rightPage=math.ceil(#draft/8)
            draw()
        end,nil,"paper")
    end)
    page(draft,rightPage,232,function(n) rightPage=n end,function(i,spell,y)
        button(230,y,129,i.."  "..caption(spell),nil,nil,"step")
        button(359,y,54,spell.oncePerTarget and tr("1×/Ziel","1×/unit") or (spell.repeats or 1).."×",function(_,mouseButton)
            local current=spell.oncePerTarget and 6 or (spell.repeats or 1)
            local delta=mouseButton=="RightButton" and -1 or 1
            local nextMode=(current-1+delta)%6+1
            draft[i]={name=spell.name,icon=spell.icon,oncePerTarget=nextMode==6,repeats=nextMode==6 and 1 or nextMode,
                mouseover=spell.mouseover}
            draw()
        end,nil,"counter")
        for k,delta in ipairs({-1,1}) do
            button(414+(k-1)*37,y,36,delta==-1 and tr("Auf","Up") or tr("Ab","Dn"),function()
                local j=i+delta
                if draft[j] then
                    draft[i],draft[j]=draft[j],draft[i]
                    rightPage=math.ceil(j/8)
                    draw()
                end
            end)
        end
        button(488,y,31,"X",function()
            table.remove(draft,i)
            rightPage=math.max(1,math.min(rightPage,math.ceil(#draft/8)))
            draw()
        end)
        mouseoverCheckbox(y, i, spell)
    end)
    if editing then button(12,425,112,tr("Löschen","Delete"),requestDelete) end
    button(230,425,112,tr("Zurück","Back"),function() draft=nil leftPage=1 draw() end)
    button(350,425,169,tr("Speichern","Save"),save,nil,"save")
end

local tabs={}
local paper
-- Mirror the active client's page art, including cropped atlas coordinates.
local function pageArt(frame,depth)
    for _,region in ipairs({frame:GetRegions()}) do
        if region:IsObjectType("Texture") and region:IsVisible() then
            local atlas=region:GetAtlas()
            local path=region.GetTextureFilePath and region:GetTextureFilePath()
            local key=(Bars.Text(atlas) and atlas or Bars.Text(path) and path or ""):lower()
            if region:GetWidth()>220 and region:GetHeight()>220 and
                (key:find("parchment") or key:find("spellbook") and
                (key:find("background") or key:find("page") or key:find("interior"))) then
                return region
            end
        end
    end
    if depth>0 then
        for _,child in ipairs({frame:GetChildren()}) do
            if child~=panel and not child:IsForbidden() and child:IsVisible() then
                local art=pageArt(child,depth-1)
                if art then return art end
            end
        end
    end
end

local function toggle(book)
    if InCombatLockdown() or not Buddy.char then return end
    if panel and panel:IsShown() then panel:Hide() return end
    if not panel then
        panel=CreateFrame("Frame",nil,UIParent)
        panel:SetSize(620,495)
        panel:SetClampedToScreen(true)
        panel:EnableMouse(true)
        paper=panel:CreateTexture(nil,"BACKGROUND")
        paper:SetAllPoints()
        paperTitle=lettering(panel,"QuestTitleFontBlackShadow")
        paperTitle:SetShadowOffset(0,0)
        paperTitle:SetPoint("TOPLEFT",18,-18)
        title=lettering(panel,"QuestTitleFontBlackShadow")
        title:SetPoint("TOPLEFT",231,-18)
        title:SetText(tr("Folge bearbeiten","Edit sequence"))
        nameLabel=lettering(panel,"GameFontNormal")
        nameLabel:SetTextColor(.18,.10,.045)
        nameLabel:SetPoint("TOPLEFT",232,-54)
        nameLabel:SetText("Name")
        hint=lettering(panel,"GameFontNormalSmall")
        hint:SetPoint("BOTTOM",0,10)
        nameBox=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
        nameBox:SetPoint("TOPLEFT",280,-44)
        nameBox:SetSize(233,30)
        nameBox:SetAutoFocus(false)
        nameBox:SetMaxLetters(32)
        local close=CreateFrame("Button",nil,panel,"UIPanelCloseButton")
        close:SetPoint("TOPRIGHT")
        close:SetScript("OnClick",function() panel:Hide() end)
    end
    panel:SetParent(book)
    panel:SetFrameLevel(book:GetFrameLevel()+30)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT",book,"TOPRIGHT",6,0)
    local art=pageArt(book,4)
    if art then
        if art:GetAtlas() then paper:SetAtlas(art:GetAtlas()) else paper:SetTexture(art:GetTexture()) end
        paper:SetTexCoord(art:GetTexCoord())
    else
        paper:SetTexture("Interface\\Spellbook\\UI-SpellbookPanel-Page1")
        paper:SetTexCoord(0,1,0,1)
    end
    draft,leftPage=nil,1
    panel:Show()
    draw()
end

local function attach(book)
    if not book or tabs[book] then return end
    local header=book
    if PlayerSpellsFrame and book==PlayerSpellsFrame.SpellBookFrame then header=PlayerSpellsFrame end
    local close=header.CloseButton
    local resize=header.MaximizeMinimizeButton or header.MaximizeMinimizeFrame
    -- The title controls can sit outside the clipped spellbook content frame.
    local owner=close and close:GetParent() or header
    local tab=CreateFrame("Button",nil,owner)
    tab:SetSize(112,22)
    tab:SetFrameStrata(close and close:GetFrameStrata() or header:GetFrameStrata())
    tab:SetFrameLevel(math.max(owner:GetFrameLevel(),close and close:GetFrameLevel() or 0,
        resize and resize:GetFrameLevel() or 0)+2)
    local face=tab:CreateTexture(nil,"ARTWORK")
    face:SetAllPoints()
    face:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    face:SetTexCoord(0,.625,0,.6875)
    local label=tab:CreateFontString(nil,"OVERLAY","GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText("BuddyRotation")
    tab:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight","ADD")
    if resize and resize:IsShown() then
        tab:SetPoint("RIGHT",resize,"LEFT",-3,0)
    elseif close then
        tab:SetPoint("RIGHT",close,"LEFT",-30,0)
    else
        tab:SetPoint("TOPRIGHT",header,"TOPRIGHT",-58,-3)
    end
    tab:SetShown(book:IsShown())
    book:HookScript("OnShow",function() tab:Show() end)
    tab:SetScript("OnClick",function() toggle(book) end)
    book:HookScript("OnHide",function()
        tab:Hide()
        if panel and panel:GetParent()==book then panel:Hide() end
    end)
    tabs[book]=tab
end

local function attachBooks()
    if InCombatLockdown() then return end
    attach(SpellBookFrame)
    attach(SpellbookFrame)
    attach(SpellBookStandaloneFrame)
    if PlayerSpellsFrame then attach(PlayerSpellsFrame.SpellBookFrame or PlayerSpellsFrame) end
end

function Buddy.InitializeRotation()
    if SlashCmdList.BUDDYROTATION then return end
    SLASH_BUDDYROTATIONQUIET1="/brq"
    SlashCmdList.BUDDYROTATIONQUIET=function()
        quietUntil=GetTime()+0.25
    end
    local pendingRestore=InCombatLockdown()
    if not pendingRestore then installCooldownFilter() end
    restoreSequences()
    attachBooks()
    if hooksecurefunc and ShowUIPanel then
        hooksecurefunc("ShowUIPanel",function(frame)
            attachBooks()
            if not frame or frame:IsForbidden() or InCombatLockdown() then return end
            local label=frame.TitleText or (frame.TitleContainer and frame.TitleContainer.TitleText)
            if label and label.GetText then
                local text=label:GetText()
                if SPELLBOOK and Bars.Public(text) and text==SPELLBOOK then attach(frame) end
            end
        end)
    end
    SLASH_BUDDYROTATION1="/buddyrotation"
    SlashCmdList.BUDDYROTATION=function()
        if InCombatLockdown() then return end
        for book in pairs(tabs) do if book:IsVisible() then toggle(book) return end end
        if ToggleSpellBook then ToggleSpellBook("spell")
        elseif PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBook then PlayerSpellsUtil.ToggleSpellBook() end
        attachBooks()
        for book in pairs(tabs) do if book:IsVisible() then toggle(book) return end end
    end
    local events=CreateFrame("Frame")
    for _, event in ipairs({
        "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "PLAYER_ENTERING_WORLD",
        "UPDATE_MACROS", "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED",
    }) do
        events:RegisterEvent(event)
    end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_REGEN_ENABLED" then queueIconRefresh() end
        if event=="PLAYER_REGEN_DISABLED" then
            if panel then panel:Hide() end
        elseif event=="ADDON_LOADED" or event=="PLAYER_REGEN_ENABLED" then
            if pendingRestore and not InCombatLockdown() then
                installCooldownFilter()
                restoreSequences()
                pendingRestore=false
            end
            attachBooks()
        else
            queueIconRefresh()
        end
    end)
end
