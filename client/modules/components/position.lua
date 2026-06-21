-- client/modules/components/position.lua
Position = {}

local lastSavedPos     = nil
local lastSavedHeading = nil
local positionSaved    = false

local MOVE_THRESHOLD = 2.0
local SAVE_INTERVAL  = 30000
local MIN_INTERVAL   = 3000
local lastSaveTime   = 0

local function getCharacterStats()
    local ped    = PlayerPedId()
    local health = GetEntityHealth(ped)
    local armor  = GetPedArmour(ped)
    local isDead = IsEntityDead(ped)
    return health, armor, isDead
end

-- BUG-1 : hasMoved compare toujours deux vector3 grâce à la normalisation dans setLast
local function hasMoved(newPos)
    if not lastSavedPos or not newPos then return true end
    -- newPos est toujours un vector3 (GetEntityCoords), lastSavedPos aussi (normalisé dans setLast)
    return #(newPos - lastSavedPos) > MOVE_THRESHOLD
end

local function canSave()
    return (GetGameTimer() - lastSaveTime) >= MIN_INTERVAL
end

function Position.save(force)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    if IsEntityDead(ped) then
        Logger:debug("Position skip: joueur mort")
        return
    end
    local coords  = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    if math.abs(coords.x) < 1.0 and math.abs(coords.y) < 1.0 then
        Logger:debug("Position skip: coords nulles (spawn en cours)")
        return
    end
    if not force and not canSave() then return end
    local health, armor, isDead = getCharacterStats()
    if Client.currentCharacter then
        Client.currentCharacter.health  = health
        Client.currentCharacter.armor   = armor
        Client.currentCharacter.is_dead = isDead and 1 or 0
    end
    lastSavedPos     = coords  -- vector3 natif, pas de conversion nécessaire
    lastSavedHeading = heading
    positionSaved    = true
    lastSaveTime     = GetGameTimer()
    Logger:debug(("Position save → x=%.1f y=%.1f z=%.1f HP=%d Armor=%d"):format(
        coords.x, coords.y, coords.z, health, armor
    ))
    TriggerServerEvent("union:position:save", coords, heading, health, armor, isDead)
end

function Position.get()
    return lastSavedPos, lastSavedHeading, positionSaved
end

-- BUG-1 : forcer vector3 dans setLast pour que hasMoved() ne crashe jamais
function Position.setLast(position, heading)
    if position == nil then
        lastSavedPos     = nil
        lastSavedHeading = nil
        positionSaved    = false
        Logger:debug("Position reset (ensure/restart)")
        return
    end
    -- Normaliser en vector3 FiveM quelle que soit la forme reçue (table ou vector3)
    local px = position.x or 0
    local py = position.y or 0
    local pz = position.z or 0
    if math.abs(px) < 1.0 and math.abs(py) < 1.0 then
        positionSaved = false
        Logger:debug("Position invalide reçue du serveur (x≈0 y≈0)")
        return
    end
    lastSavedPos     = vector3(px, py, pz)  -- toujours vector3, jamais une table Lua
    lastSavedHeading = heading or 0.0
    positionSaved    = true
    Logger:debug(("Position reçue du serveur: x=%.1f y=%.1f z=%.1f h=%.1f"):format(px, py, pz, lastSavedHeading))
end

RegisterNetEvent("union:position:loaded", function(position, heading)
    Position.setLast(position, heading)
end)

CreateThread(function()
    while true do
        Wait(1000)
        if not Client.isReady or not Client.currentCharacter then goto continue end
        local ped = PlayerPedId()
        if not DoesEntityExist(ped) or IsEntityDead(ped) then goto continue end
        local coords = GetEntityCoords(ped)
        if hasMoved(coords) and canSave() then
            Logger:debug("Mouvement détecté → save immédiate")
            Position.save(true)
            goto continue
        end
        if (GetGameTimer() - lastSaveTime) >= SAVE_INTERVAL then
            Logger:debug("Save périodique (30s)")
            Position.save(true)
        end
        ::continue::
    end
end)
