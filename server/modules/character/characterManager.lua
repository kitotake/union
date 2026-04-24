-- ============================================================
--  server/modules/character/characterManager.lua
--  CORRIGÉ : colonnes SQL réelles (position JSON, identifier, unique_id)
--  Ce fichier gère le flow initial : joueur prêt → spawn ou sélection
-- ============================================================

-- Nb de slots par défaut si absent en BDD
local MAX_SLOTS_DEFAULT = 1

-- ────────────────────────────────────────────────────────────────────────────
-- Utilitaire : décode la colonne `position` JSON en coordonnées
-- ────────────────────────────────────────────────────────────────────────────
local function decodePosition(raw)
    if not raw then return nil end
    local ok, p = pcall(json.decode, tostring(raw))
    if ok and p and p.x then
        return p.x, p.y, p.z, (p.heading or 0.0)
    end
    return nil
end

-- ────────────────────────────────────────────────────────────────────────────
-- Position sécurisée si invalide
-- ────────────────────────────────────────────────────────────────────────────
local SAFE_SPAWN = {
    x       = Config.spawn.defaultPosition.x,
    y       = Config.spawn.defaultPosition.y,
    z       = Config.spawn.defaultPosition.z,
    heading = Config.spawn.defaultHeading,
}

local function sanitizePosition(x, y, z, heading)
    local MIN_Z = -200.0
    if not x or not y or not z or z < MIN_Z then
        return SAFE_SPAWN.x, SAFE_SPAWN.y, SAFE_SPAWN.z, SAFE_SPAWN.heading
    end
    return x, y, z, (heading or 0.0)
end

-- ────────────────────────────────────────────────────────────────────────────
-- Récupère les personnages d'un joueur depuis la BDD
-- Retourne { slots = N, characters = { ... } }
-- ────────────────────────────────────────────────────────────────────────────
local function fetchPlayerCharacters(license, callback)
    if not license then
        if callback then callback({ slots = MAX_SLOTS_DEFAULT, characters = {} }) end
        return
    end

    -- Récupère slots depuis users
    Database.scalar(
        "SELECT slots FROM users WHERE identifier = ?",
        { license },
        function(userSlots)
            local slots = userSlots or MAX_SLOTS_DEFAULT

            exports.oxmysql:fetch([[
                SELECT
                    c.id,
                    c.unique_id,
                    c.firstname,
                    c.lastname,
                    c.dateofbirth,
                    c.gender,
                    c.model,
                    c.position,
                    c.health,
                    c.armor,
                    c.job,
                    c.job_grade,
                    ca.skin_data
                FROM characters c
                LEFT JOIN character_appearances ca ON ca.unique_id = c.unique_id
                WHERE c.identifier = ?
                ORDER BY c.last_played DESC
            ]], { license }, function(result)
                if not result or #result == 0 then
                    if callback then callback({ slots = slots, characters = {} }) end
                    return
                end

                local characters = {}

                for _, row in ipairs(result) do
                    local px, py, pz, heading = decodePosition(row.position)
                    px, py, pz, heading = sanitizePosition(px, py, pz, heading)

                    local model = row.model
                    if not model or model == "" then
                        model = (row.gender == "f") and Config.spawn.femaleModel or Config.spawn.defaultModel
                    end

                    local skinData = nil
                    if row.skin_data then
                        local ok, decoded = pcall(json.decode, row.skin_data)
                        if ok and decoded then skinData = decoded end
                    end

                    table.insert(characters, {
                        id          = row.id,
                        unique_id   = row.unique_id,
                        firstname   = row.firstname,
                        lastname    = row.lastname,
                        dateofbirth = row.dateofbirth,
                        gender      = row.gender,
                        model       = model,
                        position    = { x = px, y = py, z = pz },
                        heading     = heading,
                        health      = row.health  or Config.character.defaultHealth,
                        armor       = row.armor   or 0,
                        job         = row.job     or "unemployed",
                        job_grade   = row.job_grade or 0,
                        hair         = skinData and skinData.hair         or nil,
                        headBlend    = skinData and skinData.headBlend    or nil,
                        faceFeatures = skinData and skinData.faceFeatures or nil,
                        headOverlays = skinData and skinData.headOverlays or nil,
                        components   = skinData and skinData.components   or nil,
                        props        = skinData and skinData.props        or nil,
                        tattoos      = skinData and skinData.tattoos      or nil,
                    })
                end

                if callback then callback({ slots = slots, characters = characters }) end
            end)
        end
    )
end

-- ────────────────────────────────────────────────────────────────────────────
-- Construit le charData complet prêt à être envoyé au client
-- (même format que Character.select dans character/main.lua)
-- ────────────────────────────────────────────────────────────────────────────
local function buildCharData(char)
    return {
        id          = char.id,
        unique_id   = char.unique_id,
        firstname   = char.firstname,
        lastname    = char.lastname,
        gender      = char.gender,
        model       = char.model,
        dateofbirth = char.dateofbirth,
        position    = char.position,
        heading     = char.heading,
        health      = char.health,
        armor       = char.armor,
        job         = char.job,
        job_grade   = char.job_grade,
        hair         = char.hair,
        headBlend    = char.headBlend,
        faceFeatures = char.faceFeatures,
        headOverlays = char.headOverlays,
        components   = char.components,
        props        = char.props,
        tattoos      = char.tattoos,
    }
end

