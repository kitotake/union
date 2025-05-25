-- 📁 shared/config.lua

Config = {}

Config.debugMode = true
Config.defaultHealth = 200
Config.defaultArmor = 100
Config.defaultModel = "mp_m_freemode_01"
Config.femaleModel = "mp_f_freemode_01"

Config.temporaryModel = "player_zero"
Config.useTemporaryModel = true
Config.modelTransitionFade = true

Config.spawnDelay = 5000
Config.spawnPos = vector3(-268.5, -957.8, 31.2)
Config.heading = 90.0
Config.temporary = vector3(221.5427, -917.5260, 30.6920)

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


-- ✅ Export client
exports("GetConfig", function()
    return Config -- Retourne la variable globale Config
end)