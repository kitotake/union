-- client/modules/spawn/handler.lua
Spawn.Handler = {}

function Spawn.Handler.getLastPosition()
    local pos, heading, hasSaved = Position.get()
    if hasSaved and pos then
        return pos, heading
    end
    return Config.spawn.defaultPosition, Config.spawn.defaultHeading
end

function Spawn.Handler.setDefaultClothes(ped)
    for i = 0, 11 do
        SetPedComponentVariation(ped, i, 0, 0, 1)
    end
    for i = 0, 7 do
        ClearPedProp(ped, i)
    end
end

function Spawn.Handler.applyOutfit(ped, outfitStyle)
    -- This can be expanded later for different outfit styles
    Spawn.Handler.setDefaultClothes(ped)
end

-- Auto-initialize spawn on player enter world
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end
    
    Wait(2000)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    
    -- Spawn temporary model while waiting
    local tempModel = Config.spawn.temporaryModel
    RequestModel(GetHashKey(tempModel))
    
    local startTime = GetGameTimer()
    while not HasModelLoaded(GetHashKey(tempModel)) do
        Wait(50)
        if GetGameTimer() - startTime > 5000 then
            Logger:error("Failed to load temporary model")
            break
        end
    end
    
    SetPlayerModel(PlayerId(), GetHashKey(tempModel))
    SetModelAsNoLongerNeeded(GetHashKey(tempModel))
    
    Wait(500)
    Spawn.initialize()
end)