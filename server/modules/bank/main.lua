-- server/modules/bank/main.lua
-- FIX BK1 : txUniqueId utilise un compteur atomique pour éviter les collisions à la même seconde.
-- FIX BK2 : Bank.transfer est maintenant atomique via une vraie transaction SQL.
--            Si le deposit échoue, le withdraw est rollbacké automatiquement.
-- FIX BK3 : Les handlers net capturent unique_id dès le début pour éviter la race condition
--            si player.currentCharacter change pendant le callback DB.

Bank        = {}
Bank.logger = Logger:child("BANK")

-- FIX BK1 : compteur atomique pour les IDs de transaction
local _txCounter = 0
local function nextTxId()
    _txCounter = _txCounter + 1
    return string.format("TXN_%d_%04d", os.time(), _txCounter % 10000)
end

local function isConnected(src)
    return GetPlayerEndpoint(src) ~= nil
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CORE API
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
    if not uniqueId or not amount or amount <= 0 then
        if callback then callback(false) end
        return
    end

    Database.execute([[
        UPDATE bank_accounts SET balance = balance + ?
        WHERE unique_id = ? AND type = 'personal'
    ]], { amount, uniqueId }, function(result)
        if result then
            Bank.logTransaction(uniqueId, amount, "deposit", description)
            Bank.logger:info(("Dépôt : %d pour %s"):format(amount, uniqueId))
            if callback then callback(true) end
        else
            if callback then callback(false) end
        end
    end)
end

function Bank.withdraw(uniqueId, amount, description, callback)
    if not uniqueId or not amount or amount <= 0 then
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
            WHERE unique_id = ? AND type = 'personal' AND balance >= ?
        ]], { amount, uniqueId, amount }, function(result)
            -- La clause AND balance >= ? assure qu'on ne tombe pas en négatif
            -- même en cas de race condition (deux retraits simultanés)
            if result and result.affectedRows and result.affectedRows > 0 then
                Bank.logTransaction(uniqueId, amount, "withdraw", description)
                Bank.logger:info(("Retrait : %d pour %s"):format(amount, uniqueId))
                if callback then callback(true) end
            else
                -- Solde insuffisant ou race condition
                if callback then callback(false) end
            end
        end)
    end)
end

-- FIX BK2 : transfert atomique via transaction SQL
-- Si l'une des deux opérations échoue, tout est rollbacké.
function Bank.transfer(fromId, toId, amount, description, callback)
    if not fromId or not toId or not amount or amount <= 0 then
        if callback then callback(false) end
        return
    end

    -- Vérifier solde d'abord
    Bank.getBalance(fromId, function(balance)
        if balance < amount then
            if callback then callback(false) end
            return
        end

        -- FIX BK2 : transaction SQL atomique
        Database.transaction({
            {
                query  = "UPDATE bank_accounts SET balance = balance - ? WHERE unique_id = ? AND type = 'personal' AND balance >= ?",
                values = { amount, fromId, amount },
            },
            {
                query  = "UPDATE bank_accounts SET balance = balance + ? WHERE unique_id = ? AND type = 'personal'",
                values = { amount, toId },
            },
        }, function(success)
            if success then
                Bank.logTransaction(fromId, amount, "transfer", "Transfert vers " .. toId)
                Bank.logTransaction(toId,   amount, "deposit",  "Transfert depuis " .. fromId)
                Bank.logger:info(("Transfert : %d de %s vers %s"):format(amount, fromId, toId))
                if callback then callback(true) end
            else
                Bank.logger:warn(("Transfert échoué : %d de %s vers %s"):format(amount, fromId, toId))
                if callback then callback(false) end
            end
        end)
    end)
end

-- FIX BK1 : ID unique via compteur atomique
function Bank.logTransaction(uniqueId, amount, txType, description)
    local txUniqueId = nextTxId()
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
-- NET EVENTS
-- FIX BK3 : capture unique_id au début du handler (avant tout callback async)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:bank:getBalance", function()
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end

    -- FIX BK3 : capturer immédiatement
    local uid = player.currentCharacter.unique_id

    Bank.getBalance(uid, function(balance)
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

    -- FIX BK3
    local uid = player.currentCharacter.unique_id

    Bank.deposit(uid, amount, "Dépôt manuel", function(success)
        if not isConnected(src) then return end
        if success then
            Bank.getBalance(uid, function(balance)
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

    -- FIX BK3
    local uid = player.currentCharacter.unique_id

    Bank.withdraw(uid, amount, "Retrait manuel", function(success)
        if not isConnected(src) then return end
        if success then
            Bank.getBalance(uid, function(balance)
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

    -- FIX BK3
    local fromUid  = player.currentCharacter.unique_id
    local fromName = player.name

    if not target or not target.currentCharacter then
        if isConnected(src) then
            TriggerClientEvent("union:bank:transferResult", src, false, amount)
        end
        return
    end

    -- FIX BK3
    local toUid  = target.currentCharacter.unique_id
    local toName = target.name

    Bank.transfer(fromUid, toUid, amount, "Transfert vers " .. toName, function(success)
        if isConnected(src) then
            TriggerClientEvent("union:bank:transferResult", src, success, amount)
        end
        if success and isConnected(targetId) then
            TriggerClientEvent("union:notify", targetId,
                string.format("Vous avez reçu $%s de %s", amount, fromName), "success", 5000)
        end
    end)
end)

RegisterNetEvent("union:bank:transactions", function()
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end

    -- FIX BK3
    local uid = player.currentCharacter.unique_id

    BankDB.getTransactions(uid, 10, function(transactions)
        if isConnected(src) then
            TriggerClientEvent("union:bank:transactionsReceived", src, transactions or {})
        end
    end)
end)

return Bank