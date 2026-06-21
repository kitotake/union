-- server/modules/vehicle/manager/main.lua
Vehicle        = {}
Vehicle.logger = Logger:child("VEHICLE")
Vehicle.owned  = {}

local function generateUniquePlate(callback)
    local function tryGenerate(attempts)
        if attempts > 10 then
            local fallback = "U" .. tostring(os.time()):sub(-5) .. tostring(math.random(10, 99))
            callback(fallback); return
        end
        local plate = "UNI" .. math.random(100, 999) .. math.random(10, 99)
        Database.scalar("SELECT COUNT(*) FROM owned_vehicles WHERE plate = ?", { plate }, function(count)
            if not count or count == 0 then callback(plate)
            else
                Vehicle.logger:warn(("Plaque %s déjà utilisée, tentative %d/10"):format(plate, attempts))
                tryGenerate(attempts + 1)
            end
        end)
    end
    tryGenerate(1)
end

function Vehicle.giveToPlayer(player, model, props, callback)
    if not player or not model then if callback then callback(false) end; return end
    if not player.currentCharacter then
        Vehicle.logger:warn("giveToPlayer: aucun personnage actif pour " .. player.name)
        if callback then callback(false) end; return
    end
    generateUniquePlate(function(plate)
        Database.insert([[
            INSERT INTO owned_vehicles (plate, unique_id, vehicle_model, vehicle_props) VALUES (?, ?, ?, ?)
        ]], { plate, player.currentCharacter.unique_id, model, json.encode(props or {}) }, function(result)
            if result then
                Vehicle.logger:info("Véhicule donné à " .. player.name .. " : " .. plate)
                player:notify("Véhicule donné : " .. plate, "success")
                if callback then callback(true) end
            else
                Vehicle.logger:error("Échec INSERT owned_vehicles pour " .. player.name)
                if callback then callback(false) end
            end
        end)
    end)
end

function Vehicle.getPlayerVehicles(uniqueId, callback)
    Database.fetch("SELECT * FROM owned_vehicles WHERE unique_id = ?", { uniqueId }, callback)
end

function Vehicle.remove(plate, callback)
    Database.execute("DELETE FROM owned_vehicles WHERE plate = ?", { plate }, callback)
end

RegisterNetEvent("union:vehicle:give", function(model)
    local src    = source
    local player = PlayerManager.get(src)
    if not player then return end
    Vehicle.giveToPlayer(player, model, {}, function(success)
        TriggerClientEvent("union:vehicle:given", src, success)
    end)
end)

RegisterNetEvent("union:vehicle:list", function()
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    Vehicle.getPlayerVehicles(player.currentCharacter.unique_id, function(vehicles)
        TriggerClientEvent("union:vehicle:listReceived", src, vehicles or {})
    end)
end)

RegisterNetEvent("union:vehicle:spawn", function(plate)
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    Database.fetchOne("SELECT * FROM owned_vehicles WHERE plate = ? AND unique_id = ?",
        { plate, player.currentCharacter.unique_id }, function(vehicle)
            if not vehicle then TriggerClientEvent("union:vehicle:spawnResult", src, false, plate); return end
            Database.execute("UPDATE owned_vehicles SET stored = 0 WHERE plate = ?", { plate }, function()
                TriggerClientEvent("union:vehicle:spawnResult", src, true, plate)
            end)
        end)
end)

RegisterNetEvent("union:vehicle:store", function(plate)
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    Database.fetchOne("SELECT * FROM owned_vehicles WHERE plate = ? AND unique_id = ?",
        { plate, player.currentCharacter.unique_id }, function(vehicle)
            if not vehicle then TriggerClientEvent("union:vehicle:storeResult", src, false, plate); return end
            Database.execute("UPDATE owned_vehicles SET stored = 1 WHERE plate = ?", { plate }, function()
                TriggerClientEvent("union:vehicle:storeResult", src, true, plate)
            end)
        end)
end)

return Vehicle
