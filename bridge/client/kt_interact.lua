-- bridge/client/kt_interact.lua
-- Bridge client vers kt_interact
-- Gère l'activation/désactivation des interactions selon l'état du personnage

Bridge.Interact = Bridge.create("kt_interact")
Bridge.register("kt_interact", Bridge.Interact)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REGISTRE LOCAL DES INTERACTIONS
-- Stocke toutes les interactions enregistrées pour les
-- réactiver automatiquement si kt_interact redémarre
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Bridge.Interact._registered = {}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- API PUBLIQUE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Ajoute une interaction
-- options = { id, label, icon, distance, action, job, canInteract }
function Bridge.Interact.add(options)
    if not options or not options.id then
        print("^1[BRIDGE:kt_interact] add : options.id manquant^7")
        return false
    end

    -- Sauvegarde pour restauration si ressource redémarre
    Bridge.Interact._registered[options.id] = options

    if not Bridge.Interact:isAvailable() then
        print(("^3[BRIDGE:kt_interact] add '%s' différé — ressource non disponible^7"):format(options.id))
        return false
    end

    -- Vérification job si requis
    if options.job then
        local currentJob = Client.currentCharacter and Client.currentCharacter.job or "unemployed"
        if type(options.job) == "string" and options.job ~= currentJob then
            return false
        end
        if type(options.job) == "table" then
            local allowed = false
            for _, j in ipairs(options.job) do
                if j == currentJob then allowed = true; break end
            end
            if not allowed then return false end
        end
    end

    local ok, err = pcall(function()
        exports["kt_interact"]:AddInteraction(options)
    end)

    if not ok then
        print(("^1[BRIDGE:kt_interact] add erreur : %s^7"):format(tostring(err)))
        return false
    end

    return true
end

-- Supprime une interaction par son id
function Bridge.Interact.remove(id)
    if not id then return false end

    Bridge.Interact._registered[id] = nil

    if not Bridge.Interact:isAvailable() then return false end

    local ok, err = pcall(function()
        exports["kt_interact"]:RemoveInteraction(id)
    end)

    if not ok then
        print(("^1[BRIDGE:kt_interact] remove erreur : %s^7"):format(tostring(err)))
        return false
    end

    return true
end

-- Active toutes les interactions enregistrées
function Bridge.Interact.enableAll()
    if not Bridge.Interact:isAvailable() then return end

    for id, options in pairs(Bridge.Interact._registered) do
        Bridge.Interact.add(options)
    end

    print(("^2[BRIDGE:kt_interact] %d interaction(s) activée(s)^7"):format(
        Bridge.Interact._count()
    ))
end

-- Désactive toutes les interactions
function Bridge.Interact.disableAll()
    if not Bridge.Interact:isAvailable() then return end

    for id, _ in pairs(Bridge.Interact._registered) do
        pcall(function()
            exports["kt_interact"]:RemoveInteraction(id)
        end)
    end
end

function Bridge.Interact._count()
    local n = 0
    for _ in pairs(Bridge.Interact._registered) do n = n + 1 end
    return n
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RESTAURATION SI LA RESSOURCE REDÉMARRE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AddEventHandler("onResourceStart", function(r)
    if r == "kt_interact" and Client.currentCharacter then
        Wait(500) -- laisse kt_interact s'initialiser
        Bridge.Interact.enableAll()
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LIAISON AUX EVENTS UNION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:player:spawned", function()
    Wait(600) -- après le spawn complet
    Bridge.Interact.enableAll()
end)

AddEventHandler("union:character:unloaded", function()
    Bridge.Interact.disableAll()
end)

RegisterNetEvent("union:job:updated", function()
    -- Recharge les interactions filtrées par job
    Bridge.Interact.disableAll()
    Wait(100)
    Bridge.Interact.enableAll()
end)
