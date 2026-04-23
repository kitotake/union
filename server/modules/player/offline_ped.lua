-- server/modules/player/offline_ped.lua
-- FIX #7 : le ped offline est maintenant broadcasté à TOUS les clients connectés
--           (TriggerClientEvent -1) et non à un seul joueur aléatoire (players[1]).
--           Sans ça, si le premier joueur se déconnecte le ped disparaît,
--           et les joueurs qui rejoignent après ne le voient jamais.

OfflinePed = {}
OfflinePed.logger = Logger:child("OFFLINE_PED")

-- Stocke les netId par unique_id pour référence serveur
OfflinePed.peds = {}

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
function OfflinePed.create(player)
    if not player or not player.currentCharacter then return end

    local char = player.currentCharacter
    local pos  = decodePos(char.position)

    if not pos then
        OfflinePed.logger:warn("Position invalide pour ped offline uid=" .. tostring(char.unique_id))
        return
    end

    local model = char.model or "mp_m_freemode_01"

    local data = {
        uniqueId = char.unique_id,
        model    = model,
        x        = pos.x,
        y        = pos.y,
        z        = pos.z,
        heading  = pos.heading or 0.0,
    }

    -- FIX #7 : -1 = tous les clients connectés
    TriggerClientEvent("union:offlineped:create", -1, data)

    OfflinePed.logger:info(("Ped offline créé pour uid=%s"):format(char.unique_id))
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SUPPRIMER PED (broadcast à tous)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function OfflinePed.remove(uniqueId)
    if not uniqueId then return end

    TriggerClientEvent("union:offlineped:remove", -1, uniqueId)

    OfflinePed.peds[uniqueId] = nil

    OfflinePed.logger:info(("Ped offline supprimé pour uid=%s"):format(uniqueId))
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SAVE NETID (reçu du client owner)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:offlineped:spawned", function(uniqueId, netId)
    if not uniqueId or not netId then return end
    OfflinePed.peds[uniqueId] = netId
    OfflinePed.logger:debug(("NetId %s enregistré pour uid=%s"):format(tostring(netId), uniqueId))
end)

return OfflinePed