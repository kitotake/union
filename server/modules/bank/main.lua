-- server/modules/bank/main.lua
-- FIX #8 : remplacement de "local source = source" par "local src = source"
--           dans tous les NetEvents pour éviter le shadowing de la globale FiveM.

Bank = {}
Bank.logger = Logger:child("BANK")

function Bank.getBalance(uniqueId, callback)
    Database.fetchOne(
        "SELECT balance FROM bank_accounts WHERE unique_id = ? AND type = 'personal'",
        {uniqueId},
        function(result)
            if result then
                if callback then callback(result.balance or 0) end
            else
                if callback then callback(0) end
            end
        end
    )
end

function Bank.deposit(uniqueId, amount, description, callback)
    if not uniqueId or amount <= 0 then
        if callback then callback(false) end
        return
    end

    Database.execute([[
        UPDATE bank_accounts SET balance = balance + ?
        WHERE unique_id = ? AND type = 'personal'
    ]], {amount, uniqueId}, function(result)
        if result then
            Bank.logTransaction(uniqueId, amount, "deposit", description)
            Bank.logger:info("Deposit: " .. amount .. " for " .. uniqueId)
            if callback then callback(true) end
        else
            if callback then callback(false) end
        end
    end)
end

function Bank.withdraw(uniqueId, amount, description, callback)
    if not uniqueId or amount <= 0 then
        if callback then callback(false) end
        return
    end

    Bank.getBalance(uniqueId, function(balance)
        if balance < amount then
            if callback then callback(false) end
            return
        end

        Database.execute([[
            UPDATE bank_accounts SET balance = balance - ?
            WHERE unique_id = ? AND type = 'personal'
        ]], {amount, uniqueId}, function(result)
            if result then
                Bank.logTransaction(uniqueId, amount, "withdraw", description)
                Bank.logger:info("Withdrawal: " .. amount .. " for " .. uniqueId)
                if callback then callback(true) end
            else
                if callback then callback(false) end
            end
        end)
    end)
end

function Bank.transfer(fromId, toId, amount, description, callback)
    if not fromId or not toId or amount <= 0 then
        if callback then callback(false) end
        return
    end

    Bank.withdraw(fromId, amount, "Transfer to " .. toId, function(success)
        if success then
            Bank.deposit(toId, amount, "Transfer from " .. fromId, function(depositSuccess)
                if callback then callback(depositSuccess) end
            end)
        else
            if callback then callback(false) end
        end
    end)
end

function Bank.logTransaction(accountId, amount, txType, description)
    local uniqueId = "TXN_" .. os.time() .. "_" .. math.random(1000, 9999)
    Database.execute([[
        INSERT INTO bank_transactions
        (account_id, unique_id, amount, description, type)
        SELECT id, ?, ?, ?, ? FROM bank_accounts WHERE unique_id = ?
    ]], {uniqueId, amount, description, txType, accountId}, function()
        Bank.logger:debug("Transaction logged: " .. uniqueId)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NET EVENTS — FIX #8 : src au lieu de local source = source
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:bank:getBalance", function()
    local src    = source
    local player = PlayerManager.get(src)

    if player and player.currentCharacter then
        Bank.getBalance(player.currentCharacter.unique_id, function(balance)
            TriggerClientEvent("union:bank:balanceReceived", src, balance)
        end)
    end
end)

RegisterNetEvent("union:bank:deposit", function(amount)
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end

    Bank.deposit(player.currentCharacter.unique_id, amount, "Dépôt manuel", function(success)
        if success then
            Bank.getBalance(player.currentCharacter.unique_id, function(balance)
                TriggerClientEvent("union:bank:depositResult", src, true, amount, balance)
            end)
        else
            TriggerClientEvent("union:bank:depositResult", src, false, amount, 0)
        end
    end)
end)

RegisterNetEvent("union:bank:withdraw", function(amount)
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end

    Bank.withdraw(player.currentCharacter.unique_id, amount, "Retrait manuel", function(success)
        if success then
            Bank.getBalance(player.currentCharacter.unique_id, function(balance)
                TriggerClientEvent("union:bank:withdrawResult", src, true, amount, balance)
            end)
        else
            TriggerClientEvent("union:bank:withdrawResult", src, false, amount, 0)
        end
    end)
end)

RegisterNetEvent("union:bank:transfer", function(targetId, amount)
    local src    = source
    local player = PlayerManager.get(src)
    local target = PlayerManager.get(targetId)

    if not player or not player.currentCharacter then return end
    if not target or not target.currentCharacter then
        TriggerClientEvent("union:bank:transferResult", src, false, amount)
        return
    end

    Bank.transfer(
        player.currentCharacter.unique_id,
        target.currentCharacter.unique_id,
        amount,
        "Transfert vers " .. target.name,
        function(success)
            TriggerClientEvent("union:bank:transferResult", src, success, amount)
            if success then
                TriggerClientEvent("union:notify", targetId,
                    string.format("Vous avez reçu $%s de %s", amount, player.name), "success", 5000)
            end
        end
    )
end)

RegisterNetEvent("union:bank:transactions", function()
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end

    BankDB.getTransactions(player.currentCharacter.unique_id, 10, function(transactions)
        TriggerClientEvent("union:bank:transactionsReceived", src, transactions or {})
    end)
end)

return Bank