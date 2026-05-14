-- server/modules/player/persistence.lua
-- FIX CRIT-4 : position lue depuis player.currentCharacter.position (en mémoire).
-- FIX #1 : savePlayer() vérifie player.isSpawned avant de sauvegarder.
-- FIX #2 : saveAllPlayers() ignore les joueurs non spawnés.
-- FIX #3 : vérification que les coords ne sont pas nulles.
-- FIX HP   : is_dead inclus dans chaque sauvegarde.
-- NOTE     : la sauvegarde principale est désormais faite dans position.lua
--            à chaque mouvement. Persistence reste la sauvegarde de sécurité.

Persistence          = {}
Persistence.logger   = Logger:child("PERSISTENCE")
Persistence.saveInterval = Config.spawn.saveInterval or 30000

function Persistence.savePlayer(player)
    if not player or not player.currentCharacter then return false end

    if not player.isSpawned then
        Persistence.logger:debug("Skip save (non spawné) : " .. (player.name or "?"))
        return false
    end

    local char    = player.currentCharacter
    local posData = char.position

    if not posData then
        Persistence.logger:warn("Skip save (position nil) : " .. (player.name or "?"))
        return false
    end

    -- Normalise la position
    local px, py, pz, heading
    if type(posData) == "table" then
        px, py, pz = posData.x, posData.y, posData.z
        heading    = posData.heading or char.heading or 0.0
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

    if not px or (math.abs(px) < 1.0 and math.abs(py or 0) < 1.0) then
        Persistence.logger:warn("Skip save (coords nulles) : " .. (player.name or "?"))
        return false
    end

    local posJson = json.encode({ x = px, y = py, z = pz, heading = heading })
    local health  = char.health  or Config.character.defaultHealth
    local armor   = char.armor   or 0
    local isDead  = char.is_dead or 0

    Database.execute([[
        UPDATE characters
        SET position = ?, health = ?, armor = ?, is_dead = ?, last_played = NOW()
        WHERE unique_id = ?
    ]], {
        posJson, health, armor, isDead, char.unique_id
    }, function(result)
        if result then
            Persistence.logger:debug(("Backup save OK: %s | HP=%d Armor=%d Dead=%d"):format(
                player.name, health, armor, isDead
            ))
        else
            Persistence.logger:error("Backup save échoué: " .. player.name)
        end
    end)

    return true
end

function Persistence.saveAllPlayers()
    local saved = 0
    for _, player in pairs(PlayerManager.getAll()) do
        if player.isSpawned and Persistence.savePlayer(player) then
            saved = saved + 1
        end
    end
    if saved > 0 then
        Persistence.logger:debug(("Backup save: %d joueur(s)"):format(saved))
    end
end

-- Sauvegarde de sécurité toutes les saveInterval ms
CreateThread(function()
    while true do
        Wait(Persistence.saveInterval)
        Persistence.saveAllPlayers()
    end
end)

-- Sauvegarde à l'arrêt de la resource
AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        Persistence.logger:info("Sauvegarde avant arrêt...")
        for _, player in pairs(PlayerManager.getAll()) do
            Persistence.savePlayer(player)
        end
    end
end)

return Persistence