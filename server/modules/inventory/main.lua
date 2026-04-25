-- server/modules/inventory/main.lua

UnionInventory = {}
UnionInventory.logger = Logger:child("INVENTORY")
UnionInventory._loadedPlayers = {}

local function isInventoryAvailable()
    local state = GetResourceState('kt_inventory')
    if state ~= 'started' then
        UnionInventory.logger:warn(
            ("kt_inventory non disponible (état: %s) — opération ignorée"):format(state)
        )
        return false
    end
    return true
end

-- ─────────────────────────────────────────────────────────────
-- loadForPlayer : intentionnellement vide.
-- Le chargement de l'inventaire est géré exclusivement par
-- kt_inventory/modules/bridge/union/server.lua via l'event
-- union:player:spawned. Appeler setPlayerInventory ici
-- provoquerait une erreur "double-load".
-- ─────────────────────────────────────────────────────────────
function UnionInventory.loadForPlayer(player)
    UnionInventory.logger:warn(
        "loadForPlayer appelé directement — ignoré (géré par kt_inventory bridge)"
    )
end

-- Nettoyage à la déconnexion
AddEventHandler("playerDropped", function()
    local src = source
    UnionInventory._loadedPlayers[src] = nil
end)

-- ─────────────────────────────────────────────────────────────
-- ⚠️  PAS DE LISTENER union:player:spawned ICI
--     Le chargement est délégué exclusivement à
--     kt_inventory/modules/bridge/union/server.lua
-- ─────────────────────────────────────────────────────────────

function UnionInventory.save(src)
    UnionInventory.logger:debug("Sauvegarde inventaire pour " .. tostring(src))
end

function UnionInventory.addItem(src, itemName, count, metadata)
    if not isInventoryAvailable() then return false end
    return exports["kt_inventory"]:AddItem(src, itemName, count, metadata)
end

function UnionInventory.removeItem(src, itemName, count, metadata)
    if not isInventoryAvailable() then return false end
    return exports["kt_inventory"]:RemoveItem(src, itemName, count, metadata)
end

function UnionInventory.getItemCount(src, itemName)
    if not isInventoryAvailable() then return 0 end
    return exports["kt_inventory"]:GetItemCount(src, itemName)
end

function UnionInventory.canCarry(src, itemName, count)
    if not isInventoryAvailable() then return false end
    return exports["kt_inventory"]:CanCarryItem(src, itemName, count)
end

function UnionInventory.giveMoney(src, amount)
    if amount <= 0 then return false end
    return UnionInventory.addItem(src, "money", amount)
end

function UnionInventory.removeMoney(src, amount)
    if amount <= 0 then return false end
    return UnionInventory.removeItem(src, "money", amount)
end

function UnionInventory.getMoney(src)
    return UnionInventory.getItemCount(src, "money")
end

exports("AddItem",      UnionInventory.addItem)
exports("RemoveItem",   UnionInventory.removeItem)
exports("GetItemCount", UnionInventory.getItemCount)
exports("CanCarryItem", UnionInventory.canCarry)
exports("GiveMoney",    UnionInventory.giveMoney)
exports("RemoveMoney",  UnionInventory.removeMoney)
exports("GetMoney",     UnionInventory.getMoney)

return UnionInventory