local function read(path)
    local file=assert(io.open(path));local text=file:read('*a');file:close();return text
end
local function loadLocale(locale)
    GetLocale=function() return locale end
    local ns={}
    assert(loadfile('Locales/enUS.lua'))('test',ns)
    assert(loadfile('Locales/deDE.lua'))('test',ns)
    return ns.L
end
local english=loadLocale('enUS')
for _,locale in ipairs({'deDE','enUS','enGB','frFR','koKR'}) do
    local strings=loadLocale(locale)
    for key,value in pairs(english) do
        assert(type(strings[key])=='string' and strings[key]~='',locale..': '..key)
        if locale~='deDE' then assert(strings[key]==value,'English fallback '..key) end
        local function tokens(text)
            local result={}
            for token in text:gmatch('%%[-+ #0%d%.]*[cdiouxXeEfgGqs]') do result[#result+1]=token end
            return table.concat(result,',')
        end
        assert(tokens(value)==tokens(strings[key]),'format mismatch: '..key)
        local function count(text,pattern) local _,n=text:gsub(pattern,'');return n end
        assert(count(value,'\n')==count(strings[key],'\n'),'line breaks: '..key)
        assert(count(value,'|c%x%x%x%x%x%x%x%x')==count(strings[key],'|c%x%x%x%x%x%x%x%x'),'colors: '..key)
    end
    for key in pairs(strings) do assert(english[key],'missing English key: '..key) end
end
local toc="Foreverbuddy.toc"
local source=read(toc)
assert(source:find('Locales/enUS.lua\nLocales/deDE.lua\nCore.lua',1,true),'locale load order')
for file in source:gmatch('[^\n]+') do
    if file:match('%.lua$') and not file:match('^Locales/') then
        for literal in read(file):gmatch('L%[(".-")%]') do
            local key=assert(loadstring('return '..literal))()
            assert(english[key],file..': missing translation '..key)
        end
    end
end
assert(loadLocale('deDE')['One Button Setup']=='Ein-Knopf-Einrichtung')
print('PASS: deDE/enUS/enGB, unsupported-locale fallback, keys, formats, colors and TOC order')

local version=assert(source:match("## Version: ([^\n]+)"))
local core=read('Core.lua')
local runtimeVersion=core:match('UI.VERSION = "([^"]+)"')
if runtimeVersion then assert(version==runtimeVersion,'TOC/runtime version mismatch') end
assert(read('README.md'):match('^#[^\n]*'..version:gsub('%.','%%.')),'README version mismatch')
assert(source:find('## Notes-deDE:',1,true),'German addon description missing')
