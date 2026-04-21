-- server/modules/commands/taginfo.lua

RegisterNetEvent("union:taginfo:request", function()
    local src = source
    local player = PlayerManager.get(src)

    if not player then return end

    -- Permission : admin ou modérateur uniquement
    if not player:hasPermission("admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local result = {}

    for _, p in pairs(PlayerManager.getAll()) do
        if p.source ~= src then
            local uniqueId = "N/A"
            if p.currentCharacter then
                uniqueId = p.currentCharacter.unique_id or "N/A"
            end

            table.insert(result, {
                serverId  = p.source,
                steamName = p.name or "Inconnu",
                uniqueId  = uniqueId,
            })
        end
    end

    TriggerClientEvent("union:taginfo:receive", src, result)
end)