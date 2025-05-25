-- 📁 server/main.lua


-- Événements supplémentaires
AddEventHandler("playerDropped", function(reason)
    local src = source
    print("^3[SpawnSystem] Déconnexion de " .. GetPlayerName(src) .. " - sauvegarde en attente")
end)

AddEventHandler("onResourceStart", function(resName)
    if GetCurrentResourceName() == resName then
        local config = exports.union:GetConfig()
        print("^2[SpawnSystem] Initialisé. Modèle temporaire: " .. config.temporaryModel)
        print("^2[SpawnSystem] Modèle par défaut: " .. config.defaultModel)
    end
end)
