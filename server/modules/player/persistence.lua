-- server/modules/player/persistence.lua
-- FIX CRIT-4 : GetEntityCoords(ped) côté serveur retourne toujours 0,0,0 pour les
--              peds des clients. La vraie position est maintenue dans
--              player.currentCharacter.position, mise à jour à chaque réception
--              de union:position:save (SpawnPosition) et à la déco (playerDropped
--              dans manager.lua qui lit aussi cette valeur).
--              On lit donc directement player.currentCharacter.position au lieu
--              d'appeler GetEntityCoords. Le health/armor ne peut pas être lu
--              non plus côté serveur — on conserve les dernières valeurs connues.
-- FIX #1 : savePlayer() vérifie player.isSpawned avant de sauvegarder.
-- FIX #2 : saveAllPlayers() ignore les joueurs non spawnés.
-- FIX #3 : Vérification que les coords ne sont pas nulles (0,0,0).

Persistence = {}
Persistence.logger = Logger:child("PERSISTENCE")
Persistence.saveInterval = Config.spawn.saveInterval or 30000

function Persistence.savePlayer(player)
    if not player or not player.currentCharacter then
        return false
    end

    -- FIX #1 : ne pas sauvegarder un joueur non encore spawné
    if not player.isSpawned then
        Persistence.logger:debug("Skip save (non spawné) : " .. (player.name or "?"))
        return false
    end

    local char = player.currentCharacter

    -- FIX CRIT-4 : lire la position depuis la structure en mémoire (mise à jour
    -- par union:position:save côté client via SpawnPosition.save).
    -- On NE PAS utiliser GetEntityCoords qui retourne 0,0,0 pour les clients.
    local posData = char.position
    if not posData then
        Persistence.logger:warn("Skip save (position nil) : " .. (player.name or "?"))
        return false
    end

    -- Normalise la position en table si nécessaire
    local px, py, pz, heading
    if type(posData) == "table" then
        px, py, pz   = posData.x, posData.y, posData.z
        heading      = posData.heading or char.heading or 0.0
    elseif type(posData) == "string" then
        local ok, p = pcall(json.decode, posData)
        if ok and p and p.x then
            px, py, pz = p.x, p.y, p.z
            heading    = p.heading or char.heading or 0.0
        end
    elseif type(posData) == "vector3" then
        px, py, pz = posData.x, posData.y, posData.z
        heading    = char.heading or 0.0
    end

    -- FIX #3 : skip si coords nulles
    if not px or (math.abs(px) < 1.0 and math.abs(py or 0) < 1.0) then
        Persistence.logger:warn("Skip save (coords nulles) : " .. (player.name or "?"))
        return false
    end

    local posJson = json.encode({
        x       = px,
        y       = py,
        z       = pz,
        heading = heading,
    })

    -- health/armor : dernières valeurs connues en mémoire
    -- (mises à jour par union:spawn:confirm et union:position:save)
    local health = char.health or Config.character.defaultHealth
    local armor  = char.armor  or 0

    Database.execute([[
        UPDATE characters SET
        position = ?, health = ?, armor = ?,
        last_played = NOW()
        WHERE unique_id = ?
    ]], {
        posJson, health, armor,
        char.unique_id
    }, function(result)
        if result then
            Persistence.logger:debug("Saved: " .. player.name)
        else
            Persistence.logger:error("Failed to save: " .. player.name)
        end
    end)

    return true
end

function Persistence.saveAllPlayers()
    local saved   = 0
    local skipped = 0

    for _, player in pairs(PlayerManager.getAll()) do
        -- FIX #2 : ignorer les joueurs non spawnés
        if player.isSpawned then
            if Persistence.savePlayer(player) then
                saved = saved + 1
            end
        else
            skipped = skipped + 1
        end
    end

    if saved > 0 or skipped > 0 then
        Persistence.logger:debug(("AutoSave: %d sauvegardés, %d ignorés (non spawnés)"):format(saved, skipped))
    end
end

-- Auto-save thread
CreateThread(function()
    while true do
        Wait(Persistence.saveInterval)
        Persistence.saveAllPlayers()
    end
end)

-- Save on resource stop
AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        Persistence.logger:info("Saving all players before shutdown...")
        for _, player in pairs(PlayerManager.getAll()) do
            Persistence.savePlayer(player)
        end
    end
end)

return Persistence