-- client/modules/character/characterManager.lua
-- FIX #1 : suppression de TriggerClientEvent(-1) depuis le client (invalide dans FiveM)
-- FIX : seule la NUI est gérée ici — le spawn est délégué à spawn/main.lua via union:spawn:apply

local nuiOpen = false

local function closeSelectionUI()
    if not nuiOpen then return end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
    nuiOpen = false
end

-- EVENT : auto-spawn (1 seul personnage)
-- FIX #1 : suppression des TriggerEvent/TriggerClientEvent redondants et invalides
-- Le serveur déclenche directement union:spawn:apply via Character.select
RegisterNetEvent("characters:autoSpawn", function(charData)
    if not charData then
        Logger:error("[charManager] autoSpawn : charData nil")
        return
    end

    Logger:info(("[charManager] Auto-spawn pour %s %s"):format(
        charData.firstname or "?",
        charData.lastname  or "?"
    ))

    closeSelectionUI()
    -- union:spawn:apply est déclenché par le serveur (Character.select)
    -- Ne pas le déclencher ici pour éviter le double spawn
end)

-- EVENT : ouvre la NUI de sélection (plusieurs personnages)
RegisterNetEvent("characters:openSelection", function(data)
    if nuiOpen then return end

    Logger:info(("[charManager] Ouverture sélection NUI (%d personnages)"):format(
        data.characters and #data.characters or 0
    ))

    SetNuiFocus(true, true)
    SendNUIMessage({
        action     = "openCharacterSelection",
        slots      = data.slots,
        characters = data.characters,
    })
    nuiOpen = true
end)

-- EVENT : ouvre la NUI de création (aucun personnage)
RegisterNetEvent("characters:openCreation", function(data)
    Logger:info(("[charManager] Création demandée (slots=%d)"):format(data.slots or 1))
end)

-- EVENT : spawn après sélection validée côté serveur
-- FIX #1 : suppression du double TriggerEvent/TriggerClientEvent
-- spawn/main.lua reçoit union:spawn:apply directement du serveur
RegisterNetEvent("characters:doSpawn", function(charData)
    if not charData then
        Logger:error("[charManager] doSpawn : charData nil")
        return
    end

    Logger:info(("[charManager] doSpawn reçu pour %s %s"):format(
        charData.firstname or "?",
        charData.lastname  or "?"
    ))

    closeSelectionUI()
    -- Le serveur a déjà envoyé union:spawn:apply au client via Character.select
    -- Ne pas re-déclencher ici
end)

-- EVENT : message d'erreur depuis le serveur
RegisterNetEvent("characters:error", function(msg)
    Logger:error("[charManager] Erreur : " .. tostring(msg))
    SendNUIMessage({ action = "showError", message = msg })
    Notifications.send(msg, "error")
end)

-- NUI CALLBACK : le joueur clique "Jouer" dans la sélection
RegisterNUICallback("selectCharacter", function(data, cb)
    if not data or not data.charId then
        cb({ ok = false, reason = "ID de personnage manquant" })
        return
    end

    Logger:info("[charManager] NUI selectCharacter charId=" .. tostring(data.charId))
    TriggerServerEvent("characters:selectCharacter", data.charId)
    cb({ ok = true })
end)

-- NUI CALLBACK : le joueur tente de fermer sans avoir sélectionné
RegisterNUICallback("closeCharacterSelection", function(_, cb)
    cb({ ok = false, reason = "Vous devez sélectionner un personnage." })
end)

-- Initialisation : signale au serveur que le client est prêt
AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(2000)
    Logger:info("[charManager] Client prêt, envoi characters:playerReady")
    TriggerServerEvent("characters:playerReady")
end)