-- server/modules/commands/debug.lua
if not Config.debug then return end

local function isConsole(src)
    return src == 0
end

local function requirePerm(src, perm)
    if isConsole(src) then return true end
    local admin = PlayerManager.get(src)
    return admin and admin:hasPermission(perm)
end

-- /dbg:player <id>
RegisterCommand("dbg:player", function(source, args)
    local src = source
    if not requirePerm(src, "admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1]) or (not isConsole(src) and src or nil)
    if not targetId then
        print("^1[DEBUG] Usage: dbg:player <id>^7")
        return
    end

    local target = PlayerManager.get(targetId)
    if not target then
        print("^1[DEBUG] Joueur " .. targetId .. " introuvable^7")
        ServerUtils.notifyPlayer(src, "Joueur introuvable.", "error")
        return
    end

    print("^5[DEBUG] ══ PLAYER DUMP ══^7")
    print("  source    : " .. tostring(target.source))
    print("  name      : " .. tostring(target.name))
    print("  license   : " .. tostring(target.license))
    print("  discord   : " .. tostring(target.discord))
    print("  group     : " .. tostring(target.group))
    print("  slots     : " .. tostring(target.slots))
    print("  isSpawned : " .. tostring(target.isSpawned))

    if target.currentCharacter then
        local c = target.currentCharacter
        local pos = c.position or {}
        print("^5  ── CHARACTER ──^7")
        print("    id        : " .. tostring(c.id))
        print("    unique_id : " .. tostring(c.unique_id))
        print("    name      : " .. (c.firstname or "?") .. " " .. (c.lastname or "?"))
        print("    gender    : " .. tostring(c.gender))
        print("    model     : " .. tostring(c.model))
        print("    job       : " .. tostring(c.job) .. " (" .. tostring(c.job_grade) .. ")")
        print("    health    : " .. tostring(c.health))
        print("    armor     : " .. tostring(c.armor))
        print("    pos       : " .. tostring(pos.x or 0) .. ", " .. tostring(pos.y or 0) .. ", " .. tostring(pos.z or 0))
        print("    heading   : " .. tostring(c.heading or 0))
    else
        print("^3  (aucun personnage actif)^7")
    end

    ServerUtils.notifyPlayer(src, "Dump de " .. target.name .. " en console.", "info")
end, false)


-- /dbg:server
RegisterCommand("dbg:server", function(source)
    local src = source
    if not requirePerm(src, "admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local stats = PlayerManager.getStats()

    print("^5[DEBUG] ══ SERVER STATS ══^7")
    print("  Joueurs total : " .. stats.total)
    print("  Admins        : " .. stats.admins)
    print("  Modérateurs   : " .. stats.moderators)
    print("  Utilisateurs  : " .. stats.users)
    print("  Ressource     : " .. GetCurrentResourceName())

    ServerUtils.notifyPlayer(src,
        string.format("Serveur: %d joueurs (%d admins, %d modos).",
            stats.total, stats.admins, stats.moderators),
        "info"
    )
end, false)


-- /dbg:db <unique_id>
RegisterCommand("dbg:db", function(source, args)
    local src = source
    if not requirePerm(src, "admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local uid = args[1]
    if not uid then
        print("^1[DEBUG] Usage: dbg:db <unique_id>^7")
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

            local pos = {}
            if result.position then
                local ok, p = pcall(json.decode, tostring(result.position))
                if ok and p then pos = p end
            end

            print("^5[DEBUG] ══ DB CHARACTER ══^7")
            print("  id        : " .. tostring(result.id))
            print("  unique_id : " .. tostring(result.unique_id))
            print("  name      : " .. (result.firstname or "?") .. " " .. (result.lastname or "?"))
            print("  gender    : " .. tostring(result.gender))
            print("  model     : " .. tostring(result.model))
            print("  job       : " .. tostring(result.job))
            print("  pos       : " .. tostring(pos.x or 0) .. ", " .. tostring(pos.y or 0) .. ", " .. tostring(pos.z or 0))
            print("  has_skin  : " .. (result.skin_data and "oui" or "non"))
            print("  created   : " .. tostring(result.created_at))

            ServerUtils.notifyPlayer(src, "DB dump pour " .. uid .. " en console.", "info")
        end
    )
end, false)


-- /dbg:pos
RegisterCommand("dbg:pos", function(source)
    local src = source
    if not requirePerm(src, "admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    if isConsole(src) then
        print("^3[DEBUG] Console: utilisez dbg:player <id> pour voir la position d'un joueur^7")
        return
    end

    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then
        ServerUtils.notifyPlayer(src, "Aucun personnage actif.", "warning")
        return
    end

    local c   = player.currentCharacter
    local pos = c.position or {}
    local msg = string.format(
        "Pos: %.2f / %.2f / %.2f | Heading: %.1f",
        pos.x    or 0,
        pos.y    or 0,
        pos.z    or 0,
        c.heading or 0
    )

    print("^5[DEBUG] " .. player.name .. " — " .. msg .. "^7")
    ServerUtils.notifyPlayer(src, msg, "info")
end, false)