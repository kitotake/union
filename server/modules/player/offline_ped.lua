OfflinePed = {}
OfflinePed.logger = Logger:child("OFFLINE_PED")

OfflinePed.peds = {}

local function decodePos(pos)
    if type(pos) == "table" then return pos end
    if type(pos) ~= "string" then return nil end

    local ok, data = pcall(json.decode, pos)
    if ok and data and data.x then return data end

    return nil
end

-- ✔️ CRÉER PED (1 seul client)
function OfflinePed.create(player)
    if not player or not player.currentCharacter then return end

    local char = player.currentCharacter
    local pos  = decodePos(char.position)

    if not pos then return end

    local model = char.model or "mp_m_freemode_01"

    local players = GetPlayers()
    local target  = players[1]

    if not target then return end

    TriggerClientEvent("union:offlineped:create", target, {
        uniqueId = char.unique_id,
        model    = model,
        x        = pos.x,
        y        = pos.y,
        z        = pos.z,
        heading  = pos.heading or 0.0
    })

    OfflinePed.logger:info(("Créé %s"):format(char.unique_id))
end

-- ✔️ SUPPRIMER
function OfflinePed.remove(uniqueId)
    if not uniqueId then return end

    TriggerClientEvent("union:offlineped:remove", -1, uniqueId)

    OfflinePed.peds[uniqueId] = nil

    OfflinePed.logger:info(("Supprimé %s"):format(uniqueId))
end

-- ✔️ SAVE NETID
RegisterNetEvent("union:offlineped:spawned", function(uniqueId, netId)
    OfflinePed.peds[uniqueId] = netId
end)

return OfflinePed