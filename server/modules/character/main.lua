-- server/modules/character/main.lua
Character = {}
Character.logger = Logger:child("CHARACTER")

function Character.create(player, data, callback)
    if not player or not data then
        if callback then callback(false, nil, nil) end
        return
    end
    
    -- Validate data
    if not data.firstname or not data.lastname or not data.dateofbirth or not data.gender then
        Character.logger:warn("Invalid character data for " .. player.name)
        if callback then callback(false, nil, nil) end
        return
    end
    
    -- Clean data
    local firstname = Utils.safeString(data.firstname, 50)
    local lastname = Utils.safeString(data.lastname, 50)
    local dateofbirth = Utils.safeString(data.dateofbirth)
    local gender = data.gender:lower() == "f" and "f" or "m"
    local model = gender == "f" and Config.spawn.femaleModel or Config.spawn.defaultModel
    
    -- Generate unique ID
    local uniqueId = ServerUtils.generateUniqueId(12)
    
    Database.insert([[
        INSERT INTO characters
        (identifier, unique_id, firstname, lastname, dateofbirth, gender, model, position_x, position_y, position_z, heading)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        player.license,
        uniqueId,
        firstname,
        lastname,
        dateofbirth,
        gender,
        model,
        Config.spawn.defaultPosition.x,
        Config.spawn.defaultPosition.y,
        Config.spawn.defaultPosition.z,
        Config.spawn.defaultHeading
    }, function(characterId)
        if characterId then
            -- Create default appearance
            Database.insert(
                "INSERT INTO character_appearances (unique_id) VALUES (?)",
                {uniqueId},
                function(appearanceId)
                    if appearanceId then
                        Character.logger:info("Character created for " .. player.name .. ": " .. firstname .. " " .. lastname)
                        player:loadCharacters(function()
                            if callback then callback(true, characterId, uniqueId) end
                        end)
                    else
                        Character.logger:error("Failed to create appearance for character")
                        if callback then callback(false, characterId, uniqueId) end
                    end
                end
            )
        else
            Character.logger:error("Failed to create character for " .. player.name)
            if callback then callback(false, nil, nil) end
        end
    end)
end

function Character.select(player, characterId, callback)
    if not player or not characterId then
        if callback then callback(false, nil) end
        return
    end
    
    -- Find character
    local selected = nil
    for _, char in ipairs(player.characters) do
        if char.id == characterId then
            selected = char
            break
        end
    end
    
    if not selected then
        Character.logger:warn("Character not found for player " .. player.name .. ": " .. tostring(characterId))
        if callback then callback(false, nil) end
        return
    end
    
    player.currentCharacter = selected
    Character.logger:info("Character selected for " .. player.name .. ": " .. selected.firstname .. " " .. selected.lastname)
    
    -- Send character to client
    local charData = {
        id = selected.id,
        unique_id = selected.unique_id,
        firstname = selected.firstname,
        lastname = selected.lastname,
        gender = selected.gender,
        dateofbirth = selected.dateofbirth,
        model = selected.model,
        position = vector3(selected.position_x or Config.spawn.defaultPosition.x,
                          selected.position_y or Config.spawn.defaultPosition.y,
                          selected.position_z or Config.spawn.defaultPosition.z),
        heading = selected.heading or Config.spawn.defaultHeading,
        health = selected.health or Config.character.defaultHealth,
        armor = selected.armor or 0,
    }
    
    TriggerClientEvent("union:spawn:apply", player.source, charData)
    
    if callback then callback(true, selected) end
end

function Character.delete(player, characterId, callback)
    if not player or not characterId then
        if callback then callback(false) end
        return
    end
    
    Database.execute(
        "DELETE FROM characters WHERE id = ? AND identifier = ?",
        {characterId, player.license},
        function(result)
            if result then
                Character.logger:info("Character deleted for " .. player.name .. ": " .. characterId)
                player:loadCharacters(function()
                    if callback then callback(true) end
                end)
            else
                Character.logger:error("Failed to delete character for " .. player.name)
                if callback then callback(false) end
            end
        end
    )
end

-- Network events
RegisterNetEvent("union:character:create", function(data)
    local source = source
    local player = PlayerManager.get(source)
    
    if not player then
        Character.logger:warn("Character create requested by invalid player: " .. source)
        TriggerClientEvent("union:character:created", source, false)
        return
    end
    
    Character.create(player, data, function(success, id, uniqueId)
        TriggerClientEvent("union:character:created", source, success, id, uniqueId)
    end)
end)

RegisterNetEvent("union:character:list", function()
    local source = source
    local player = PlayerManager.get(source)
    
    if not player then return end
    
    TriggerClientEvent("union:character:listReceived", source, player.characters)
end)

RegisterNetEvent("union:character:select", function(characterId)
    local source = source
    local player = PlayerManager.get(source)
    
    if not player then return end
    
    Character.select(player, characterId, function(success, character)
        TriggerClientEvent("union:character:selected", source, success, character)
    end)
end)

RegisterNetEvent("union:character:delete", function(characterId)
    local source = source
    local player = PlayerManager.get(source)
    
    if not player or not player:hasPermission("character.delete") then
        TriggerClientEvent("union:character:deleted", source, false)
        return
    end
    
    Character.delete(player, characterId, function(success)
        TriggerClientEvent("union:character:deleted", source, success)
    end)
end)

return Character