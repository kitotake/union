-- server/modules/commands/character.lua
-- FIX #1 : /givechar supprimé — remplacé par exports("GiveCharacter") ci-dessous.
--           Utilisation depuis une autre ressource :
--             exports["union"]:GiveCharacter(targetSrc, "mp_m_freemode_01")
-- FIX #2 : ped_model utilisé à la place de model (colonne réelle).

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EXPORT : GiveCharacter
-- Permet à n'importe quelle ressource de spawner
-- un personnage sur un joueur ciblé.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports("GiveCharacter", function(targetSrc, pedModel, overrides)
    targetSrc = tonumber(targetSrc)
    if not targetSrc then
        Logger:warn("[GiveCharacter] targetSrc invalide")
        return false
    end

    pedModel = pedModel or Config.spawn.defaultModel

    -- FIX #2 : le champ s'appelle ped_model côté client (spawn:apply)
    local charData = {
        ped_model = pedModel,
        position  = Config.spawn.defaultPosition,
        heading   = Config.spawn.defaultHeading,
        health    = Config.character.defaultHealth,
        armor     = 0,
    }

    -- Fusion avec les overrides optionnels (position, health, etc.)
    if type(overrides) == "table" then
        for k, v in pairs(overrides) do
            charData[k] = v
        end
    end

    -- S'assurer que position est une table sérialisable (pas vector3 brut)
    local pos = charData.position
    if type(pos) == "vector3" then
        charData.position = { x = pos.x, y = pos.y, z = pos.z }
    end

    if GetPlayerEndpoint(targetSrc) then
        TriggerClientEvent("union:spawn:apply", targetSrc, charData)
        Logger:info(("[GiveCharacter] Appliqué sur src=%d model=%s"):format(targetSrc, pedModel))
        return true
    else
        Logger:warn(("[GiveCharacter] src=%d non connecté"):format(targetSrc))
        return false
    end
end)


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- COMMANDES ADMIN (inchangées)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- /charinfo <id> — affiche les infos du personnage actif d'un joueur
RegisterCommand("charinfo", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        ServerUtils.notifyPlayer(src, "Usage: /charinfo <id>", "error")
        return
    end

    local target = PlayerManager.get(targetId)
    if not target then
        ServerUtils.notifyPlayer(src, "Joueur introuvable.", "error")
        return
    end

    local char = target.currentCharacter
    if not char then
        ServerUtils.notifyPlayer(src, target.name .. " n'a pas de personnage actif.", "warning")
        return
    end

    local msg = string.format(
        "[CHARINFO] %s | Perso: %s %s | UID: %s | Job: %s (%s) | HP: %s | Armor: %s",
        target.name,
        char.firstname  or "?",
        char.lastname   or "?",
        char.unique_id  or "?",
        char.job        or "unemployed",
        char.job_grade  or 0,
        char.health     or 0,
        char.armor      or 0
    )

    print("^3" .. msg .. "^7")
    ServerUtils.notifyPlayer(src, msg, "info")
end, false)


-- /deletechar <id> <characterId> — supprimer un personnage (admin)
RegisterCommand("deletechar", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("character.delete") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId    = tonumber(args[1])
    local characterId = tonumber(args[2])

    if not targetId or not characterId then
        ServerUtils.notifyPlayer(src, "Usage: /deletechar <id> <characterId>", "error")
        return
    end

    local target = PlayerManager.get(targetId)
    if not target then
        ServerUtils.notifyPlayer(src, "Joueur introuvable.", "error")
        return
    end

    Character.delete(target, characterId, function(success)
        if success then
            ServerUtils.notifyPlayer(src, "Personnage " .. characterId .. " supprimé.", "success")
            ServerUtils.notifyPlayer(targetId, "Un de vos personnages a été supprimé par un admin.", "warning")
        else
            ServerUtils.notifyPlayer(src, "Échec de la suppression.", "error")
        end
    end)
end, false)