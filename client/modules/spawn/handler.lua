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

-- Au niveau global du script — obligatoire pour FiveM
RegisterNetEvent("union:player:loaded")

CreateThread(function()
    local playerId = PlayerId()

    -- ── 1. Attendre réseau actif ──────────────────────────────────────
    while not NetworkIsPlayerActive(playerId) do Wait(0) end

    -- ── 2. Attendre que tous les modules soient chargés ───────────────
    -- Evite que le spawn démarre avant client/main.lua et charManager
    Wait(1000)

    -- ── 3. Écran noir immédiat ────────────────────────────────────────
    DoScreenFadeOut(0)

    local ped = PlayerPedId()

    -- ── 4. Freeze ─────────────────────────────────────────────────────
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetPlayerInvincible(playerId, true)

    -- ── 5. Modèle temporaire ──────────────────────────────────────────
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

    -- ── 6. Collisions ─────────────────────────────────────────────────
    local coords = GetEntityCoords(ped)
    if math.abs(coords.x) < 1.0 and math.abs(coords.y) < 1.0 then
        coords = Config.spawn.defaultPosition
    end

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local collTimeout = GetGameTimer() + 8000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collTimeout do
        Wait(0)
    end

    -- ── 7. Loading screen ─────────────────────────────────────────────
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    -- ── 8. Enregistrer le handler AVANT d'envoyer joined ─────────────
    local loaded = false
    local loadHandler = AddEventHandler("union:player:loaded", function()
        loaded = true
    end)

    -- ── 9. Notifier le serveur ────────────────────────────────────────
    TriggerServerEvent("union:player:joined")

    -- ── 10. Attendre union:player:loaded ─────────────────────────────
    local timeout = GetGameTimer() + 12000
    while not loaded and GetGameTimer() < timeout do Wait(100) end
    RemoveEventHandler(loadHandler)

    if not loaded then
        Logger:error("union:player:loaded timeout — forcing spawn anyway")
    else
        Logger:info("union:player:loaded reçu — DB chargée")
    end

    -- ── 11. Réactiver ─────────────────────────────────────────────────
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetPlayerInvincible(playerId, false)

    -- ── 12. Fade in ───────────────────────────────────────────────────
    DoScreenFadeIn(250)

    -- ── 13. Marquer prêt ──────────────────────────────────────────────
    Client.isReady = true
    TriggerEvent("union:client:ready")
    Logger:info("Client ready — requesting initial spawn")

    -- ── 14. Spawn initial ─────────────────────────────────────────────
    Spawn.initialize()
end)