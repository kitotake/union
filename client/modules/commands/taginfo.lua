-- client/modules/commands/taginfo.lua
local activeTags = {}
local tagThread = nil
local isRunning = false

local function createTag(playerId, data)
    activeTags[playerId] = data
end

local function removeTag(playerId)
    activeTags[playerId] = nil
end

local function clearAllTags()
    activeTags = {}
    isRunning = false
end

local function startRenderThread()
    if isRunning then return end
    isRunning = true

    CreateThread(function()
        while isRunning do
            local playerPed = PlayerPedId()

            for targetId, data in pairs(activeTags) do
                local targetPed = GetPlayerPed(GetPlayerFromServerId(targetId))

                if DoesEntityExist(targetPed) and not IsEntityDead(targetPed) then
                    local targetCoords = GetEntityCoords(targetPed)
                    local myCoords = GetEntityCoords(playerPed)
                    local dist = #(targetCoords - myCoords)

                    if dist <= 30.0 then
                        local tagPos = vector3(
                            targetCoords.x,
                            targetCoords.y,
                            targetCoords.z + 1.15
                        )

                        -- Fond noir semi-transparent
                        local r, g, b, a = 0, 0, 0, 160
                        DrawMarker(
                            28,
                            tagPos.x, tagPos.y, tagPos.z + 0.25,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            0.55, 0.22, 0.01,
                            r, g, b, a,
                            false, true, 2, false, nil, nil, false
                        )

                        -- ID du joueur (jaune)
                        SetTextScale(0.0, 0.28)
                        SetTextFont(4)
                        SetTextColour(255, 220, 50, 255)
                        SetTextOutline()
                        SetTextCentre(true)
                        BeginTextCommandDisplayText("STRING")
                        AddTextComponentSubstringPlayerName("ID: " .. targetId)
                        EndTextCommandDisplayText3dWithFont(
                            tagPos.x, tagPos.y, tagPos.z + 0.38,
                            0
                        )

                        -- Nom Steam (blanc)
                        SetTextScale(0.0, 0.24)
                        SetTextFont(4)
                        SetTextColour(255, 255, 255, 255)
                        SetTextOutline()
                        SetTextCentre(true)
                        BeginTextCommandDisplayText("STRING")
                        AddTextComponentSubstringPlayerName(data.steamName)
                        EndTextCommandDisplayText3dWithFont(
                            tagPos.x, tagPos.y, tagPos.z + 0.26,
                            0
                        )

                        -- Unique ID (gris clair)
                        SetTextScale(0.0, 0.20)
                        SetTextFont(4)
                        SetTextColour(180, 180, 180, 255)
                        SetTextOutline()
                        SetTextCentre(true)
                        BeginTextCommandDisplayText("STRING")
                        AddTextComponentSubstringPlayerName("UID: " .. data.uniqueId)
                        EndTextCommandDisplayText3dWithFont(
                            tagPos.x, tagPos.y, tagPos.z + 0.14,
                            0
                        )
                    end
                end
            end

            Wait(0)
        end
    end)
end

-- Réception des données depuis le serveur
RegisterNetEvent("union:taginfo:receive", function(players)
    clearAllTags()

    if not players or #players == 0 then
        Notifications.send("Aucun joueur en ligne.", "warning")
        return
    end

    for _, p in ipairs(players) do
        createTag(p.serverId, {
            steamName = p.steamName,
            uniqueId  = p.uniqueId,
        })
    end

    startRenderThread()
    Notifications.send("Tags affichés pour " .. #players .. " joueur(s). /taginfo off pour masquer.", "info")
end)

-- Commande principale
RegisterCommand("taginfo", function(source, args)
    local sub = args[1]

    if sub == "off" then
        clearAllTags()
        Notifications.send("Tags masqués.", "info")
        return
    end

    TriggerServerEvent("union:taginfo:request")
end, false)