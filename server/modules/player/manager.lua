-- server/modules/player/manager.lua
PlayerManager = {}
PlayerManager.logger = Logger:child("PLAYER:MANAGER")
PlayerManager.players = {}

function PlayerManager.create(source)
    if PlayerManager.players[source] then
        PlayerManager.logger:warn("Player " .. source .. " already exists")
        return PlayerManager.players[source]
    end
    
    local player = Player.new(source)
    PlayerManager.players[source] = player
    
    return player
end

function PlayerManager.get(source)
    return PlayerManager.players[source]
end

function PlayerManager.getByLicense(license)
    for _, player in pairs(PlayerManager.players) do
        if player.license == license then
            return player
        end
    end
    return nil
end

function PlayerManager.getByName(name)
    for _, player in pairs(PlayerManager.players) do
        if player.name == name then
            return player
        end
    end
    return nil
end

function PlayerManager.getAll()
    return PlayerManager.players
end

function PlayerManager.remove(source)
    if PlayerManager.players[source] then
        PlayerManager.logger:info("Removing player: " .. PlayerManager.players[source].name)
        PlayerManager.players[source] = nil
    end
end

function PlayerManager.count()
    local count = 0
    for _ in pairs(PlayerManager.players) do
        count = count + 1
    end
    return count
end

function PlayerManager.notifyAll(message, type, duration)
    for _, player in pairs(PlayerManager.players) do
        player:notify(message, type, duration)
    end
end

function PlayerManager.getStats()
    local stats = {
        total = PlayerManager.count(),
        admins = 0,
        moderators = 0,
        users = 0,
    }
    
    for _, player in pairs(PlayerManager.players) do
        if player:isAdmin() then
            stats.admins = stats.admins + 1
        elseif player:isModerator() then
            stats.moderators = stats.moderators + 1
        else
            stats.users = stats.users + 1
        end
    end
    
    return stats
end

-- Initialize player on join
RegisterNetEvent("union:player:joined", function()
    local source = source
    
    local player = PlayerManager.create(source)
    player:loadFromDatabase(function(success)
        if success then
            PlayerManager.logger:info("Player " .. player.name .. " loaded successfully")
            Auth.Webhooks.playerJoined(source)
            TriggerClientEvent("union:player:loaded", source)
        else
            PlayerManager.logger:error("Failed to load player " .. source)
            DropPlayer(source, "Failed to load player data")
        end
    end)
end)

-- Handle player disconnect
AddEventHandler("playerDropped", function(reason)
    local source = source
    local player = PlayerManager.get(source)

    if player then
        Auth.Webhooks.playerLeft(source, reason)
        PlayerManager.logger:info("Player " .. player.name .. " disconnected: " .. reason)

        -- ✅ Sauvegarde du personnage à la déconnexion
        if player.currentCharacter then
            local ped = GetPlayerPed(source)

            if DoesEntityExist(ped) then
                local coords  = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)
                local health  = GetEntityHealth(ped)
                local armor   = GetPedArmour(ped)

                Database.execute([[
                    UPDATE characters SET
                    position_x = ?, position_y = ?, position_z = ?,
                    heading = ?, health = ?, armor = ?,
                    last_played = NOW()
                    WHERE unique_id = ?
                ]], {
                    coords.x, coords.y, coords.z,
                    heading, health, armor,
                    player.currentCharacter.unique_id
                }, function(result)
                    if result then
                        PlayerManager.logger:info("Character saved on disconnect for " .. player.name)
                    else
                        PlayerManager.logger:error("Failed to save character on disconnect for " .. player.name)
                    end
                end)
            end
        end

        PlayerManager.remove(source)
    end
end)

return PlayerManager