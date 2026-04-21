-- server/modules/auth/whitelist.lua
Whitelist = {}
Whitelist.logger = Logger:child("WHITELIST")

-- Vérifier si un joueur est whitelisté
function Whitelist.isAllowed(license, callback)
    if not Config.whitelist or not Config.whitelist.enabled then
        if callback then callback(true) end
        return
    end

    Database.fetchOne(
        "SELECT * FROM whitelist WHERE license = ? AND active = 1",
        { license },
        function(result)
            if callback then callback(result ~= nil) end
        end
    )
end

-- Ajouter un joueur à la whitelist
function Whitelist.add(license, addedBy, callback)
    Database.execute(
        "INSERT IGNORE INTO whitelist (license, added_by) VALUES (?, ?)",
        { license, addedBy or "console" },
        function(result)
            if result then
                Whitelist.logger:info("Whitelist added: " .. license)
                if callback then callback(true) end
            else
                if callback then callback(false) end
            end
        end
    )
end

-- Retirer un joueur de la whitelist
function Whitelist.remove(license, callback)
    Database.execute(
        "UPDATE whitelist SET active = 0 WHERE license = ?",
        { license },
        function(result)
            if callback then callback(result ~= nil) end
        end
    )
end

-- Commandes console/admin
RegisterCommand("wl:add", function(source, args)
    local src     = source
    local license = args[1]

    if not license then
        print("^1Usage: /wl:add <license>^7")
        return
    end

    -- Vérification permission si appelé par un joueur
    if src ~= 0 then
        local admin = PlayerManager.get(src)
        if not admin or not admin:hasPermission("admin.all") then
            ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
            return
        end
    end

    local addedBy = src == 0 and "console" or (PlayerManager.get(src) and PlayerManager.get(src).name or "unknown")

    Whitelist.add(license, addedBy, function(success)
        local msg = success
            and ("Whitelist ajouté : " .. license)
            or  ("Échec whitelist pour : " .. license)
        print((success and "^2" or "^1") .. "[WHITELIST] " .. msg .. "^7")
        if src ~= 0 then
            ServerUtils.notifyPlayer(src, msg, success and "success" or "error")
        end
    end)
end, true)

RegisterCommand("wl:remove", function(source, args)
    local src     = source
    local license = args[1]

    if not license then
        print("^1Usage: /wl:remove <license>^7")
        return
    end

    if src ~= 0 then
        local admin = PlayerManager.get(src)
        if not admin or not admin:hasPermission("admin.all") then
            ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
            return
        end
    end

    Whitelist.remove(license, function(success)
        local msg = success
            and ("Whitelist retiré : " .. license)
            or  ("Échec retrait pour : " .. license)
        print((success and "^2" or "^1") .. "[WHITELIST] " .. msg .. "^7")
        if src ~= 0 then
            ServerUtils.notifyPlayer(src, msg, success and "success" or "error")
        end
    end)
end, true)

-- Vérification automatique à la connexion
-- À appeler dans auth/connect.lua après la vérification des identifiants
function Whitelist.check(src, license, name, deferrals, callback)
    if not Config.whitelist or not Config.whitelist.enabled then
        if callback then callback(true) end
        return
    end

    deferrals.update("Vérification whitelist...")

    Whitelist.isAllowed(license, function(allowed)
        if callback then callback(allowed) end
    end)
end

return Whitelist