-- server/modules/character/main.lua
-- FIX CH1 : callback(true, selected) documenté.
-- FIX CH2 : applySkinData renommée pour clarifier l'effet de bord.
-- FIX CH3 : création du compte bancaire via BankDB.createAccount avec owner_identifier.
-- FIX CH4 : gender supprimé (colonne inexistante) — dérivé de ped_model uniquement.
-- FIX CH5 : position transmise en JSON-sérialisable (vector3 non transmissible via NUI).
-- FIX CH6 : charData.model remplacé par charData.ped_model partout.

Character        = {}
Character.logger = Logger:child("CHARACTER")

local function isPlayerConnected(src)
    return GetPlayerEndpoint(src) ~= nil
end

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

-- FIX CH6 : ped_model est la colonne réelle (pas "model")
local function resolveModel(selected)
    return selected.ped_model or "mp_m_freemode_01"
end

local function applySkinDataToCharData(charData, appearance)
    if not (appearance and appearance.skin_data) then return end

    local ok, skin = pcall(json.decode, appearance.skin_data)
    if not (ok and type(skin) == "table") then return end

    if type(skin.hair)         == "table" then charData.hair         = skin.hair         end
    if type(skin.headBlend)    == "table" then charData.headBlend    = skin.headBlend    end
    if type(skin.faceFeatures) == "table" then charData.faceFeatures = skin.faceFeatures end
    if type(skin.headOverlays) == "table" then charData.headOverlays = skin.headOverlays end
    if type(skin.components)   == "table" then charData.components   = skin.components   end
    if type(skin.props)        == "table" then charData.props        = skin.props        end
    if type(skin.tattoos)      == "table" then charData.tattoos      = skin.tattoos      end
end

function Character.create(player, data, callback)
    if not player or not data then
        return callback and callback(false, nil, nil)
    end

    if not (data.firstname and data.lastname and data.dateofbirth and data.ped_model) then
        Character.logger:warn("Données de personnage invalides pour " .. player.name)
        return callback and callback(false, nil, nil)
    end

    local firstname   = Utils.safeString(data.firstname, 50)
    local lastname    = Utils.safeString(data.lastname,  50)
    local dateofbirth = Utils.safeString(data.dateofbirth)
    local ped_model   = Utils.safeString(data.ped_model, 60)

    -- FIX CH4 : pas de colonne gender — on valide ped_model uniquement
    if ped_model ~= "mp_m_freemode_01" and ped_model ~= "mp_f_freemode_01" then
        ped_model = "mp_m_freemode_01"
    end

    CreateThread(function()
        local uniqueId = ServerUtils.generateUniqueId(12)

        local defPos  = Config.spawn.defaultPosition
        local posJson = json.encode({
            x       = defPos.x,
            y       = defPos.y,
            z       = defPos.z,
            heading = Config.spawn.defaultHeading,
        })

        Database.insert([[
            INSERT INTO characters
                (unique_id, firstname, lastname, dateofbirth, ped_model, position)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], {
            uniqueId, firstname, lastname, dateofbirth, ped_model,
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
                    Database.insert(
                        "INSERT INTO user_character (identifier, unique_id) VALUES (?, ?)",
                        { player.license, uniqueId },
                        function()
                            -- FIX CH3 : passer player.license comme owner_identifier
                            BankDB.createAccount(uniqueId, "personal", function(accountId)
                                if not accountId then
                                    Character.logger:warn("Compte bancaire non créé pour uid=" .. uniqueId)
                                end

                                Character.logger:info(
                                    ("Personnage créé pour %s : %s %s (uid=%s)"):format(
                                        player.name, firstname, lastname, uniqueId
                                    )
                                )
                                player:loadCharacters(function()
                                    if callback then callback(true, characterId, uniqueId) end
                                end)
                            end, player.license)  -- FIX CH3 : owner_identifier = licence
                        end
                    )
                end
            )
        end)
    end)
end

function Character.select(player, characterId, callback)
    if not player or not characterId then
        return callback and callback(false, nil)
    end

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

    local position, heading

    -- FIX CH5 : position stockée en JSON (colonne `position` JSON), pas en x/y/z séparés
    if selected.position then
        position, heading = decodePosition(selected.position)
    else
        position = Config.spawn.defaultPosition
        heading  = Config.spawn.defaultHeading
    end

    -- FIX CH4+CH6 : pas de gender en DB, ped_model est la colonne réelle
    local pedModel = resolveModel(selected)

    local charData = {
        id          = selected.id,
        unique_id   = selected.unique_id,
        firstname   = selected.firstname,
        lastname    = selected.lastname,
        ped_model   = pedModel,
        -- FIX CH5 : transmettre position sous forme de table JSON-sérialisable
        -- vector3 ne se sérialise pas correctement via TriggerClientEvent sur certaines versions
        position    = { x = position.x, y = position.y, z = position.z },
        heading     = heading,
        health      = selected.health or Config.character.defaultHealth,
        armor       = selected.armor  or 0,
        job         = selected.job    or "unemployed",
        job_grade   = selected.job_grade or 0,
        dateofbirth = selected.dateofbirth,
    }

    Database.fetchOne(
        "SELECT skin_data FROM character_appearances WHERE unique_id = ?",
        { selected.unique_id },
        function(appearance)
            applySkinDataToCharData(charData, appearance)

            if callback then callback(true, selected) end

            if not isPlayerConnected(player.source) then
                Character.logger:warn(
                    ("select: joueur %s déconnecté avant TriggerClientEvent"):format(player.name)
                )
                return
            end

            TriggerClientEvent("union:spawn:apply", player.source, charData)
        end
    )
end

function Character.delete(player, characterId, callback)
    if not player or not characterId then
        return callback and callback(false)
    end

    local selected
    for _, char in ipairs(player.characters) do
        if char.id == characterId then
            selected = char
            break
        end
    end

    if not selected then
        Character.logger:warn("Personnage à supprimer introuvable : " .. tostring(characterId))
        return callback and callback(false)
    end

    Database.execute(
        "DELETE FROM characters WHERE id = ? AND unique_id = ?",
        { characterId, selected.unique_id },
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

local function getPlayer(src)
    local player = PlayerManager.get(src)
    if not player then
        Character.logger:warn("Joueur introuvable pour source " .. tostring(src))
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

RegisterNetEvent("union:character:reload", function()
    local src    = source
    local player = getPlayer(src)
    if not player then return end

    -- Recharger les personnages depuis la DB pour ce joueur
    player:loadCharacters(function()
        TriggerClientEvent("union:character:reload", src, true)
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

RegisterNetEvent("union:character:saveAppearance", function(uniqueId, appearance)
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end

    if player.currentCharacter.unique_id ~= uniqueId then
        Character.logger:warn("Tentative de sauvegarde d'apparence non autorisée — src=" .. src)
        return
    end

    if appearance then
        CharacterAppearance.save(
            uniqueId,
            appearance.skin_data,
            appearance.face_features,
            appearance.tattoos,
            function()
                Character.logger:info("Apparence sauvegardée pour uid=" .. uniqueId)
            end
        )
    end
end)

return Character
