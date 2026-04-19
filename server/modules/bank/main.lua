-- server/modules/bank/main.lua
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
            -- Log transaction
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
    
    -- Check balance first
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

RegisterNetEvent("union:bank:getBalance", function()
    local source = source
    local player = PlayerManager.get(source)
    
    if player and player.currentCharacter then
        Bank.getBalance(player.currentCharacter.unique_id, function(balance)
            TriggerClientEvent("union:bank:balanceReceived", source, balance)
        end)
    end
end)

return Bank