Config = {}

-- Debug & Logging
Config.debugMode = true
Config.logLevel = 1 -- 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR

-- Default Values
Config.defaultHealth = 200
Config.defaultArmor = 100
Config.defaultModel = "mp_m_freemode_01"
Config.femaleModel = "mp_f_freemode_01"
Config.temporaryModel = "player_zero"

-- Spawn Settings
Config.spawnDelay = 3000
Config.spawnPos = vector3(-268.5, -957.8, 31.2)
Config.heading = 90.0
Config.saveInterval = 30000

-- Dans shared/config.lua, ajouter :
Config.outfits = {
    male = {
        casual = {
            [11] = {12, 0, 2},
            [8]  = {15, 0, 2},
            [4]  = {21, 0, 2},
            [6]  = {34, 0, 2},
        }
    },
    female = {
        casual = {
            [11] = {6, 0, 2},
            [8]  = {15, 0, 2},
            [4]  = {10, 0, 2},
            [6]  = {29, 0, 2},
        }
    }
}

Config.webhooks = {
    connectionRejected = "https://discord.com/api/webhooks/1373130149783928832/v9K-8keDi0pks3MO0oYeR2KTyoazfAVa23q8NxSCqlPTvz0CylEYZhBOvmm4M-H2zeXO",
     connectionAccepted = "https://discord.com/api/webhooks/1373130231485042768/66pfKgU1SmESfA7yJ89HfAkv1mNN3Z3bdlgcIYCnc3exhb5unjIwIyfnwFcDniOAo3YA",
 }
-- Locale
Config.locale = "fr"

-- Export pour accès global
if IsDuplicityVersion() then -- Server
    exports("GetConfig", function() return Config end)
else -- Client
    exports("GetConfig", function() return Config end)
end
