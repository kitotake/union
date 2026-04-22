-- server/modules/character/main.lua
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIX: création insère position JSON
-- FIX: select lit position JSON (compatible avant/après migration)
-- FIX: resolveModel retourne toujours un modèle GTA V valide
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Character        = {}
Character.logger = Logger:child("CHARACTER")

-- ─── Helpers internes ─────────────────────────────────────────────────────

--- Décode un champ position JSON → (vector3, heading)
local function decodePosition(raw)
    local defPos = Config.spawn.defaultPosition
    local defHdg = Config.spawn.defaultHeading

    if not raw then return vector3(defPos.x, defPos.y, defPos.z), defHdg end

    local ok, p = pcall(json.decode, tostring(raw))
    if ok and p and p.x then
        return vector3(p.x, p.y, p.z), (p.heading or defHdg)
    end

    return vector3(defPos.x, defPos.y, defPos.z), defHdg
end

--- Retourne le modèle ped approprié (toujours un string GTA V valide)
local function resolveModel(selected)
    if selected.model and selected.model ~= "" then
        -- Vérifier que ce n'est pas une valeur enum ("m"/"f")
        if selected.model == "mp_m_freemode_01" or selected.model == "mp_f_freemode_01" then
            return selected.model
        end
    end
    return selected.gender == "f" and "mp_f_freemode_01" or "mp_m_freemode_01"
end

--- Fusionne le skin dans charData
local function applySkinData(charData, appearance)
    if not (appearance and appearance.skin_data) then return end

    local ok, skin = pcall(json.decode, appearance.skin_data)
    if not (ok and skin) then return end

    charData.hair         = skin.hair
    charData.headBlend    = skin.headBlend
    charData.faceFeatures = skin.faceFeatures
    charData.headOverlays = skin.headOverlays
    charData.components   = skin.components
    charData.props        = skin.props
    charData.tattoos      = skin.tattoos
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Character.create
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Character.create(player, data, callback)
    if not player or not data then
        return callback and callback(false, nil, nil)
    end

    if not (data.firstname and data.lastname and data.dateofbirth and data.gender) then
        Character.logger:warn("Données de personnage invalides pour " .. player.name)
        return callback and callback(false, nil, nil)
    end

    local firstname   = Utils.safeString(data.firstname, 50)
    local lastname    = Utils.safeString(data.lastname,  50)
    local dateofbirth = Utils.safeString(data.dateofbirth)
    local gender      = data.gender:lower() == "f" and "f" or "m"
    local model       = gender == "f" and Config.spawn.femaleModel or Config.spawn.defaultModel
    local uniqueId    = ServerUtils.generateUniqueId(12)

    local defPos = Config.spawn.defaultPosition

    -- Stocker la position en JSON
    local posJson = json.encode({
        x       = defPos.x,
        y       = defPos.y,
        z       = defPos.z,
        heading = Config.spawn.defaultHeading,
    })

    Database.insert([[
        INSERT INTO characters
            (identifier, unique_id, firstname, lastname, dateofbirth, gender, model, position)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        player.license, uniqueId,
        firstname, lastname, dateofbirth, gender, model,
        posJson,
    }, function(characterId)
        if not characterId then
            Character.logger:error("Échec de création du personnage pour " .. player.name)
            return callback and callback(false, nil, nil)
        end

        Database.insert(
            "INSERT INTO character_appearances (unique_id) VALUES (?)",
            { uniqueId },
            function()
                Character.logger:info(
                    ("Personnage créé pour %s : %s %s"):format(player.name, firstname, lastname)
                )
                player:loadCharacters(function()
                    if callback then callback(true, characterId, uniqueId) end
                end)
            end
        )
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Character.select
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Character.select(player, characterId, callback)
    if not player or not characterId then
        return callback and callback(false, nil)
    end

    -- Chercher le personnage dans la liste du joueur
    local selected
    for _, char in ipairs(player.characters) do
        if char.id == characterId then
            selected = char
            break
        end
    end

    if not selected then
        Character.logger:warn("Personnage introuvable : " .. tostring(characterId))
        return callback and callback(false, nil)
    end

    player.currentCharacter = selected
    Character.logger:info(
        ("Personnage sélectionné pour %s : %s %s"):format(
            player.name, selected.firstname, selected.lastname
        )
    )

    -- Résoudre la position — compatible avant et après migration SQL
    local position, heading

    if selected.position then
        -- Nouveau schéma : colonne JSON
        position, heading = decodePosition(selected.position)
    elseif selected.position_x and selected.position_x ~= 0 then
        -- Ancien schéma : colonnes séparées (avant migration)
        position = vector3(selected.position_x, selected.position_y, selected.position_z)
        heading  = selected.heading or Config.spawn.defaultHeading
    else
        position = Config.spawn.defaultPosition
        heading  = Config.spawn.defaultHeading
    end

    -- Construire le payload de spawn
    local charData = {
        id          = selected.id,
        unique_id   = selected.unique_id,
        firstname   = selected.firstname,
        lastname    = selected.lastname,
        gender      = selected.gender,
        model       = resolveModel(selected),
        dateofbirth = selected.dateofbirth,
        position    = position,
        heading     = heading,
        health      = selected.health or Config.character.defaultHealth,
        armor       = selected.armor  or 0,
    }

    -- Charger le skin avant le spawn
    Database.fetchOne(
        "SELECT skin_data FROM character_appearances WHERE unique_id = ?",
        { selected.unique_id },
        function(appearance)
            applySkinData(charData, appearance)
            TriggerClientEvent("union:spawn:apply", player.source, charData)
            if callback then callback(true, selected) end
        end
    )
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Character.delete
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Character.delete(player, characterId, callback)
    if not player or not characterId then
        return callback and callback(false)
    end

    Database.execute(
        "DELETE FROM characters WHERE id = ? AND identifier = ?",
        { characterId, player.license },
        function(result)
            if result then
                Character.logger:info("Personnage supprimé : " .. tostring(characterId))
                player:loadCharacters(function()
                    if callback then callback(true) end
                end)
            else
                if callback then callback(false) end
            end
        end
    )
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Net events
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function getPlayer(source)
    local player = PlayerManager.get(source)
    if not player then
        Character.logger:warn("Joueur introuvable pour la source " .. tostring(source))
    end
    return player
end

RegisterNetEvent("union:character:create", function(data)
    local src    = source
    local player = getPlayer(src)
    if not player then
        return TriggerClientEvent("union:character:created", src, false)
    end

    Character.create(player, data, function(success, id, uniqueId)
        TriggerClientEvent("union:character:created", src, success, id, uniqueId)
    end)
end)

RegisterNetEvent("union:character:list", function()
    local src    = source
    local player = getPlayer(src)
    if not player then return end

    TriggerClientEvent("union:character:listReceived", src, player.characters)
end)

RegisterNetEvent("union:character:select", function(characterId)
    local src    = source
    local player = getPlayer(src)
    if not player then return end

    Character.select(player, characterId, function(success, character)
        TriggerClientEvent("union:character:selected", src, success, character)
    end)
end)

RegisterNetEvent("union:character:delete", function(characterId)
    local src    = source
    local player = getPlayer(src)

    if not player or not player:hasPermission("character.delete") then
        return TriggerClientEvent("union:character:deleted", src, false)
    end

    Character.delete(player, characterId, function(success)
        TriggerClientEvent("union:character:deleted", src, success)
    end)
end)

return Character