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



-- Locale
Config.locale = "fr"

-- Export pour accès global
if IsDuplicityVersion() then -- Server
    exports("GetConfig", function() return Config end)
else -- Client
    exports("GetConfig", function() return Config end)
end
