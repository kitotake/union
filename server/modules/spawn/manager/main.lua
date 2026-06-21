Spawn = {}
local logger = Logger:child("SPAWN:SERVER")

print("Spawn module loaded") -- Debug initial load

function Spawn.initialize(player)
    if not player then return false end

    logger:info(("Initialisation spawn pour %s"):format(player.name or "?"))

    print("Spawn.initialize called for player: " .. (player.name or "?")) -- OK ici

    return true
end

-- ❌ SUPPRIMÉ : print avec player hors scope (ca faisait crash)

function Spawn.respawnPlayer(src, model)
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return false end
    if not GetPlayerEndpoint(src) then return false end

    local defPos = Config.spawn.defaultPosition
    local char   = player.currentCharacter

    print(
        "position for respawn set to x=" .. tostring(defPos.x) ..
        " y=" .. tostring(defPos.y) ..
        " z=" .. tostring(defPos.z)
    )

    TriggerClientEvent("union:spawn:apply", src, {
        id = char.id,
        unique_id = char.unique_id,
        ped_model = model or char.ped_model or Config.spawn.defaultModel,
        position = {
            x = defPos.x,
            y = defPos.y,
            z = defPos.z
        },
        heading = Config.spawn.defaultHeading,
        health = Config.character.defaultHealth,
        armor = 0,
    })

    print("Spawn.respawnPlayer event triggered for src=" ..
        tostring(src) .. " model=" .. tostring(model)
    )

    return true
end

return Spawn
