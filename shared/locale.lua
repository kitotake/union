-- shared/locale.lua
-- FIX #11 : le dossier de locales s'appelle "shared/locale/" (sans 's').
--            Le commentaire FIXME est retiré car le code charge bien depuis "shared/locale/".
--            Assurez-vous que vos fichiers sont dans shared/locale/ et non shared/locales/.

Locale = {}
Locale.current = Config.locale or "en"
Locale.translations = {}

local localeDir = "shared/locale/"
local localeFiles = {
    "en.lua",
    "fr.lua",
}

for _, file in ipairs(localeFiles) do
    local chunk = LoadResourceFile(GetCurrentResourceName(), localeDir .. file)
    if chunk then
        local loaded = load(chunk, localeDir .. file)
        if loaded then loaded() end
    else
        -- Avertissement si le fichier de locale est introuvable
        print("^3[LOCALE] Fichier introuvable : " .. localeDir .. file .. "^7")
    end
end

function _t(key, ...)
    local translations = Locale.translations[Locale.current] or Locale.translations["en"] or {}
    local text = translations[key] or key
    -- Protection contre les erreurs de format si les args sont manquants
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