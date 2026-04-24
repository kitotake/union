-- ============================================================
--  server/modules/character/characterManager.lua
--  Système de gestion de personnages - Côté Serveur
-- ============================================================

local MAX_SLOTS_DEFAULT = 1  -- slots par défaut si non défini en BDD

-- ============================================================
--  Utilitaire : récupère les personnages d'un joueur depuis la BDD
--  Retourne : { slots = N, characters = { {id, name, model, x, y, z, heading, skin}, ... } }
-- ============================================================
local function fetchPlayerData(license)
    -- Adaptez cette requête à votre ORM / framework (oxmysql, ghmattimysql, etc.)
    local result = exports.oxmysql:executeSync(
    "SELECT id, firstname, lastname, model, position, skin, slots FROM characters WHERE identifier = ?",
    { license }
)

    if not result or #result == 0 then
        return { slots = MAX_SLOTS_DEFAULT, characters = {} }
    end

    local slots = result[1].slots or MAX_SLOTS_DEFAULT
    local characters = {}

    for _, row in ipairs(result) do
        table.insert(characters, {
            id      = row.id,
            name    = row.name,
            model   = row.model   or "mp_m_freemode_01",
            x       = row.pos_x   or 0.0,
            y       = row.pos_y   or 0.0,
            z       = row.pos_z   or 0.0,
            heading = row.heading or 0.0,
            skin    = row.skin    -- JSON string sérialisé
        })
    end

    return { slots = slots, characters = characters }
end

-- ============================================================
--  Valide et sécurise une position (évite de spawn sous la map)
-- ============================================================
local SAFE_SPAWN = { x = -1042.0, y = -2745.0, z = 20.0, heading = 0.0 }
local MIN_Z      = -200.0   -- en dessous = position invalide

local function sanitizePosition(char)
    if not char.x or not char.y or not char.z then
        return SAFE_SPAWN
    end
    if char.z < MIN_Z then
        return SAFE_SPAWN
    end
    return { x = char.x, y = char.y, z = char.z, heading = char.heading or 0.0 }
end

-- ============================================================
--  Événement principal : joueur prêt côté client
-- ============================================================
RegisterNetEvent("characters:playerReady", function()
    local src     = source
    local license = GetPlayerIdentifierByType(src, "license")

    if not license then
        print(("[CHARACTERS] Licence introuvable pour la source %s"):format(src))
        DropPlayer(src, "Identifiant invalide.")
        return
    end

    local data = fetchPlayerData(license)

    -- Cas 1 : aucun personnage — ouvre l'écran de création
    if #data.characters == 0 then
        TriggerClientEvent("characters:openCreation", src, { slots = data.slots })
        return
    end

    -- Cas 2 : un seul personnage créé → spawn automatique (peu importe le nb de slots)
    if #data.characters == 1 then
        TriggerClientEvent("characters:autoSpawn", src, data.characters[1])
        return
    end

    -- Cas 3 : plusieurs personnages → ouvre la sélection
    TriggerClientEvent("characters:openSelection", src, {
        slots      = data.slots,
        characters = data.characters
    })
end)

-- ============================================================
--  Le joueur a sélectionné un personnage depuis le menu NUI
-- ============================================================
RegisterNetEvent("characters:selectCharacter", function(charId)
    local src     = source
    local license = GetPlayerIdentifierByType(src, "license")

    if not license then return end

    -- Sécurité : on revalide en BDD que ce personnage appartient bien à ce joueur
    local result = exports.oxmysql:executeSync(
        "SELECT id, name, model, pos_x, pos_y, pos_z, heading, skin FROM characters WHERE id = ? AND license = ? LIMIT 1",
        { charId, license }
    )

    if not result or #result == 0 then
        TriggerClientEvent("characters:error", src, "Personnage introuvable ou accès refusé.")
        return
    end

    local char = {
        id      = result[1].id,
        name    = result[1].name,
        model   = result[1].model   or "mp_m_freemode_01",
        x       = result[1].pos_x,
        y       = result[1].pos_y,
        z       = result[1].pos_z,
        heading = result[1].heading or 0.0,
        skin    = result[1].skin
    }

    TriggerClientEvent("characters:doSpawn", src, char)
end)

-- ============================================================
--  Sauvegarde la position du joueur à la déconnexion
-- ============================================================
AddEventHandler("playerDropped", function(reason)
    local src = source
    -- Récupère le personnage actif s'il a bien spawné
    -- Vous pouvez stocker l'ID du personnage actif dans une table globale
    local activeChar = GlobalState["activeChar_" .. src]
    if not activeChar then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    exports.oxmysql:execute(
        "UPDATE characters SET pos_x = ?, pos_y = ?, pos_z = ?, heading = ? WHERE id = ?",
        { coords.x, coords.y, coords.z, heading, activeChar }
    )

    GlobalState["activeChar_" .. src] = nil
end)

-- ============================================================
--  Le client confirme le spawn → on mémorise le personnage actif
-- ============================================================
RegisterNetEvent("characters:spawnConfirmed", function(charId)
    local src = source
    GlobalState["activeChar_" .. src] = charId
end)