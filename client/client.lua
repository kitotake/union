-- 📁 client/client.lua

local Config = exports.union:GetConfig()
local spawnInProgress = false
local spawnAttempts = 0
local fallbackTriggered = false
local lastSavedPos = vector3(0, 0, 0)

-- 💬 Log format helper
local function log(tag, msg)
    print(string.format("^6[%s]^0 %s", tag, msg))
end

-- 📦 Ping SQL pour vérifier la communication DB
RegisterNetEvent('spawn:client:sqlOk', function()
    log("SQL", "Base de données connectée avec succès.")
end)

RegisterNetEvent('spawn:client:sqlFail', function()
    log("SQL", "ERREUR : Échec de la connexion à la base de données.")
end)

-- 🧵 Thread principal de spawn
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
        log("SPAWN", "En attente de NetworkIsPlayerActive...")
    end

    -- ⏳ Chargement du modèle temporaire
    local tempModel = Config.temporaryModel or "player_one"
    RequestModel(GetHashKey(tempModel))

    local startTime = GetGameTimer()
    while not HasModelLoaded(GetHashKey(tempModel)) do
        Wait(50)
        if GetGameTimer() - startTime > Config.timeouts.modelLoad then
            log("ERROR", "Échec chargement modèle temporaire. Utilisation secours.")
            tempModel = Config.temporaryModel
            RequestModel(GetHashKey(tempModel))
            Wait(500)
            break
        end
    end

    SetPlayerModel(PlayerId(), GetHashKey(tempModel))
    SetModelAsNoLongerNeeded(GetHashKey(tempModel))
    SetEntityVisible(PlayerPedId(), true, false)
    log("SPAWN", "Modèle temporaire appliqué.")

    while not DoesEntityExist(PlayerPedId()) do
        Wait(500)
        log("SPAWN", "En attente du Ped...")
    end

    local safeCoords = vector3(-268.5, -957.8, 31.2)
    RequestCollisionAtCoord(safeCoords.x, safeCoords.y, safeCoords.z)
    log("SPAWN", "Chargement de la collision...")

    local timer = 0
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and timer < 10000 do
        Wait(500)
        timer += 500
    end

    if timer >= 10000 then
        log("SPAWN", "⚠ Collision non totalement chargée après 10s.")
    end

    -- Ping SQL test
    log("SPAWN", "Ping SQL vers le serveur...")
    TriggerServerEvent("spawn:server:pingSQL")
    TriggerServerEvent("union:playerJoined")

    -- Déclencher spawn
    TriggerServerEvent("spawn:server:requestInitialSpawn")
end)

-- 🔁 Application complète du modèle et spawn visuel
RegisterNetEvent("spawn:client:applyCharacter")
AddEventHandler("spawn:client:applyCharacter", function(model, position, heading, outfitStyle)
    spawnInProgress = true
    spawnAttempts += 1

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    Wait(1000)

    log("SPAWN", "Déclenchement de spawn:server:requestInitialSpawn")
    if Config.debugMode then
        log("SPAWN", "Debug actif. Déclenchement du spawn initial")
    end

    if not IsModelValid(GetHashKey(model)) then
        log("ERROR", "Modèle invalide: " .. model)
        fallbackTriggered = true
        TriggerServerEvent("spawn:server:reportError", "MODEL_INVALID")
        return
    end

    RequestModel(GetHashKey(model))
    local startTime = GetGameTimer()
    while not HasModelLoaded(GetHashKey(model)) do
        Wait(50)
        if GetGameTimer() - startTime > Config.timeouts.modelLoad then
            log("ERROR", "Timeout chargement modèle: " .. model)
            fallbackTriggered = true
            TriggerServerEvent("spawn:server:reportError", "MODEL_LOAD_FAILED")
            return
        end
    end

    SetPlayerModel(PlayerId(), GetHashKey(model))
    SetModelAsNoLongerNeeded(GetHashKey(model))

    local ped = PlayerPedId()
    if GetEntityModel(ped) ~= GetHashKey(model) then
        log("ERROR", "Échec application modèle.")
        Wait(500)
        SetPlayerModel(PlayerId(), GetHashKey(model))
        ped = PlayerPedId()

        if GetEntityModel(ped) ~= GetHashKey(model) then
            log("ERROR", "Nouvelle tentative échouée.")
            fallbackTriggered = true
            TriggerServerEvent("spawn:server:reportError", "MODEL_APPLICATION_FAILED")
            return
        end
    end

    SetDefaultClothes(ped)
    SetPedDefaultComponentVariation(ped)

    NetworkResurrectLocalPlayer(position.x, position.y, position.z, heading, true, true)
    SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, false, false, false, true)
    SetEntityHeading(ped, heading)
    SetEntityVisible(ped, true, false)
    SetPlayerInvincible(PlayerId(), false)
    FreezeEntityPosition(ped, false)

    log("HEALTH", "Application de la santé et armure...")
    SetEntityHealth(ped, Config.defaultHealth)
    SetPedArmour(ped, Config.defaultArmor)

    TriggerEvent("chat:addMessage", {
        color = { 255, 255, 0 },
        multiline = true,
        args = { "[UNION]", "Bienvenue ! Tout semble en ordre. Bonne chance là-dehors." }
    })

    -- Blip temporaire
    if Config.showSpawnBlip then
        local blip = AddBlipForCoord(position.x, position.y, position.z)
        SetBlipSprite(blip, 1)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 1.0)
        SetBlipColour(blip, 2)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Spawn Point")
        EndTextCommandSetBlipName(blip)
        SetTimeout(Config.blipDuration, function()
            RemoveBlip(blip)
            log("BLIP", "Blip supprimé après délai.")
        end)
    end

    TriggerEvent("spawn:client:setOutfit", outfitStyle)
    TriggerServerEvent("spawn:server:confirmComplete")
    TriggerServerEvent("spawn:server:savePosition", position, heading)
    fallbackTriggered = false
end)

-- 👕 Réinitialisation vêtements
function SetDefaultClothes(ped)
    for i = 0, 11 do SetPedComponentVariation(ped, i, 0, 0, 1) end
    for i = 0, 7 do ClearPedProp(ped, i) end
end

-- 🎭 Animation de spawn
RegisterNetEvent("spawn:client:confirmed")
AddEventHandler("spawn:client:confirmed", function()
    if Config.debugMode then log("SPAWN", "Spawn confirmé par le serveur") end
    spawnInProgress = false
    spawnAttempts = 0

    local ped = PlayerPedId()
    if not IsEntityDead(ped) then
        LoadAnimDict("amb@world_human_stand_mobile@male@text@base")
        TaskPlayAnim(ped, "amb@world_human_stand_mobile@male@text@base", "base", 8.0, -8.0, -1, 0, 0, false, false, false)
        Wait(1000)
        StopAnimTask(ped, "amb@world_human_stand_mobile@male@text@base", "base", 1.0)
    end

    log("SPAWN", "Joueur entièrement chargé. Événement playerSpawned émis.")
    TriggerEvent("playerSpawned")
end)

function LoadAnimDict(dict)
    RequestAnimDict(dict)
    local startTime = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if GetGameTimer() - startTime > 5000 then
            log("ERROR", "Échec chargement animdict: " .. dict)
            break
        end
    end
end
