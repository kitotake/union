-- client/modules/vehicle/commands.lua

RegisterCommand("myvehicles", function()
    Vehicle.list()
end, false)

RegisterCommand("spawncar", function(source, args)
    if not args[1] or not args[2] or not args[3] or not args[4] then
        Notifications.send("Usage: /spawncar [plate] [x] [y] [z] [heading]", "error")
        return
    end
    
    local plate = args[1]
    local x, y, z = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
    local heading = tonumber(args[5]) or 0
    
    if not x or not y or not z then
        Notifications.send("Invalid coordinates", "error")
        return
    end
    
    Vehicle.spawn(plate, x, y, z, heading)
end, false)