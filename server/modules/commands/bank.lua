-- server/modules/commands/bank.lua

-- /givemoney <id> <montant> — donner de l'argent à un joueur (admin)
RegisterCommand("givemoney", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.all") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1])
    local amount   = tonumber(args[2])

    if not targetId or not amount or amount <= 0 then
        ServerUtils.notifyPlayer(src, "Usage: /givemoney <id> <montant>", "error")
        return
    end

    local target = PlayerManager.get(targetId)
    if not target or not target.currentCharacter then
        ServerUtils.notifyPlayer(src, "Joueur ou personnage introuvable.", "error")
        return
    end

    Bank.deposit(target.currentCharacter.unique_id, amount, "Don admin", function(success)
        if success then
            ServerUtils.notifyPlayer(src,      string.format("$%s donné à %s.", amount, target.name), "success")
            ServerUtils.notifyPlayer(targetId, string.format("Vous avez reçu $%s d'un administrateur.", amount), "success")
            Logger:info(string.format("[BANK] %s a donné $%s à %s", admin.name, amount, target.name))
        else
            ServerUtils.notifyPlayer(src, "Échec du don.", "error")
        end
    end)
end, false)


-- /removemoney <id> <montant> — retirer de l'argent à un joueur (admin)
RegisterCommand("removemoney", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.all") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1])
    local amount   = tonumber(args[2])

    if not targetId or not amount or amount <= 0 then
        ServerUtils.notifyPlayer(src, "Usage: /removemoney <id> <montant>", "error")
        return
    end

    local target = PlayerManager.get(targetId)
    if not target or not target.currentCharacter then
        ServerUtils.notifyPlayer(src, "Joueur ou personnage introuvable.", "error")
        return
    end

    Bank.withdraw(target.currentCharacter.unique_id, amount, "Retrait admin", function(success)
        if success then
            ServerUtils.notifyPlayer(src,      string.format("$%s retiré à %s.", amount, target.name), "success")
            ServerUtils.notifyPlayer(targetId, string.format("$%s ont été retirés de votre compte par un admin.", amount), "warning")
            Logger:info(string.format("[BANK] %s a retiré $%s à %s", admin.name, amount, target.name))
        else
            ServerUtils.notifyPlayer(src, "Solde insuffisant ou échec.", "error")
        end
    end)
end, false)


-- /checkbalance <id> — voir le solde d'un joueur (admin)
RegisterCommand("checkbalance", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        ServerUtils.notifyPlayer(src, "Usage: /checkbalance <id>", "error")
        return
    end

    local target = PlayerManager.get(targetId)
    if not target or not target.currentCharacter then
        ServerUtils.notifyPlayer(src, "Joueur ou personnage introuvable.", "error")
        return
    end

    Bank.getBalance(target.currentCharacter.unique_id, function(balance)
        local msg = string.format(
            "[BANK] %s (%s) — Solde : $%s",
            target.name,
            target.currentCharacter.unique_id,
            balance
        )
        print("^3" .. msg .. "^7")
        ServerUtils.notifyPlayer(src, msg, "info")
    end)
end, false)


-- /setbalance <id> <montant> — définir le solde exact d'un joueur (admin)
RegisterCommand("setbalance", function(source, args)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.all") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    local targetId = tonumber(args[1])
    local amount   = tonumber(args[2])

    if not targetId or not amount or amount < 0 then
        ServerUtils.notifyPlayer(src, "Usage: /setbalance <id> <montant>", "error")
        return
    end

    local target = PlayerManager.get(targetId)
    if not target or not target.currentCharacter then
        ServerUtils.notifyPlayer(src, "Joueur ou personnage introuvable.", "error")
        return
    end

    Database.execute(
        "UPDATE bank_accounts SET balance = ? WHERE unique_id = ? AND type = 'personal'",
        { amount, target.currentCharacter.unique_id },
        function(result)
            if result then
                ServerUtils.notifyPlayer(src,
                    string.format("Solde de %s défini à $%s.", target.name, amount),
                    "success"
                )
                ServerUtils.notifyPlayer(targetId,
                    string.format("Votre solde a été modifié par un admin : $%s.", amount),
                    "info"
                )
                Logger:info(string.format("[BANK] %s a défini le solde de %s à $%s", admin.name, target.name, amount))
            else
                ServerUtils.notifyPlayer(src, "Échec de la modification du solde.", "error")
            end
        end
    )
end, false)


-- /banktop — top 10 des personnages les plus riches (admin)
RegisterCommand("banktop", function(source)
    local src   = source
    local admin = PlayerManager.get(src)
    if not admin or not admin:hasPermission("admin.kick") then
        ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
        return
    end

    Database.fetch([[
        SELECT c.firstname, c.lastname, c.unique_id, ba.balance
        FROM bank_accounts ba
        JOIN characters c ON c.unique_id = ba.unique_id
        WHERE ba.type = 'personal'
        ORDER BY ba.balance DESC
        LIMIT 10
    ]], {}, function(results)
        if not results or #results == 0 then
            ServerUtils.notifyPlayer(src, "Aucun compte trouvé.", "warning")
            return
        end

        print("^5[BANKTOP] ══ Top 10 ══^7")
        for i, row in ipairs(results) do
            print(string.format(
                "  ^3#%d^7 %s %s — $%s [%s]",
                i,
                row.firstname or "?",
                row.lastname  or "?",
                row.balance   or 0,
                row.unique_id or "?"
            ))
        end

        ServerUtils.notifyPlayer(src, "Top 10 affiché en console.", "info")
    end)
end, false)