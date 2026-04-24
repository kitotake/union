-- server/modules/player/manager.lua
-- FIX: conflit de nom entre la classe Player (main.lua) et le native FiveM Player()
--      → PlayerClass.new() utilisé à la place de Player.new()
-- FIX: sauvegarde position JSON à la déconnexion
-- AJOUT: création ped persistant hors-ligne à la déconnexion

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
        total      = PlayerManager.count(),
        admins     = 0,
        moderators = 0,
        users      = 0,
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

-- ──────────────────────────────────────────────────────────────────────────
-- Joueur rejoint
-- ──────────────────────────────────────────────────────────────────────────
RegisterNetEvent("union:player:joined", function()
    local source = source

    local player = PlayerManager.create(source)
    if not player then
        PlayerManager.logger:error("Failed to create player object for source " .. tostring(source))
        DropPlayer(source, "Failed to initialize player data")
        return
    end

    player:loadFromDatabase(function(success)
        if success then
            PlayerManager.logger:info("Player " .. player.name .. " loaded successfully")
            Auth.Webhooks.playerJoined(source)
            TriggerClientEvent("union:player:loaded", source)
        else
            PlayerManager.logger:error("Failed to load player " .. tostring(source))
            DropPlayer(source, "Failed to load player data")
        end
    end)
end)

-- ──────────────────────────────────────────────────────────────────────────
-- Joueur quitte
-- ──────────────────────────────────────────────────────────────────────────
AddEventHandler("playerDropped", function(reason)
    local source = source
    local player = PlayerManager.get(source)

    if player then
        Auth.Webhooks.playerLeft(source, reason)
        PlayerManager.logger:info("Player " .. player.name .. " disconnected: " .. reason)

        if player.currentCharacter then
            local ped = GetPlayerPed(source)

            if DoesEntityExist(ped) then
                local coords  = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)
                local health  = GetEntityHealth(ped)
                local armor   = GetPedArmour(ped)

                local posJson = json.encode({
                    x       = coords.x,
                    y       = coords.y,
                    z       = coords.z,
                    heading = heading,
                })

                Database.execute([[
                    UPDATE characters SET
                    position = ?, health = ?, armor = ?,
                    last_played = NOW()
                    WHERE unique_id = ?
                ]], {
                    posJson, health, armor,
                    player.currentCharacter.unique_id,
                }, function(result)
                    if result then
                        PlayerManager.logger:info("Character saved on disconnect for " .. player.name)
                    else
                        PlayerManager.logger:error("Failed to save character on disconnect for " .. player.name)
                    end
                end)

                -- Créer le ped persistant avec la position actuelle
                if OfflinePed then
                    local charSnapshot = {}
                    for k, v in pairs(player.currentCharacter) do
                        charSnapshot[k] = v
                    end
                    charSnapshot.position = {
                        x       = coords.x,
                        y       = coords.y,
                        z       = coords.z,
                        heading = heading,
                    }

                    OfflinePed.create({
                        source           = source,
                        name             = player.name,
                        currentCharacter = charSnapshot,
                        group            = player.group,
                    })
                end
            end
        end

        PlayerManager.remove(source)
    end
end)

return PlayerManager    