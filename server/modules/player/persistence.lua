-- server/modules/player/persistence.lua
-- FIXES:
--   #1 : savePlayer() vérifie player.isSpawned avant de sauvegarder.
--        Évite d'écraser la dernière position valide avec des coords de spawn/zéro.
--   #2 : saveAllPlayers() ignore les joueurs non spawnés.
--   #3 : Vérification supplémentaire que les coords ne sont pas nulles (0,0,0)
--        avant d'écraser la position en base.

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

    local ped = GetPlayerPed(player.source)
    if not DoesEntityExist(ped) then
        return false
    end

    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local health  = GetEntityHealth(ped)
    local armor   = GetPedArmour(ped)

    -- FIX #3 : ne pas sauvegarder des coords nulles (joueur en cours de spawn)
    if math.abs(coords.x) < 1.0 and math.abs(coords.y) < 1.0 then
        Persistence.logger:warn("Skip save (coords nulles) : " .. (player.name or "?"))
        return false
    end

    local posJson = json.encode({
        x       = coords.x,
        y       = coords.y,
        z       = coords.z,
        heading = heading
    })

    Database.execute([[
        UPDATE characters SET
        position = ?, health = ?, armor = ?,
        last_played = NOW()
        WHERE unique_id = ?
    ]], {
        posJson, health, armor,
        player.currentCharacter.unique_id
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
    local saved  = 0
    local skipped = 0

    for _, player in pairs(PlayerManager.getAll()) do
        -- FIX #2 : ignorer les joueurs non spawnés dans la boucle globale
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
        -- Au shutdown on sauvegarde tout le monde, spawné ou non,
        -- pour ne pas perdre de données critiques
        for _, player in pairs(PlayerManager.getAll()) do
            Persistence.savePlayer(player)
        end
    end
end)

return Persistence
