-- server/modules/player/manager/offline_ped.lua
-- FIX OP-4: table.getn deprecated → compteur manuel
OfflinePed        = {}
OfflinePed.logger = Logger:child("OFFLINE_PED")
OfflinePed.store  = {}

local function decodePos(pos)
    if type(pos) == "table" then return pos end
    if type(pos) ~= "string" then return nil end
    local ok, data = pcall(json.decode, pos)
    if ok and data and data.x then return data end
    return nil
end

local function countTable(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function OfflinePed.create(playerData, excludeSrc)
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
    local model = char.ped_model or "mp_m_freemode_01"
    if model ~= "mp_m_freemode_01" and model ~= "mp_f_freemode_01" then model = "mp_m_freemode_01" end
    local data = {
        uniqueId  = char.unique_id,
        model     = model,
        x         = pos.x, y = pos.y, z = pos.z,
        heading   = pos.heading or 0.0,
    }
    local recipients = {}
    for src, _ in pairs(PlayerManager.getAll()) do
        if src ~= excludeSrc and GetPlayerEndpoint(src) then
            TriggerClientEvent("union:offlineped:create", src, data)
            recipients[src] = true
        end
    end
    data.recipients = recipients
    OfflinePed.store[char.unique_id] = data
    OfflinePed.logger:info(("Ped offline créé pour uid=%s (%d destinataires)"):format(
        char.unique_id, countTable(recipients)
    ))
end

function OfflinePed.remove(uniqueId)
    if not uniqueId then return end
    local entry = OfflinePed.store[uniqueId]
    OfflinePed.store[uniqueId] = nil
    if not entry then return end
    if entry.recipients then
        for src in pairs(entry.recipients) do
            if GetPlayerEndpoint(src) then
                TriggerClientEvent("union:offlineped:remove", src, uniqueId)
            end
        end
    else
        TriggerClientEvent("union:offlineped:remove", -1, uniqueId)
    end
    OfflinePed.logger:info(("Ped offline supprimé pour uid=%s"):format(uniqueId))
end

AddEventHandler("union:player:spawned", function(src, character)
    if not src or not character then return end
    local list = {}
    for _, data in pairs(OfflinePed.store) do
        if data.uniqueId ~= character.unique_id then
            table.insert(list, data)
            if data.recipients then data.recipients[src] = true end
        end
    end
    if #list > 0 then
        TriggerClientEvent("union:offlineped:loadAll", src, list)
        OfflinePed.logger:debug(("Envoi de %d ped(s) offline à src=%s"):format(#list, tostring(src)))
    end
end)

AddEventHandler("union:player:dropping", function(src)
    for _, data in pairs(OfflinePed.store) do
        if data.recipients then data.recipients[src] = nil end
    end
end)

AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(10000)
    Database.fetch([[
        SELECT c.unique_id, c.ped_model, c.position FROM characters c
        INNER JOIN user_character uc ON uc.unique_id = c.unique_id
        WHERE c.position IS NOT NULL AND c.last_played > DATE_SUB(NOW(), INTERVAL 24 HOUR)
    ]], {}, function(rows)
        if not rows or #rows == 0 then return end
        local rebuilt = 0
        for _, row in ipairs(rows) do
            local isOnline = false
            for _, player in pairs(PlayerManager.getAll()) do
                if player.currentCharacter and player.currentCharacter.unique_id == row.unique_id then
                    isOnline = true; break
                end
            end
            if not isOnline and row.position then
                local ok, pos = pcall(json.decode, row.position)
                if ok and pos and pos.x then
                    OfflinePed.store[row.unique_id] = {
                        uniqueId = row.unique_id, model = row.ped_model or "mp_m_freemode_01",
                        x = pos.x, y = pos.y, z = pos.z, heading = pos.heading or 0.0, recipients = {},
                    }
                    rebuilt = rebuilt + 1
                end
            end
        end
        OfflinePed.logger:info(("Store offline reconstruit : %d ped(s)"):format(rebuilt))
    end)
end)

return OfflinePed
