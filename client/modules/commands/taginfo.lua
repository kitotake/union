local activeTags = {}
local isRunning = false

-- =========================
-- Draw 3D Text
-- =========================
local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local camCoords = GetGameplayCamCoords()

    local dist = #(camCoords - vector3(x, y, z))
    local scale = (1 / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov

    if onScreen then
        SetTextScale(0.0 * scale, 0.35 * scale)
        SetTextFont(4)
        SetTextCentre(true)
        SetTextOutline()

        BeginTextCommandDisplayText("STRING")
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandDisplayText(_x, _y)
    end
end

-- =========================
-- Clear
-- =========================
local function clearAllTags()
    activeTags = {}
    isRunning = false
end

-- =========================
-- Thread Render
-- =========================
local function startRenderThread()
    if isRunning then return end
    isRunning = true

    CreateThread(function()
        while isRunning do
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)

            for serverId, data in pairs(activeTags) do
                local player = GetPlayerFromServerId(serverId)

                if player ~= -1 then
                    local targetPed = GetPlayerPed(player)

                    if DoesEntityExist(targetPed) and not IsEntityDead(targetPed) then
                        local coords = GetEntityCoords(targetPed)
                        local dist = #(coords - myCoords)

                        if dist <= 50.0 then
                            local baseZ = coords.z + 1.2

                            

                            DrawText3D(coords.x, coords.y, baseZ + 0.15, ("ID: %s"):format(serverId))
                            DrawText3D(coords.x, coords.y, baseZ, data.steamName or "Unknown")
                            DrawText3D(coords.x, coords.y, baseZ - 0.15, ("UID: %s"):format(data.uniqueId or "N/A"))
                        end
                    end
                end
            end

            Wait(0)
        end
    end)
end

-- =========================
-- Event réception
-- =========================
RegisterNetEvent("union:taginfo:receive", function(players)
    clearAllTags()

    if not players or #players == 0 then
        print("[TAGINFO] Aucun joueur reçu")
        return
    end

    for _, p in ipairs(players) do
        activeTags[p.serverId] = {
            steamName = p.steamName,
            uniqueId  = p.uniqueId
        }
    end

    startRenderThread()
    print("[TAGINFO] Tags activés:", #players)
end)

-- =========================
-- Commande
-- =========================
RegisterCommand("taginfo", function(_, args)
    if args[1] == "off" then
        clearAllTags()
        print("[TAGINFO] Désactivé")
        return
    end

    TriggerServerEvent("union:taginfo:request")
end, false)