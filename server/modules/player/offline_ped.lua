-- server/modules/player/offline_ped.lua
-- FIX OP-1 : char.model → char.ped_model (colonne réelle dans characters).
-- FIX OP-2 : gender supprimé (colonne inexistante) — dérivé de ped_model si besoin.
-- FIX OP-3 : OfflinePed.create reçoit directement les données snapshottées (pas player.*).

OfflinePed = {}
OfflinePed.logger = Logger:child("OFFLINE_PED")

-- Store persistant des peds offline (uid → data)
OfflinePed.store = {}

local function decodePos(pos)
    if type(pos) == "table" then return pos end
    if type(pos) ~= "string" then return nil end

    local ok, data = pcall(json.decode, pos)
    if ok and data and data.x then return data end

    return nil
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CRÉER PED (broadcast à tous les clients)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function OfflinePed.create(playerData)
    if not playerData or not playerData.currentCharacter then
        OfflinePed.logger:warn("create: données manquantes")
        return
    end

    local char = playerData.currentCharacter
    local pos  = decodePos(char.position)

    if not pos or not pos.x then
        OfflinePed.logger:warn("Position invalide pour ped offline uid=" .. tostring(char.unique_id))
        return
    end

    -- FIX OP-1 : ped_model est la colonne réelle (pas "model")
    local model = char.ped_model or "mp_m_freemode_01"
    if model ~= "mp_m_freemode_01" and model ~= "mp_f_freemode_01" then
        model = "mp_m_freemode_01"
    end

    local data = {
        uniqueId = char.unique_id,
        model    = model,          -- côté client le champ s'appelle "model" pour le spawn ped
        x        = pos.x,
        y        = pos.y,
        z        = pos.z,
        heading  = pos.heading or 0.0,
    }

    OfflinePed.store[char.unique_id] = data

    TriggerClientEvent("union:offlineped:create", -1, data)

    OfflinePed.logger:info(("Ped offline créé pour uid=%s"):format(char.unique_id))
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SUPPRIMER PED
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function OfflinePed.remove(uniqueId)
    if not uniqueId then return end

    OfflinePed.store[uniqueId] = nil

    TriggerClientEvent("union:offlineped:remove", -1, uniqueId)

    OfflinePed.logger:info(("Ped offline supprimé pour uid=%s"):format(uniqueId))
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Envoi du dump initial quand un joueur spawne
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character then return end

    local list = {}
    for _, data in pairs(OfflinePed.store) do
        if data.uniqueId ~= character.unique_id then
            table.insert(list, data)
        end
    end

    if #list > 0 then
        TriggerClientEvent("union:offlineped:loadAll", src, list)
        OfflinePed.logger:debug(("Envoi de %d ped(s) offline à src=%s"):format(#list, tostring(src)))
    end
end)

return OfflinePed
