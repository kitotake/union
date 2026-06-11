-- client/modules/spawn/handler.lua

Spawn.Handler = {}

function Spawn.Handler.getLastPosition()
    local pos, heading, hasSaved = Position.get()
    if hasSaved and pos then return pos, heading end
    return Config.spawn.defaultPosition, Config.spawn.defaultHeading
end

function Spawn.Handler.setDefaultClothes(ped)
    for i = 0, 11 do SetPedComponentVariation(ped, i, 0, 0, 1) end
    for i = 0, 7  do ClearPedProp(ped, i) end
end

RegisterNetEvent("union:player:loaded")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Seul RegisterNetEvent("union:spawn:apply") de tout le côté client
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local spawnInProgress     = false
local currentSpawnSession = 0

local function resetSpawnGuard()
    spawnInProgress = false
end

-- BUG-6 : remettre la NUI de sélection en cas de timeout spawn
local function resetToCharacterSelection()
    resetSpawnGuard()
    Logger:warn("Timeout spawn — retour à la sélection de personnage")
    -- Ré-demander la liste de personnages au serveur pour rouvrir la NUI
    TriggerServerEvent("union:spawn:requestInitial")
end

local function startSpawnTimeout(seconds, sessionId)
    CreateThread(function()
        local limit = GetGameTimer() + (seconds * 1000)
        while GetGameTimer() < limit do
            Wait(500)
            if currentSpawnSession ~= sessionId then return end
        end
        if currentSpawnSession == sessionId and spawnInProgress then
            Logger:warn(("Spawn timeout (%ds) [session %d]"):format(seconds, sessionId))
            -- BUG-6 : au lieu de juste reset le guard, on remet le joueur en état de sélectionner
            resetToCharacterSelection()
        end
    end)
end

local function SafePed()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    return ped
end

