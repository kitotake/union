-- shared/config.lua

Config = {} -- Rendu global au lieu de local pour être accessible aux autres scripts

Config.debugMode = true
Config.defaultHealth = 200
Config.defaultArmor = 100
Config.spawnPos = vector3(-268.5, -957.8, 31.2)
Config.heading = 90.0
Config.showSpawnBlip = true
Config.blipDuration = 5000

-- Ajouts suggérés pour la config
Config.locale = "fr" -- Support multilingue
Config.saveInterval = 30000 -- Intervalle de sauvegarde des données joueurs
Config.maxSpawnAttempts = 3 -- Nombre maximum de tentatives de spawn

Config.webhooks = {
    connectionRejected = "https://discord.com/api/webhooks/1372720711369621504/###",
    connectionAccepted = "https://discord.com/api/webhooks/1372720870598115358/###",
}

Config.timeouts = {
    modelLoad = 5000,
    modelVerify = 5000,
    networkVisibility = 3000,
}

Config.retries = {
    spawn = 3,
    visibility = 5,
}

-- Ajout dans config.lua
Config.temporaryModel = "player_zero"  -- Modèle utilisé pendant le chargement
Config.useTemporaryModel = true        -- Activer l'utilisation du modèle temporaire
Config.modelTransitionFade = true      -- Utiliser un fondu lors du changement de modèle
Config.defaultModel = "mp_m_freemode_01"
Config.femaleModel = "mp_f_freemode_01"
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