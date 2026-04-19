-- server/modules/spawn/position.lua
SpawnPosition = {}
SpawnPosition.logger = Logger:child("SPAWN:POSITION")

function SpawnPosition.save(player, position, heading)
    if not player or not player.currentCharacter or not position then
        SpawnPosition.logger:warn("Cannot save position: invalid parameters")
        return false
    end
    
    Database.execute([[
        UPDATE characters SET
        position_x = ?, position_y = ?, position_z = ?, heading = ?
        WHERE unique_id = ?
    ]], {
        position.x, position.y, position.z, heading or 0.0,
        player.currentCharacter.unique_id
    }, function(result)
        if result then
            SpawnPosition.logger:debug("Position saved for " .. player.name)
        else
            SpawnPosition.logger:error("Failed to save position for " .. player.name)
        end
    end)
    
    return true
end

function SpawnPosition.load(uniqueId, callback)
    Database.fetchOne(
        "SELECT position_x, position_y, position_z, heading FROM characters WHERE unique_id = ?",
        {uniqueId},
        function(result)
            if result then
                local position = vector3(result.position_x, result.position_y, result.position_z)
                local heading = result.heading or Config.spawn.defaultHeading
                if callback then callback(position, heading) end
            else
                if callback then callback(Config.spawn.defaultPosition, Config.spawn.defaultHeading) end
            end
        end
    )
end

function SpawnPosition.isValid(position)
    if not position then return false end
    if position.x == 0 and position.y == 0 and position.z == 0 then return false end
    return true
end

RegisterNetEvent("union:position:save", function(position, heading)
    local source = source
    local player = PlayerManager.get(source)
    
    if player and position then
        SpawnPosition.save(player, position, heading)
        -- Send back to client
        TriggerClientEvent("union:position:loaded", source, position, heading)
    end
end)

return SpawnPosition