RegisterNetEvent("union:spawn:apply", function(characterData)
    if not characterData then
        Logger:error("characterData nil")
        return
    end
    if spawnInProgress then
        Logger:warn("Spawn déjà en cours — événement dupliqué ignoré")
        return
    end
    spawnInProgress = true
    currentSpawnSession = currentSpawnSession + 1
    local mySession = currentSpawnSession
    startSpawnTimeout(30, mySession)

    local model = characterData.ped_model
    if not model or model == "" then
        Logger:error("ped_model manquant dans characterData")
        resetSpawnGuard()
        return
    end

    Logger:info("Application du modèle personnage : " .. model)

    Citizen.CreateThread(function()
        -- 1. LOAD MODEL
        local modelHash = GetHashKey(model)
        if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
            Logger:error("Modèle invalide : " .. model)
            TriggerServerEvent("union:spawn:error", "MODEL_INVALID")
            resetSpawnGuard()
            return
        end
        RequestModel(modelHash)
        local timeout = GetGameTimer() + 8000
        while not HasModelLoaded(modelHash) do
            Wait(0)
            if GetGameTimer() > timeout then
                Logger:error("Timeout chargement modèle : " .. model)
                TriggerServerEvent("union:spawn:error", "MODEL_LOAD_FAILED")
                resetSpawnGuard()
                return
            end
            if currentSpawnSession ~= mySession then
                Logger:warn("Session spawn invalidée pendant chargement modèle")
                return
            end
        end

        -- 2. SET MODEL
        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)
        Wait(0)
        local ped = SafePed()
        FreezeEntityPosition(ped, true)

        -- 3. DATA
        local rawPos  = characterData.position or Config.spawn.defaultPosition
        local posX    = rawPos.x or Config.spawn.defaultPosition.x
        local posY    = rawPos.y or Config.spawn.defaultPosition.y
        local posZ    = rawPos.z or Config.spawn.defaultPosition.z
        local heading = characterData.heading or Config.spawn.defaultHeading
        local health  = characterData.health  or Config.character.defaultHealth
        local armor   = characterData.armor   or 0

        -- 4. APPARENCE
        local waited = 0
        while not Bridge.Character:isAvailable() and waited < 20 do
            Wait(250)
            waited = waited + 1
        end
        if Bridge.Character:isAvailable() then
            local ok, err = pcall(function()
                exports["kt_character"]:ApplyPreview(characterData)
            end)
            if ok then
                Logger:info("Skin du personnage chargé avec succès")
            else
                Logger:warn("ApplyPreview échoué : " .. tostring(err) .. " — fallback")
                Bridge.Character._applyFallback(characterData)
            end
        else
            Logger:warn("kt_character non disponible — fallback modèle de base")
            Bridge.Character._applyFallback(characterData)
        end

        -- 5. COLLISION + RESPAWN
        RequestCollisionAtCoord(posX, posY, posZ)
        local collTimeout = GetGameTimer() + 6000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collTimeout do
            Wait(50)
        end
        NetworkResurrectLocalPlayer(posX, posY, posZ, heading, true, true)
        Wait(0)
        ped = SafePed()
        SetEntityHealth(ped, health)
        SetPedArmour(ped, armor)
        SetEntityHeading(ped, heading)
        ClearPedTasksImmediately(ped)

        -- 6. OFFLINE PED CLEAN
        if OfflinePeds and OfflinePeds.list and characterData.unique_id then
            local offlinePed = OfflinePeds.list[characterData.unique_id]
            if offlinePed and DoesEntityExist(offlinePed) then
                DeleteEntity(offlinePed)
                OfflinePeds.list[characterData.unique_id] = nil
            end
        end

        -- 7. VISIBILITÉ FINALE
        SetEntityVisible(ped, true, false)
        SetEntityAlpha(ped, 255, false)
        FreezeEntityPosition(ped, false)

        -- 8. STORE CHARACTER
        Client.currentCharacter = characterData
        Logger:info("Personnage spawné avec succès")
        resetSpawnGuard()

        -- 9. CONFIRM SERVEUR
        TriggerServerEvent("union:spawn:confirm", characterData.unique_id)

        -- 10. APPARENCE depuis DB si kt_character indispo
        if not Bridge.Character:isAvailable() then
            SetTimeout(1000, function()
                TriggerServerEvent("union:player:apparence")
                Logger:info("Apparence DB demandée au serveur")
            end)
        end

        -- 11. EVENTS LOCAUX
        TriggerEvent("union:player:spawned", characterData)
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Thread principal de connexion
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CreateThread(function()
    local playerId = PlayerId()
    while not NetworkIsPlayerActive(playerId) do Wait(0) end
    Wait(1000)
    DoScreenFadeOut(0)
    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetPlayerInvincible(playerId, true)

    local tempModel = Config.spawn.temporaryModel
    local tempHash  = GetHashKey(tempModel)
    RequestModel(tempHash)
    local startTime = GetGameTimer()
    while not HasModelLoaded(tempHash) do
        Wait(50)
        if GetGameTimer() - startTime > 5000 then
            Logger:error("Failed to load temporary model: " .. tempModel)
            break
        end
    end
    SetPlayerModel(playerId, tempHash)
    SetModelAsNoLongerNeeded(tempHash)
    ped = PlayerPedId()

    local coords = GetEntityCoords(ped)
    if math.abs(coords.x) < 1.0 and math.abs(coords.y) < 1.0 then
        coords = Config.spawn.defaultPosition
    end
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local collTimeout = GetGameTimer() + 8000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collTimeout do
        Wait(0)
    end

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    local loaded = false
    local loadHandler = AddEventHandler("union:player:loaded", function()
        loaded = true
    end)
    TriggerServerEvent("union:player:joined")

    local timeoutWait = GetGameTimer() + 12000
    while not loaded and GetGameTimer() < timeoutWait do Wait(100) end
    RemoveEventHandler(loadHandler)

    if not loaded then
        Logger:error("union:player:loaded timeout — forcing spawn anyway")
    else
        Logger:info("union:player:loaded reçu — DB chargée")
    end

    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetPlayerInvincible(playerId, false)
    DoScreenFadeIn(250)

    Client.isReady = true
    TriggerEvent("union:client:ready")
    Logger:info("Client ready — requesting initial spawn")
    Spawn.initialize()
end)