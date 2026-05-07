-- server/modules/commands/cardlist.lua

RegisterCommand("cardlist", function(source, args)
    local src       = source
    local isConsole = src == 0

    -- Permission check
    if not isConsole then
        local admin = PlayerManager.get(src)

        if not admin or not admin:hasPermission("admin.kick") then
            ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
            return
        end
    end

    Database.fetch([[
        SELECT
            bc.id          AS card_id,
            bc.card_number AS card_number,
            bc.type        AS card_type,
            bc.active      AS active,
            bc.expires_at  AS expires_at,
            bc.created_at  AS created_at,
            bc.unique_id   AS owner_uid,

            ba.balance     AS balance,
            ba.status      AS account_status,
            ba.iban        AS iban,

            c.firstname    AS firstname,
            c.lastname     AS lastname

        FROM bank_cards bc

        LEFT JOIN bank_accounts ba
            ON ba.id = bc.account_id

        LEFT JOIN characters c
            ON c.unique_id COLLATE utf8mb4_unicode_ci =
               bc.unique_id COLLATE utf8mb4_unicode_ci

        ORDER BY bc.created_at DESC
    ]], {}, function(results)

        if not results or #results == 0 then
            if isConsole then
                print("^1[CARDLIST]^7 Aucune carte trouvée.")
            else
                ServerUtils.notifyPlayer(src, "Aucune carte trouvée.", "warning")
            end
            return
        end

        print("^5[CARDLIST] ═══════ " .. #results .. " carte(s) ═══════^7")

        for _, row in ipairs(results) do
            local firstname = row.firstname or "?"
            local lastname  = row.lastname or "?"
            local ownerUid  = row.owner_uid or "?"
            local balance   = tonumber(row.balance) or 0
            local active    = tonumber(row.active) == 1

            local owner

            if row.firstname and row.lastname then
                owner = string.format(
                    "%s %s [%s]",
                    firstname,
                    lastname,
                    ownerUid
                )
            else
                owner = string.format(
                    "^1[PERSONNAGE SUPPRIMÉ]^7 [%s]",
                    ownerUid
                )
            end

            local cardStatus = active and "^2[ACTIVE]^7" or "^1[BLOQUÉE]^7"

            print(string.format(
                " ^3#%d^7 %s ^6%s^7 | Type: %s | Owner: %s | Solde: ^2$%s^7 | Compte: %s | Expire: %s",
                row.card_id or 0,
                cardStatus,
                row.card_number or "?",
                row.card_type or "?",
                owner,
                string.format("%.2f", balance),
                row.account_status or "?",
                tostring(row.expires_at or "?")
            ))
        end

        print("^5═══════════════════════════════════════^7")

        local msg = string.format(
            "%d carte(s) affichée(s) dans la console.",
            #results
        )

        if isConsole then
            print("^2[CARDLIST]^7 " .. msg)
        else
            ServerUtils.notifyPlayer(src, msg, "info")
        end
    end)
end, false)


-- /deletecard <card_id> — supprimer une carte (admin)
RegisterCommand("deletecard", function(source, args)
    local src       = source
    local isConsole = src == 0

    if not isConsole then
        local admin = PlayerManager.get(src)
        if not admin or not admin:hasPermission("admin.all") then
            ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
            return
        end
    end

    local cardId = tonumber(args[1])
    if not cardId then
        local msg = "Usage: /deletecard <card_id>"
        if isConsole then print(msg) else ServerUtils.notifyPlayer(src, msg, "error") end
        return
    end

    Database.execute(
        "DELETE FROM bank_cards WHERE id = ?",
        { cardId },
        function(result)
            local affected = type(result) == "table" and (result.affectedRows or 0) or (result or 0)
            if affected and affected > 0 then
                local msg = string.format("Carte #%d supprimée.", cardId)
                if isConsole then
                    print("[CARDLIST] " .. msg)
                else
                    ServerUtils.notifyPlayer(src, msg, "success")
                    Logger:info(string.format("[CARDLIST] Carte #%d supprimée par %s",
                        cardId, PlayerManager.get(src).name))
                end
            else
                local msg = "Carte introuvable ou déjà supprimée."
                if isConsole then print("[CARDLIST] " .. msg) else ServerUtils.notifyPlayer(src, msg, "error") end
            end
        end
    )
end, false)


-- /blockcard <id> — bloquer la carte d'un joueur (admin)
RegisterCommand("blockcard", function(source, args)
    local src       = source
    local isConsole = src == 0

    if not isConsole then
        local admin = PlayerManager.get(src)
        if not admin or not admin:hasPermission("admin.all") then
            ServerUtils.notifyPlayer(src, "Permission refusée.", "error")
            return
        end
    end

    local targetId = tonumber(args[1])
    if not targetId then
        local msg = "Usage: /blockcard <id>"
        if isConsole then print(msg) else ServerUtils.notifyPlayer(src, msg, "error") end
        return
    end

    local target = PlayerManager.get(targetId)
    if not target or not target.currentCharacter then
        local msg = "Joueur ou personnage introuvable."
        if isConsole then print(msg) else ServerUtils.notifyPlayer(src, msg, "error") end
        return
    end

    local uid = target.currentCharacter.unique_id

    Database.execute(
        "UPDATE bank_cards SET active = 0 WHERE unique_id = ?",
        { uid },
        function(result)
            local affected = type(result) == "table" and (result.affectedRows or 0) or (result or 0)
            if affected and affected > 0 then
                local msg = string.format("Carte de %s bloquée.", target.name)
                if isConsole then print("[CARDLIST] " .. msg) else ServerUtils.notifyPlayer(src, msg, "success") end
                ServerUtils.notifyPlayer(targetId, "Votre carte bancaire a été bloquée par un administrateur.", "error")
                Logger:info(string.format("[CARDLIST] Carte de %s bloquée", target.name))
            else
                local msg = "Aucune carte trouvée pour ce joueur."
                if isConsole then print("[CARDLIST] " .. msg) else ServerUtils.notifyPlayer(src, msg, "error") end
            end
        end
    )
end, false)