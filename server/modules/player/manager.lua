-- server/modules/player/manager.lua
PlayerManager = {}
PlayerManager.logger = Logger:child("PLAYER:MANAGER")
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

function PlayerManager.get(source) return PlayerManager.players[source] end
function PlayerManager.getAll() return PlayerManager.players end
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
    local stats = {total = PlayerManager.count(), admins = 0, moderators = 0, users = 0}
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
        
        -- FIX ENSURE: sauvegarder la position avant de reset
        if existing.currentCharacter and existing.isSpawned then
            local char = existing.currentCharacter
            if char.position and type(char.position) == "table" and
                not (char.position.x == 0 and char.position.y == 0) then
                local posJson = json.encode({
                    x = char.position.x,
                    y = char.position.y,
                    z = char.position.z,
                    heading = char.heading or 0.0,
                })
                exports.oxmysql:execute(
                    "UPDATE characters SET position = ?, health = ?, armor = ?, is_dead = ?, last_played = NOW() WHERE unique_id = ?",
                    {posJson, char.health or 200, char.armor or 0, char.is_dead or 0, char.unique_id},
                    function(result)
                        if result then
                            PlayerManager.logger:info(("Ensure save OK: %s | pos=%.1f,%.1f"):format(
                                existing.name, char.position.x, char.position.y))
                        end
                    end
            )
            end
        end
        
        -- FIX ENSURE: nettoyer le store OfflinePed (pas de playerDropped lors d'un ensure)
        if existing.currentCharacter and OfflinePed then
            local uid = existing.currentCharacter.unique_id
            if uid and OfflinePed.store[uid] then
                OfflinePed.store[uid] = nil
                PlayerManager.logger:debug(("Ensure: OfflinePed store nettoyé uid=%s"):format(uid))
            end
        end
        
        existing.isSpawned = false
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

    -- Déclencher AVANT remove pour que les listeners aient encore accès au player
    TriggerEvent("union:player:dropping", src, player, reason)

    -- ─────────────────────────────────────────────────────────────
    -- Helper local : encode proprement une position en JSON
    -- Gère string, table et vector3 sans casser le heading
    -- ─────────────────────────────────────────────────────────────
    local function encodePosition(posData, fallbackHeading)
        if not posData then return nil end

        local px, py, pz, hdg

        if type(posData) == "string" then
            -- Déjà encodé : décoder pour récupérer/compléter le heading
            local ok, p = pcall(json.decode, posData)
            if not ok or not p or not p.x then return posData end -- garder tel quel si invalide
            px, py, pz = p.x, p.y, p.z
            hdg = p.heading or fallbackHeading or 0.0

        elseif type(posData) == "table" then
            px, py, pz = posData.x, posData.y, posData.z
            hdg = posData.heading or fallbackHeading or 0.0

        elseif type(posData) == "vector3" then
            -- FIX: json.encode(vector3) donne [x,y,z], pas {x=...,y=...}
            px, py, pz = posData.x, posData.y, posData.z
            hdg = fallbackHeading or 0.0

        else
            return nil
        end

        if not px or not py or not pz then return nil end

        -- Coordonnées nulles = spawn en cours, pas fiable
        if math.abs(px) < 1.0 and math.abs(py) < 1.0 then return nil end

        return json.encode({ x = px, y = py, z = pz, heading = hdg })
    end

    -- ─────────────────────────────────────────────────────────────
    -- Snapshot sauvegarde + OfflinePed (avant PlayerManager.remove)
    -- ─────────────────────────────────────────────────────────────
    local saveData = nil

    if player.currentCharacter and player.isSpawned then
        local char   = player.currentCharacter
        local posJson = encodePosition(char.position, char.heading)

        saveData = {
            unique_id = char.unique_id,
            health    = char.health  or 200,
            armor     = char.armor   or 0,
            is_dead   = char.is_dead or 0,
            posJson   = posJson,
            name      = player.name,
        }

        -- OfflinePed : utilise le même posJson déjà encodé proprement
        if OfflinePed and posJson then
            OfflinePed.create({
                currentCharacter = {
                    unique_id = char.unique_id,
                    ped_model = char.ped_model or "mp_m_freemode_01",
                    position  = posJson,
                },
                name = player.name,
            }, src)
        end
    end

    PlayerManager.remove(src)

    -- ─────────────────────────────────────────────────────────────
    -- Sauvegarde async (oxmysql est déjà async, pas besoin de thread)
    -- ─────────────────────────────────────────────────────────────
    if saveData then
        if not saveData.posJson then
            PlayerManager.logger:warn("Sauvegarde déco ignorée (position invalide) : " .. saveData.name)
            return
        end

        exports.oxmysql:execute([[
            UPDATE characters
            SET position = ?, health = ?, armor = ?, is_dead = ?, last_played = NOW()
            WHERE unique_id = ?
        ]], {
            saveData.posJson,
            saveData.health,
            saveData.armor,
            saveData.is_dead,
            saveData.unique_id,
        }, function(result)
            if result then
                PlayerManager.logger:info(("Sauvegarde déco OK: %s | HP=%d Armor=%d Dead=%d pos=%s"):format(
                    saveData.name, saveData.health, saveData.armor, saveData.is_dead, saveData.posJson))
            else
                PlayerManager.logger:error("Échec sauvegarde déco pour " .. saveData.name)
            end
        end)
    end
end)

return PlayerManager
