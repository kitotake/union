-- client/modules/spawn/handler.lua
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Gestion du spawn client : chargement modèle, collisions, fade, freeze
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- THREAD D'INITIALISATION AU DÉMARRAGE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CreateThread(function()
    local playerId = PlayerId()

    -- ── 1. Attendre que le joueur soit actif sur le réseau ────────────────
    while not NetworkIsPlayerActive(playerId) do
        Wait(0)
    end

    -- ── 2. Écran noir immédiat pour éviter les flashs ────────────────────
    DoScreenFadeOut(0)

    local ped = PlayerPedId()

    -- ── 3. Rendre invisible + freeze + invincible pendant le chargement ──
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetPlayerInvincible(playerId, true)

    -- ── 4. Charger le modèle temporaire ──────────────────────────────────
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

    -- Récupérer le nouveau ped après changement de modèle
    ped = PlayerPedId()

    -- ── 5. Charger les collisions à la position courante ─────────────────
    local coords = GetEntityCoords(ped)

    -- Fallback si le ped est à (0,0,0) — pas encore placé
    if math.abs(coords.x) < 1.0 and math.abs(coords.y) < 1.0 then
        coords = Config.spawn.defaultPosition
    end

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    local collTimeout = GetGameTimer() + 8000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collTimeout do
        Wait(0)
    end

    -- ── 6. Arrêter le loading screen ────────────────────────────────────
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    -- ── 7. Notifier le serveur que le joueur est prêt ────────────────────
    TriggerServerEvent("union:player:joined")

    -- ── 8. Attendre la confirmation serveur (max 10s) ────────────────────
    local loaded = false
    local loadHandler

    loadHandler = AddEventHandler("union:player:loaded", function()
        loaded = true
        RemoveEventHandler(loadHandler)
    end)

    local timeout = GetGameTimer() + 10000
    while not loaded and GetGameTimer() < timeout do
        Wait(100)
    end

    if not loaded then
        Logger:error("Player load timeout — forcing spawn anyway")
    end

    -- ── 9. Réactiver le joueur ───────────────────────────────────────────
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetPlayerInvincible(playerId, false)

    -- ── 10. Fade in propre ───────────────────────────────────────────────
    DoScreenFadeIn(800)

    -- ── 11. Signaler que le client est prêt ─────────────────────────────
    Client.isReady = true
    TriggerEvent("union:client:ready")
    Logger:info("Client ready — requesting initial spawn")

    -- ── 12. Demander le spawn initial ────────────────────────────────────
    Spawn.initialize()
end)