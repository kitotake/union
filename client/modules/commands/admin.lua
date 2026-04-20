-- client/modules/commands/admin.lua

-----------------------------------------
-- CONFIG
-----------------------------------------
local ADMIN_ACE = "admin"

-----------------------------------------
-- CLIENT SIDE
-----------------------------------------
if not IsDuplicityVersion() then

    local isLoaded = false

    -- Player loaded event (à adapter si besoin)
    RegisterNetEvent("union:playerLoaded", function()
        isLoaded = true
    end)

    -----------------------------------------
    -- COMMANDES
    -----------------------------------------

    RegisterCommand("respawn", function()
        TriggerServerEvent("admin:respawn")
    end, false)

    RegisterCommand("revive", function()
        TriggerServerEvent("admin:respawn")
    end, false)

    RegisterCommand("heal", function()
        TriggerServerEvent("admin:heal")
    end, false)

    -----------------------------------------
    -- EVENTS CLIENT
    -----------------------------------------

    RegisterNetEvent("admin:respawn:client", function()
        if not isLoaded then
            print("[ADMIN] Player not loaded, respawn cancelled")
            return
        end

        if Spawn and Spawn.respawn then
            local success = Spawn.respawn()

            if not success then
                print("[ADMIN] Respawn failed (Spawn returned false)")
            end
        else
            print("[ADMIN] Spawn system not found")
        end
    end)

    RegisterNetEvent("admin:heal:client", function()
        local ped = PlayerPedId()

        if DoesEntityExist(ped) then
            SetEntityHealth(ped, 200)
            print("[ADMIN] Player healed")
        end
    end)

end

-----------------------------------------
-- SERVER SIDE
-----------------------------------------
if IsDuplicityVersion() then

    local function hasPermission(src)
        return IsPlayerAceAllowed(src, ADMIN_ACE)
    end

    -----------------------------------------
    -- RESPAWN
    -----------------------------------------
    RegisterNetEvent("admin:respawn", function()
        local src = source

        if not hasPermission(src) then
            print(("[SECURITY] %s tried /respawn without permission"):format(src))
            return
        end

        print(("[ADMIN] %s used /respawn"):format(src))
        TriggerClientEvent("admin:respawn:client", src)
    end)

    -----------------------------------------
    -- HEAL
    -----------------------------------------
    RegisterNetEvent("admin:heal", function()
        local src = source

        if not hasPermission(src) then
            print(("[SECURITY] %s tried /heal without permission"):format(src))
            return
        end

        print(("[ADMIN] %s used /heal"):format(src))
        TriggerClientEvent("admin:heal:client", src)
    end)

end