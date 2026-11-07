local addonName, Buddy = ...
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" and name==addonName then
        ForeverbuddyDB = type(ForeverbuddyDB)=="table" and ForeverbuddyDB or {}
        ForeverbuddyCharDB = type(ForeverbuddyCharDB)=="table" and ForeverbuddyCharDB or {}
        Buddy.db, Buddy.char = ForeverbuddyDB, ForeverbuddyCharDB
        Buddy.db.enabled = Buddy.db.enabled or {}
        Buddy.db.clock, Buddy.db.schedule = nil, nil
        Buddy.db.enabled.clock, Buddy.db.enabled.schedule = nil, nil
        Buddy.db.minimap = Buddy.db.minimap or {angle=220}
        Buddy.db.minimap.angle = tonumber(Buddy.db.minimap.angle) or 220
        Buddy.loaded = {}
        for _,module in ipairs(Buddy.modules) do
            Buddy.db[module.key] = Buddy.db[module.key] or {}
            if Buddy.db.enabled[module.key]==nil then Buddy.db.enabled[module.key]=true end
            if Buddy.db.enabled[module.key] then
                Buddy[module.loader]()
                Buddy.loaded[module.key] = true
            end
        end
        events:UnregisterEvent("ADDON_LOADED")
        SLASH_FOREVERBUDDY1="/fb"; SLASH_FOREVERBUDDY2="/foreverbuddy"
        SlashCmdList.FOREVERBUDDY=function(input)
            local command=(input or ""):match("^%s*(.-)%s*$"):lower()
            local aliases={chars=1,charaktere=1,transmog=2,meter=3,schadensmeter=3,bars=4,leisten=4,aktionsleisten=4}
            if aliases[command] then
                local module=Buddy.modules[aliases[command]]
                if module and module.key=="bars" then Buddy.Toggle()
                else Buddy.OpenModule(module) end
            else Buddy.Toggle() end
        end
    elseif event=="PLAYER_LOGIN" then
        Buddy.CreateMinimap()
        events:UnregisterEvent("PLAYER_LOGIN")
    end
end)
