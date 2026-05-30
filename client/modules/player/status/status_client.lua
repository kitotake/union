-- client/modules/player/status/status_client.lua
StatusClient        = {}
StatusClient.status = { hunger = 100, thirst = 100, stress = 0 }
StatusClient.isActive = false

RegisterNetEvent("union:status:init", function(status)
    if not status then return end
    StatusClient.status = {
        hunger = status.hunger or 100,
        thirst = status.thirst or 100,
        stress = status.stress or 0
    }
    StatusClient.isActive = true
    LocalPlayer.state:set("hunger", StatusClient.status.hunger, false)
    LocalPlayer.state:set("thirst", StatusClient.status.thirst, false)
    LocalPlayer.state:set("stress", StatusClient.status.stress, false)
    TriggerEvent("union:status:ready", StatusClient.status)
end)

RegisterNetEvent("union:status:updateAll", function(status)
    if not status then return end
    if status.hunger ~= nil then StatusClient.status.hunger = status.hunger end
    if status.thirst ~= nil then StatusClient.status.thirst = status.thirst end
    if status.stress ~= nil then StatusClient.status.stress = status.stress end
    LocalPlayer.state:set("hunger", StatusClient.status.hunger, false)
    LocalPlayer.state:set("thirst", StatusClient.status.thirst, false)
    LocalPlayer.state:set("stress", StatusClient.status.stress, false)
    TriggerEvent("union:status:tick", StatusClient.status)
    TriggerEvent("union:status:changed", nil, nil)
end)

RegisterNetEvent("union:status:update", function(stat, value)
    if not stat or StatusClient.status[stat] == nil then return end
    StatusClient.status[stat] = value
    LocalPlayer.state:set(stat, value, false)
    TriggerEvent("union:status:tick", StatusClient.status)
    TriggerEvent("union:status:changed", stat, value)
end)

RegisterNetEvent("union:status:applyDamage", function(amount)
    local ped = PlayerPedId()
    local hp  = GetEntityHealth(ped)
    if hp > 101 then
        SetEntityHealth(ped, hp - amount)
    end
end)

AddEventHandler("union:character:unloaded", function()
    StatusClient.isActive = false
    StatusClient.status   = { hunger = 100, thirst = 100, stress = 0 }
end)

exports("GetStatus", function()
    return StatusClient.status
end)

exports("SetStat", function(stat, value)
    if not StatusClient.status[stat] then return end
    if not Client.currentCharacter then return end
    StatusClient.status[stat] = math.max(0, math.min(100, math.floor(value + 0.5)))
    LocalPlayer.state:set(stat, StatusClient.status[stat], false)
    TriggerServerEvent("union:status:sync", StatusClient.status)
    TriggerEvent("union:status:changed", stat, StatusClient.status[stat])
end)

exports("AddStat", function(stat, value)
    if not StatusClient.status[stat] then return end
    if not Client.currentCharacter then return end
    StatusClient.status[stat] = math.max(0, math.min(100,
        math.floor(StatusClient.status[stat] + (value or 0) + 0.5)
    ))
    LocalPlayer.state:set(stat, StatusClient.status[stat], false)
    TriggerServerEvent("union:status:sync", StatusClient.status)
    TriggerEvent("union:status:changed", stat, StatusClient.status[stat])
end)

exports("AddPlayerStat", function(stat, value)
    exports["union"]:AddStat(stat, value)
end)

return StatusClient
