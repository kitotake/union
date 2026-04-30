-- bridge/client/kt_hud.lua
-- Bridge client vers kt_hud
-- Fix : normalisation santé 100-200 → 0-100%
-- Thread de mise à jour uniquement quand un personnage est actif

Bridge.Hud = Bridge.create("kt_hud")
Bridge.register("kt_hud", Bridge.Hud)

local hudActive    = false
local hudThread    = false
local UPDATE_DELAY = 500 -- ms entre chaque update

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NORMALISATION DES VALEURS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- FiveM : health 0 = mort, 100 = 0 HP joueur, 200 = 100 HP joueur
-- On normalise vers 0-100 pour le HUD
local function normalizeHealth(rawHealth)
    if rawHealth <= 100 then return 0 end
    return math.floor(((rawHealth - 100) / 100) * 100)
end

-- Armor : déjà en 0-100
local function normalizeArmor(rawArmor)
    return math.max(0, math.min(100, math.floor(rawArmor)))
end

-- Stamina : 0.0-1.0 → 0-100
local function normalizeStamina(rawStamina)
    return math.floor((1.0 - rawStamina) * 100)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- COLLECTE DES DONNÉES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function collectHudData()
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local inVeh   = DoesEntityExist(vehicle) and vehicle ~= 0

    local data = {
        -- Joueur
        health   = normalizeHealth(GetEntityHealth(ped)),
        armor    = normalizeArmor(GetPedArmour(ped)),
        stamina  = normalizeStamina(GetPlayerStamina(PlayerId())),
        isDead   = IsEntityDead(ped),

        -- Véhicule
        inVehicle     = inVeh,
        speed         = inVeh and math.floor(GetEntitySpeed(vehicle) * 3.6) or 0,  -- km/h
        fuel          = inVeh and math.floor(GetVehicleFuelLevel(vehicle)) or 0,
        engineHealth  = inVeh and math.floor(GetVehicleEngineHealth(vehicle) / 10) or 0,
        seatbelt      = false, -- à implémenter si besoin

        -- Personnage actif
        character = Client.currentCharacter and {
            firstname = Client.currentCharacter.firstname,
            lastname  = Client.currentCharacter.lastname,
            job       = Client.currentCharacter.job or "unemployed",
            job_grade = Client.currentCharacter.job_grade or 0,
        } or nil,
    }

    return data
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ENVOI AU HUD
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Bridge.Hud.update(data)
    if not Bridge.Hud:isAvailable() then return end

    data = data or collectHudData()

    local ok, err = pcall(function()
        -- Adapter selon l'API réelle de kt_hud
        -- Option A : export
        exports["kt_hud"]:Update(data)
        -- Option B : NUI message direct (décommenter si kt_hud utilise SendNUIMessage)
        -- SendNUIMessage({ action = "updateHud", data = data })
    end)

    if not ok then
        print(("^1[BRIDGE:kt_hud] Update erreur : %s^7"):format(tostring(err)))
    end
end

function Bridge.Hud.show()
    if not Bridge.Hud:isAvailable() then return end
    pcall(function() exports["kt_hud"]:Show() end)
    hudActive = true
    Bridge.Hud._startThread()
end

function Bridge.Hud.hide()
    if not Bridge.Hud:isAvailable() then return end
    pcall(function() exports["kt_hud"]:Hide() end)
    hudActive = false
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- THREAD DE MISE À JOUR
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
-- LIAISON AUX EVENTS UNION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Affiche le HUD dès que le joueur est spawné
RegisterNetEvent("union:player:spawned", function(character)
    Wait(500) -- laisse le spawn se terminer
    Bridge.Hud.show()
end)

-- Cache le HUD quand le personnage est déchargé (déconnexion, sélection)
AddEventHandler("union:character:unloaded", function()
    Bridge.Hud.hide()
end)

-- Mise à jour immédiate si le job change
RegisterNetEvent("union:job:updated", function(job, grade)
    if Client.currentCharacter then
        Client.currentCharacter.job       = job
        Client.currentCharacter.job_grade = grade
        Bridge.Hud.update()
    end
end)
