-- client/modules/spawn/handler.lua
Spawn.Handler = {}

function Spawn.Handler.getLastPosition()
    local pos, heading, hasSaved = Position.get()
    if hasSaved and pos then
        return pos, heading
    end
    return Config.spawn.defaultPosition, Config.spawn.defaultHeading
end

function Spawn.Handler.setDefaultClothes(ped)
    for i = 0, 11 do
        SetPedComponentVariation(ped, i, 0, 0, 1)
    end
    for i = 0, 7 do
        ClearPedProp(ped, i)
    end
end

function Spawn.Handler.applyOutfit(ped, outfitStyle)
    Spawn.Handler.setDefaultClothes(ped)
end

-- Auto-initialize spawn on player enter world
CreateThread(function()
    -- Attendre que le joueur soit actif sur le réseau
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end

    Wait(2000)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    -- Charger le modèle temporaire (pendant le chargement des données)
    local tempModel = Config.spawn.temporaryModel
    RequestModel(GetHashKey(tempModel))

    local startTime = GetGameTimer()
    while not HasModelLoaded(GetHashKey(tempModel)) do
        Wait(50)
        if GetGameTimer() - startTime > 5000 then
            Logger:error("Failed to load temporary model")
            break
        end
    end

    SetPlayerModel(PlayerId(), GetHashKey(tempModel))
    SetModelAsNoLongerNeeded(GetHashKey(tempModel))

    -- Notifier le serveur que le joueur est prêt
    -- Le serveur va créer l'entrée dans PlayerManager et charger les données
    TriggerServerEvent("union:player:joined")

    -- Attendre que le serveur confirme le chargement du joueur
    -- avant de demander le spawn
    local loaded = false
    RegisterNetEvent("union:player:loaded", function()
        loaded = true
    end)

    -- Timeout de sécurité : 10 secondes max
    local timeout = GetGameTimer() + 10000
    while not loaded and GetGameTimer() < timeout do
        Wait(100)
    end

    if not loaded then
        Logger:error("Player load timeout - forcing spawn anyway")
    end

    Client.isReady = true
    TriggerEvent("union:client:ready")
    Logger:info("Client ready, requesting spawn")

    Spawn.initialize()
end)