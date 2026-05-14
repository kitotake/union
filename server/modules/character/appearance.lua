-- server/modules/character/appearance.lua
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
-- TROIS EVENTS PUBLICS
--
-- 1) union:player:apparence
--    → Charge l'apparence depuis la BDD et l'applique au client.
--    → Déclenché automatiquement à union:player:spawned.
--    → Appelable manuellement :
--        Serveur : TriggerEvent("union:player:apparence", src)
--        Client  : TriggerServerEvent("union:player:apparence")
--
-- 2) union:player:UpdateApparence
--    → Déclenché quand kt_character sauvegarde une modification.
--    → Sauvegarde les nouvelles données en BDD puis réapplique.
--    → Appelable aussi depuis n'importe quelle ressource externe :
--        Serveur : TriggerEvent("union:player:UpdateApparence", src, data)
--        Client  : TriggerServerEvent("union:player:UpdateApparence", data)
--
-- 3) union:player:apparenceUpgrade
--    → Mise à jour PARTIELLE — seuls les champs fournis sont modifiés.
--    → Les autres données existantes sont conservées en BDD.
--    → Champs supportés : hair, headBlend, headOverlays, faceFeatures,
--                         components, props, tattoos, ped_model
--        Serveur : TriggerEvent("union:player:apparenceUpgrade", src, partial)
--        Client  : TriggerServerEvent("union:player:apparenceUpgrade", partial)
--
-- EXPORTS SERVEUR
--    exports["union"]:GetPlayerAppearance(src, callback)    → table apparence (async)
--    exports["union"]:SetPlayerAppearance(src, data)        → update complet
--    exports["union"]:UpgradePlayerAppearance(src, partial) → update partiel
--    exports["union"]:ReloadPlayerAppearance(src)           → recharge depuis BDD
--
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CharacterAppearance        = {}
CharacterAppearance.logger = Logger:child("CHARACTER:APPEARANCE")

-- ─── Helpers internes ─────────────────────────────────────────────────────

local function isConnected(src)
    return GetPlayerEndpoint(src) ~= nil
end

local function safeJson(raw)
    if not raw or raw == "" then return {} end
    local ok, result = pcall(json.decode, raw)
    return (ok and type(result) == "table") and result or {}
end

local function normalizePed(model)
    if model == "mp_f_freemode_01" then return "mp_f_freemode_01", "f" end
    return "mp_m_freemode_01", "m"
end

-- Construit la table d'apparence complète depuis une ligne character_appearances
local function buildFromRow(row, charData)
    if not row then return nil end

    local skin         = safeJson(row.skin_data)
    local faceFeatures = safeJson(row.face_features)
    local tattoos      = safeJson(row.tattoos)

    local rawModel        = (charData and charData.ped_model) or skin.ped_model or "mp_m_freemode_01"
    local pedModel, gender = normalizePed(rawModel)

    return {
        ped_model    = pedModel,
        gender       = gender,
        hair         = skin.hair         or {},
        headBlend    = skin.headBlend    or {},
        headOverlays = skin.headOverlays or {},
        faceFeatures = faceFeatures,
        components   = skin.components   or {},
        props        = skin.props        or {},
        tattoos      = tattoos,
    }
end

-- ─── BDD : load ───────────────────────────────────────────────────────────

function CharacterAppearance.load(uniqueId, callback)
    Database.fetchOne(
        "SELECT skin_data, face_features, tattoos FROM character_appearances WHERE unique_id = ?",
        { uniqueId },
        function(result)
            if callback then callback(result or nil) end
        end
    )
end

-- ─── BDD : save complet ───────────────────────────────────────────────────

function CharacterAppearance.save(uniqueId, skinData, faceFeatures, tattoos, callback)
    Database.execute([[
        UPDATE character_appearances
        SET skin_data = ?, face_features = ?, tattoos = ?, updated_at = NOW()
        WHERE unique_id = ?
    ]], {
        json.encode(skinData     or {}),
        json.encode(faceFeatures or {}),
        json.encode(tattoos      or {}),
        uniqueId,
    }, function(result)
        CharacterAppearance.logger:info("Sauvegarde apparence uid=" .. uniqueId)
        if callback then callback(result) end
    end)
end

-- ─── BDD : save partiel (merge avec les données existantes) ───────────────

local SKIN_FIELDS = { "hair", "headBlend", "headOverlays", "components", "props", "ped_model", "gender" }

