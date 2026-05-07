-- client/modules/character/characterManager.lua
-- FIX #1 : suppression de TriggerClientEvent(-1) depuis le client (invalide).
-- FIX #2 : characters:playerReady est toujours envoyé au démarrage ;
--           le serveur a maintenant un handler no-op pour l'absorber proprement.
-- FIX #3 : doSpawn ne déclenche plus de spawn supplémentaire (déjà géré par union:spawn:apply).
-- FIX #4 : closeSelectionUI appelé une seule fois, guard nuiOpen fiable.

local nuiOpen = false

local function closeSelectionUI()
    if not nuiOpen then return end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
    nuiOpen = false
end

-- EVENT : auto-spawn (1 seul personnage)
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
    if nuiOpen then
        Logger:warn("[charManager] NUI déjà ouverte, openSelection ignoré")
        return
    end

    local chars = data and data.characters or {}
    Logger:info(("[charManager] Ouverture sélection NUI (%d personnages)"):format(#chars))

    SetNuiFocus(true, true)
    SendNUIMessage({
        action     = "openCharacterSelection",
        slots      = data and data.slots or 1,
        characters = chars,
    })
    nuiOpen = true
end)

-- EVENT : ouvre la NUI de création (aucun personnage)
RegisterNetEvent("characters:openCreation", function(data)
    Logger:info(("[charManager] Création demandée (slots=%d)"):format(data and data.slots or 1))
    -- La création est gérée par kt_character via le net event kt_character:openCreator
end)

-- EVENT : spawn après sélection validée côté serveur
-- FIX #3 : doSpawn sert UNIQUEMENT à fermer la NUI. Le spawn est géré par union:spawn:apply.
RegisterNetEvent("characters:doSpawn", function(charData)
    if not charData then
        Logger:error("[charManager] doSpawn : charData nil")
        return
    end

    Logger:info(("[charManager] doSpawn reçu pour %s %s — fermeture NUI"):format(
        charData.firstname or "?",
        charData.lastname  or "?"
    ))

    closeSelectionUI()
    -- NE PAS re-déclencher union:spawn:apply ici
end)

-- EVENT : message d'erreur depuis le serveur
RegisterNetEvent("characters:error", function(msg)
    Logger:error("[charManager] Erreur : " .. tostring(msg))
    if nuiOpen then
        SendNUIMessage({ action = "showError", message = msg })
    end
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

-- FIX #2 : au démarrage, on signale que le client est prêt.
-- Le serveur a un handler no-op pour characters:playerReady.
-- Le vrai routing de spawn passe par union:spawn:requestInitial.
AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(2000)
    Logger:info("[charManager] Client prêt, envoi characters:playerReady")
    TriggerServerEvent("characters:playerReady")
    -- Relancer le flow complet comme au premier chargement
    TriggerServerEvent("union:player:joined")
end)
