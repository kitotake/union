-- shared/lange/locale.lua
Locales = {}

function _(str, ...)
    local locale = Config.locale or "fr"
    if not Locales[locale] then return str end
    
    local translated = Locales[locale][str] or str
    return string.format(translated, ...)
end

-- Example Locale File: locales/fr.lua
Locales["fr"] = {
    ["weapon_given"] = "Arme donnée: %s",
    ["unknown_weapon"] = "Arme inconnue: %s",
    ["usage_giveweapon"] = "Usage: /givegun [id]",
    -- etc...
}