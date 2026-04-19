-- server/modules/vehicle/database.lua
VehicleDB = {}
VehicleDB.logger = Logger:child("VEHICLE:DATABASE")

function VehicleDB.getVehicle(plate, callback)
    Database.fetchOne(
        "SELECT * FROM owned_vehicles WHERE plate = ?",
        {plate},
        callback
    )
end

function VehicleDB.updateHealth(plate, engineHealth, bodyHealth)
    Database.execute(
        "UPDATE owned_vehicles SET engine_health = ?, body_health = ? WHERE plate = ?",
        {engineHealth, bodyHealth, plate},
        function() end
    )
end

function VehicleDB.updateFuel(plate, fuel)
    Database.execute(
        "UPDATE owned_vehicles SET fuel = ? WHERE plate = ?",
        {fuel, plate},
        function() end
    )
end

return VehicleDB