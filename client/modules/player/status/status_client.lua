-- client/modules/player/status/status_client.lua
-- FIXES:
--   #1 : Export "SetStat" implémenté
--   #2 : Les envois vers le serveur ne se font que si un personnage est actif
--   #3 : Suppression du RegisterNetEvent("union:status:sync") côté client
--        qui ne faisait rien (handler vide) mais pouvait intercepter l'event
--        avant les autres listeners
--   #4 : Guard sur updateAll pour éviter de setter des stats nil

StatusClient = {}
StatusClient.status   = { hunger = 100, thirst = 100, stress = 0 }
StatusClient.isActive = false

-- ─────────────────────────────────────────────
-- INIT / UPDATE
-- ─────────────────────────────────────────────

RegisterNetEvent("union:status:init", function(status)
    if not status then return end

    StatusClient.status = {
        hunger = status.hunger or 100,
        thirst = status.thirst or 100,
        stress = status.stress or 0
    }

    StatusClient.isActive = true

    LocalPlayer.state:set("hunger", StatusClient.status.hunger, false)
    LocalPlayer.state:set("thirst", StatusClient.status.thirst, false)
    LocalPlayer.state:set("stress", StatusClient.status.stress, false)

    TriggerEvent("union:status:ready", StatusClient.status)
end)

RegisterNetEvent("union:status:updateAll", function(status)
    if not status then return end

    -- FIX #4 : vérifier que les valeurs sont bien des nombres
    if status.hunger ~= nil then StatusClient.status.hunger = status.hunger end
    if status.thirst ~= nil then StatusClient.status.thirst = status.thirst end
    if status.stress ~= nil then StatusClient.status.stress = status.stress end

    LocalPlayer.state:set("hunger", StatusClient.status.hunger, false)
    LocalPlayer.state:set("thirst", StatusClient.status.thirst, false)
    LocalPlayer.state:set("stress", StatusClient.status.stress, false)

    TriggerEvent("union:status:tick", StatusClient.status)
    TriggerEvent("union:status:changed", nil, nil)
end)

RegisterNetEvent("union:status:update", function(stat, value)
    if not stat or StatusClient.status[stat] == nil then return end
    StatusClient.status[stat] = value

    LocalPlayer.state:set(stat, value, false)

    TriggerEvent("union:status:tick", StatusClient.status)
    TriggerEvent("union:status:changed", stat, value)
end)

-- ─────────────────────────────────────────────
-- DAMAGE FROM SERVER
-- ─────────────────────────────────────────────

RegisterNetEvent("union:status:applyDamage", function(amount)
    local ped = PlayerPedId()
    local hp  = GetEntityHealth(ped)

    if hp > 101 then
        SetEntityHealth(ped, hp - amount)
    end
end)

-- ─────────────────────────────────────────────
-- RESET AU DÉCHARGEMENT DU PERSONNAGE
-- ─────────────────────────────────────────────

AddEventHandler("union:character:unloaded", function()
    StatusClient.isActive = false
    StatusClient.status = { hunger = 100, thirst = 100, stress = 0 }
end)

-- ─────────────────────────────────────────────
-- EXPORTS
-- ─────────────────────────────────────────────

exports("GetStatus", function()
    return StatusClient.status
end)

-- FIX #1 : SetStat — fixe une stat à une valeur précise
exports("SetStat", function(stat, value)
    if not StatusClient.status[stat] then return end
    -- FIX #2 : vérifier qu'un personnage est actif
    if not Client.currentCharacter then return end

    StatusClient.status[stat] = math.max(0, math.min(100, math.floor(value + 0.5)))
    LocalPlayer.state:set(stat, StatusClient.status[stat], false)

    TriggerServerEvent("union:status:sync", StatusClient.status)
    TriggerEvent("union:status:changed", stat, StatusClient.status[stat])
end)

exports("AddStat", function(stat, value)
    if not StatusClient.status[stat] then return end
    -- FIX #2 : vérifier qu'un personnage est actif
    if not Client.currentCharacter then return end

    StatusClient.status[stat] = math.max(0, math.min(100,
        math.floor(StatusClient.status[stat] + (value or 0) + 0.5)
    ))
    LocalPlayer.state:set(stat, StatusClient.status[stat], false)

    TriggerServerEvent("union:status:sync", StatusClient.status)
    TriggerEvent("union:status:changed", stat, StatusClient.status[stat])
end)

-- Compatibilité ancienne API
exports("AddPlayerStat", function(stat, value)
    exports["union"]:AddStat(stat, value)
end)

-- FIX #3 : SUPPRIMÉ — RegisterNetEvent("union:status:sync") retiré
-- Ce handler était vide (commentaire "reçu du serveur après un sync")
-- et pouvait intercepter l'event avant d'autres listeners.
-- Le serveur n'envoie jamais "union:status:sync" au client de toute façon.

return StatusClient