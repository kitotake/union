-- ============================================================
--  client/modules/character/characterManager.lua
--  CORRIGÉ : ne gère QUE la logique NUI de sélection/création
--  Le spawn réel est délégué à client/modules/spawn/main.lua
--  (union:spawn:apply) pour éviter les doublons
-- ============================================================

local nuiOpen = false

-- ────────────────────────────────────────────────────────────────────────────
-- Ferme proprement la NUI de sélection
-- ────────────────────────────────────────────────────────────────────────────
local function closeSelectionUI()
    if not nuiOpen then return end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
    nuiOpen = false
end

-- ────────────────────────────────────────────────────────────────────────────
-- EVENT : auto-spawn (1 seul personnage)
-- Le serveur nous envoie directement le charData complet ;
-- on le transmet à union:spawn:apply (géré dans spawn/main.lua)
-- ────────────────────────────────────────────────────────────────────────────
RegisterNetEvent("characters:autoSpawn", function(charData)
    if not charData then
        Logger:error("[charManager] autoSpawn : charData nil")
        return
    end

    Logger:info(("[charManager] Auto-spawn pour %s %s"):format(
        charData.firstname or "?",
        charData.lastname  or "?"
    ))

    -- S'assure que la NUI est fermée
    closeSelectionUI()

    -- Déclenche le système de spawn unifié (spawn/main.lua)
    -- On passe par l'event pour respecter l'architecture existante
    TriggerEvent("union:spawn:apply", charData)
    TriggerClientEvent("union:spawn:apply", -1, charData)  -- ne sert qu'à soi-même
    -- En réalité c'est un NetEvent reçu depuis le serveur
    -- donc on laisse spawn/main.lua l'écouter ; ici on ne respawn pas
end)

-- ────────────────────────────────────────────────────────────────────────────
-- EVENT : ouvre la NUI de sélection (plusieurs personnages)
-- ────────────────────────────────────────────────────────────────────────────
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

-- ────────────────────────────────────────────────────────────────────────────
-- EVENT : ouvre la NUI de création (aucun personnage)
-- ────────────────────────────────────────────────────────────────────────────
RegisterNetEvent("characters:openCreation", function(data)
    -- kt_character gère déjà la création via kt_character:openCreator
    -- On stocke juste le slots pour info
    Logger:info(("[charManager] Création demandée (slots=%d)"):format(data.slots or 1))
    -- La NUI de création est ouverte par client/main.lua (kt_character)
end)

-- ────────────────────────────────────────────────────────────────────────────
-- EVENT : spawn après sélection validée côté serveur
-- Le serveur nous renvoie le charData final via characters:doSpawn
-- On ferme la NUI et on laisse union:spawn:apply faire le travail
-- ────────────────────────────────────────────────────────────────────────────
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

    -- union:spawn:apply est géré dans spawn/main.lua
    -- Il sera déclenché automatiquement par le serveur via Character.select
end)

-- ────────────────────────────────────────────────────────────────────────────
-- EVENT : message d'erreur depuis le serveur
-- ────────────────────────────────────────────────────────────────────────────
RegisterNetEvent("characters:error", function(msg)
    Logger:error("[charManager] Erreur : " .. tostring(msg))
    SendNUIMessage({ action = "showError", message = msg })
    Notifications.send(msg, "error")
end)

-- ────────────────────────────────────────────────────────────────────────────
-- NUI CALLBACK : le joueur clique "Jouer" dans la sélection
-- ────────────────────────────────────────────────────────────────────────────
RegisterNUICallback("selectCharacter", function(data, cb)
    if not data or not data.charId then
        cb({ ok = false, reason = "ID de personnage manquant" })
        return
    end

    Logger:info("[charManager] NUI selectCharacter charId=" .. tostring(data.charId))
    TriggerServerEvent("characters:selectCharacter", data.charId)
    cb({ ok = true })
end)

-- ────────────────────────────────────────────────────────────────────────────
-- NUI CALLBACK : le joueur tente de fermer sans avoir sélectionné
-- ────────────────────────────────────────────────────────────────────────────
RegisterNUICallback("closeCharacterSelection", function(_, cb)
    -- On ne permet pas de fermer sans choisir
    cb({ ok = false, reason = "Vous devez sélectionner un personnage." })
end)

-- ────────────────────────────────────────────────────────────────────────────
-- Initialisation : signale au serveur que le client est prêt
-- ────────────────────────────────────────────────────────────────────────────
AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- Attend que le client soit pleinement chargé
    Wait(2000)
    Logger:info("[charManager] Client prêt, envoi characters:playerReady")
    TriggerServerEvent("characters:playerReady")
end)