-- client/modules/vehicle/main.lua
Vehicle = {}
Vehicle.logger = Logger:child("VEHICLE")
Vehicle.owned = {}
Vehicle.currentVehicle = nil

function Vehicle.list()
    Vehicle.logger:info("Requesting vehicle list")
    TriggerServerEvent("union:vehicle:list")
end

function Vehicle.spawn(plate)
    if not plate then return end
    Vehicle.logger:info("Spawning vehicle: " .. plate)
    TriggerServerEvent("union:vehicle:spawn", plate)
end

function Vehicle.store(plate)
    if not plate then return end
    Vehicle.logger:info("Storing vehicle: " .. plate)
    TriggerServerEvent("union:vehicle:store", plate)
end

RegisterNetEvent("union:vehicle:given", function(success)
    if success then
        Notifications.send("Vehicle given successfully", "success")
        Vehicle.list()
    else
        Notifications.send("Failed to give vehicle", "error")
    end
end)

return Vehicle
