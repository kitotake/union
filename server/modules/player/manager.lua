-- server/modules/player/manager.lua
PlayerManager         = {}
PlayerManager.logger  = Logger:child("PLAYER:MANAGER")
PlayerManager.players = {}

function PlayerManager.create(source)
    if PlayerManager.players[source] then
        PlayerManager.logger:warn("Joueur " .. source .. " déjà existant")
        return PlayerManager.players[source]
    end
    if not PlayerClass then
        PlayerManager.logger:error("PlayerClass nil — vérifier l'ordre fxmanifest")
        return nil
    end
    local player = PlayerClass.new(source)
    PlayerManager.players[source] = player
    return player
end

function PlayerManager.get(source)   return PlayerManager.players[source] end
function PlayerManager.getAll()      return PlayerManager.players end
function PlayerManager.count()
    local count = 0
    for _ in pairs(PlayerManager.players) do count = count + 1 end
    return count
end

function PlayerManager.getByLicense(license)
    for _, player in pairs(PlayerManager.players) do
        if player.license == license then return player end
    end
    return nil
end

function PlayerManager.remove(source)
    if PlayerManager.players[source] then
        PlayerManager.logger:info("Suppression joueur : " .. (PlayerManager.players[source].name or tostring(source)))
        PlayerManager.players[source] = nil
    end
end

function PlayerManager.getStats()
    local stats = { total = PlayerManager.count(), admins = 0, moderators = 0, users = 0 }
    for _, player in pairs(PlayerManager.players) do
        if player:isAdmin() then stats.admins = stats.admins + 1
        elseif player:isModerator() then stats.moderators = stats.moderators + 1
        else stats.users = stats.users + 1 end
    end
    return stats
end

RegisterNetEvent("union:player:joined", function()
    local src = source
    local existing = PlayerManager.get(src)
    if existing then
        PlayerManager.logger:warn(("Joueur %d déjà présent — rechargement après restart"):format(src))
        existing.isSpawned        = false
        existing.currentCharacter = nil
        existing:loadFromDatabase(function(success)
            if success then
                TriggerClientEvent("union:player:loaded", src)
            else
                DropPlayer(src, "Échec rechargement données après restart")
            end
        end)
        return
    end

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

AddEventHandler("playerDropped", function(reason)
    local src    = source
    local player = PlayerManager.get(src)
    if not player then return end

    Auth.Webhooks.playerLeft(src, reason)
    PlayerManager.logger:info("Joueur " .. player.name .. " déconnecté : " .. tostring(reason))

    -- FIX CRIT-5: déclencher AVANT remove
    TriggerEvent("union:player:dropping", src, player, reason)

    -- Snapshot pour sauvegarde async
    local saveData = nil
    if player.currentCharacter and player.isSpawned then
        local char    = player.currentCharacter
        local posJson = nil
        if type(char.position) == "string" then
            posJson = char.position
        elseif type(char.position) == "table" then
            posJson = json.encode(char.position)
        elseif type(char.position) == "vector3" then
            posJson = json.encode({ x = char.position.x, y = char.position.y, z = char.position.z, heading = char.heading or 0.0 })
        end
        saveData = {
            unique_id = char.unique_id,
            health    = char.health  or 200,
            armor     = char.armor   or 0,
            is_dead   = char.is_dead or 0,
            posJson   = posJson,
            name      = player.name,
        }
    end

    -- OfflinePed AVANT remove
    if player.currentCharacter and OfflinePed then
        local char    = player.currentCharacter
        local posData = char.position
        if posData then
            local posStr
            if type(posData) == "string" then posStr = posData
            elseif type(posData) == "table" then posStr = json.encode(posData)
            elseif type(posData) == "vector3" then
                posStr = json.encode({ x = posData.x, y = posData.y, z = posData.z, heading = char.heading or 0.0 })
            end
            if posStr then
                OfflinePed.create({
                    currentCharacter = {
                        unique_id = char.unique_id,
                        ped_model = char.ped_model or "mp_m_freemode_01",
                        position  = posStr,
                    },
                    name = player.name,
                }, src)
            end
        end
    end

    PlayerManager.remove(src)

    if saveData then
        CreateThread(function()
            if not saveData.posJson then
                PlayerManager.logger:warn("Pas de position à sauvegarder pour " .. saveData.name)
                return
            end
            exports.oxmysql:execute([[
                UPDATE characters
                SET position = ?, health = ?, armor = ?, is_dead = ?, last_played = NOW()
                WHERE unique_id = ?
            ]], { saveData.posJson, saveData.health, saveData.armor, saveData.is_dead, saveData.unique_id },
            function(result)
                if result then
                    PlayerManager.logger:info(("Sauvegarde déco OK: %s | HP=%d Armor=%d Dead=%d"):format(
                        saveData.name, saveData.health, saveData.armor, saveData.is_dead
                    ))
                else
                    PlayerManager.logger:error("Échec sauvegarde déco pour " .. saveData.name)
                end
            end)
        end)
    end
end)

return PlayerManager
