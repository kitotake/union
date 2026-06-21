-- server/modules/commands/manager/taginfo.lua
RegisterNetEvent("union:taginfo:request", function()
    local src = source

    local player = PlayerManager.get(src)

    if not player then
        return
    end

    if not player:hasPermission("admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local result = {}

    for _, p in pairs(PlayerManager.getAll()) do
        local uniqueId = "N/A"

        if p.currentCharacter then
            uniqueId = p.currentCharacter.unique_id or "N/A"
        end

        table.insert(result, {
            serverId = p.source,
            steamName = p.name or ("Player_" .. p.source),
            uniqueId = uniqueId
        })
    end

    print(("[TAGINFO] Envoi de %s joueurs à %s"):format(
        #result,
        src
    ))

    TriggerClientEvent(
        "union:taginfo:receive",
        src,
        result
    )
end)