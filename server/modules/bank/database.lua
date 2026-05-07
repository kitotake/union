-- server/modules/bank/database.lua
-- FIX BD-1 : generateAccountNumber — boucle locale corrigée (charAt inexistant en Lua).
-- FIX BD-2 : getTransactions — colonne transaction_uuid (pas unique_id) dans la jointure.
-- FIX BD-3 : owner_identifier renseigné avec la licence du joueur si disponible,
--            sinon fallback sur unique_id (la colonne est VARCHAR(60) NOT NULL).

BankDB        = {}
BankDB.logger = Logger:child("BANK:DATABASE")

-- Génère un numéro de compte unique avec vérification DB
local function generateUniqueAccountNumber(callback)
    local function tryGenerate(attempts)
        if attempts > 10 then
            local fallback = tostring(os.time()):sub(-10)
            callback(fallback)
            return
        end

        -- FIX BD-1 : string.sub au lieu de charAt (inexistant en Lua)
        local chars  = "0123456789"
        local number = ""
        for _ = 1, 10 do
            local idx = math.random(1, #chars)
            number = number .. chars:sub(idx, idx)
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

-- FIX BD-3 : owner_identifier est VARCHAR(60) NOT NULL — on passe uniqueId en fallback
-- si la licence n'est pas transmise. Les appelants peuvent passer ownerIdentifier en 4e arg.
function BankDB.createAccount(uniqueId, accountType, callback, ownerIdentifier)
    generateUniqueAccountNumber(function(accountNumber)
        local owner = ownerIdentifier or uniqueId   -- fallback : unique_id si pas de licence

        Database.insert(
            "INSERT INTO bank_accounts (account_number, unique_id, owner_identifier, type, status, balance) VALUES (?, ?, ?, ?, 'active', 0)",
            { accountNumber, uniqueId, owner, accountType or "personal" },
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

-- Gardé pour compatibilité interne (utilisé localement)
function BankDB.generateAccountNumber()
    local chars  = "0123456789"
    local number = ""
    for _ = 1, 10 do
        local idx = math.random(1, #chars)
        number = number .. chars:sub(idx, idx)
    end
    return number
end

function BankDB.getAccount(uniqueId, callback)
    Database.fetchOne(
        "SELECT * FROM bank_accounts WHERE unique_id = ? AND type = 'personal'",
        { uniqueId },
        callback
    )
end

-- FIX BD-2 : la colonne s'appelle transaction_uuid dans bank_transactions (pas unique_id)
function BankDB.getTransactions(uniqueId, limit, callback)
    limit = limit or 50
    Database.fetch(
        [[SELECT bt.id, bt.transaction_uuid, bt.type, bt.amount, bt.balance_after,
                 bt.description, bt.source_identifier, bt.created_at
          FROM bank_transactions bt
          JOIN bank_accounts ba ON ba.id = bt.account_id
          WHERE ba.unique_id = ? AND ba.type = 'personal'
          ORDER BY bt.created_at DESC
          LIMIT ?]],
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
