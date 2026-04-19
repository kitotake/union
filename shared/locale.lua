-- shared/locale.lua
Locale = {}
Locale.current = Config.locale or "en"
Locale.translations = {}

-- Load all locale files
local localeDir = "shared/locales/"
local localeFiles = {
    "en.lua",
    "fr.lua",
}

for _, file in ipairs(localeFiles) do
    local chunk = LoadResourceFile(GetCurrentResourceName(), localeDir .. file)
    if chunk then
        local loaded = load(chunk, localeDir .. file)
        if loaded then loaded() end
    end
end

-- Get a translated string
function _t(key, ...)
    local translations = Locale.translations[Locale.current] or Locale.translations["en"] or {}
    local text = translations[key] or key
    return string.format(text, ...)
end

-- Set current locale
function Locale.setLocale(lang)
    if Locale.translations[lang] then
        Locale.current = lang
        return true
    end
    return false
end

return Locale