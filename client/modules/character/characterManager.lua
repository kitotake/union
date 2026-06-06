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
        print("NUI already open, ignoring openSelection") -- Debug
        return
    end
    local chars = data and data.characters or {}
    Logger:info(("[charManager] Ouverture sélection NUI (%d personnages)"):format(#chars))
    
    print("Opening character selection NUI with " .. tostring(#chars) .. " characters") -- Debug

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
    print("Character creation requested with slots: " .. tostring(data and data.slots or 1)) -- Debug
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
print ("Character manager received error: " .. tostring(msg)) -- Debug

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

    print("NUI requested to close character selection without selection") -- Debug
print("Ignoring close request to enforce character selection") -- Debug
print("Character selection close request received, but selection is required") -- Debug
print("Close request ignored, character selection required")
print("NUI closeCharacterSelection callback executed, but character selection is mandatory") -- Debug
print("Character selection close callback executed without selection, ignoring") -- Debug




end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(2000)

    Logger:info("[charManager] Restart resource détecté — reset état client")
    Client.isReady          = false
    Client.currentCharacter = nil
    nuiOpen                 = false
    SetNuiFocus(false, false)

    -- FIX ENSURE: reset de la position mémorisée pour éviter d'utiliser une ancienne position
    if Position then
        print("Reset de la position mémorisée à cause du restart resource") -- Debug
        Position.setLast(nil, nil)
    end
print("Character manager reset completed, waiting for player to spawn...") -- Debug
    Logger:info("[charManager] Reset terminé — handler.lua prend le relais")
end)