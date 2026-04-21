-- server/modules/character/main.lua
Character = {}
Character.logger = Logger:child("CHARACTER")

function Character.create(player, data, callback)
    if not player or not data then
        if callback then callback(false, nil, nil) end
        return
    end
    if not data.firstname or not data.lastname or not data.dateofbirth or not data.gender then
        Character.logger:warn("Invalid character data for " .. player.name)
        if callback then callback(false, nil, nil) end
        return
    end

    local firstname   = Utils.safeString(data.firstname, 50)
    local lastname    = Utils.safeString(data.lastname, 50)
    local dateofbirth = Utils.safeString(data.dateofbirth)
    local gender      = data.gender:lower() == "f" and "f" or "m"
    local model       = gender == "f" and Config.spawn.femaleModel or Config.spawn.defaultModel
    local uniqueId    = ServerUtils.generateUniqueId(12)

    Database.insert([[
        INSERT INTO characters
        (identifier, unique_id, firstname, lastname, dateofbirth, gender, model,
         position_x, position_y, position_z, heading)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        player.license, uniqueId, firstname, lastname, dateofbirth, gender, model,
        Config.spawn.defaultPosition.x,
        Config.spawn.defaultPosition.y,
        Config.spawn.defaultPosition.z,
        Config.spawn.defaultHeading
    }, function(characterId)
        if characterId then
            Database.insert(
                "INSERT INTO character_appearances (unique_id) VALUES (?)",
                {uniqueId},
                function()
                    Character.logger:info("Character created for " .. player.name .. ": " .. firstname .. " " .. lastname)
                    player:loadCharacters(function()
                        if callback then callback(true, characterId, uniqueId) end
                    end)
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

    local selected = nil
    for _, char in ipairs(player.characters) do
        if char.id == characterId then
            selected = char
            break
        end
    end

    if not selected then
        Character.logger:warn("Character not found: " .. tostring(characterId))
        if callback then callback(false, nil) end
        return
    end

    player.currentCharacter = selected
    Character.logger:info("Character selected for " .. player.name .. ": " .. selected.firstname .. " " .. selected.lastname)

    local modelStr
    if selected.model and selected.model ~= "" then
        modelStr = selected.model
    elseif selected.gender == "f" then
        modelStr = "mp_f_freemode_01"
    else
        modelStr = "mp_m_freemode_01"
    end

    local posX = (selected.position_x and selected.position_x ~= 0) and selected.position_x or Config.spawn.defaultPosition.x
    local posY = (selected.position_y and selected.position_y ~= 0) and selected.position_y or Config.spawn.defaultPosition.y
    local posZ = (selected.position_z and selected.position_z ~= 0) and selected.position_z or Config.spawn.defaultPosition.z

    local charData = {
        id          = selected.id,
        unique_id   = selected.unique_id,
        firstname   = selected.firstname,
        lastname    = selected.lastname,
        gender      = selected.gender,
        model       = modelStr,
        dateofbirth = selected.dateofbirth,
        position    = vector3(posX, posY, posZ),
        heading     = selected.heading or Config.spawn.defaultHeading,
        health      = selected.health  or Config.character.defaultHealth,
        armor       = selected.armor   or 0,
    }

    -- ✅ FIX : charger le skin depuis character_appearances avant le spawn
    Database.fetchOne(
        "SELECT skin_data FROM character_appearances WHERE unique_id = ?",
        { selected.unique_id },
        function(appearance)
            if appearance and appearance.skin_data then
                local skin = json.decode(appearance.skin_data)
                if skin then
                    charData.hair         = skin.hair
                    charData.headBlend    = skin.headBlend
                    charData.faceFeatures = skin.faceFeatures
                    charData.headOverlays = skin.headOverlays
                    charData.components   = skin.components
                    charData.props        = skin.props
                    charData.tattoos      = skin.tattoos
                end
            end

            TriggerClientEvent("union:spawn:apply", player.source, charData)
            if callback then callback(true, selected) end
        end
    )
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
                Character.logger:info("Character deleted: " .. characterId)
                player:loadCharacters(function()
                    if callback then callback(true) end
                end)
            else
                if callback then callback(false) end
            end
        end
    )
end

RegisterNetEvent("union:character:create", function(data)
    local source = source
    local player = PlayerManager.get(source)
    if not player then
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