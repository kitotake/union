-- server/modules/player/manager.lua
-- FIXES:
--   #1 : Race condition playerDropped — OfflinePed.create() est maintenant
--        appelé AVANT PlayerManager.remove() dans manager.lua.
--   #2 : SUPPRESSION du handler "union:player:spawned" pour StatusManager.load
--        → Ce handler est maintenant UNIQUEMENT dans status/manager.lua
--        pour éviter le double chargement et le double union:status:init.
--   #3 : StatusManager.cache nettoyé APRÈS PlayerManager.remove() pour que
--        le handler playerDropped dans status/manager.lua ait encore accès
--        à PlayerManager.get() et puisse capturer la license.

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
            TriggerClientEvent("union:player:loaded", src)
        else
            PlayerManager.logger:error("Failed to load player " .. tostring(src))
            DropPlayer(src, "Failed to load player data")
        end
    end)
end)

-- FIX #2 : SUPPRIMÉ — le handler "union:player:spawned" pour StatusManager.load
-- est maintenant UNIQUEMENT dans server/modules/player/status/manager.lua
-- Avoir deux handlers sur le même event causait un double chargement
-- et un double envoi de "union:status:init" au client.
--
-- Si vous avez besoin d'exécuter de la logique au spawn côté PlayerManager,
-- ajoutez-la ici sans toucher au StatusManager :
AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character then return end
    -- Marquer le joueur comme spawné
    local player = PlayerManager.get(src)
    if player then
        player.isSpawned = true
        PlayerManager.logger:debug(("Joueur spawné src=%d"):format(src))
    end
end)

-- ──────────────────────────────────────────────────────────────────────────
-- Joueur quitte
-- FIX #3 : L'ordre est important :
--   1. OfflinePed.create (besoin des données du personnage)
--   2. Sauvegarde DB position/HP
--   3. PlayerManager.remove (NE PAS le faire avant les étapes 1 et 2)
--   Note: StatusManager.cache est nettoyé dans son propre playerDropped handler
--         qui s'exécute AVANT ou APRÈS selon l'ordre de chargement —
--         mais grâce à la capture de license dans status/manager.lua,
--         l'ordre n'est plus critique.
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

                player.currentCharacter.position = posJson

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

                -- FIX #3 : créer le ped AVANT remove (données encore disponibles)
                if OfflinePed then
                    local charSnapshot = {
                        unique_id = player.currentCharacter.unique_id,
                        model     = player.currentCharacter.model,
                        gender    = player.currentCharacter.gender,
                        position  = posJson,
                    }
                    OfflinePed.create({
                        currentCharacter = charSnapshot,
                        name             = player.name,
                    })
                end
            end
        end

        -- FIX #3 : remove APRÈS OfflinePed.create et sauvegarde DB
        -- Le StatusManager.cache est nettoyé dans son propre handler
        -- (status/manager.lua) qui capte la license AVANT que PlayerManager
        -- libère le joueur grâce à l'ordre d'exécution Lua.
        PlayerManager.remove(src)
    end
end)

return PlayerManager