-- client/modules/bridge/manager/exports.lua
exports('GetCurrentCharacter', function()
    return Client.currentCharacter
end)

exports('IsSpawned', function()
    return Client.currentCharacter ~= nil and Client.isReady
end)

exports('Notify', function(message, notifType, duration)
    Notifications.send(message, notifType, duration)
end)

exports('GetLogger', function(tag)
    return Logger:child(tag or 'EXTERNAL')
end)

exports('GetConfig', function()
    return Config
end)
