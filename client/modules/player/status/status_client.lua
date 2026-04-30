-- client/player/status/status_client.lua

StatusClient        = {}
StatusClient.logger = Logger:child("STATUS:CLIENT")

-- ────────────────────────────────────────────────────────────────────────────
-- État local
-- ────────────────────────────────────────────────────────────────────────────

StatusClient.status = {
    hunger = 100,
    thirst = 100,
    stress = 0,
}

StatusClient.isActive  = false   -- true une fois que le serveur a envoyé init
StatusClient.lastShot  = 0       -- timestamp dernier tir (pour stress)

-- ────────────────────────────────────────────────────────────────────────────
-- HELPERS
-- ────────────────────────────────────────────────────────────────────────────

local function clamp(v)
    return math.max(StatusConfig.min, math.min(StatusConfig.max, v))
end

local function set(stat, value)
    StatusClient.status[stat] = clamp(value)
end

local function add(stat, delta)
    set(stat, StatusClient.status[stat] + delta)
end

-- ────────────────────────────────────────────────────────────────────────────
-- RÉCEPTION DES STATUS INITIAUX
-- ────────────────────────────────────────────────────────────────────────────

RegisterNetEvent("union:status:init", function(serverStatus)
    if not serverStatus then return end

    StatusClient.status.hunger = clamp(serverStatus.hunger or 100)
    StatusClient.status.thirst = clamp(serverStatus.thirst or 100)
    StatusClient.status.stress = clamp(serverStatus.stress or 0)

    StatusClient.isActive = true

    StatusClient.logger:info(
        ("Status initialisés — hunger=%d thirst=%d stress=%d"):format(
            StatusClient.status.hunger,
            StatusClient.status.thirst,
            StatusClient.status.stress
        )
    )

    -- Notifier la HUD si elle existe
    TriggerEvent("union:status:ready", StatusClient.status)
end)

-- Mise à jour partielle depuis le serveur (ex: admin set stat)
RegisterNetEvent("union:status:update", function(stat, value)
    if StatusClient.status[stat] == nil then return end
    set(stat, value)
    TriggerEvent("union:status:changed", stat, StatusClient.status[stat])
end)

-- ────────────────────────────────────────────────────────────────────────────
-- THREAD PRINCIPAL — Diminution & effets
-- ────────────────────────────────────────────────────────────────────────────

CreateThread(function()
    -- Attendre l'initialisation
    while not StatusClient.isActive do Wait(1000) end

    StatusClient.logger:info("Thread principal démarré")

    while StatusClient.isActive do
        Wait(StatusConfig.tickInterval)

        local ped      = PlayerPedId()
        local isAlive  = not IsEntityDead(ped)
        if not isAlive then goto continue end

        -- ── 1. Diminution hunger ──────────────────────────────────────
        add("hunger", -StatusConfig.decay.hunger)

        -- ── 2. Diminution thirst ─────────────────────────────────────
        add("thirst", -StatusConfig.decay.thirst)

        -- ── 3. Récupération passive du stress ────────────────────────
        if StatusClient.status.stress > 0 then
            add("stress", -StatusConfig.stressDecay)
        end

        -- ── 4. Détection sprint → gain de stress ─────────────────────
        if IsPedSprinting(ped) then
            add("stress", StatusConfig.stressGain.sprinting)
        end

        -- ── 5. Effets si hunger ou thirst = 0 ────────────────────────
        if StatusConfig.effects.damageOnEmpty then
            if StatusClient.status.hunger <= 0 or StatusClient.status.thirst <= 0 then
                local current = GetEntityHealth(ped)
                if current > 100 then  -- 100 = seuil mort dans GTA
                    SetEntityHealth(ped, current - StatusConfig.effects.damageAmount)
                end
            end
        end

        -- ── 6. Effets visuels du stress ───────────────────────────────
        if StatusConfig.effects.stressVisual then
            StatusClient._applyStressEffects(ped)
        end

        -- ── 7. Notifier la HUD ────────────────────────────────────────
        TriggerEvent("union:status:tick", StatusClient.status)

        ::continue::
    end
end)

-- ────────────────────────────────────────────────────────────────────────────
-- THREAD SYNCHRONISATION → SERVEUR
-- Envoie les valeurs courantes pour sauvegarde BDD périodique
-- ────────────────────────────────────────────────────────────────────────────

CreateThread(function()
    while not StatusClient.isActive do Wait(1000) end

    while StatusClient.isActive do
        Wait(StatusConfig.syncInterval)

        if Client.currentCharacter then
            TriggerServerEvent("union:status:sync", StatusClient.status)
            StatusClient.logger:debug("Status synchronisés vers le serveur")
        end
    end
end)

-- ────────────────────────────────────────────────────────────────────────────
-- DÉTECTION DES ACTIONS → STRESS
-- ────────────────────────────────────────────────────────────────────────────

-- Tir d'arme
AddEventHandler("gameEventTriggered", function(name, args)
    if not StatusClient.isActive then return end

    if name == "CEventGunFired" or name == "CEventGunShotFired" then
        local now = GetGameTimer()
        -- Anti-spam : 1 gain de stress par seconde max
        if now - StatusClient.lastShot > 1000 then
            add("stress", StatusConfig.stressGain.shooting)
            StatusClient.lastShot = now
        end
    end
end)

-- Bagarre à mains nues (melee hit)
AddEventHandler("gameEventTriggered", function(name, args)
    if not StatusClient.isActive then return end

    if name == "CEventMeleeAction" or name == "CEventNetworkEntityDamage" then
        local ped = PlayerPedId()
        if IsPedPerformingMeleeAction(ped) then
            add("stress", StatusConfig.stressGain.fistFight / 10)  -- par frame, lissé
        end
    end
end)