-- ────────────────────────────────────────────────────────────────────────────
-- EVENT : le client signale qu'il est prêt (onClientResourceStart)
-- Routing : 0 perso → création | 1 perso → auto-spawn | N persos → sélection NUI
-- ────────────────────────────────────────────────────────────────────────────
RegisterNetEvent("characters:playerReady", function()
    local src     = source
    local license = GetPlayerIdentifierByType(src, "license")

    if not license then
        Logger:warn("[charManager] Licence introuvable pour source " .. src)
        DropPlayer(src, "Identifiant invalide.")
        return
    end

    fetchPlayerCharacters(license, function(data)
        local chars = data.characters
        local slots = data.slots

        -- Cas 0 : aucun personnage → ouvre le creator kt_character
        if #chars == 0 then
            Logger:info("[charManager] " .. license .. " → 0 personnage, ouverture création")
            TriggerClientEvent("characters:openCreation", src, { slots = slots })
            TriggerClientEvent("kt_character:openCreator", src)
            return
        end

        -- Cas 1 : un seul personnage → auto-spawn
        if #chars == 1 then
            Logger:info("[charManager] " .. license .. " → 1 personnage, auto-spawn")
            local charData = buildCharData(chars[1])
            TriggerClientEvent("characters:autoSpawn", src, charData)
            return
        end

        -- Cas N : plusieurs personnages → sélection NUI
        Logger:info(("[charManager] %s → %d personnages, sélection NUI"):format(license, #chars))
        TriggerClientEvent("characters:openSelection", src, {
            slots      = slots,
            characters = chars,
        })
    end)
end)

-- ────────────────────────────────────────────────────────────────────────────
-- EVENT : le joueur a sélectionné un personnage depuis la NUI
-- Sécurité : on revalide que le perso appartient bien à ce joueur
-- ────────────────────────────────────────────────────────────────────────────
RegisterNetEvent("characters:selectCharacter", function(charId)
    local src     = source
    local license = GetPlayerIdentifierByType(src, "license")

    if not license or not charId then return end

    -- Récupère via PlayerManager si disponible (évite un double aller-retour BDD)
    local player = PlayerManager and PlayerManager.get(src) or nil

    if player and player.characters then
        -- Réutilise la liste déjà chargée
        local found = nil
        for _, c in ipairs(player.characters) do
            if c.id == tonumber(charId) then
                found = c
                break
            end
        end

        if found then
            -- Passe par Character.select pour charger le skin et déclencher union:spawn:apply
            Character.select(player, found.id, function(success, character)
                if not success then
                    TriggerClientEvent("characters:error", src, "Sélection impossible.")
                end
            end)
        else
            TriggerClientEvent("characters:error", src, "Personnage introuvable ou accès refusé.")
        end
        return
    end

    -- Fallback : on retourne chercher en BDD
    exports.oxmysql:fetchOne([[
        SELECT
            c.*,
            ca.skin_data
        FROM characters c
        LEFT JOIN character_appearances ca ON ca.unique_id = c.unique_id
        WHERE c.id = ? AND c.identifier = ?
        LIMIT 1
    ]], { tonumber(charId), license }, function(row)
        if not row then
            TriggerClientEvent("characters:error", src, "Personnage introuvable ou accès refusé.")
            return
        end

        local px, py, pz, heading = decodePosition(row.position)
        px, py, pz, heading = sanitizePosition(px, py, pz, heading)

        local model = row.model
        if not model or model == "" then
            model = (row.gender == "f") and Config.spawn.femaleModel or Config.spawn.defaultModel
        end

        local skinData = nil
        if row.skin_data then
            local ok, decoded = pcall(json.decode, row.skin_data)
            if ok then skinData = decoded end
        end

        local charData = {
            id          = row.id,
            unique_id   = row.unique_id,
            firstname   = row.firstname,
            lastname    = row.lastname,
            gender      = row.gender,
            model       = model,
            dateofbirth = row.dateofbirth,
            position    = vector3(px, py, pz),
            heading     = heading,
            health      = row.health  or Config.character.defaultHealth,
            armor       = row.armor   or 0,
            hair         = skinData and skinData.hair         or nil,
            headBlend    = skinData and skinData.headBlend    or nil,
            faceFeatures = skinData and skinData.faceFeatures or nil,
            headOverlays = skinData and skinData.headOverlays or nil,
            components   = skinData and skinData.components   or nil,
            props        = skinData and skinData.props        or nil,
            tattoos      = skinData and skinData.tattoos      or nil,
        }

        TriggerClientEvent("characters:doSpawn", src, charData)
    end)
end)

-- ────────────────────────────────────────────────────────────────────────────
-- EVENT : le client confirme que le spawn a bien eu lieu
-- Mémorise le personnage actif pour la sauvegarde à la déconnexion
-- ────────────────────────────────────────────────────────────────────────────
RegisterNetEvent("characters:spawnConfirmed", function(charId)
    local src = source
    -- Stocké dans GlobalState pour les autres modules
    GlobalState["activeChar_" .. src] = charId
    Logger:info(("[charManager] Spawn confirmé pour source %s, charId=%s"):format(src, tostring(charId)))
end)

-- ────────────────────────────────────────────────────────────────────────────
-- Nettoyage à la déconnexion
-- ────────────────────────────────────────────────────────────────────────────
AddEventHandler("playerDropped", function()
    local src = source
    GlobalState["activeChar_" .. src] = nil
end)