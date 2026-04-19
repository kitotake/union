-- client/modules/spawn/main.lua
Spawn = {}
local logger = Logger:child("SPAWN")

function Spawn.initialize()
    logger:info("Initializing spawn system")
    TriggerServerEvent("union:spawn:requestInitial")
end

function Spawn.respawn(model)
    logger:info("Requesting respawn with model: " .. (model or "default"))
    TriggerServerEvent("union:spawn:requestRespawn", model)
end

-- Listen for spawn events
RegisterNetEvent("union:spawn:apply", function(characterData)
    logger:info("Applying character: " .. characterData.model)
    
    -- Load model
    local modelHash = GetHashKey(characterData.model)
    if not IsModelValid(modelHash) then
        logger:error("Invalid model: " .. characterData.model)
        return
    end
    
    RequestModel(modelHash)
    local startTime = GetGameTimer()
    while not HasModelLoaded(modelHash) and GetGameTimer() - startTime < 10000 do
        Wait(50)
    end
    
    if not HasModelLoaded(modelHash) then
        logger:error("Failed to load model: " .. characterData.model)
        TriggerServerEvent("union:spawn:error", "MODEL_LOAD_FAILED")
        return
    end
    
    -- Load collision
    local pos = characterData.position or Config.spawn.defaultPosition
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    
    -- Apply model and spawn
    SetPlayerModel(PlayerId(), modelHash)
    SetModelAsNoLongerNeeded(modelHash)
    
    local ped = PlayerPedId()
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, characterData.heading or 0.0, true, true)
    SetEntityVisible(ped, true, false)
    ClearPedTasksImmediately(ped)
    
    -- Store current character
    Client.currentCharacter = characterData
    
    logger:info("Character spawned successfully")
    TriggerServerEvent("union:spawn:confirm")
end)

RegisterNetEvent("union:spawn:error", function(errorType)
    logger:error("Spawn error: " .. errorType)
    -- Fallback spawn
    Spawn.respawn()
end)