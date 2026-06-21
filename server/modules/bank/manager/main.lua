-- server/modules/bank/manager/main.lua
Bank        = {}
Bank.logger = Logger:child("BANK")

-- SEC-2 : rate limit par joueur/action
local _bankCooldown = {}
local BANK_COOLDOWN = 2000 -- ms entre deux opérations bancaires

local function checkCooldown(src, action)
    local key = tostring(src) .. "_" .. action
    local now = GetGameTimer()
    if _bankCooldown[key] and (now - _bankCooldown[key]) < BANK_COOLDOWN then
        Bank.logger:warn(("Rate limit banque src=%d action=%s"):format(src, action))
        return false
    end
    _bankCooldown[key] = now
    return true
end

AddEventHandler("union:player:dropping", function(src)
    -- Nettoyage cooldowns à la déconnexion
    local prefix = tostring(src) .. "_"
    local toDelete = {}
    for key in pairs(_bankCooldown) do
        if key:sub(1, #prefix) == prefix then toDelete[#toDelete + 1] = key end
    end
    for _, key in ipairs(toDelete) do _bankCooldown[key] = nil end
end)

-- BUG-5 : guard contre double-création de compte
local _accountCreating = {}

local _txCounter = 0
local function nextTxId()
    _txCounter = _txCounter + 1
    return string.format("TXN_%d_%04d", os.time(), _txCounter % 10000)
end

local function isConnected(src) return GetPlayerEndpoint(src) ~= nil end

function Bank.getBalance(uniqueId, callback)
    Database.fetchOne("SELECT balance FROM bank_accounts WHERE unique_id = ? AND type = 'personal'",
        { uniqueId }, function(result)
            if callback then callback(result and result.balance or 0) end
        end)
end

function Bank.deposit(uniqueId, amount, description, callback)
    if not uniqueId or not amount or amount <= 0 then if callback then callback(false) end; return end
    Database.execute("UPDATE bank_accounts SET balance = balance + ? WHERE unique_id = ? AND type = 'personal'",
        { amount, uniqueId }, function(result)
            if result and (result.affectedRows or result) then
                Bank.getBalance(uniqueId, function(newBalance)
                    Bank.logTransaction(uniqueId, amount, "deposit", description, newBalance)
                end)
                Bank.logger:info(("Dépôt : %d pour %s"):format(amount, uniqueId))
                if callback then callback(true) end
            else
                if callback then callback(false) end
            end
        end)
end

function Bank.withdraw(uniqueId, amount, description, callback)
    if not uniqueId or not amount or amount <= 0 then if callback then callback(false) end; return end
    Bank.getBalance(uniqueId, function(balance)
        if balance < amount then if callback then callback(false) end; return end
        Database.execute([[
            UPDATE bank_accounts SET balance = balance - ?
            WHERE unique_id = ? AND type = 'personal' AND balance >= ?
        ]], { amount, uniqueId, amount }, function(result)
            local affected = type(result) == "table" and (result.affectedRows or 0) or (result or 0)
            if affected and affected > 0 then
                Bank.getBalance(uniqueId, function(newBalance)
                    Bank.logTransaction(uniqueId, amount, "withdraw", description, newBalance)
                end)
                Bank.logger:info(("Retrait : %d pour %s"):format(amount, uniqueId))
                if callback then callback(true) end
            else
                if callback then callback(false) end
            end
        end)
    end)
end

function Bank.transfer(fromId, toId, amount, description, callback)
    if not fromId or not toId or not amount or amount <= 0 then if callback then callback(false) end; return end
    Bank.getBalance(fromId, function(balance)
        if balance < amount then if callback then callback(false) end; return end
        Database.transaction({
            { query = "UPDATE bank_accounts SET balance = balance - ? WHERE unique_id = ? AND type = 'personal' AND balance >= ?", values = { amount, fromId, amount } },
            { query = "UPDATE bank_accounts SET balance = balance + ? WHERE unique_id = ? AND type = 'personal'", values = { amount, toId } },
        }, function(success)
            if success then
                Bank.getBalance(fromId, function(b1) Bank.logTransaction(fromId, amount, "transfer_out", "Transfert vers " .. toId, b1) end)
                Bank.getBalance(toId,   function(b2) Bank.logTransaction(toId, amount, "transfer_in", "Transfert depuis " .. fromId, b2) end)
                Bank.logger:info(("Transfert : %d de %s vers %s"):format(amount, fromId, toId))
                if callback then callback(true) end
            else
                Bank.logger:warn(("Transfert échoué : %d de %s vers %s"):format(amount, fromId, toId))
                if callback then callback(false) end
            end
        end)
    end)
end

function Bank.logTransaction(uniqueId, amount, txType, description, balanceAfter)
    local txUniqueId = nextTxId()
    balanceAfter = balanceAfter or 0
    local validTypes = { deposit=true, withdraw=true, transfer_in=true, transfer_out=true, admin=true }
    if not validTypes[txType] then txType = "admin" end
    Database.execute([[
        INSERT INTO bank_transactions (account_id, transaction_uuid, type, amount, balance_after, description)
        SELECT id, ?, ?, ?, ?, ? FROM bank_accounts WHERE unique_id = ? AND type = 'personal' LIMIT 1
    ]], { txUniqueId, txType, amount, balanceAfter, description or "", uniqueId }, function(result)
        if result then Bank.logger:debug("Transaction enregistrée : " .. txUniqueId)
        else Bank.logger:warn("Échec enregistrement transaction pour " .. uniqueId) end
    end)
end

-- BUG-5 : guard d'idempotence pour la création de compte
function Bank.ensureAccount(uniqueId, license, callback)
    if _accountCreating[uniqueId] then
        Bank.logger:warn("Création compte en cours pour uid=" .. uniqueId .. " — doublon ignoré")
        if callback then callback(false) end
        return
    end
    -- Vérifier si le compte existe déjà
    Database.scalar("SELECT COUNT(*) FROM bank_accounts WHERE unique_id = ? AND type = 'personal'",
        { uniqueId }, function(count)
            if count and count > 0 then
                Bank.logger:debug("Compte déjà existant pour uid=" .. uniqueId)
                if callback then callback(true) end
                return
            end
            _accountCreating[uniqueId] = true
            BankDB.createAccount(uniqueId, "personal", function(accountId)
                _accountCreating[uniqueId] = nil
                if callback then callback(accountId ~= nil) end
            end, license)
        end)
end

RegisterNetEvent("union:bank:getBalance", function()
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    local uid = player.currentCharacter.unique_id
    Bank.getBalance(uid, function(balance)
        if isConnected(src) then TriggerClientEvent("union:bank:balanceReceived", src, balance) end
    end)
end)

RegisterNetEvent("union:bank:deposit", function(amount)
    local src = source
    -- SEC-2 : rate limit
    if not checkCooldown(src, "deposit") then
        TriggerClientEvent("union:bank:depositResult", src, false, 0, 0)
        return
    end
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    -- Limite de montant raisonnable
    if amount > 1000000 then
        Bank.logger:warn(("Dépôt suspect src=%d montant=%d"):format(src, amount))
        return
    end
    local uid = player.currentCharacter.unique_id
    Bank.deposit(uid, amount, "Dépôt manuel", function(success)
        if not isConnected(src) then return end
        if success then
            Bank.getBalance(uid, function(balance)
                if isConnected(src) then TriggerClientEvent("union:bank:depositResult", src, true, amount, balance) end
            end)
        else
            TriggerClientEvent("union:bank:depositResult", src, false, amount, 0)
        end
    end)
end)

RegisterNetEvent("union:bank:withdraw", function(amount)
    local src = source
    -- SEC-2 : rate limit
    if not checkCooldown(src, "withdraw") then
        TriggerClientEvent("union:bank:withdrawResult", src, false, 0, 0)
        return
    end
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    if amount > 1000000 then
        Bank.logger:warn(("Retrait suspect src=%d montant=%d"):format(src, amount))
        return
    end
    local uid = player.currentCharacter.unique_id
    Bank.withdraw(uid, amount, "Retrait manuel", function(success)
        if not isConnected(src) then return end
        if success then
            Bank.getBalance(uid, function(balance)
                if isConnected(src) then TriggerClientEvent("union:bank:withdrawResult", src, true, amount, balance) end
            end)
        else
            TriggerClientEvent("union:bank:withdrawResult", src, false, amount, 0)
        end
    end)
end)

RegisterNetEvent("union:bank:transfer", function(targetId, amount)
    local src = source
    -- SEC-2 : rate limit
    if not checkCooldown(src, "transfer") then
        TriggerClientEvent("union:bank:transferResult", src, false, 0)
        return
    end
    local player = PlayerManager.get(src)
    local target = PlayerManager.get(targetId)
    if not player or not player.currentCharacter then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    if amount > 1000000 then return end
    -- Empêcher auto-transfert
    if src == targetId then
        TriggerClientEvent("union:bank:transferResult", src, false, amount)
        return
    end
    local fromUid  = player.currentCharacter.unique_id
    local fromName = player.name
    if not target or not target.currentCharacter then
        if isConnected(src) then TriggerClientEvent("union:bank:transferResult", src, false, amount) end; return
    end
    local toUid  = target.currentCharacter.unique_id
    local toName = target.name
    Bank.transfer(fromUid, toUid, amount, "Transfert vers " .. toName, function(success)
        if isConnected(src) then TriggerClientEvent("union:bank:transferResult", src, success, amount) end
        if success and isConnected(targetId) then
            TriggerClientEvent("union:notify", targetId, string.format("Vous avez reçu $%s de %s", amount, fromName), "success", 5000)
        end
    end)
end)

RegisterNetEvent("union:bank:transactions", function()
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    local uid = player.currentCharacter.unique_id
    BankDB.getTransactions(uid, 10, function(transactions)
        if isConnected(src) then TriggerClientEvent("union:bank:transactionsReceived", src, transactions or {}) end
    end)
end)

return Bank
