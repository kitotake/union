Config = {} -- Rendu global au lieu de local pour être accessible aux autres scripts

Config.debugMode = true
Config.defaultHealth = 200
Config.defaultArmor = 100
Config.spawnPos = vector3(-268.5, -957.8, 31.2)
Config.heading = 90.0
Config.showSpawnBlip = true
Config.blipDuration = 5000

Config.timeouts = {
    modelLoad = 5000,
    modelVerify = 5000,
    networkVisibility = 3000,
}

Config.retries = {
    spawn = 3,
    visibility = 5,
}

Config.defaultModel = "mp_m_freemode_01"
Config.femaleModel = "mp_f_freemode_01"
Config.temporaryModel = "a_m_m_skater_01"
Config.useTemporaryModel = true

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

Config.failover = {
    defaultModel = "a_m_m_bevhills_01",
    useFailoverModel = true,
    continueOnModelError = false,
    continueOnVisibilityError = false,
}

Config.autoRecovery = true

-- ✅ Export client
exports("GetConfig", function()
    return Config -- Retourne la variable globale Config
end)