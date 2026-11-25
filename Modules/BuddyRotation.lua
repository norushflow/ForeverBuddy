local _, Buddy = ...
local Bars = Buddy.Bars
local de = GetLocale() == "deDE"
local function tr(german, english) return de and german or english end
local panel, title, nameBox, hint
local controls = {rows={}, actions={}}
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
local function launcher(key,steps,mode)
    local opening = {}
    for _,step in ipairs(steps) do
        if step.oncePerTarget then opening[#opening+1]=step.name end
    end
    local lines = {}
    if #opening>0 then
        lines[1]="/castsequence reset=target "..table.concat(opening,", ")..", null"
    end
    if #opening<#steps then
        if mode=="target" then
            local cycle={}
            for _,step in ipairs(steps) do
                if not step.oncePerTarget then
                    for attempt=1,step.repeats or 1 do cycle[#cycle+1]=step.name end
                end
            end
            lines[#lines+1]="/castsequence reset=target "..table.concat(cycle,", ")
        else
            lines[#lines+1]="/click ForeverBuddySequence" .. key
        end
    end
    return table.concat(lines,"\n")
end

local function configure(key, steps, mode)
    local runner = runners[key]
    if not runner then
        runner = CreateFrame("Button","ForeverBuddySequence"..key,UIParent,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
        runner:RegisterForClicks("LeftButtonUp")
        runner:SetAttribute("useOnKeyDown",false)
        SecureHandlerWrapScript(runner,"OnClick",runner,[[
            local count = self:GetAttribute("count")
            if not count or count == 0 then return end
            local step = self:GetAttribute("next") or 1
            self:SetAttribute("spell",self:GetAttribute("step"..step))
            self:SetAttribute("next",step % count + 1)
        ]])
        runner:SetAttribute("_onstate-rotationcombat",[[
            if newstate == "in" and self:GetAttribute("resetCombat") then
                self:SetAttribute("next",1)
            end
        ]])

        runners[key]=runner
    end
    if mode=="combat" and not runner.combatDriver then
        RegisterStateDriver(runner,"rotationcombat","[combat] in; out")
        runner.combatDriver=true
    end
    runner:SetAttribute("resetCombat",mode=="combat")
    local count=0
    for _,step in ipairs(steps) do
        if not step.oncePerTarget then
            for attempt=1,step.repeats or 1 do
                count=count+1
                runner:SetAttribute("step"..count,step.name)
            end
        end
    end
    runner:SetAttribute("count",count)
    runner:SetAttribute("spell",count>0 and runner:GetAttribute("step1") or nil)
    runner:SetAttribute("next",1)
    runner:SetAttribute("type",count>0 and "spell" or nil)
end

local function macroBody(index)
    local body=select(3,GetMacroInfo(index))
    if type(body)=="string" then return (body:gsub("\r\n","\n"):gsub("%s+$","")) end
end

local function applySequence(old,key,steps,mode)
    local body = launcher(key,steps,mode)
    if #body>255 then
        return nil,tr("Folge zu lang für ein Makro.", "Sequence exceeds the macro length limit.")
    end
    -- Existing action-bar macros must have a live target even before the
    -- character macro list is available during login.
    if mode~="target" then configure(key,steps,mode) end
    local index, scope = Bars.MacroLookup(key)
    local icon = steps[1].icon or 134400
    local actual=index and macroBody(index)
    local ok=old and index and actual==body
    local previous=old and old.body and old.body:gsub("\r\n","\n"):gsub("%s+$","")
    if not ok and old and index and actual==previous then
        ok=pcall(EditMacro,index,key,icon,body)
    elseif scope=="missing" then
        ok=pcall(CreateMacro,key,icon,body,true)
    end
    index=Bars.MacroLookup(key)
    if not ok or not index or macroBody(index)~=body then
        return nil,tr("Makro prüfen: freier Platz oder manuelle Änderung.","Check macro space or external edits.")
    end
    return body
end

local function sync(record)
    local ok,body,problem=pcall(applySequence,record,record.key,record.steps,record.resetMode)
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
    local record={label=label,steps=draft,key=key,resetMode=resetMode,body=old and old.body}
    records()[editing or (#records()+1)]=record
    Buddy.char.rotationSerial=serial
    local problem=sync(record)
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
            configure(target.key,{})
            table.remove(records(),editing)
            editing,draft,leftPage=nil,nil,1
            draw()
        end,
    }
    StaticPopup_Show(dialog,record.label,nil,record)
end

local used = {rows=0,actions=0}
local paperTitle, nameLabel
local function lettering(parent, font)
    return parent:CreateFontString(nil,"OVERLAY",font)
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
            draft[i]={name=spell.name,icon=spell.icon,oncePerTarget=nextMode==6,repeats=nextMode==6 and 1 or nextMode}
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
            local key=(atlas or path or ""):lower()
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
        panel:SetSize(530,495)
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
    local pendingRestore=InCombatLockdown()
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
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_REGEN_DISABLED" then
            if panel then panel:Hide() end
        else
            if pendingRestore and not InCombatLockdown() then
                restoreSequences()
                pendingRestore=false
            end
            attachBooks()
        end
    end)
end
