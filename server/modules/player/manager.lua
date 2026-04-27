-- server/modules/player/manager.lua
-- FIX : utilise PlayerClass.new() — la native Player() n'est plus écrasée.

PlayerManager = {}
PlayerManager.logger = Logger:child("PLAYER:MANAGER")
PlayerManager.players = {}

function PlayerManager.create(source)
    if PlayerManager.players[source] then
        PlayerManager.logger:warn("Player " .. source .. " already exists")
        return PlayerManager.players[source]
    end

    if not PlayerClass then
        PlayerManager.logger:error("PlayerClass is nil — check fxmanifest load order")
        return nil
    end

    local player = PlayerClass.new(source)
    PlayerManager.players[source] = player
    return player
end

function PlayerManager.get(source)
    return PlayerManager.players[source]
end

function PlayerManager.getByLicense(license)
    for _, player in pairs(PlayerManager.players) do
        if player.license == license then return player end
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
    for _ in pairs(PlayerManager.players) do count = count + 1 end
    return count
end

function PlayerManager.getStats()
    local stats = { total = PlayerManager.count(), admins = 0, moderators = 0, users = 0 }
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

-- ──────────────────────────────────────────────────────────────────────────
-- Joueur rejoint
-- ──────────────────────────────────────────────────────────────────────────
RegisterNetEvent("union:player:joined", function()
    local src = source

    local player = PlayerManager.create(src)
    if not player then
        PlayerManager.logger:error("Failed to create player object for source " .. tostring(src))
        DropPlayer(src, "Failed to initialize player data")
        return
    end

    player:loadFromDatabase(function(success)
        if success then
            PlayerManager.logger:info("Player " .. player.name .. " loaded successfully")
            Auth.Webhooks.playerJoined(src)
            -- FIX : union:player:loaded est envoyé ici, le client appellera Spawn.initialize()
            TriggerClientEvent("union:player:loaded", src)
        else
            PlayerManager.logger:error("Failed to load player " .. tostring(src))
            DropPlayer(src, "Failed to load player data")
        end
    end)
end)

-- ──────────────────────────────────────────────────────────────────────────
-- Joueur quitte — sauvegarde position + création ped offline
-- ──────────────────────────────────────────────────────────────────────────
AddEventHandler("playerDropped", function(reason)
    local src    = source
    local player = PlayerManager.get(src)

    if player then
        Auth.Webhooks.playerLeft(src, reason)
        PlayerManager.logger:info("Player " .. player.name .. " disconnected: " .. reason)

        if player.currentCharacter then
            local ped = GetPlayerPed(src)

            if DoesEntityExist(ped) then
                local coords  = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)
                local health  = GetEntityHealth(ped)
                local armor   = GetPedArmour(ped)

                local posJson = json.encode({
                    x = coords.x, y = coords.y, z = coords.z, heading = heading,
                })

                Database.execute([[
                    UPDATE characters SET
                    position = ?, health = ?, armor = ?, last_played = NOW()
                    WHERE unique_id = ?
                ]], { posJson, health, armor, player.currentCharacter.unique_id },
                function(result)
                    if result then
                        PlayerManager.logger:info("Character saved on disconnect for " .. player.name)
                    else
                        PlayerManager.logger:error("Failed to save character for " .. player.name)
                    end
                end)

                if OfflinePed then
                    local charSnapshot = {}
                    for k, v in pairs(player.currentCharacter) do charSnapshot[k] = v end
                    charSnapshot.position = {
                        x = coords.x, y = coords.y, z = coords.z, heading = heading,
                    }
                    OfflinePed.create({
                        source           = src,
                        name             = player.name,
                        currentCharacter = charSnapshot,
                        group            = player.group,
                    })
                end
            end
        end

        PlayerManager.remove(src)
    end
end)

return PlayerManager