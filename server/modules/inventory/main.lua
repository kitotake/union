-- server/modules/inventory/main.lua
-- FIX : guard anti-double-chargement ajouté
-- La variable _loadingPlayers manquait, ce qui causait une erreur
-- "attempt to index a nil value" dans le bridge kt_inventory/union.

UnionInventory = {}
UnionInventory.logger = Logger:child("INVENTORY")

-- ─────────────────────────────────────────────────────────────
-- Guard anti-double-chargement
-- kt_inventory bridge appelle setPlayerInventory via union:player:spawned.
-- Si union déclenche l'event deux fois (ex: double confirm), ça crashe.
-- Ce guard bloque le second appel.
-- ─────────────────────────────────────────────────────────────
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
-- Nettoyage à la déconnexion
-- ─────────────────────────────────────────────────────────────
AddEventHandler("playerDropped", function()
    local src = source
    UnionInventory._loadedPlayers[src] = nil
end)

-- ─────────────────────────────────────────────────────────────
-- Écoute union:player:spawned pour initialiser l'inventaire
-- Une seule fois par session grâce au guard _loadedPlayers
-- ─────────────────────────────────────────────────────────────
AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character then return end
    if not isInventoryAvailable() then return end

    if UnionInventory._loadedPlayers[src] then
        UnionInventory.logger:warn(
            ("Inventaire déjà chargé pour src=%s — second appel ignoré"):format(tostring(src))
        )
        return
    end

    UnionInventory._loadedPlayers[src] = true
    UnionInventory.logger:info(("Chargement inventaire pour src=%s uid=%s"):format(
        tostring(src), tostring(character and character.unique_id or "?")
    ))
end)

-- ─────────────────────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────────────────────
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