function CharacterAppearance.savePartial(uniqueId, partial, callback)
    if not uniqueId or not partial then return end

    CharacterAppearance.load(uniqueId, function(row)
        local skin         = safeJson(row and row.skin_data)
        local faceFeatures = safeJson(row and row.face_features)
        local tattoos      = safeJson(row and row.tattoos)

        for _, field in ipairs(SKIN_FIELDS) do
            if partial[field] ~= nil then
                skin[field] = partial[field]
            end
        end

        if partial.faceFeatures ~= nil then faceFeatures = partial.faceFeatures end
        if partial.tattoos      ~= nil then tattoos      = partial.tattoos      end

        CharacterAppearance.save(uniqueId, skin, faceFeatures, tattoos, callback)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENT 1 : union:player:apparence
-- Charge depuis la BDD et applique. Déclenché automatiquement au spawn.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function doApplyAppearance(src, character)
    if not src or not character or not character.unique_id then return end
    if not isConnected(src) then return end

    CharacterAppearance.load(character.unique_id, function(row)
        if not row then
            CharacterAppearance.logger:warn("Pas d'apparence en BDD uid=" .. tostring(character.unique_id))
            return
        end

        local data = buildFromRow(row, character)
        if not data then return end

        TriggerClientEvent("kt_appearance:apply", src, data)
        TriggerEvent("union:player:apparence:applied", src, character.unique_id, data)

        CharacterAppearance.logger:info(("Apparence chargée src=%d uid=%s"):format(src, character.unique_id))
    end)
end

-- Handler réseau (depuis le client)
RegisterNetEvent("union:player:apparence", function()
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    doApplyAppearance(src, player.currentCharacter)
end)

-- Handler local (depuis le serveur via TriggerEvent)
AddEventHandler("union:player:apparence", function(src)
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    doApplyAppearance(src, player.currentCharacter)
end)

-- Déclenchement automatique au spawn
AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character then return end
    SetTimeout(600, function()
        if isConnected(src) then
            doApplyAppearance(src, character)
        end
    end)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENT 2 : union:player:UpdateApparence
-- Déclenché quand kt_character sauvegarde une modif.
-- Sauvegarde en BDD puis réapplique immédiatement.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function doUpdateAppearance(src, data)
    if not src or not data then return end

    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then
        CharacterAppearance.logger:warn("UpdateApparence: joueur introuvable src=" .. tostring(src))
        return
    end
    if not isConnected(src) then return end

    local uniqueId           = player.currentCharacter.unique_id
    local pedModel, gender   = normalizePed(data.ped_model or player.currentCharacter.ped_model)

    -- Sauvegarde complète en BDD
    CharacterAppearance.save(
        uniqueId,
        {
            ped_model    = pedModel,
            gender       = gender,
            hair         = data.hair         or {},
            headBlend    = data.headBlend    or {},
            headOverlays = data.headOverlays or {},
            components   = data.components   or {},
            props        = data.props        or {},
        },
        data.faceFeatures or {},
        data.tattoos      or {},
        function()
            CharacterAppearance.logger:info("UpdateApparence BDD OK uid=" .. uniqueId)
        end
    )

    -- Application immédiate au client
    local appearanceData = {
        ped_model    = pedModel,
        gender       = gender,
        hair         = data.hair         or {},
        headBlend    = data.headBlend    or {},
        headOverlays = data.headOverlays or {},
        faceFeatures = data.faceFeatures or {},
        components   = data.components   or {},
        props        = data.props        or {},
        tattoos      = data.tattoos      or {},
    }

    TriggerClientEvent("kt_appearance:apply", src, appearanceData)
    TriggerEvent("union:player:UpdateApparence:applied", src, uniqueId, appearanceData)

    CharacterAppearance.logger:info(("UpdateApparence appliqué src=%d uid=%s"):format(src, uniqueId))
end

-- Handler réseau (depuis le client / kt_character)
RegisterNetEvent("union:player:UpdateApparence", function(data)
    doUpdateAppearance(source, data)
end)

-- Handler local (depuis le serveur / autre ressource)
AddEventHandler("union:player:UpdateApparence", function(src, data)
    doUpdateAppearance(src, data)
end)

-- ─── Intégration kt_character ─────────────────────────────────────────────
-- Intercepte la sauvegarde de kt_character pour synchroniser Union.
-- kt_character:updateAppearance → on sauvegarde aussi côté Union.

RegisterNetEvent("kt_character:updateAppearance", function(data)
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    if not data or not data.unique_id then return end

    -- Vérification de propriété
    if player.currentCharacter.unique_id ~= data.unique_id then
        CharacterAppearance.logger:warn(("UpdateApparence refusé: uid mismatch src=%d"):format(src))
        return
    end

    -- On laisse kt_character faire sa sauvegarde normale,
    -- puis on synchronise les données dans la table character_appearances d'Union
    doUpdateAppearance(src, data)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENT 3 : union:player:apparenceUpgrade
-- Mise à jour PARTIELLE. Seuls les champs fournis sont modifiés.
-- Les autres données existantes sont conservées en BDD.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function doUpgradeAppearance(src, partial)
    if not src or not partial or next(partial) == nil then return end

    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then
        CharacterAppearance.logger:warn("apparenceUpgrade: joueur introuvable src=" .. tostring(src))
        return
    end
    if not isConnected(src) then return end

    local uniqueId = player.currentCharacter.unique_id

    -- Sauvegarde partielle en BDD (merge avec données existantes)
    CharacterAppearance.savePartial(uniqueId, partial, function()
        CharacterAppearance.logger:info("apparenceUpgrade BDD OK uid=" .. uniqueId)
    end)

    -- Application partielle au client
    TriggerClientEvent("union:player:apparenceUpgrade:apply", src, partial)
    TriggerEvent("union:player:apparenceUpgrade:applied", src, uniqueId, partial)

    local fields = {}
    for k in pairs(partial) do table.insert(fields, k) end
    CharacterAppearance.logger:info(("apparenceUpgrade src=%d uid=%s → [%s]"):format(
        src, uniqueId, table.concat(fields, ", ")
    ))
end

-- Handler réseau (depuis le client)
RegisterNetEvent("union:player:apparenceUpgrade", function(partial)
    doUpgradeAppearance(source, partial)
end)

-- Handler local (depuis le serveur / autre ressource)
AddEventHandler("union:player:apparenceUpgrade", function(src, partial)
    doUpgradeAppearance(src, partial)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EXPORTS SERVEUR
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports("GetPlayerAppearance", function(src, callback)
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then
        if callback then callback(nil) end
        return
    end
    CharacterAppearance.load(player.currentCharacter.unique_id, function(row)
        if callback then callback(buildFromRow(row, player.currentCharacter)) end
    end)
end)

exports("SetPlayerAppearance", function(src, data)
    doUpdateAppearance(src, data)
end)

exports("UpgradePlayerAppearance", function(src, partial)
    doUpgradeAppearance(src, partial)
end)

exports("ReloadPlayerAppearance", function(src)
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return false end
    doApplyAppearance(src, player.currentCharacter)
    return true
end)

return CharacterAppearance