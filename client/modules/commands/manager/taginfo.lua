-- client/modules/commands/manager/taginfo.lualocal tags = {}
local enabled = false

local function removeAllTags()
    for _, tag in pairs(tags) do
        if tag and IsMpGamerTagActive(tag) then
            RemoveMpGamerTag(tag)
        end
    end

    tags = {}
    enabled = false
end

RegisterNetEvent("union:taginfo:receive", function(players)
    removeAllTags()

    enabled = true

    CreateThread(function()
        while enabled do
            Wait(1000)

            for _, data in ipairs(players) do
                local serverId = data.serverId

                local player = GetPlayerFromServerId(serverId)

                if player ~= -1 and player ~= PlayerId() then
                    local ped = GetPlayerPed(player)

                    if DoesEntityExist(ped) then
                        if not tags[serverId] or not IsMpGamerTagActive(tags[serverId]) then
                            local name = ("%s [%s]"):format(
                                data.steamName,
                                data.uniqueId
                            )

                            local tag = CreateMpGamerTag(
                                ped,
                                name,
                                false,
                                false,
                                "",
                                0
                            )

                            tags[serverId] = tag

                            SetMpGamerTagVisibility(tag, 0, true)
                            SetMpGamerTagVisibility(tag, 2, true)
                            SetMpGamerTagHealthBarColour(tag, 25)
                        end
                    end
                end
            end
        end
    end)
end)

RegisterCommand("taginfo", function(_, args)
    if args[1] == "off" then
        removeAllTags()

        if Notifications then
            Notifications.send("TagInfo désactivé", "info")
        end

        return
    end

    TriggerServerEvent("union:taginfo:request")

    if Notifications then
        Notifications.send("Chargement des tags...", "info")
    end
end, false)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        removeAllTags()
    end
end)