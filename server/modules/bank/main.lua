-- server/modules/bank/main.lua
-- FIX #1 : Bank.logTransaction — utilise account_id (INT) correctement via SELECT imbriqué.
--           La version précédente passait unique_id (string) là où account_id (int) était attendu.
-- FIX #2 : "local src = source" dans tous les RegisterNetEvent.
-- FIX #3 : vérification connexion avant TriggerClientEvent.

Bank        = {}
Bank.logger = Logger:child("BANK")

local function isConnected(src)
    return GetPlayerEndpoint(src) ~= nil
end

function Bank.getBalance(uniqueId, callback)
    Database.fetchOne(
        "SELECT balance FROM bank_accounts WHERE unique_id = ? AND type = 'personal'",
        { uniqueId },
        function(result)
            if callback then callback(result and result.balance or 0) end
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
    ]], { amount, uniqueId }, function(result)
        if result then
            Bank.logTransaction(uniqueId, amount, "deposit", description)
            Bank.logger:info("Dépôt : " .. amount .. " pour " .. uniqueId)
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
        ]], { amount, uniqueId }, function(result)
            if result then
                Bank.logTransaction(uniqueId, amount, "withdraw", description)
                Bank.logger:info("Retrait : " .. amount .. " pour " .. uniqueId)
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

    Bank.withdraw(fromId, amount, "Transfert vers " .. toId, function(success)
        if success then
            Bank.deposit(toId, amount, "Transfert depuis " .. fromId, function(depositSuccess)
                if callback then callback(depositSuccess) end
            end)
        else
            if callback then callback(false) end
        end
    end)
end

-- FIX #1 : logTransaction utilise le bon account_id via SELECT imbriqué dans INSERT
function Bank.logTransaction(uniqueId, amount, txType, description)
    local txUniqueId = "TXN_" .. os.time() .. "_" .. math.random(1000, 9999)
    Database.execute([[
        INSERT INTO bank_transactions
            (account_id, unique_id, amount, description, type)
        SELECT id, ?, ?, ?, ?
        FROM bank_accounts
        WHERE unique_id = ? AND type = 'personal'
        LIMIT 1
    ]], { txUniqueId, amount, description or "", txType, uniqueId }, function(result)
        if result then
            Bank.logger:debug("Transaction enregistrée : " .. txUniqueId)
        else
            Bank.logger:warn("Échec enregistrement transaction pour " .. uniqueId)
        end
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NET EVENTS — FIX #2 + FIX #3
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:bank:getBalance", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player or not player.currentCharacter then return end

    Bank.getBalance(player.currentCharacter.unique_id, function(balance)
        -- FIX #3 : vérification connexion
        if isConnected(src) then
            TriggerClientEvent("union:bank:balanceReceived", src, balance)
        end
    end)
end)

RegisterNetEvent("union:bank:deposit", function(amount)
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    Bank.deposit(player.currentCharacter.unique_id, amount, "Dépôt manuel", function(success)
        if not isConnected(src) then return end
        if success then
            Bank.getBalance(player.currentCharacter.unique_id, function(balance)
                if isConnected(src) then
                    TriggerClientEvent("union:bank:depositResult", src, true, amount, balance)
                end
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

    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    Bank.withdraw(player.currentCharacter.unique_id, amount, "Retrait manuel", function(success)
        if not isConnected(src) then return end
        if success then
            Bank.getBalance(player.currentCharacter.unique_id, function(balance)
                if isConnected(src) then
                    TriggerClientEvent("union:bank:withdrawResult", src, true, amount, balance)
                end
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

    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    if not target or not target.currentCharacter then
        if isConnected(src) then
            TriggerClientEvent("union:bank:transferResult", src, false, amount)
        end
        return
    end

    Bank.transfer(
        player.currentCharacter.unique_id,
        target.currentCharacter.unique_id,
        amount,
        "Transfert vers " .. target.name,
        function(success)
            if isConnected(src) then
                TriggerClientEvent("union:bank:transferResult", src, success, amount)
            end
            if success and isConnected(targetId) then
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
        if isConnected(src) then
            TriggerClientEvent("union:bank:transactionsReceived", src, transactions or {})
        end
    end)
end)

return Bank
