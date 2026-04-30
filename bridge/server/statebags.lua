-- bridge/server/statebags.lua
-- Gestion des StateBags pour synchroniser les données du personnage actif
-- Remplace le pattern exports("GetCurrentCharacter") côté serveur
-- Les scripts externes lisent : Player(src).state.character

StateBags = {}
StateBags.logger = Logger:child("STATEBAGS")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DONNÉES PARTAGÉES AU SPAWN
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Met à jour le StateBag d'un joueur avec son personnage actif
-- replicated = true → visible côté client aussi
function StateBags.setCharacter(src, charData)
    if not src or not charData then return end

    local state = Player(src).state

    -- Données publiques (répliquées côté client)
    state:set("character", {
        unique_id   = charData.unique_id,
        firstname   = charData.firstname,
        lastname    = charData.lastname,
        gender      = charData.gender,
        job         = charData.job or "unemployed",
        job_grade   = charData.job_grade or 0,
    }, true) -- true = répliqué à tous les clients

    -- Job en raccourci
    state:set("job", {
        name  = charData.job or "unemployed",
        grade = charData.job_grade or 0,
    }, true)

    -- Données privées (seulement ce client) pour les scripts côté serveur
    state:set("unique_id", charData.unique_id, false)

    StateBags.logger:debug(("StateBag mis à jour pour src=%s uid=%s"):format(
        tostring(src),
        tostring(charData.unique_id)
    ))
end

-- Efface le StateBag d'un joueur (déconnexion, changement de perso)
function StateBags.clearCharacter(src)
    if not src then return end

    local ok, err = pcall(function()
        local state = Player(src).state
        state:set("character", nil, true)
        state:set("job",       nil, true)
        state:set("unique_id", nil, false)
    end)

    if not ok then
        StateBags.logger:warn("clearCharacter erreur src=" .. tostring(src) .. " : " .. tostring(err))
    end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LECTURE (pour les autres scripts serveur)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function StateBags.getCharacter(src)
    if not src then return nil end
    local ok, result = pcall(function()
        return Player(src).state.character
    end)
    return ok and result or nil
end

function StateBags.getJob(src)
    if not src then return "unemployed", 0 end
    local ok, result = pcall(function()
        return Player(src).state.job
    end)
    if ok and result then
        return result.name or "unemployed", result.grade or 0
    end
    return "unemployed", 0
end

function StateBags.getUniqueId(src)
    if not src then return nil end
    local ok, result = pcall(function()
        return Player(src).state.unique_id
    end)
    return ok and result or nil
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LIAISON AUX EVENTS UNION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Met à jour au spawn confirmé
AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character then return end
    StateBags.setCharacter(src, character)
end)

-- Met à jour si le job change
AddEventHandler("union:job:updated", function(src, job, grade)
    if not src then return end
    local state = Player(src).state
    state:set("job", { name = job, grade = grade }, true)

    -- Mise à jour du champ job dans character aussi
    local char = state.character
    if char then
        char.job       = job
        char.job_grade = grade
        state:set("character", char, true)
    end
end)

-- Efface à la déconnexion
AddEventHandler("playerDropped", function()
    StateBags.clearCharacter(source)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EXPORTS pour les ressources externes
-- Usage : exports["union"]:GetCharacterState(src)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports("GetCharacterState", StateBags.getCharacter)
exports("GetJobState",       StateBags.getJob)
exports("GetUniqueIdState",  StateBags.getUniqueId)

return StateBags
