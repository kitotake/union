print("^2[UNION] Initialisation du framework...")

-- Variables globales
Players = {}
union = union or {}

-- Chargement des modules
local function loadModule(path, name)
    local success, err = pcall(function()
        local chunk = LoadResourceFile(GetCurrentResourceName(), path)
        if chunk then
            local func = load(chunk, name)
            if func then func() end
        end
    end)
    if not success then
        print("^1[UNION] Erreur chargement " .. name .. ": " .. tostring(err))
    end
end

-- Chargement des fichiers
loadModule("server/connect.lua", "Connect")
loadModule("server/player.lua", "Player")
loadModule("server/character_data.lua", "CharacterData")
loadModule("server/spawn_functions.lua", "SpawnFunctions")
loadModule("server/events.lua", "Events")

print("^2[UNION] Framework initialisé avec succès!")