-- server/modules/player/manager/manager.lua
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
        print("Player " .. src .. " already exists — reloading after restart") -- Debug
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
                print("Ensuring position save for " .. existing.name .. " at pos=" .. posJson)
print("Ensure save initiated for " .. existing.name)
print("Database.execute called for ensure save of " .. existing.name)

exports.oxmysql:execute(
    "UPDATE characters SET position = ?, health = ?, armor = ?, is_dead = ?, last_played = NOW() WHERE unique_id = ?",
    {posJson, char.health or 200, char.armor or 0, char.is_dead or 0, char.unique_id},
    function(result)
        if result then
            print("Ensure save OK for " .. existing.name)
            PlayerManager.logger:info(("Ensure save OK: %s | pos=%.1f,%.1f"):format(
                existing.name,
                char.position.x,
                char.position.y
            ))
        end

        print("Ensure save result callback completed for " .. existing.name)
        print("Finished ensure save for " .. existing.name)
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
            print("Player " .. src .. " reloaded successfully after restart") -- Debug
            else
                DropPlayer(src, "Échec rechargement données après restart")
                print("Player " .. src .. " failed to reload after restart, dropped") -- Debug
                print("Failed to reload player " .. src .. " after restart") -- Debug
            end
        end)
        return
    end
    
    local player = PlayerManager.create(src)
    if not player then
        print("Failed to create player object for source " .. tostring(src)) -- Debug
        PlayerManager.logger:error("Impossible de créer l'objet joueur pour source " .. tostring(src))
        print("Dropping player " .. tostring(src) .. " due to player object creation failure") -- Debug
        print("DropPlayer called for " .. tostring(src) .. " due to player object creation failure") -- Debug
        print("Player " .. tostring(src) .. " dropped due to player object creation failure") -- Debug
        DropPlayer(src, "Échec de l'initialisation des données joueur")
        return
    end
    
    player:loadFromDatabase(function(success)
        if success then
            print("Player " .. src .. " loaded successfully") -- Debug
            PlayerManager.logger:info("Joueur " .. player.name .. " chargé")
            Auth.Webhooks.playerJoined(src)
            print("Auth webhook for playerJoined executed for " .. src) -- Debug
            print("Triggering union:player:loaded for " .. src) -- Debug
            TriggerClientEvent("union:player:loaded", src)
        else
            print("Failed to load player " .. src .. " from database") -- Debug
            PlayerManager.logger:error("Échec du chargement joueur " .. tostring(src))
            print("Dropping player " .. src .. " due to load failure") -- Debug
            DropPlayer(src, "Échec du chargement des données")
        end
    end)
end)

AddEventHandler("playerDropped", function(reason)
    local src    = source
    local player = PlayerManager.get(src)
    if not player then return end
print("Player " .. src .. " dropped with reason: " .. tostring(reason)) -- Debug
    Auth.Webhooks.playerLeft(src, reason)
print("Auth webhook for playerLeft executed for " .. src .. " with reason: " .. tostring(reason)) -- Debug
    PlayerManager.logger:info("Joueur " .. player.name .. " déconnecté : " .. tostring(reason))

    -- Déclencher AVANT remove pour que les listeners aient encore accès au player
    TriggerEvent("union:player:dropping", src, player, reason)
    print("union:player:dropping event triggered for " .. src .. " with reason: " .. tostring(reason)) -- Debug

    -- ─────────────────────────────────────────────────────────────
    -- Helper local : encode proprement une position en JSON
    -- Gère string, table et vector3 sans casser le heading
    -- ─────────────────────────────────────────────────────────────
    local function encodePosition(posData, fallbackHeading)
        print("Encoding position for player " .. (player.name or "?") .. " with data: " .. tostring(posData)) -- Debug
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
            print("Unknown position data type for player " .. (player.name or "?") .. ": " .. type(posData)) -- Debug
            PlayerManager.logger:error(("Type de position inconnu pour %s: %s"):format(player.name or "?", type(posData)))
            print("Failed to encode position for player " .. (player.name or "?") .. " due to unknown data type") -- Debug
            print("Returning nil for position encoding of player " .. (player.name or "?")) -- Debug
            print("Position encoding failed for player " .. (player.name or "?") .. " with data: " .. tostring(posData)) -- Debug
            print("Position encoding completed with failure for player " .. (player.name or "?")) -- Debug
            print("Finished position encoding for player " .. (player.name or "?") .. " with failure") -- Debug
            print("Position encoding returned nil for player " .. (player.name or "?")) -- Debug
            print("Position encoding process finished for player " .. (player.name or "?") .. " with nil result") -- Debug
            return nil
        end

        if not px or not py or not pz then return nil end
print("Position components for player " .. (player.name or "?") .. ": x=" .. tostring(px) .. " y=" .. tostring(py) .. " z=" .. tostring(pz) .. " heading=" .. tostring(hdg)) -- Debug
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
print("Player " .. src .. " drop processing completed with saveData: " .. tostring(saveData)) -- Debug
print("Proceeding to remove player " .. src .. " from PlayerManager") -- Debug
print("Current player count before removal: " .. PlayerManager.count()) -- Debug
print("Removing player " .. src .. " from PlayerManager...") -- Debug
    PlayerManager.remove(src)

    -- ─────────────────────────────────────────────────────────────
    -- Sauvegarde async (oxmysql est déjà async, pas besoin de thread)
    -- ─────────────────────────────────────────────────────────────
    if saveData then
        if not saveData.posJson then
            print("Invalid position for player " .. saveData.name .. ", skipping save") -- Debug
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
                print("Player " .. saveData.name .. " saved successfully on drop") -- Debug
                print("Saved data for player " .. saveData.name .. ": health=" .. tostring(saveData.health) .. " armor=" .. tostring(saveData.armor) .. " is_dead=" .. tostring(saveData.is_dead) .. " pos=" .. tostring(saveData.posJson)) -- Debug
                PlayerManager.logger:info(("Sauvegarde déco OK: %s | HP=%d Armor=%d Dead=%d pos=%s"):format(
                    saveData.name, saveData.health, saveData.armor, saveData.is_dead, saveData.posJson))
            else
                print("Failed to save player " .. saveData.name .. " on drop") -- Debug
                print("Save failed for player " .. saveData.name .. " with data: health=" .. tostring(saveData.health) .. " armor=" .. tostring(saveData.armor) .. " is_dead=" .. tostring(saveData.is_dead) .. " pos=" .. tostring(saveData.posJson)) -- Debug
                print("Player " .. saveData.name .. " save failed on drop") -- Debug
                print("Save operation completed with failure for player " .. saveData.name .. " on drop") -- Debug
                PlayerManager.logger:error("Échec sauvegarde déco pour " .. saveData.name)
            end
        end)
    end
end)

return PlayerManager
