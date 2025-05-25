RegisterCommand("respawn", function(src, args)
    if src == 0 then
        local target = tonumber(args[1])
        if target and GetPlayerName(target) then
            TriggerClientEvent("spawn:respawn", target)
            print("^3[SpawnSystem] Respawn forcé pour " .. GetPlayerName(target))
        end
    else
        TriggerClientEvent("spawn:respawn", src)
    end
end, false)
