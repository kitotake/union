-- bridge/client/kt_interact_data.lua
-- Bridge client vers kt_interact_data.
-- Charge les interactions au démarrage et expose une API propre.

Bridge.InteractData = Bridge.create("kt_interact_data")
Bridge.register("kt_interact_data", Bridge.InteractData)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ÉTAT INTERNE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Bridge.InteractData._interactions = {}
Bridge.InteractData._loaded       = false

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CHARGEMENT INITIAL
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if not Bridge.InteractData:isAvailable() then
        print("^3[BRIDGE:kt_interact_data] ressource absente — chargement ignoré^7")
        return
    end

    -- Délai pour laisser kt_target s'initialiser
    SetTimeout(1000, function()
        TriggerServerEvent("kt_interact_data:requestAll")
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RÉCEPTION DES DONNÉES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("kt_interact_data:loadAll", function(interactions)
    if type(interactions) ~= "table" then
        print("^1[BRIDGE:kt_interact_data] loadAll : données invalides^7")
        return
    end

    Bridge.InteractData._interactions = {}

    for _, data in ipairs(interactions) do
        if data and data.id then
            Bridge.InteractData._interactions[data.id] = data
        end
    end

    Bridge.InteractData._loaded = true
    print(("^2[BRIDGE:kt_interact_data] %d interaction(s) chargée(s)^7"):format(#interactions))
end)

-- Ajout live (broadcast admin)
RegisterNetEvent("kt_interact_data:added", function(data)
    if not data or not data.id then return end
    Bridge.InteractData._interactions[data.id] = data
end)

-- Mise à jour live
RegisterNetEvent("kt_interact_data:updated", function(data)
    if not data or not data.id then return end
    Bridge.InteractData._interactions[data.id] = data
end)

-- Suppression live
RegisterNetEvent("kt_interact_data:removed", function(id)
    if not id then return end
    Bridge.InteractData._interactions[id] = nil
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- API PUBLIQUE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

--- Retourne une interaction par son ID.
---@param id string
---@return table|nil
function Bridge.InteractData.get(id)
    return Bridge.InteractData._interactions[id]
end

--- Retourne toutes les interactions sous forme de tableau.
---@return table[]
function Bridge.InteractData.getAll()
    local result = {}
    for _, v in pairs(Bridge.InteractData._interactions) do
        result[#result + 1] = v
    end
    return result
end

--- Retourne true si les interactions sont chargées.
---@return boolean
function Bridge.InteractData.isLoaded()
    return Bridge.InteractData._loaded
end

--- Recharge toutes les interactions depuis le serveur.
function Bridge.InteractData.reload()
    if not Bridge.InteractData:isAvailable() then
        print("^3[BRIDGE:kt_interact_data] reload ignoré — ressource non disponible^7")
        return
    end
    Bridge.InteractData._loaded = false
    Bridge.InteractData._interactions = {}
    TriggerServerEvent("kt_interact_data:requestAll")
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NETTOYAGE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AddEventHandler("union:character:unloaded", function()
    -- On garde le cache en mémoire (les interactions sont globales, pas par joueur)
    -- Mais on peut forcer un rechargement si nécessaire
end)

AddEventHandler("onResourceStop", function(r)
    if r == "kt_interact_data" then
        Bridge.InteractData._interactions = {}
        Bridge.InteractData._loaded       = false
        print("^3[BRIDGE:kt_interact_data] ressource arrêtée — cache vidé^7")
    end
end)