-- bridge/server/kt_inventory.lua
-- Bridge serveur vers kt_inventory
-- FIX DOUBLE-LOAD : guard _loadedPlayers par uid pour éviter le double chargement
--   de l'inventaire après "ensure union". Après un restart, le client renvoie
--   union:player:joined → spawned → union:player:spawned est déclenché 2x.
--   kt_inventory lève alors : "attempted to load active player's inventory a secondary time".
--   Le guard bloque le second appel à kt_inventory:playerSpawned pour le même uid.

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
-- GUARD ANTI-DOUBLE CHARGEMENT INVENTAIRE
-- Clé : unique_id → timestamp de dernier chargement
-- Fenêtre : 8s (plus large que la fenêtre spawn 5s pour absorber le délai réseau)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local _inventoryLoaded   = {}
local INVENTORY_DEDUP_MS = 8000

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
-- FIX DOUBLE-LOAD : guard _inventoryLoaded par unique_id
AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character then return end

    if not Bridge.Inventory:isAvailable() then
        print(("^3[BRIDGE:kt_inventory] Spawn src=%s — inventaire non chargé (ressource absente)^7"):format(tostring(src)))
        return
    end

    local uid = character.unique_id
    if not uid then return end

    -- Guard anti-double chargement
    local now  = GetGameTimer()
    local last = _inventoryLoaded[uid]
    if last and (now - last) < INVENTORY_DEDUP_MS then
        print(("^3[BRIDGE:kt_inventory] Double chargement inventaire ignoré uid=%s (delta=%dms)^7"):format(
            uid, now - last
        ))
        return
    end
    _inventoryLoaded[uid] = now

    local ok, err = pcall(function()
        TriggerEvent("kt_inventory:playerSpawned", src, uid)
    end)

    if not ok then
        print(("^1[BRIDGE:kt_inventory] Erreur spawn inventaire : %s^7"):format(tostring(err)))
    end
end)

-- Nettoyage du guard à la déconnexion
AddEventHandler("union:player:dropping", function(src, player)
    if player and player.currentCharacter and player.currentCharacter.unique_id then
        _inventoryLoaded[player.currentCharacter.unique_id] = nil
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
