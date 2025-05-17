-- server/economy.lua
local Economy = {}
Economy.defaultStartingMoney = 1000

function Economy.givePlayerMoney(playerId, amount)
    local p = GetPlayerFromId(playerId)
    if not p or not p.currentCharacter then return false end
    
    -- Implement money giving logic
    -- ...
    
    TriggerClientEvent("union:updateMoney", playerId, newBalance)
    return true
end

-- Export functions
exports("givePlayerMoney", Economy.givePlayerMoney)