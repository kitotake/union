-- shared/config/config.lua
Config = {
    version = "0.0.15",
    debug = true,
    logLevel = 1,

    spawn = {
        defaultModel = "mp_m_freemode_01",
        femaleModel = "mp_f_freemode_01",
        temporaryModel = "player_zero",
        defaultPosition = vector3(-268.5, -957.8, 31.2),
        defaultHeading = 90.0,
        spawnDelay = 3000,
        saveInterval = 30000,
        timeouts = {
            modelLoad = 10000,
            collisionLoad = 10000,
        }
    },

    character = {
        defaultHealth = 200,
        defaultArmor = 100,
        maxCharactersPerPlayer = 5,
    },

    -- ✅ Table vide : les vraies URLs sont dans shared/config/webhooks.lua
    webhooks = {},

    locale = "en",

    permissions = {
        defaultGroup = "user",
        autoAssign = true,
    },
    -- Whitelist
    whitelist = {
        enabled = false, -- passer à true pour activer
    },
}



if IsDuplicityVersion() then
    exports("GetConfig", function() return Config end)
else
    exports("GetConfig", function() return Config end)
end

return Config