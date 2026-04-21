-- server/modules/commands/debug.lua

if not Config.debug then return end


-- /dbg:player <id> — dump complet d'un joueur en console
RegisterCommand("dbg:player", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.kick") then return end

    local targetId = tonumber(args[1]) or src
    local target   = PlayerManager.get(targetId)

    if not target then
        print("^1[DEBUG] Joueur " .. targetId .. " introuvable^7")
        return
    end

    print("^5[DEBUG] ══ PLAYER DUMP ══^7")
    print("  source    : " .. tostring(target.source))
    print("  name      : " .. tostring(target.name))
    print("  license   : " .. tostring(target.license))
    print("  discord   : " .. tostring(target.discord))
    print("  group     : " .. tostring(target.group))
    print("  permission: " .. tostring(target.permission))
    print("  isSpawned : " .. tostring(target.isSpawned))

    if target.currentCharacter then
        local c = target.currentCharacter
        print("^5  ── CHARACTER ──^7")
        print("    id        : " .. tostring(c.id))
        print("    unique_id : " .. tostring(c.unique_id))
        print("    name      : " .. (c.firstname or "?") .. " " .. (c.lastname or "?"))
        print("    gender    : " .. tostring(c.gender))
        print("    model     : " .. tostring(c.model))
        print("    job       : " .. tostring(c.job) .. " (" .. tostring(c.job_grade) .. ")")
        print("    health    : " .. tostring(c.health))
        print("    armor     : " .. tostring(c.armor))
        print("    pos       : " .. tostring(c.position_x) .. ", " .. tostring(c.position_y) .. ", " .. tostring(c.position_z))
    else
        print("^3  (aucun personnage actif)^7")
    end

    ServerUtils.notifyPlayer(src, "Dump de " .. target.name .. " en console.", "info")
end, false)


-- /dbg:server — stats générales du serveur
RegisterCommand("dbg:server", function(source)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.kick") then return end

    local stats = PlayerManager.getStats()

    print("^5[DEBUG] ══ SERVER STATS ══^7")
    print("  Joueurs total : " .. stats.total)
    print("  Admins        : " .. stats.admins)
    print("  Modérateurs   : " .. stats.moderators)
    print("  Utilisateurs  : " .. stats.users)
    print("  Ressource     : " .. GetCurrentResourceName())

    ServerUtils.notifyPlayer(src,
        string.format("Serveur: %d joueurs (%d admins, %d modos). Voir console.",
            stats.total, stats.admins, stats.moderators),
        "info"
    )
end, false)


-- /dbg:db <unique_id> — vérifie qu'un personnage existe en DB
RegisterCommand("dbg:db", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.kick") then return end

    local uid = args[1]
    if not uid then
        ServerUtils.notifyPlayer(src, "Usage: /dbg:db <unique_id>", "error")
        return
    end

    Database.fetchOne(
        "SELECT c.*, ca.skin_data FROM characters c LEFT JOIN character_appearances ca ON ca.unique_id = c.unique_id WHERE c.unique_id = ?",
        { uid },
        function(result)
            if not result then
                print("^1[DEBUG] Aucun personnage trouvé pour UID: " .. uid .. "^7")
                ServerUtils.notifyPlayer(src, "UID introuvable en DB.", "error")
                return
            end

            print("^5[DEBUG] ══ DB CHARACTER ══^7")
            print("  id        : " .. tostring(result.id))
            print("  unique_id : " .. tostring(result.unique_id))
            print("  name      : " .. (result.firstname or "?") .. " " .. (result.lastname or "?"))
            print("  gender    : " .. tostring(result.gender))
            print("  model     : " .. tostring(result.model))
            print("  job       : " .. tostring(result.job))
            print("  has_skin  : " .. (result.skin_data and "oui" or "non"))
            print("  created   : " .. tostring(result.created_at))

            ServerUtils.notifyPlayer(src, "DB dump pour " .. uid .. " en console.", "info")
        end
    )
end, false)


-- /dbg:pos — affiche la position sauvegardée du personnage actif
RegisterCommand("dbg:pos", function(source)
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then
        ServerUtils.notifyPlayer(src, "Aucun personnage actif.", "warning")
        return
    end

    local c = player.currentCharacter
    local msg = string.format(
        "Pos: %.2f / %.2f / %.2f | Heading: %.1f",
        c.position_x or 0,
        c.position_y or 0,
        c.position_z or 0,
        c.heading    or 0
    )

    print("^5[DEBUG] " .. player.name .. " — " .. msg .. "^7")
    ServerUtils.notifyPlayer(src, msg, "info")
end, false)