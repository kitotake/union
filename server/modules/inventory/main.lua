-- server/modules/inventory/main.lua
-- Intégration kt_inventory dans Union Framework

UnionInventory = {}
UnionInventory.logger = Logger:child("INVENTORY")

-- ──────────────────────────────────────────────────────────────────────────
-- Chargement de l'inventaire d'un personnage depuis kt_inventory
-- Appelé automatiquement par l'event union:player:spawned
-- ──────────────────────────────────────────────────────────────────────────
function UnionInventory.loadForPlayer(player)
    if not player or not player.currentCharacter then
        UnionInventory.logger:error("loadForPlayer: joueur ou personnage invalide")
        return
    end

    local uniqueId = player.currentCharacter.unique_id
    if not uniqueId then
        UnionInventory.logger:error("loadForPlayer: unique_id manquant")
        return
    end

    -- kt_inventory s'attend à recevoir un objet avec .source, .identifier, .name
    -- On construit un objet compatible avec server.setPlayerInventory de kt_inventory
    local inventoryPlayer = {
        source      = player.source,
        identifier  = uniqueId,   -- kt_inventory utilise `identifier` comme owner
        name        = player.name,
        job         = { name = player.currentCharacter.job or "unemployed",
                        grade = player.currentCharacter.job_grade or 0 },
        groups      = {},
        sex         = player.currentCharacter.gender,
        dateofbirth = player.currentCharacter.dateofbirth,
    }

    -- Construction des groupes
    local job = player.currentCharacter.job or "unemployed"
    inventoryPlayer.groups[job] = player.currentCharacter.job_grade or 0
    if player.group and player.group ~= "user" then
        inventoryPlayer.groups[player.group] = 0
    end

    -- Déléguer à kt_inventory
    exports["kt_inventory"]:setPlayerInventory(inventoryPlayer)

    UnionInventory.logger:info(
        ("Inventaire chargé pour %s (%s)"):format(player.name, uniqueId)
    )
end

-- ──────────────────────────────────────────────────────────────────────────
-- Sauvegarde explicite (utilisé avant un changement de personnage)
-- ──────────────────────────────────────────────────────────────────────────
function UnionInventory.save(source)
    -- kt_inventory gère la sauvegarde automatiquement à playerDropped
    -- Cette fonction peut être étendue si nécessaire
    UnionInventory.logger:debug("Sauvegarde inventaire déclenchée pour " .. source)
end

-- ──────────────────────────────────────────────────────────────────────────
-- Helpers publics — wrappers sur les exports kt_inventory
-- ──────────────────────────────────────────────────────────────────────────

--- Ajoute un item à l'inventaire d'un joueur
---@param source number
---@param itemName string
---@param count number
---@param metadata? table
function UnionInventory.addItem(source, itemName, count, metadata)
    return exports["kt_inventory"]:AddItem(source, itemName, count, metadata)
end

--- Retire un item de l'inventaire d'un joueur
---@param source number
---@param itemName string
---@param count number
---@param metadata? table
function UnionInventory.removeItem(source, itemName, count, metadata)
    return exports["kt_inventory"]:RemoveItem(source, itemName, count, metadata)
end

--- Vérifie si un joueur possède un item
---@param source number
---@param itemName string
---@param count? number
---@return number
function UnionInventory.getItemCount(source, itemName, count)
    return exports["kt_inventory"]:GetItemCount(source, itemName)
end

--- Vérifie si un joueur peut porter un item
---@param source number
---@param itemName string
---@param count number
---@return boolean
function UnionInventory.canCarry(source, itemName, count)
    return exports["kt_inventory"]:CanCarryItem(source, itemName, count)
end

--- Donne de l'argent (item money) à un joueur
---@param source number
---@param amount number
function UnionInventory.giveMoney(source, amount)
    if amount <= 0 then return false end
    return UnionInventory.addItem(source, "money", amount)
end

--- Retire de l'argent (item money) d'un joueur
---@param source number
---@param amount number
function UnionInventory.removeMoney(source, amount)
    if amount <= 0 then return false end
    return UnionInventory.removeItem(source, "money", amount)
end

--- Retourne le solde en liquide (item money)
---@param source number
---@return number
function UnionInventory.getMoney(source)
    return UnionInventory.getItemCount(source, "money")
end

-- ──────────────────────────────────────────────────────────────────────────
-- Events
-- ──────────────────────────────────────────────────────────────────────────

-- Chargement automatique après spawn confirmé
AddEventHandler("union:player:spawned", function(source, characterData)
    local player = PlayerManager.get(source)
    if player then
        UnionInventory.loadForPlayer(player)
    end
end)

-- Exports Union pour les autres resources
exports("AddItem",        UnionInventory.addItem)
exports("RemoveItem",     UnionInventory.removeItem)
exports("GetItemCount",   UnionInventory.getItemCount)
exports("CanCarryItem",   UnionInventory.canCarry)
exports("GiveMoney",      UnionInventory.giveMoney)
exports("RemoveMoney",    UnionInventory.removeMoney)
exports("GetMoney",       UnionInventory.getMoney)

return UnionInventory