-- bridge/server/kt_inventory.lua
-- Bridge serveur vers kt_inventory
-- Remplace inventory/main.lua (supprime le guard fragile)

Bridge.Inventory = Bridge.create("kt_inventory")
Bridge.register("kt_inventory", Bridge.Inventory)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- GUARD INTERNE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function inv(fnName, ...)
    if not Bridge.Inventory:isAvailable() then
        print(("^3[BRIDGE:kt_inventory] '%s' ignoré — ressource non disponible^7"):format(fnName))
        return nil
    end
    local args = { ... }
    local ok, result = pcall(function()
        return exports["kt_inventory"][fnName](exports["kt_inventory"], table.unpack(args))
    end)
    if not ok then
        print(("^1[BRIDGE:kt_inventory] Erreur '%s' : %s^7"):format(fnName, tostring(result)))
        return nil
    end
    return result
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- API PUBLIQUE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Bridge.Inventory.addItem(src, itemName, count, metadata)
    count = count or 1
    local result = inv("AddItem", src, itemName, count, metadata)
    return result ~= nil and result ~= false
end

function Bridge.Inventory.removeItem(src, itemName, count, metadata)
    count = count or 1
    local result = inv("RemoveItem", src, itemName, count, metadata)
    return result ~= nil and result ~= false
end

function Bridge.Inventory.getItemCount(src, itemName)
    local result = inv("GetItemCount", src, itemName)
    return result or 0
end

function Bridge.Inventory.canCarry(src, itemName, count)
    count = count or 1
    local result = inv("CanCarryItem", src, itemName, count)
    return result == true
end

-- ── Argent via item "money" ────────────────
function Bridge.Inventory.giveMoney(src, amount)
    if not amount or amount <= 0 then return false end
    return Bridge.Inventory.addItem(src, "money", amount)
end

function Bridge.Inventory.removeMoney(src, amount)
    if not amount or amount <= 0 then return false end
    return Bridge.Inventory.removeItem(src, "money", amount)
end

function Bridge.Inventory.getMoney(src)
    return Bridge.Inventory.getItemCount(src, "money")
end

-- ── Chargement inventaire au spawn ─────────
-- Remplace le AddEventHandler("union:player:spawned") de inventory/main.lua
-- Plus de guard _loadedPlayers : on laisse kt_inventory gérer les doublons lui-même
AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character then return end

    if not Bridge.Inventory:isAvailable() then
        print(("^3[BRIDGE:kt_inventory] Spawn src=%s — inventaire non chargé (ressource absente)^7"):format(tostring(src)))
        return
    end

    -- Notifie kt_inventory que le joueur est prêt
    -- kt_inventory doit écouter cet event ou un export setPlayerInventory
    local ok, err = pcall(function()
        -- Adapter selon l'API réelle de kt_inventory
        -- Option A : export direct
        -- exports["kt_inventory"]:SetPlayerInventory(src, character.unique_id)
        -- Option B : event
        TriggerEvent("kt_inventory:playerSpawned", src, character.unique_id)
    end)

    if not ok then
        print(("^1[BRIDGE:kt_inventory] Erreur spawn inventaire : %s^7"):format(tostring(err)))
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RE-EXPORT vers les autres ressources via Union
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports("AddItem",      Bridge.Inventory.addItem)
exports("RemoveItem",   Bridge.Inventory.removeItem)
exports("GetItemCount", Bridge.Inventory.getItemCount)
exports("CanCarryItem", Bridge.Inventory.canCarry)
exports("GiveMoney",    Bridge.Inventory.giveMoney)
exports("RemoveMoney",  Bridge.Inventory.removeMoney)
exports("GetMoney",     Bridge.Inventory.getMoney)
