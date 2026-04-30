-- bridge/client/kt_target.lua
-- Bridge client vers kt_target
-- Synchronise le personnage actif via StateBags

Bridge.Target = Bridge.create("kt_target")
Bridge.register("kt_target", Bridge.Target)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SYNCHRONISATION PERSONNAGE ACTIF → STATEBAG
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Met à jour le StateBag local avec les données du personnage
-- kt_target (et les autres scripts) peuvent lire LocalPlayer.state.character
local function syncCharacterState(charData)
    if not charData then
        LocalPlayer.state:set("character", nil, false)
        LocalPlayer.state:set("job",       nil, false)
        return
    end

    LocalPlayer.state:set("character", {
        unique_id   = charData.unique_id,
        firstname   = charData.firstname,
        lastname    = charData.lastname,
        gender      = charData.gender,
        job         = charData.job or "unemployed",
        job_grade   = charData.job_grade or 0,
    }, false)

    -- Raccourci job pour les scripts externes
    LocalPlayer.state:set("job", {
        name  = charData.job or "unemployed",
        grade = charData.job_grade or 0,
    }, false)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- API PUBLIQUE — ZONES & ENTITÉS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Ajoute une zone de target (box, sphere, poly…)
function Bridge.Target.addZone(name, coords, options)
    if not Bridge.Target:isAvailable() then
        print(("^3[BRIDGE:kt_target] addZone '%s' ignoré — ressource non disponible^7"):format(tostring(name)))
        return false
    end

    local ok, err = pcall(function()
        exports["kt_target"]:AddTargetZone(name, coords, options)
    end)

    if not ok then
        print(("^1[BRIDGE:kt_target] addZone erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

-- Supprime une zone de target
function Bridge.Target.removeZone(name)
    if not Bridge.Target:isAvailable() then return false end

    local ok, err = pcall(function()
        exports["kt_target"]:RemoveTargetZone(name)
    end)

    if not ok then
        print(("^1[BRIDGE:kt_target] removeZone erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

-- Ajoute des options sur une entité (ped, vehicle, object)
function Bridge.Target.addEntity(entities, options)
    if not Bridge.Target:isAvailable() then return false end

    local ok, err = pcall(function()
        exports["kt_target"]:AddTargetEntity(entities, options)
    end)

    if not ok then
        print(("^1[BRIDGE:kt_target] addEntity erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

-- Supprime des options d'une entité
function Bridge.Target.removeEntity(entities, labels)
    if not Bridge.Target:isAvailable() then return false end

    local ok, err = pcall(function()
        exports["kt_target"]:RemoveTargetEntity(entities, labels)
    end)

    if not ok then
        print(("^1[BRIDGE:kt_target] removeEntity erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

-- Ajoute des options sur un modèle global
function Bridge.Target.addModel(models, options)
    if not Bridge.Target:isAvailable() then return false end

    local ok, err = pcall(function()
        exports["kt_target"]:AddTargetModel(models, options)
    end)

    if not ok then
        print(("^1[BRIDGE:kt_target] addModel erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LIAISON AUX EVENTS UNION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Synchronise le StateBag au spawn
RegisterNetEvent("union:player:spawned", function(character)
    syncCharacterState(character or Client.currentCharacter)
end)

-- Synchronise si le job change
RegisterNetEvent("union:job:updated", function(job, grade)
    if Client.currentCharacter then
        Client.currentCharacter.job       = job
        Client.currentCharacter.job_grade = grade
        syncCharacterState(Client.currentCharacter)
    end
end)

-- Réinitialise au déchargement du personnage
AddEventHandler("union:character:unloaded", function()
    syncCharacterState(nil)
end)

-- Export pour les scripts externes qui veulent lire le personnage actif
-- Usage depuis un autre script : exports["union"]:GetActiveCharacter()
-- (à ajouter dans bridge/client/exports.lua ou fxmanifest)
exports("GetActiveCharacter", function()
    return Client.currentCharacter
end)

exports("GetActiveJob", function()
    if not Client.currentCharacter then return "unemployed", 0 end
    return Client.currentCharacter.job or "unemployed",
           Client.currentCharacter.job_grade or 0
end)
