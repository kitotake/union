-- bridge/client/kt_hud.lua
-- Bridge client vers kt_hud
-- FIX : SendNUIMessage depuis "union" échoue (union n'a pas de frame NUI).
--       La solution correcte est de déléguer l'envoi à kt_hud lui-même
--       via un event local client (TriggerEvent = même process, pas de réseau).
--       kt_hud/client/main.lua doit enregistrer "kt_hud:sendNui".

Bridge.Hud = Bridge.create("kt_hud")
Bridge.register("kt_hud", Bridge.Hud)

local hudActive = false
local hudThread = false
local UPDATE_DELAY = 500

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NORMALISATION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function normalizeHealth(raw)
    if raw <= 100 then return 0 end
    return math.floor(((raw - 100) / 100) * 100)
end

local function normalizeArmor(raw)
    return math.max(0, math.min(100, math.floor(raw)))
end

local function normalizeStamina(raw)
    return math.floor((1.0 - raw) * 100)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- COLLECTE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function collectHudData()
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local inVeh   = DoesEntityExist(vehicle) and vehicle ~= 0

    local ps     = LocalPlayer.state
    local hunger = ps.hunger or 100
    local thirst = ps.thirst or 100
    local stress = ps.stress or 0

    return {
        health  = normalizeHealth(GetEntityHealth(ped)),
        armor   = normalizeArmor(GetPedArmour(ped)),
        stamina = normalizeStamina(GetPlayerStamina(PlayerId())),
        hunger  = math.max(0, math.min(100, math.floor(hunger))),
        thirst  = math.max(0, math.min(100, math.floor(thirst))),
        stress  = math.max(0, math.min(100, math.floor(stress))),
        isDead  = IsEntityDead(ped),

        inVehicle    = inVeh,
        speed        = inVeh and math.floor(GetEntitySpeed(vehicle) * 3.6) or 0,
        fuel         = inVeh and math.floor(GetVehicleFuelLevel(vehicle))  or 0,
        rpm          = inVeh and math.floor((GetVehicleCurrentRpm(vehicle) or 0) * 100) / 100 or 0,
        gear         = inVeh and GetVehicleCurrentGear(vehicle) or 0,
        engineHealth = inVeh and math.floor(GetVehicleEngineHealth(vehicle)) or 0,
    }
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ENVOI — délégué à kt_hud via event local
--
-- POURQUOI :
--   SendNUIMessage() n'est valable QUE dans la ressource qui déclare
--   ui_page dans son fxmanifest.lua. Depuis "union", appeler
--   SendNUIMessage envoie à la frame NUI de "union" (qui n'existe pas)
--   → erreur "resource union has no UI frame".
--
-- SOLUTION :
--   On déclenche un event local (même client, zéro latence réseau).
--   kt_hud/client/main.lua écoute "kt_hud:sendNui" et fait lui-même
--   le SendNUIMessage dans son propre contexte → ça fonctionne.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function sendToNui(action, data)
    TriggerEvent("kt_hud:sendNui", action, data)
end

function Bridge.Hud.update(data)
    if not Bridge.Hud:isAvailable() then return end

    data = data or collectHudData()

    local ok, err = pcall(function()
        sendToNui("updateHud", {
            health  = data.health,
            armor   = data.armor,
            stamina = data.stamina,
            hunger  = data.hunger,
            thirst  = data.thirst,
            stress  = data.stress,
            isDead  = data.isDead,
        })
        sendToNui("updateVehicle", {
            inVehicle    = data.inVehicle,
            speed        = data.speed,
            fuel         = data.fuel,
            rpm          = data.rpm,
            gear         = data.gear,
            engineHealth = data.engineHealth,
        })
    end)

    if not ok then
        print(("^1[BRIDGE:kt_hud] update erreur : %s^7"):format(tostring(err)))
    end
end

function Bridge.Hud.show()
    if not Bridge.Hud:isAvailable() then return end
    sendToNui("setVisible", { visible = true })
    hudActive = true
    Bridge.Hud._startThread()
end

function Bridge.Hud.hide()
    if not Bridge.Hud:isAvailable() then return end
    sendToNui("setVisible", { visible = false })
    hudActive = false
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- THREAD
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Bridge.Hud._startThread()
    if hudThread then return end
    hudThread = true

    CreateThread(function()
        while hudActive do
            if Client.currentCharacter then
                Bridge.Hud.update(collectHudData())
            end
            Wait(UPDATE_DELAY)
        end
        hudThread = false
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENTS UNION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RegisterNetEvent("union:player:spawned", function()
    Wait(500)
    Bridge.Hud.show()
end)

AddEventHandler("union:character:unloaded", function()
    Bridge.Hud.hide()
end)

RegisterNetEvent("union:job:updated", function(job, grade)
    if Client.currentCharacter then
        Client.currentCharacter.job       = job
        Client.currentCharacter.job_grade = grade
        Bridge.Hud.update()
    end
end)

AddEventHandler("onResourceStart", function(r)
    if r == "kt_hud" and hudActive then
        Wait(300)
        Bridge.Hud.show()
    end
end)

AddEventHandler("onResourceStop", function(r)
    if r == "kt_hud" then
        hudActive = false
    end
end)