-- server/modules/character/appearance.lua
-- FIX DOUBLE-APPLY : guard _applyGuard par (src+uid) dans une fenêtre de 5s.
--   Après "ensure union", union:player:spawned est reçu deux fois par ce module
--   (via AddEventHandler). Le guard détecte le doublon et bloque le second envoi
--   de kt_appearance:apply, supprimant le double chargement visible dans les logs :
--     [INFO|CHARACTER:APPEARANCE] Apparence chargée src=1 uid=chr_xxx  ← 1er OK
--     [INFO|CHARACTER:APPEARANCE] Apparence chargée src=1 uid=chr_xxx  ← 2e bloqué
--
-- Les autres correctifs (EVENT 1/2/3, exports) sont inchangés.

CharacterAppearance        = {}
CharacterAppearance.logger = Logger:child("CHARACTER:APPEARANCE")

CharacterAppearance._applyGuard = {}   -- FIX DOUBLE-APPLY
local APPLY_DEDUP_WINDOW        = 5000 -- ms

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

-- ─── BDD : save partiel ───────────────────────────────────────────────────

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
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function doApplyAppearance(src, character)
    if not src or not character or not character.unique_id then return end
    if not isConnected(src) then return end

    -- FIX DOUBLE-APPLY : guard temporel par (src + uid)
    local guardKey = tostring(src) .. "_" .. tostring(character.unique_id)
    local now      = GetGameTimer()
    local last     = CharacterAppearance._applyGuard[guardKey]

    if last and (now - last) < APPLY_DEDUP_WINDOW then
        CharacterAppearance.logger:warn(("Double apply bloqué src=%d uid=%s (delta=%dms)"):format(
            src, character.unique_id, now - last
        ))
        return
    end
    CharacterAppearance._applyGuard[guardKey] = now

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

-- Handler local (depuis le serveur)
AddEventHandler("union:player:apparence", function(src)
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    doApplyAppearance(src, player.currentCharacter)
end)

-- Déclenchement automatique au spawn (avec délai pour laisser le client se stabiliser)
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

RegisterNetEvent("union:player:UpdateApparence", function(data)
    doUpdateAppearance(source, data)
end)

AddEventHandler("union:player:UpdateApparence", function(src, data)
    doUpdateAppearance(src, data)
end)

RegisterNetEvent("kt_character:updateAppearance", function(data)
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    if not data or not data.unique_id then return end

    if player.currentCharacter.unique_id ~= data.unique_id then
        CharacterAppearance.logger:warn(("UpdateApparence refusé: uid mismatch src=%d"):format(src))
        return
    end

    doUpdateAppearance(src, data)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENT 3 : union:player:apparenceUpgrade
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

    CharacterAppearance.savePartial(uniqueId, partial, function()
        CharacterAppearance.logger:info("apparenceUpgrade BDD OK uid=" .. uniqueId)
    end)

    TriggerClientEvent("union:player:apparenceUpgrade:apply", src, partial)
    TriggerEvent("union:player:apparenceUpgrade:applied", src, uniqueId, partial)

    local fields = {}
    for k in pairs(partial) do table.insert(fields, k) end
    CharacterAppearance.logger:info(("apparenceUpgrade src=%d uid=%s → [%s]"):format(
        src, uniqueId, table.concat(fields, ", ")
    ))
end

RegisterNetEvent("union:player:apparenceUpgrade", function(partial)
    doUpgradeAppearance(source, partial)
end)

AddEventHandler("union:player:apparenceUpgrade", function(src, partial)
    doUpgradeAppearance(src, partial)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NETTOYAGE DU GUARD À LA DÉCONNEXION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AddEventHandler("union:player:dropping", function(src)
    local srcStr  = tostring(src)
    local toDelete = {}
    for key in pairs(CharacterAppearance._applyGuard) do
        if key:sub(1, #srcStr + 1) == srcStr .. "_" then
            toDelete[#toDelete + 1] = key
        end
    end
    for _, key in ipairs(toDelete) do
        CharacterAppearance._applyGuard[key] = nil
    end
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
