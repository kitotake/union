print("^6[UNION CLIENT] Initialisation...")

-- Chargement des modules client
local modules = {
    "client/utils.lua",
    "client/position.lua",
    "client/spawn.lua",
    "client/notification.lua"
}



for _, module in ipairs(modules) do
    local chunk = LoadResourceFile(GetCurrentResourceName(), module)
    if chunk then
        local func = load(chunk, module)
        if func then 
            func() 
            print("^2[UNION] Module chargé: " .. module)
        end
    else
        print("^1[UNION] Erreur chargement: " .. module)
    end
end

-- Auto-join au spawn
AddEventHandler("playerSpawned", function()
    Wait(2000)
    TriggerServerEvent("union:playerJoined")
end)


-- 📁 client/main.lua

local function log(tag, msg)
    print(("^3[%s]^7 %s"):format(tag, msg))
end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
        log("SPAWN", "En attente de NetworkIsPlayerActive...")
    end

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    log("SPAWN", "Début du chargement du modèle temporaire...")
    local tempModel = Config.temporaryModel or "player_zero"
    RequestModel(GetHashKey(tempModel))

    local startTime = GetGameTimer()
    while not HasModelLoaded(GetHashKey(tempModel)) do
        Wait(50)
        if GetGameTimer() - startTime > Config.timeouts.modelLoad then
            log("ERROR", "Échec du chargement du modèle temporaire depuis Config.")
            TriggerServerEvent("spawn:server:reportError", "TEMP_MODEL_LOAD_FAILED")
            return
        end
    end

    SetPlayerModel(PlayerId(), GetHashKey(tempModel))
    SetModelAsNoLongerNeeded(GetHashKey(tempModel))
    SetEntityVisible(PlayerPedId(), true, false)
    log("SPAWN", "Modèle temporaire appliqué.")

    while not DoesEntityExist(PlayerPedId()) do
        Wait(500)
        log("SPAWN", "En attente du Ped...")
    end
    
    local timer = 0
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and timer < 10000 do
        Wait(500)
        timer = timer + 500 
    end

    if timer >= 10000 then
        log("SPAWN", "⚠ Collision non totalement chargée après 10s.")
    end

    log("SPAWN", "Ping SQL vers le serveur...")
    TriggerServerEvent("spawn:server:pingSQL")
    TriggerServerEvent("union:playerJoined")
    TriggerServerEvent("spawn:server:requestInitialSpawn")
end)
