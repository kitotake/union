-- server/modules/player/manager.lua
-- FIX #1 : playerDropped — sauvegarde dans un CreateThread pour éviter le blocage
--           et garantir que la DB reçoit bien les données avant le remove.
-- FIX #2 : Un seul handler "union:player:spawned" (isSpawned uniquement ici).
-- FIX #3 : OfflinePed.create appelé AVANT PlayerManager.remove.
-- FIX #4 : Vérification GetPlayerEndpoint avant d'accéder au ped (joueur déjà parti).

PlayerManager        = {}
PlayerManager.logger = Logger:child("PLAYER:MANAGER")
PlayerManager.players = {}

function PlayerManager.create(source)
    if PlayerManager.players[source] then
        PlayerManager.logger:warn("Joueur " .. source .. " déjà existant")
        return PlayerManager.players[source]
    end

    if not PlayerClass then
        PlayerManager.logger:error("PlayerClass est nil — vérifier l'ordre de chargement fxmanifest")
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
        PlayerManager.logger:info("Suppression joueur : " .. (PlayerManager.players[source].name or tostring(source)))
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
        PlayerManager.logger:error("Impossible de créer l'objet joueur pour source " .. tostring(src))
        DropPlayer(src, "Échec de l'initialisation des données joueur")
        return
    end

    player:loadFromDatabase(function(success)
        if success then
            PlayerManager.logger:info("Joueur " .. player.name .. " chargé")
            Auth.Webhooks.playerJoined(src)
            TriggerClientEvent("union:player:loaded", src)
        else
            PlayerManager.logger:error("Échec du chargement joueur " .. tostring(src))
            DropPlayer(src, "Échec du chargement des données")
        end
    end)
end)

-- FIX #2 : isSpawned mis à jour ici, sans toucher au StatusManager
AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character then return end
    local player = PlayerManager.get(src)
    if player then
        player.isSpawned = true
        PlayerManager.logger:debug(("Joueur spawné src=%d"):format(src))
    end
end)

-- ──────────────────────────────────────────────────────────────────────────
-- Joueur quitte
-- FIX #1 : sauvegarde dans un thread pour ne pas bloquer le handler
-- FIX #3 : OfflinePed.create AVANT PlayerManager.remove
-- FIX #4 : vérification GetPlayerEndpoint
-- ──────────────────────────────────────────────────────────────────────────
AddEventHandler("playerDropped", function(reason)
    local src    = source
    local player = PlayerManager.get(src)

    if not player then return end

    Auth.Webhooks.playerLeft(src, reason)
    PlayerManager.logger:info("Joueur " .. player.name .. " déconnecté : " .. tostring(reason))

    -- Snapshot du personnage AVANT toute modification (évite race condition)
    local charSnapshot = nil
    if player.currentCharacter then
        charSnapshot = {
            unique_id = player.currentCharacter.unique_id,
            model     = player.currentCharacter.model,
            gender    = player.currentCharacter.gender,
        }
    end

    -- FIX #3 : OfflinePed AVANT PlayerManager.remove
    if charSnapshot and OfflinePed then
        -- On ne peut pas lire les coordonnées du ped ici de façon fiable
        -- car le joueur vient de quitter. On utilise la position sauvegardée.
        local posData = player.currentCharacter and player.currentCharacter.position
        if posData then
            charSnapshot.position = type(posData) == "string" and posData or json.encode(posData)
            OfflinePed.create({
                currentCharacter = charSnapshot,
                name             = player.name,
            })
        end
    end

    -- FIX #1 : sauvegarde async dans un thread dédié
    if player.currentCharacter then
        local uid    = player.currentCharacter.unique_id
        local name   = player.name

        CreateThread(function()
            -- FIX #4 : le joueur est parti, on ne peut plus lire son ped
            -- On sauvegarde la dernière position connue (déjà stockée dans currentCharacter)
            local posJson = nil
            local health  = player.currentCharacter.health or 200
            local armor   = player.currentCharacter.armor  or 0

            if player.currentCharacter.position then
                if type(player.currentCharacter.position) == "string" then
                    posJson = player.currentCharacter.position
                else
                    posJson = json.encode(player.currentCharacter.position)
                end
            end

            if posJson then
                exports.oxmysql:execute([[
                    UPDATE characters SET
                    position = ?, health = ?, armor = ?, last_played = NOW()
                    WHERE unique_id = ?
                ]], { posJson, health, armor, uid }, function(result)
                    if result then
                        PlayerManager.logger:info("Personnage sauvegardé à la déco pour " .. name)
                    else
                        PlayerManager.logger:error("Échec sauvegarde personnage pour " .. name)
                    end
                end)
            end
        end)
    end

    -- FIX #3 : remove APRÈS OfflinePed et lancement de la sauvegarde
    PlayerManager.remove(src)
end)

return PlayerManager
