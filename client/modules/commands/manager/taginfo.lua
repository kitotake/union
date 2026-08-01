-- client/modules/commands/manager/taginfo.lua
local tags = {}
local enabled = false
local players = {}
local typingState = {} -- [serverId] = true/false

print("^2[taginfo]^7 Client chargé")

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)

    if not onScreen then
        return
    end

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringKeyboardDisplay(text)
    EndTextCommandDisplayText(_x, _y)
end

local function removeAllTags()
    enabled = false

    for _, tag in pairs(tags) do
        if tag and IsMpGamerTagActive(tag) then
            RemoveMpGamerTag(tag)
        end
    end

    tags = {}
    players = {}
end

--------------------------------------------------
-- Détection locale de la touche T (chat) pour CE joueur
-- et envoi de l'état au serveur (pour que les admins le voient)
--------------------------------------------------

CreateThread(function()
    local wasTyping = false

    while true do
        Wait(0)

        local nowTyping = wasTyping

        if IsControlJustPressed(0, 245) then -- INPUT_MP_TEXT_CHAT_ALL (T)
            nowTyping = true
        elseif IsControlJustPressed(0, 191) or IsControlJustPressed(0, 200) then -- ENTER / ESC
            nowTyping = false
        end

        if nowTyping ~= wasTyping then
            wasTyping = nowTyping
            TriggerServerEvent("union:taginfo:typing", wasTyping)
        end
    end
end)

--------------------------------------------------
-- Réception de l'état "typing" d'un autre joueur (relayé par le serveur)
--------------------------------------------------

RegisterNetEvent("union:taginfo:typingUpdate", function(serverId, isTyping)
    typingState[serverId] = isTyping
end)

RegisterNetEvent("union:taginfo:receive", function(data)
    removeAllTags()

    players = data
    enabled = true
end)

CreateThread(function()
    while true do
        Wait(0)

        if enabled then
            local myCoords = GetEntityCoords(PlayerPedId())

            for _, data in ipairs(players) do
                local player = GetPlayerFromServerId(data.serverId)

                if player == -1 then
                    if tags[data.serverId] then
                        RemoveMpGamerTag(tags[data.serverId])
                        tags[data.serverId] = nil
                    end
                else
                    local ped = GetPlayerPed(player)

                    if DoesEntityExist(ped) then

                        --------------------------------------------------
                        -- Création du GamerTag
                        --------------------------------------------------

                        local isNewTag = false

                        if not tags[data.serverId] or not IsMpGamerTagActive(tags[data.serverId]) then
                            tags[data.serverId] = CreateMpGamerTag(
                                ped,
                                ("[%d] %s"):format(
                                    data.serverId,
                                    data.steamName
                                ),
                                false,
                                false,
                                "",
                                0
                            )
                            isNewTag = true
                        end

                        local tag = tags[data.serverId]

                        --------------------------------------------------
                        -- Nom (désactivé, on utilise le texte 3D à la place)
                        --------------------------------------------------

                        SetMpGamerTagVisibility(tag, 0, false)

                        --------------------------------------------------
                        -- Barre de vie
                        --------------------------------------------------

                        SetMpGamerTagVisibility(tag, 2, true)

                        --------------------------------------------------
                        -- Voix
                        --------------------------------------------------

                        SetMpGamerTagVisibility(
                            tag,
                            4,
                            NetworkIsPlayerTalking(player)
                        )

                        --------------------------------------------------
                        -- Conducteur
                        --------------------------------------------------

                        local driver = false

                        if IsPedInAnyVehicle(ped, false) then
                            local vehicle = GetVehiclePedIsIn(ped, false)
                            driver = GetPedInVehicleSeat(vehicle, -1) == ped
                        end

                        SetMpGamerTagVisibility(tag, 8, driver)

                        --------------------------------------------------
                        -- En train d'écrire (touche T)
                        --------------------------------------------------

                        SetMpGamerTagVisibility(
                            tag,
                            16,
                            typingState[data.serverId] == true
                        )

                        --------------------------------------------------
                        -- Couleur barre de vie (uniquement à la création)
                        --------------------------------------------------

                        if isNewTag then
                            SetMpGamerTagHealthBarColour(tag, 25)
                        end

                        --------------------------------------------------
                        -- ID + Steam Name + UUID + statut mort, sur une seule ligne
                        --------------------------------------------------

                        local coords = GetEntityCoords(ped)

                        if #(myCoords - coords) < 25.0 then
                            local statusText = ("[%d] %s | UUID : %s"):format(
                                data.serverId,
                                data.steamName,
                                data.uniqueId
                            )

                            if IsEntityDead(ped) then
                                statusText = statusText .. "  ~r~[MORT]~s~"
                            end

                            DrawText3D(
                                coords.x,
                                coords.y,
                                coords.z + 1.05,
                                statusText
                            )
                        end
                    end
                end
            end
        end
    end
end)

RegisterCommand("taginfo", function(_, args)

    if args[1] == "off" then
        removeAllTags()
        return
    end

    TriggerServerEvent("union:taginfo:request")
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        removeAllTags()
    end
end)