-- client/modules/components/position.lua
-- FIXES:
--   #1 : Position.save() ne sauvegarde pas si le joueur est mort.
--   #2 : Position.save() sauvegarde la position du véhicule si le joueur
--        est dedans (coords correctes), mais seulement si le véhicule existe.
--   #3 : La boucle auto-save vérifie Client.currentCharacter (pas seulement isReady).

Position = {}
local lastSavedPos     = nil
local lastSavedHeading = nil
local positionSaved    = false

function Position.save()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    -- FIX #1 : ne pas sauvegarder si mort
    if IsEntityDead(ped) then
        Logger:debug("Position skip: joueur mort")
        return
    end

    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    -- FIX #2 : si dans un véhicule, utiliser les coords du véhicule (déjà fait par GetEntityCoords sur le ped)
    -- Vérification que les coords ne sont pas nulles
    if math.abs(coords.x) < 1.0 and math.abs(coords.y) < 1.0 then
        Logger:debug("Position skip: coords nulles (spawn en cours)")
        return
    end

    lastSavedPos     = coords
    lastSavedHeading = heading
    positionSaved    = true

    Logger:debug("Position saved locally: " .. tostring(lastSavedPos))
    TriggerServerEvent("union:position:save", lastSavedPos, lastSavedHeading)
end

function Position.get()
    return lastSavedPos, lastSavedHeading, positionSaved
end

function Position.setLast(position, heading)
    if position and position.x ~= 0 then
        lastSavedPos     = position
        lastSavedHeading = heading or 0.0
        positionSaved    = true
        Logger:debug("Position received from server: " .. tostring(position))
    else
        positionSaved = false
        Logger:debug("Invalid position received from server")
    end
end

RegisterNetEvent("union:position:loaded", function(position, heading)
    Position.setLast(position, heading)
end)

-- FIX #3 : vérification Client.currentCharacter ET isReady
CreateThread(function()
    while true do
        Wait(Config.spawn.saveInterval)
        -- Ne sauvegarder que si un personnage est actif et spawné
        if Client.isReady and Client.currentCharacter then
            Position.save()
        end
    end
end)
