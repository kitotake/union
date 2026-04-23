-- server/modules/inventory/main.lua
-- FIX #6 : vérification que kt_inventory est démarré avant tout appel export.
--           Sans ce guard, si kt_inventory est absent/arrêté le framework crash
--           et empêche tout le monde de jouer.

UnionInventory = {}
UnionInventory.logger = Logger:child("INVENTORY")
UnionInventory._loadedPlayers = {}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- GUARD : kt_inventory disponible ?
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function isInventoryAvailable()
    local state = GetResourceState('kt_inventory')
    if state ~= 'started' then
        UnionInventory.logger:warn(
            ("kt_inventory non disponible (état: %s) — opération inventaire ignorée"):format(state)
        )
        return false
    end
    return true
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CHARGEMENT INVENTAIRE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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

    if UnionInventory._loadedPlayers[player.source] == uniqueId then
        UnionInventory.logger:warn(
            ("loadForPlayer: inventaire déjà chargé pour %s (%s) — skip"):format(player.name, uniqueId)
        )
        return
    end

    -- FIX #6 : guard avant l'export
    if not isInventoryAvailable() then return end

    UnionInventory._loadedPlayers[player.source] = uniqueId

    local inventoryPlayer = {
        source      = player.source,
        identifier  = uniqueId,
        name        = player.name,
        job         = {
            name  = player.currentCharacter.job or "unemployed",
            grade = player.currentCharacter.job_grade or 0
        },
        groups      = {},
        sex         = player.currentCharacter.gender,
        dateofbirth = player.currentCharacter.dateofbirth,
    }

    local job = player.currentCharacter.job or "unemployed"
    inventoryPlayer.groups[job] = player.currentCharacter.job_grade or 0
    if player.group and player.group ~= "user" then
        inventoryPlayer.groups[player.group] = 0
    end

    exports["kt_inventory"]:setPlayerInventory(inventoryPlayer)

    UnionInventory.logger:info(
        ("Inventaire chargé pour %s (%s)"):format(player.name, uniqueId)
    )
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NETTOYAGE À LA DÉCONNEXION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AddEventHandler("playerDropped", function()
    local src = source
    UnionInventory._loadedPlayers[src] = nil
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SAUVEGARDE EXPLICITE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function UnionInventory.save(source)
    UnionInventory.logger:debug("Sauvegarde inventaire déclenchée pour " .. source)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS PUBLICS — FIX #6 : guard sur chaque export
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function UnionInventory.addItem(source, itemName, count, metadata)
    if not isInventoryAvailable() then return false end
    return exports["kt_inventory"]:AddItem(source, itemName, count, metadata)
end

function UnionInventory.removeItem(source, itemName, count, metadata)
    if not isInventoryAvailable() then return false end
    return exports["kt_inventory"]:RemoveItem(source, itemName, count, metadata)
end

function UnionInventory.getItemCount(source, itemName)
    if not isInventoryAvailable() then return 0 end
    return exports["kt_inventory"]:GetItemCount(source, itemName)
end

function UnionInventory.canCarry(source, itemName, count)
    if not isInventoryAvailable() then return false end
    return exports["kt_inventory"]:CanCarryItem(source, itemName, count)
end

function UnionInventory.giveMoney(source, amount)
    if amount <= 0 then return false end
    return UnionInventory.addItem(source, "money", amount)
end

function UnionInventory.removeMoney(source, amount)
    if amount <= 0 then return false end
    return UnionInventory.removeItem(source, "money", amount)
end

function UnionInventory.getMoney(source)
    return UnionInventory.getItemCount(source, "money")
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ÉCOUTE SPAWN POUR CHARGER L'INVENTAIRE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AddEventHandler("union:player:spawned", function(src, character)
    local player = PlayerManager.get(src)
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