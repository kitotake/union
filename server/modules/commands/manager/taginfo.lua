-- server/modules/commands/manager/taginfo.lua

RegisterNetEvent("union:taginfo:request", function()
    local src = source

    print(("^3[taginfo]^7 Demande reçue de %d"):format(src))

    local player = PlayerManager.get(src)

    if not player then
        print("^1[taginfo]^7 Player introuvable")
        return
    end

    if not player:hasPermission("admin.kick") then
        print("^1[taginfo]^7 Permission refusée")
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    print("^2[taginfo]^7 Permission OK")

    local players = {}

    for _, p in pairs(PlayerManager.getAll()) do
        local uuid = "N/A"

        if p.currentCharacter then
            uuid = p.currentCharacter.unique_id or "N/A"
        end

        print(("[taginfo] %s | ID:%d | UUID:%s"):format(
            p.name or "Unknown",
            p.source,
            tostring(uuid)
        ))

        table.insert(players, {
            serverId = p.source,
            steamName = p.name or ("Player_" .. p.source),
            uniqueId = uuid
        })
    end

    print(("[taginfo] Envoi de %d joueurs"):format(#players))

    TriggerClientEvent("union:taginfo:receive", src, players)

    print("^2[taginfo]^7 Event envoyé")
end)

--------------------------------------------------
-- Relais de l'état "en train d'écrire" (touche T)
-- à tout le monde (les clients filtrent eux-mêmes via la liste players)
--------------------------------------------------

RegisterNetEvent("union:taginfo:typing", function(isTyping)
    local src = source

    TriggerClientEvent("union:taginfo:typingUpdate", -1, src, isTyping)
end)