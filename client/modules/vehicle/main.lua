-- client/modules/vehicle/main.lua
Vehicle = {}
Vehicle.logger = Logger:child("VEHICLE")
Vehicle.owned = {}
Vehicle.currentVehicle = nil

function Vehicle.list()
    Vehicle.logger:info("Requesting vehicle list")
    TriggerServerEvent("union:vehicle:list")
end

function Vehicle.spawn(plate, x, y, z, heading)
    if not plate then return end
    
    Vehicle.logger:info("Spawning vehicle: " .. plate)
    
    local data = {
        plate = plate,
        position = vector3(x, y, z),
        heading = heading or 0.0
    }
    
    TriggerServerEvent("union:vehicle:spawn", data)
end

RegisterNetEvent("union:vehicle:listReceived", function(vehicles)
    Vehicle.owned = vehicles
    Vehicle.logger:info("Received " .. #vehicles .. " vehicles")
    
    print("^2[VEHICLES] Your vehicles:")
    for _, v in ipairs(vehicles) do
        print(string.format("  ^3%s^7 - Model: %s (Health: %.0f)",
            v.plate, v.vehicle_model, v.engine_health))
    end
end)

RegisterNetEvent("union:vehicle:given", function(success)
    if success then
        Notifications.send("Vehicle given successfully", "success")
        Vehicle.list()
    else
        Notifications.send("Failed to give vehicle", "error")
    end
end)

return Vehicle