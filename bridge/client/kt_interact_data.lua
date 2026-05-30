-- bridge/client/kt_interact_data.lua
-- Bridge client vers kt_interact (fusion de kt_interact_data + kt_interact_editor).

Bridge.InteractData = Bridge.create("kt_interact")
Bridge.register("kt_interact_data", Bridge.InteractData)

Bridge.InteractData._interactions = {}
Bridge.InteractData._loaded       = false

RegisterNetEvent("kt_interact_data:serverReady", function()
    if Bridge.InteractData._loaded then return end
    TriggerServerEvent("kt_interact_data:requestAll")
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if not Bridge.InteractData:isAvailable() then
        print("^3[BRIDGE:kt_interact_data] kt_interact absent — chargement ignoré^7")
        return
    end
    SetTimeout(1000, function()
        if not Bridge.InteractData._loaded then
            TriggerServerEvent("kt_interact_data:requestAll")
        end
    end)
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= "kt_interact" then return end
    Bridge.InteractData._loaded       = false
    Bridge.InteractData._interactions = {}
    SetTimeout(500, function()
        if not Bridge.InteractData._loaded then
            TriggerServerEvent("kt_interact_data:requestAll")
        end
    end)
end)

RegisterNetEvent("kt_interact_data:loadAll", function(interactions)
    if type(interactions) ~= "table" then
        print("^1[BRIDGE:kt_interact_data] loadAll : données invalides^7")
        return
    end
    Bridge.InteractData._interactions = {}
    local count = 0
    for _, data in ipairs(interactions) do
        if data and data.id then
            Bridge.InteractData._interactions[data.id] = data
            count = count + 1
        end
    end
    Bridge.InteractData._loaded = true
    print(("^2[BRIDGE:kt_interact_data] %d interaction(s) chargée(s)^7"):format(count))
end)

RegisterNetEvent("kt_interact_data:added", function(data)
    if not data or not data.id then return end
    Bridge.InteractData._interactions[data.id] = data
end)

RegisterNetEvent("kt_interact_data:updated", function(data)
    if not data or not data.id then return end
    Bridge.InteractData._interactions[data.id] = data
end)

RegisterNetEvent("kt_interact_data:removed", function(id)
    if not id then return end
    Bridge.InteractData._interactions[id] = nil
end)

function Bridge.InteractData.get(id)
    return Bridge.InteractData._interactions[id]
end

function Bridge.InteractData.getAll()
    local result = {}
    for _, v in pairs(Bridge.InteractData._interactions) do
        result[#result + 1] = v
    end
    return result
end

function Bridge.InteractData.isLoaded()
    return Bridge.InteractData._loaded
end

function Bridge.InteractData.reload()
    Bridge.InteractData._loaded       = false
    Bridge.InteractData._interactions = {}
    TriggerServerEvent("kt_interact_data:requestAll")
end

AddEventHandler("onResourceStop", function(r)
    if r == "kt_interact" then
        Bridge.InteractData._interactions = {}
        Bridge.InteractData._loaded       = false
        print("^3[BRIDGE:kt_interact_data] kt_interact arrêté — cache vidé^7")
    end
end)
