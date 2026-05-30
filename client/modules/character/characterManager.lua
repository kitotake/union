-- client/modules/character/characterManager.lua
local nuiOpen = false

local function closeSelectionUI()
    if not nuiOpen then return end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
    nuiOpen = false
end

RegisterNetEvent("characters:autoSpawn", function(charData)
    if not charData then
        Logger:error("[charManager] autoSpawn : charData nil")
        return
    end
    Logger:info(("[charManager] Auto-spawn pour %s %s"):format(
        charData.firstname or "?", charData.lastname or "?"
    ))
    closeSelectionUI()
end)

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

RegisterNetEvent("characters:openCreation", function(data)
    Logger:info(("[charManager] Création demandée (slots=%d)"):format(data and data.slots or 1))
end)

RegisterNetEvent("characters:doSpawn", function(charData)
    if not charData then
        Logger:error("[charManager] doSpawn : charData nil")
        return
    end
    Logger:info(("[charManager] doSpawn reçu pour %s %s — fermeture NUI"):format(
        charData.firstname or "?", charData.lastname or "?"
    ))
    closeSelectionUI()
end)

RegisterNetEvent("characters:error", function(msg)
    Logger:error("[charManager] Erreur : " .. tostring(msg))
    if nuiOpen then
        SendNUIMessage({ action = "showError", message = msg })
    end
    Notifications.send(msg, "error")
end)

RegisterNUICallback("selectCharacter", function(data, cb)
    if not data or not data.charId then
        cb({ ok = false, reason = "ID de personnage manquant" })
        return
    end
    Logger:info("[charManager] NUI selectCharacter charId=" .. tostring(data.charId))
    TriggerServerEvent("characters:selectCharacter", data.charId)
    cb({ ok = true })
end)

RegisterNUICallback("closeCharacterSelection", function(_, cb)
    cb({ ok = false, reason = "Vous devez sélectionner un personnage." })
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(2000)
    Logger:info("[charManager] Restart resource détecté — reset état client")
    Client.isReady          = false
    Client.currentCharacter = nil
    nuiOpen                 = false
    SetNuiFocus(false, false)
    Logger:info("[charManager] Reset terminé — handler.lua prend le relais")
end)
