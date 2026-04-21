-- client/modules/commands/bank.lua

-- /balance — affiche le solde du compte
RegisterCommand("balance", function()
    if not Character.current then
        Notifications.send("Aucun personnage actif.", "warning")
        return
    end
    TriggerServerEvent("union:bank:getBalance")
end, false)

-- /deposit <montant> — déposer de l'argent
RegisterCommand("deposit", function(source, args)
    if not Character.current then
        Notifications.send("Aucun personnage actif.", "warning")
        return
    end

    local amount = tonumber(args[1])
    if not amount or amount <= 0 then
        Notifications.send("Usage: /deposit <montant>", "error")
        return
    end

    TriggerServerEvent("union:bank:deposit", amount)
end, false)

-- /withdraw <montant> — retirer de l'argent
RegisterCommand("withdraw", function(source, args)
    if not Character.current then
        Notifications.send("Aucun personnage actif.", "warning")
        return
    end

    local amount = tonumber(args[1])
    if not amount or amount <= 0 then
        Notifications.send("Usage: /withdraw <montant>", "error")
        return
    end

    TriggerServerEvent("union:bank:withdraw", amount)
end, false)

-- /transfer <id> <montant> — transférer de l'argent à un joueur
RegisterCommand("transfer", function(source, args)
    if not Character.current then
        Notifications.send("Aucun personnage actif.", "warning")
        return
    end

    local targetId = tonumber(args[1])
    local amount   = tonumber(args[2])

    if not targetId or not amount or amount <= 0 then
        Notifications.send("Usage: /transfer <id> <montant>", "error")
        return
    end

    TriggerServerEvent("union:bank:transfer", targetId, amount)
end, false)

-- /transactions — historique des 10 dernières transactions
RegisterCommand("transactions", function()
    if not Character.current then
        Notifications.send("Aucun personnage actif.", "warning")
        return
    end
    TriggerServerEvent("union:bank:transactions")
end, false)

-- Réceptions depuis le serveur
RegisterNetEvent("union:bank:balanceReceived", function(balance)
    Notifications.send(
        string.format("Solde : $%s", balance),
        "info"
    )
end)

RegisterNetEvent("union:bank:depositResult", function(success, amount, balance)
    if success then
        Notifications.send(
            string.format("Dépôt de $%s effectué. Nouveau solde : $%s", amount, balance),
            "success"
        )
    else
        Notifications.send("Dépôt échoué.", "error")
    end
end)

RegisterNetEvent("union:bank:withdrawResult", function(success, amount, balance)
    if success then
        Notifications.send(
            string.format("Retrait de $%s effectué. Nouveau solde : $%s", amount, balance),
            "success"
        )
    else
        Notifications.send("Solde insuffisant ou retrait échoué.", "error")
    end
end)

RegisterNetEvent("union:bank:transferResult", function(success, amount)
    if success then
        Notifications.send(
            string.format("Transfert de $%s effectué.", amount),
            "success"
        )
    else
        Notifications.send("Transfert échoué.", "error")
    end
end)

RegisterNetEvent("union:bank:transactionsReceived", function(transactions)
    if not transactions or #transactions == 0 then
        Notifications.send("Aucune transaction trouvée.", "warning")
        return
    end

    print("^2[BANK] Historique des transactions :")
    for _, t in ipairs(transactions) do
        local sign = t.type == "deposit" and "^2+" or "^1-"
        print(string.format(
            "  %s$%s^7 — %s — %s",
            sign, t.amount, t.type, t.description or "N/A"
        ))
    end

    Notifications.send(#transactions .. " transaction(s). (voir console)", "info")
end)