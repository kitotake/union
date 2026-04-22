-- server/modules/player/persistence.lua
-- FIX: utilise la colonne `position` JSON au lieu de position_x/y/z/heading séparés

Persistence = {}
Persistence.logger = Logger:child("PERSISTENCE")
Persistence.saveInterval = Config.spawn.saveInterval or 30000

function Persistence.savePlayer(player)
    if not player or not player.currentCharacter then
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

    local posJson = json.encode({
        x = coords.x,
        y = coords.y,
        z = coords.z,
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
            Persistence.logger:debug("Player " .. player.name .. " character saved")
        else
            Persistence.logger:error("Failed to save character for " .. player.name)
        end
    end)

    return true
end

function Persistence.saveAllPlayers()
    for _, player in pairs(PlayerManager.getAll()) do
        Persistence.savePlayer(player)
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
        Persistence.saveAllPlayers()
    end
end)

return Persistence