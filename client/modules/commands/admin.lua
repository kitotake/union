-- client/modules/commands/admin.lua

RegisterCommand("respawn", function(source, args)
    Spawn.respawn()
    Logger:info("Respawn requested")
end, false)

RegisterCommand("heal", function(source, args)
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        SetEntityHealth(ped, 200)
        TriggerServerEvent("union:player:healed")
        Notifications.send("Player healed", "success")
    end
end, false)

RegisterCommand("revive", function(source, args)
    Spawn.respawn()
end, false)