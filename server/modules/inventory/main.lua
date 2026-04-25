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

    local src = player.source

    -- LOCK ATOMIQUE — posé avant tout appel async
    if UnionInventory._loadedPlayers[src] then
        UnionInventory.logger:warn(
            ("loadForPlayer: déjà chargé pour %s — skip"):format(player.name)
        )
        return
    end
    UnionInventory._loadedPlayers[src] = true

    if not isInventoryAvailable() then
        UnionInventory._loadedPlayers[src] = nil
        return
    end

    local inventoryPlayer = {
        source      = src,
        identifier  = uniqueId,
        name        = player.name,
        job         = {
            name  = player.currentCharacter.job or "unemployed",
            grade = player.currentCharacter.job_grade or 0,
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

    local success, err = pcall(function()
        exports["kt_inventory"]:setPlayerInventory(inventoryPlayer)
    end)

    if not success then
        UnionInventory.logger:error(
            ("setPlayerInventory échoué pour %s : %s"):format(player.name, tostring(err))
        )
        UnionInventory._loadedPlayers[src] = nil
        return
    end

    UnionInventory.logger:info(
        ("Inventaire chargé pour %s (%s)"):format(player.name, uniqueId)
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
--     modules/bridge/union/server.lua → server.setPlayerInventory()
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