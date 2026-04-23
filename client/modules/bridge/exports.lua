-- client/modules/bridge/exports.lua
-- Exporte les données du personnage actif pour que kt_target
-- et d'autres resources puissent les lire via exports('union').

-- Retourne le personnage actuellement actif (ou nil)
exports('GetCurrentCharacter', function()
    return Client.currentCharacter
end)

-- Retourne true si un personnage est actif et que le client est spawné
exports('IsSpawned', function()
    return Client.currentCharacter ~= nil and Client.isReady
end)

-- Notifie via lib.notify
exports('Notify', function(message, notifType, duration)
    Notifications.send(message, notifType, duration)
end)

-- Retourne le logger enfant
exports('GetLogger', function(tag)
    return Logger:child(tag or 'EXTERNAL')
end)

-- Retourne la config
exports('GetConfig', function()
    return Config
end)