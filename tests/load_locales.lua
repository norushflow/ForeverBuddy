-- Load the production dictionaries for standalone module tests.
GetLocale = GetLocale or function() return "deDE" end
local originalLoadfile = loadfile
local function loadfile(path)
    local chunk, err = originalLoadfile(path)
    if not chunk then return nil, err end
    return function(name, addon, ...)
        if type(addon)=="table" and not addon.L then
            assert(originalLoadfile("Locales/enUS.lua"))(name, addon)
            assert(originalLoadfile("Locales/deDE.lua"))(name, addon)
        end
        return chunk(name, addon, ...)
    end
end

return loadfile
