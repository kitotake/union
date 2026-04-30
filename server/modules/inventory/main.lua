-- fixes/server/modules/inventory/main.lua
-- VERSION CORRIGÉE : supprime le guard _loadedPlayers fragile
-- La logique est déléguée à bridge/server/kt_inventory.lua
-- Ce fichier devient un simple proxy pour la compatibilité descendante

-- IMPORTANT : bridge/server/kt_inventory.lua DOIT être chargé avant ce fichier
-- Vérification au démarrage
if not Bridge or not Bridge.Inventory then
    print("^1[INVENTORY] Bridge.Inventory non trouvé — vérifier l'ordre de chargement dans fxmanifest.lua^7")
    print("^1[INVENTORY] bridge/server/kt_inventory.lua doit être chargé avant server/modules/inventory/main.lua^7")
    return
end

UnionInventory = {}
UnionInventory.logger = Logger:child("INVENTORY")
UnionInventory.logger:info("Module inventory chargé — délégation vers Bridge.Inventory")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- API PUBLIQUE — proxies vers Bridge.Inventory
-- Compatibilité avec le code existant qui appelle UnionInventory.xxx
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function UnionInventory.addItem(src, itemName, count, metadata)
    return Bridge.Inventory.addItem(src, itemName, count, metadata)
end

function UnionInventory.removeItem(src, itemName, count, metadata)
    return Bridge.Inventory.removeItem(src, itemName, count, metadata)
end

function UnionInventory.getItemCount(src, itemName)
    return Bridge.Inventory.getItemCount(src, itemName)
end

function UnionInventory.canCarry(src, itemName, count)
    return Bridge.Inventory.canCarry(src, itemName, count)
end

function UnionInventory.giveMoney(src, amount)
    return Bridge.Inventory.giveMoney(src, amount)
end

function UnionInventory.removeMoney(src, amount)
    return Bridge.Inventory.removeMoney(src, amount)
end

function UnionInventory.getMoney(src)
    return Bridge.Inventory.getMoney(src)
end

-- NOTE : les exports publics (AddItem, RemoveItem, etc.)
-- sont déjà déclarés dans bridge/server/kt_inventory.lua
-- Ne pas les redéclarer ici pour éviter les conflits

return UnionInventory
