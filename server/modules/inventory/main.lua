-- server/modules/inventory/main.lua
-- Intégration kt_inventory dans Union Framework
-- FIX: suppression du double-chargement (le bridge union/server.lua gère déjà setPlayerInventory)
--      L'event union:player:spawned est retiré ici — il est géré dans modules/bridge/union/server.lua

UnionInventory = {}
UnionInventory.logger = Logger:child("INVENTORY")
UnionInventory._loadedPlayers = {} -- Guard contre les doubles chargements

-- ──────────────────────────────────────────────────────────────────────────
-- Chargement de l'inventaire d'un personnage depuis kt_inventory
-- Appelé depuis le bridge union/server.lua via union:player:spawned
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

    -- Guard anti double-chargement
    if UnionInventory._loadedPlayers[player.source] == uniqueId then
        UnionInventory.logger:warn(
            ("loadForPlayer: inventaire déjà chargé pour %s (%s) — skip"):format(player.name, uniqueId)
        )
        return
    end
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

-- ──────────────────────────────────────────────────────────────────────────
-- Nettoyage du guard à la déconnexion
-- ──────────────────────────────────────────────────────────────────────────
AddEventHandler("playerDropped", function()
    local src = source
    UnionInventory._loadedPlayers[src] = nil
end)

-- ──────────────────────────────────────────────────────────────────────────
-- Sauvegarde explicite (avant changement de personnage)
-- ──────────────────────────────────────────────────────────────────────────
function UnionInventory.save(source)
    UnionInventory.logger:debug("Sauvegarde inventaire déclenchée pour " .. source)
end

-- ──────────────────────────────────────────────────────────────────────────
-- Helpers publics — wrappers sur les exports kt_inventory
-- ──────────────────────────────────────────────────────────────────────────

function UnionInventory.addItem(source, itemName, count, metadata)
    return exports["kt_inventory"]:AddItem(source, itemName, count, metadata)
end

function UnionInventory.removeItem(source, itemName, count, metadata)
    return exports["kt_inventory"]:RemoveItem(source, itemName, count, metadata)
end

function UnionInventory.getItemCount(source, itemName, count)
    return exports["kt_inventory"]:GetItemCount(source, itemName)
end

function UnionInventory.canCarry(source, itemName, count)
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

-- ──────────────────────────────────────────────────────────────────────────
-- NOTE : l'event union:player:spawned est intentionnellement ABSENT ici.
-- Le bridge (modules/bridge/union/server.lua dans kt_inventory) écoute
-- union:player:spawned et appelle server.setPlayerInventory directement.
-- Avoir les deux déclencherait un double chargement → erreur "active player".
-- ──────────────────────────────────────────────────────────────────────────

-- Exports Union pour les autres resources
exports("AddItem",        UnionInventory.addItem)
exports("RemoveItem",     UnionInventory.removeItem)
exports("GetItemCount",   UnionInventory.getItemCount)
exports("CanCarryItem",   UnionInventory.canCarry)
exports("GiveMoney",      UnionInventory.giveMoney)
exports("RemoveMoney",    UnionInventory.removeMoney)
exports("GetMoney",       UnionInventory.getMoney)

return UnionInventory