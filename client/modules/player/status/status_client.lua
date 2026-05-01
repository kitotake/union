-- client/modules/player/status/status_client.lua
-- VERSION PRODUCTION : client = affichage + détection d'actions uniquement
-- Toute la logique gameplay est serveur-authoritative

StatusClient        = {}
StatusClient.logger = Logger:child("STATUS:CLIENT")

-- ────────────────────────────────────────────────────────────────────────────
-- État local (reçu du serveur uniquement, jamais calculé ici)
-- ────────────────────────────────────────────────────────────────────────────

StatusClient.status = {
    hunger = 100,
    thirst = 100,
    stress = 0,
}

StatusClient.isActive = false

-- ────────────────────────────────────────────────────────────────────────────
-- Cooldowns anti-spam pour les actions envoyées au serveur
-- ────────────────────────────────────────────────────────────────────────────

local actionCooldowns = {
    shoot    = 0,
    sprint   = 0,
    fistfight = 0,
}

local COOLDOWN_MS = {
    shoot     = 800,
    sprint    = 3000,
    fistfight = 1500,
}

local function canSendAction(action)
    local now = GetGameTimer()
    if now - (actionCooldowns[action] or 0) >= (COOLDOWN_MS[action] or 1000) then
        actionCooldowns[action] = now
        return true
    end
    return false
end

-- ────────────────────────────────────────────────────────────────────────────
-- RÉCEPTION DES STATUS DEPUIS LE SERVEUR
-- ────────────────────────────────────────────────────────────────────────────

-- Initialisation complète au spawn
RegisterNetEvent("union:status:init", function(serverStatus)
    if not serverStatus then return end

    StatusClient.status.hunger = serverStatus.hunger or 100
    StatusClient.status.thirst = serverStatus.thirst or 100
    StatusClient.status.stress = serverStatus.stress or 0

    StatusClient.isActive = true

    StatusClient.logger:info(
        ("Status reçus du serveur — hunger=%d thirst=%d stress=%d"):format(
            StatusClient.status.hunger,
            StatusClient.status.thirst,
            StatusClient.status.stress
        )
    )

    TriggerEvent("union:status:ready", StatusClient.status)
end)

-- Mise à jour d'une stat unique (ex: after eating, admin set)
RegisterNetEvent("union:status:update", function(stat, value)
    if StatusClient.status[stat] == nil then return end
    StatusClient.status[stat] = value
    TriggerEvent("union:status:changed", stat, value)
end)

-- Mise à jour complète depuis le tick serveur
RegisterNetEvent("union:status:updateAll", function(serverStatus)
    if not serverStatus or not StatusClient.isActive then return end

    StatusClient.status.hunger = serverStatus.hunger or StatusClient.status.hunger
    StatusClient.status.thirst = serverStatus.thirst or StatusClient.status.thirst
    StatusClient.status.stress = serverStatus.stress or StatusClient.status.stress

    TriggerEvent("union:status:tick", StatusClient.status)
end)

-- ────────────────────────────────────────────────────────────────────────────
-- DÉTECTION D'ACTIONS → envoi sécurisé au serveur
-- Le serveur applique l'effet, pas le client
-- ────────────────────────────────────────────────────────────────────────────

-- Tir d'arme
AddEventHandler("gameEventTriggered", function(name, _args)
    if not StatusClient.isActive then return end

    if name == "CEventGunFired" or name == "CEventGunShotFired" then
        if canSendAction("shoot") then
            TriggerServerEvent("union:status:action", "shoot")
        end
    end
end)

-- Bagarre
AddEventHandler("gameEventTriggered", function(name, _args)
    if not StatusClient.isActive then return end

    if name == "CEventMeleeAction" then
        if canSendAction("fistfight") then
            TriggerServerEvent("union:status:action", "fistfight")
        end
    end
end)

-- Sprint — détection périodique légère
CreateThread(function()
    while true do
        Wait(2000) -- vérification toutes les 2s, pas toutes les frames

        if StatusClient.isActive and Client.currentCharacter then
            local ped = PlayerPedId()
            if IsPedSprinting(ped) and canSendAction("sprint") then
                TriggerServerEvent("union:status:action", "sprint")
            end
        end
    end
end)

-- ────────────────────────────────────────────────────────────────────────────
-- EFFETS VISUELS DU STRESS (côté client uniquement, pas de gameplay)
-- ────────────────────────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(1000)

        if not StatusClient.isActive then goto visualSkip end
        if not StatusConfig.effects.stressVisual then goto visualSkip end

        StatusClient._applyStressEffects(PlayerPedId())

        ::visualSkip::
    end
end)

function StatusClient._applyStressEffects(ped)
    local stress = StatusClient.status.stress

    if stress >= StatusConfig.effects.stressMaxThreshold then
        SetPedMotionBlur(ped, true)
        AnimpostfxPlay("DrugsMichaelAliensFight", 0, true)
        SetTimecycleModifier("damage")
        SetTimecycleModifierStrength(0.8)

    elseif stress >= StatusConfig.effects.stressHighThreshold then
        SetPedMotionBlur(ped, false)
        AnimpostfxStop("DrugsMichaelAliensFight")
        SetTimecycleModifier("damage")
        SetTimecycleModifierStrength((stress - 75) / 25 * 0.4)

    else
        SetPedMotionBlur(ped, false)
        AnimpostfxStop("DrugsMichaelAliensFight")
        ClearTimecycleModifier()
    end
end

-- ────────────────────────────────────────────────────────────────────────────
-- STAMINA native GTA — liée aux stats reçues, pas calculée localement
-- Intervalle raisonnable (500ms) au lieu de Wait(0)
-- ────────────────────────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(500)

        if not StatusClient.isActive then goto staminaSkip end

        local modifier = 1.0

        if StatusClient.status.hunger < 30 then modifier = modifier - 0.3 end
        if StatusClient.status.thirst < 20 then modifier = modifier - 0.4 end

        SetPlayerStamina(PlayerId(), math.max(0.0, modifier) * 100.0)

        ::staminaSkip::
    end
end)

-- ────────────────────────────────────────────────────────────────────────────
-- RÉINITIALISATION
-- ────────────────────────────────────────────────────────────────────────────

AddEventHandler("union:character:unloaded", function()
    StatusClient.isActive = false
    StatusClient.status   = { hunger = 100, thirst = 100, stress = 0 }
    ClearTimecycleModifier()
    AnimpostfxStop("DrugsMichaelAliensFight")
end)

AddEventHandler("union:client:ready", function()
    StatusClient.isActive = false
end)

-- ────────────────────────────────────────────────────────────────────────────
-- API PUBLIQUE (exports déclarés dans fxmanifest)
-- ────────────────────────────────────────────────────────────────────────────

function StatusClient.getStatus()
    return StatusClient.status
end

-- Ces deux fonctions sont des raccourcis locaux.
-- Pour modifier les stats pour de vrai, passer par le serveur.
function StatusClient.setStat(stat, value)
    if StatusClient.status[stat] == nil then return end
    StatusClient.status[stat] = math.max(StatusConfig.min, math.min(StatusConfig.max, value))
    TriggerEvent("union:status:changed", stat, StatusClient.status[stat])
end

function StatusClient.addStat(stat, delta)
    StatusClient.setStat(stat, (StatusClient.status[stat] or 0) + delta)
end

exports("GetStatus", StatusClient.getStatus)
exports("SetStat",   StatusClient.setStat)
exports("AddStat",   StatusClient.addStat)

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