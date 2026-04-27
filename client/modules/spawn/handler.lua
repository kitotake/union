-- client/modules/spawn/handler.lua
-- FIX : le thread de démarrage écoute maintenant union:player:loaded
--       (envoyé par le serveur après PlayerManager.loadFromDatabase)
--       au lieu d'envoyer union:player:joined puis attendre.
--       Cela évite la race condition entre characters:playerReady et requestInitial.

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

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- THREAD D'INITIALISATION AU DÉMARRAGE
-- FIX : on attend union:player:loaded AVANT d'appeler Spawn.initialize().
--       union:player:loaded est envoyé par manager.lua après le chargement BDD.
--       characters:playerReady n'est plus utilisé pour le routing du spawn.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CreateThread(function()
    local playerId = PlayerId()

    -- ── 1. Attendre que le joueur soit actif sur le réseau ────────────
    while not NetworkIsPlayerActive(playerId) do Wait(0) end

    -- ── 2. Écran noir immédiat ────────────────────────────────────────
    DoScreenFadeOut(0)

    local ped = PlayerPedId()

    -- ── 3. Freeze pendant le chargement ──────────────────────────────
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetPlayerInvincible(playerId, true)

    -- ── 4. Modèle temporaire ──────────────────────────────────────────
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

    -- ── 5. Collisions ─────────────────────────────────────────────────
    local coords = GetEntityCoords(ped)
    if math.abs(coords.x) < 1.0 and math.abs(coords.y) < 1.0 then
        coords = Config.spawn.defaultPosition
    end

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local collTimeout = GetGameTimer() + 8000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collTimeout do
        Wait(0)
    end

    -- ── 6. Arrêter le loading screen ──────────────────────────────────
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    -- ── 7. Notifier le serveur ────────────────────────────────────────
    TriggerServerEvent("union:player:joined")

    -- ── 8. Attendre union:player:loaded (envoyé par manager.lua) ──────
    local loaded = false
    local loadHandler = AddEventHandler("union:player:loaded", function()
        loaded = true
    end)

    local timeout = GetGameTimer() + 12000
    while not loaded and GetGameTimer() < timeout do Wait(100) end
    RemoveEventHandler(loadHandler)

    if not loaded then
        Logger:error("union:player:loaded timeout — forcing spawn anyway")
    end

    -- ── 9. Réactiver le joueur ────────────────────────────────────────
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetPlayerInvincible(playerId, false)

    -- ── 10. Fade in ───────────────────────────────────────────────────
    DoScreenFadeIn(250)

    -- ── 11. Marquer le client prêt ────────────────────────────────────
    Client.isReady = true
    TriggerEvent("union:client:ready")
    Logger:info("Client ready — requesting initial spawn")

    -- ── 12. Demander le spawn initial ────────────────────────────────
    -- FIX : Spawn.initialize() envoie union:spawn:requestInitial à handler.lua
    --       C'est le SEUL chemin de spawn. characters:playerReady n'intervient plus.
    Spawn.initialize()
end)