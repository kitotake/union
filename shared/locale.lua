-- shared/locale.lua
Locale = {}
Locale.current = Config.locale or "en"
Locale.translations = {}

local localeDir = "shared/locale/"
local localeFiles = { "en.lua", "fr.lua" }

for _, file in ipairs(localeFiles) do
    local chunk = LoadResourceFile(GetCurrentResourceName(), localeDir .. file)
    if chunk then
        local loaded = load(chunk, localeDir .. file)
        if loaded then loaded() end
    else
        print("^3[LOCALE] Fichier introuvable : " .. localeDir .. file .. "^7")
    end
end

function _t(key, ...)
    local translations = Locale.translations[Locale.current] or Locale.translations["en"] or {}
    local text = translations[key] or key
    local ok, result = pcall(string.format, text, ...)
    return ok and result or text
end

function Locale.setLocale(lang)
    if Locale.translations[lang] then
        Locale.current = lang
        return true
    end
    return false
end

return Locale