-- ────────────────────────────────────────────────────────────────────────────
-- EFFETS VISUELS DU STRESS
-- ────────────────────────────────────────────────────────────────────────────

function StatusClient._applyStressEffects(ped)
    local stress = StatusClient.status.stress

    if stress >= StatusConfig.effects.stressMaxThreshold then
        -- Stress extrême : tremblement fort + flou + vignette rouge
        SetPedMotionBlur(ped, true)
        AnimpostfxPlay("DrugsMichaelAliensFight", 0, true)

    elseif stress >= StatusConfig.effects.stressHighThreshold then
        -- Stress élevé : léger tremblement
        SetPedMotionBlur(ped, false)
        AnimpostfxStop("DrugsMichaelAliensFight")

        -- Vignette rouge légère
        SetTimecycleModifier("damage")
        SetTimecycleModifierStrength(math.floor((stress - 75) / 25 * 0.5 * 100) / 100)
    else
        -- Pas de stress élevé : annuler les effets
        SetPedMotionBlur(ped, false)
        AnimpostfxStop("DrugsMichaelAliensFight")
        ClearTimecycleModifier()
    end
end

-- ────────────────────────────────────────────────────────────────────────────
-- STAMINA & OXYGEN (natives GTA V — non persistés en BDD)
-- ────────────────────────────────────────────────────────────────────────────

-- Thread dédié aux stats natives GTA
CreateThread(function()
    while true do
        Wait(0)  -- chaque frame

        if not StatusClient.isActive then goto nativeSkip end

        local ped = PlayerPedId()

        -- ── STAMINA ──────────────────────────────────────────────────
        -- La stamina est liée à la forme physique dans GTA (GetPedMaxHealthExtras)
        -- On peut contrôler via SetPlayerStamina
        local staminaModifier = 1.0

        -- La faim/soif diminue la stamina max
        if StatusClient.status.hunger < 30 then
            staminaModifier = staminaModifier - 0.3
        end
        if StatusClient.status.thirst < 20 then
            staminaModifier = staminaModifier - 0.4
        end

        SetPlayerStamina(PlayerId(), math.max(0.0, staminaModifier) * 100.0)

        -- ── OXYGEN ───────────────────────────────────────────────────
        -- GetPlayerRemainingAirTime / SetPlayerAirTime
        -- Si le joueur est sous l'eau depuis longtemps, gestion automatique GTA
        -- Optionnel : on peut lire et afficher la valeur
        -- local airTime = GetPlayerRemainingAirTime(PlayerId())

        ::nativeSkip::
    end
end)

-- ────────────────────────────────────────────────────────────────────────────
-- RÉINITIALISATION à la sélection d'un nouveau personnage
-- ────────────────────────────────────────────────────────────────────────────

AddEventHandler("union:client:ready", function()
    StatusClient.isActive = false
end)

-- ────────────────────────────────────────────────────────────────────────────
-- API PUBLIQUE (accessible via exports ou events locaux)
-- ────────────────────────────────────────────────────────────────────────────

--- Retourne les status courants
function StatusClient.getStatus()
    return StatusClient.status
end

--- Modifie un status localement (utilisé par d'autres scripts client)
function StatusClient.setStat(stat, value)
    if StatusClient.status[stat] == nil then return end
    set(stat, value)
    TriggerEvent("union:status:changed", stat, StatusClient.status[stat])
end

function StatusClient.addStat(stat, delta)
    StatusClient.setStat(stat, (StatusClient.status[stat] or 0) + delta)
end

exports("GetStatus",  StatusClient.getStatus)
exports("SetStat",    StatusClient.setStat)
exports("AddStat",    StatusClient.addStat)


-- CLIENT EVENTS REÇUS :
-- "union:status:init"     → { hunger, thirst, stress }  — au spawn
-- "union:status:update"   → stat (string), value (int)  — mise à jour partielle
 
-- CLIENT EVENTS LOCAUX ÉMIS :
-- "union:status:ready"    → { hunger, thirst, stress }  — HUD peut s'initialiser
-- "union:status:tick"     → { hunger, thirst, stress }  — chaque tick (5s)
-- "union:status:changed"  → stat, value                 — à chaque changement
 
-- SERVER EVENT REÇU :
-- "union:status:sync"     → { hunger, thirst, stress }  — depuis le client
-- ─── SERVEUR ───────────────────────────────────────────────
 
-- Nourrir un joueur (ex: consommer un aliment)
-- exports['union']:AddPlayerStat(source, "hunger", 30)
-- exports['union']:AddPlayerStat(source, "thirst", 20)
 
-- Stresser un joueur suite à une action serveur
-- exports['union']:AddPlayerStat(source, "stress", 15)
 
-- Lire le status complet
-- local status = exports['union']:GetPlayerStatus(source)
-- if status and status.hunger < 20 then
--    ServerUtils.notifyPlayer(source, "Vous mourez de faim !", "warning")
-- end
 
-- ─── CLIENT ────────────────────────────────────────────────
 
-- Dans un script client qui gère les aliments
--RegisterCommand("manger", function()
--    exports['union']:AddStat("hunger", 25)
--    exports['union']:AddStat("stress", -10)  -- manger réduit le stress
--      Synchroniser immédiatement vers le serveur
--    TriggerServerEvent("union:status:sync", exports['union']:GetStatus())
-- end, false)
 
-- Écouter les changements pour la HUD
-- AddEventHandler("union:status:tick", function(status)
--     Mettre à jour les barres de la HUD
--    SendNUIMessage({
--        action = "updateStatus",
--        hunger = status.hunger,
--        thirst = status.thirst,
--        stress = status.stress,
--    })
-- end)
 



return StatusClient