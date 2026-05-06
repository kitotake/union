-- server/modules/bank/database.lua
-- FIX : generateAccountNumber avec vérification DB pour éviter les doublons.

BankDB        = {}
BankDB.logger = Logger:child("BANK:DATABASE")

-- FIX : génération sécurisée du numéro de compte
local function generateUniqueAccountNumber(callback)
    local function tryGenerate(attempts)
        if attempts > 10 then
            -- Dernier recours avec timestamp
            local fallback = tostring(os.time()):sub(-10)
            callback(fallback)
            return
        end

        local chars = "0123456789"
        local number = ""
        for _ = 1, 10 do
            number = number .. chars:sub(math.random(#chars), math.random(#chars))
        end

        Database.scalar(
            "SELECT COUNT(*) FROM bank_accounts WHERE account_number = ?",
            { number },
            function(count)
                if not count or count == 0 then
                    callback(number)
                else
                    BankDB.logger:warn("Numéro de compte " .. number .. " déjà utilisé, retry " .. attempts)
                    tryGenerate(attempts + 1)
                end
            end
        )
    end

    tryGenerate(1)
end

function BankDB.createAccount(uniqueId, accountType, callback)
    generateUniqueAccountNumber(function(accountNumber)
        Database.insert(
            "INSERT INTO bank_accounts (account_number, unique_id, owner_identifier, type, status, balance) VALUES (?, ?, ?, ?, ?, 0)",
            { accountNumber, uniqueId, uniqueId, accountType or "personal", "active" },
            function(accountId)
                if accountId then
                    BankDB.logger:info("Compte créé : " .. accountNumber .. " (uid=" .. uniqueId .. ")")
                    if callback then callback(accountId) end
                else
                    BankDB.logger:error("Échec création compte pour uid=" .. tostring(uniqueId))
                    if callback then callback(nil) end
                end
            end
        )
    end)
end

-- Conservé pour compatibilité (utilisé localement)
function BankDB.generateAccountNumber()
    local chars = "0123456789"
    local accountNumber = ""
    for _ = 1, 10 do
        accountNumber = accountNumber .. chars:sub(math.random(#chars), math.random(#chars))
    end
    return accountNumber
end

function BankDB.getAccount(uniqueId, callback)
    Database.fetchOne(
        "SELECT * FROM bank_accounts WHERE unique_id = ? AND type = 'personal'",
        { uniqueId },
        callback
    )
end

function BankDB.getTransactions(uniqueId, limit, callback)
    limit = limit or 50
    Database.fetch(
        "SELECT bt.* FROM bank_transactions bt JOIN bank_accounts ba ON ba.id = bt.account_id WHERE ba.unique_id = ? AND ba.type = 'personal' ORDER BY bt.created_at DESC LIMIT ?",
        { uniqueId, limit },
        callback
    )
end

function BankDB.getBalance(uniqueId, callback)
    Database.scalar(
        "SELECT balance FROM bank_accounts WHERE unique_id = ? AND type = 'personal'",
        { uniqueId },
        function(result)
            if callback then callback(result or 0) end
        end
    )
end

return BankDB
