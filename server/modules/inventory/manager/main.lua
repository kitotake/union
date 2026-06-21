-- server/modules/inventory/manager/main.lua
if not Bridge or not Bridge.Inventory then
    print("^1[INVENTORY] Bridge.Inventory non trouvé — vérifier l'ordre de chargement dans fxmanifest.lua^7")
    return
end

UnionInventory        = {}
UnionInventory.logger = Logger:child("INVENTORY")
UnionInventory.logger:info("Module inventory chargé — délégation vers Bridge.Inventory")

function UnionInventory.addItem(src, itemName, count, metadata)   return Bridge.Inventory.addItem(src, itemName, count, metadata) end
function UnionInventory.removeItem(src, itemName, count, metadata) return Bridge.Inventory.removeItem(src, itemName, count, metadata) end
function UnionInventory.getItemCount(src, itemName)               return Bridge.Inventory.getItemCount(src, itemName) end
function UnionInventory.canCarry(src, itemName, count)            return Bridge.Inventory.canCarry(src, itemName, count) end
function UnionInventory.giveMoney(src, amount)                    return Bridge.Inventory.giveMoney(src, amount) end
function UnionInventory.removeMoney(src, amount)                  return Bridge.Inventory.removeMoney(src, amount) end
function UnionInventory.getMoney(src)                             return Bridge.Inventory.getMoney(src) end

return UnionInventory
