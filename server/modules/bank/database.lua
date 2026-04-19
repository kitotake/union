-- server/modules/bank/database.lua
BankDB = {}
BankDB.logger = Logger:child("BANK:DATABASE")

function BankDB.createAccount(uniqueId, accountType, callback)
    local accountNumber = BankDB.generateAccountNumber()
    
    Database.execute(
        "INSERT INTO bank_accounts (account_number, owner_type, owner_id, unique_id, type, balance) VALUES (?, ?, ?, ?, ?, 0)",
        {accountNumber, "character", uniqueId, uniqueId, accountType or "personal"},
        function(result)
            if result and result.insertId then
                BankDB.logger:info("Account created: " .. accountNumber)
                if callback then callback(result.insertId) end
            else
                if callback then callback(nil) end
            end
        end
    )
end

function BankDB.generateAccountNumber()
    local chars = "0123456789"
    local accountNumber = ""
    for i = 1, 10 do
        local rand = math.random(#chars)
        accountNumber = accountNumber .. chars:sub(rand, rand)
    end
    return accountNumber
end

function BankDB.getAccount(uniqueId, callback)
    Database.fetchOne(
        "SELECT * FROM bank_accounts WHERE unique_id = ? AND type = 'personal'",
        {uniqueId},
        callback
    )
end

function BankDB.getTransactions(uniqueId, limit, callback)
    limit = limit or 50
    Database.fetch(
        "SELECT * FROM bank_transactions WHERE account_id = (SELECT id FROM bank_accounts WHERE unique_id = ?) ORDER BY created_at DESC LIMIT ?",
        {uniqueId, limit},
        callback
    )
end

function BankDB.getBalance(uniqueId, callback)
    Database.scalar(
        "SELECT balance FROM bank_accounts WHERE unique_id = ? AND type = 'personal'",
        {uniqueId},
        function(result)
            if callback then callback(result or 0) end
        end
    )
end

return BankDB