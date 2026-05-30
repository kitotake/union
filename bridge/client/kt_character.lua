-- bridge/client/kt_character.lua
Bridge.Character = Bridge.create("kt_character")
Bridge.register("kt_character", Bridge.Character)

function Bridge.Character.applyAppearance(charData)
    if not charData then return false end
    if not Bridge.Character:isAvailable() then return false end
    local ok, err = pcall(function()
        exports["kt_character"]:ApplyPreview(charData)
    end)
    if not ok then
        print(("^1[BRIDGE:kt_character] ApplyPreview échoué : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

function Bridge.Character._applyFallback(charData)
    local model = charData and charData.ped_model or "mp_m_freemode_01"
    local hash  = GetHashKey(model)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local t = GetGameTimer()
        while not HasModelLoaded(hash) do
            Wait(50)
            if GetGameTimer() - t > 5000 then
                print("^1[BRIDGE:kt_character] Timeout modèle fallback^7")
                return
            end
        end
    end
    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
    print("^3[BRIDGE:kt_character] Fallback appliqué — modèle: " .. model .. "^7")
end

function Bridge.Character.openCreator(data)
    if not Bridge.Character:isAvailable() then
        print("^3[BRIDGE:kt_character] openCreator ignoré — non disponible^7")
        return false
    end
    local ok, err = pcall(function()
        TriggerNetEvent("kt_character:openCreator", data)
    end)
    if not ok then
        print(("^1[BRIDGE:kt_character] openCreator erreur : %s^7"):format(tostring(err)))
        return false
    end
    return true
end

function Bridge.Character.getCurrentAppearance()
    if not Bridge.Character:isAvailable() then return nil end
    return Bridge.Character:call("GetCurrentAppearance")
end

function Bridge.Character.saveAppearance(uniqueId)
    if not Bridge.Character:isAvailable() then return false end
    local appearance = Bridge.Character.getCurrentAppearance()
    if not appearance then return false end
    TriggerServerEvent("union:character:saveAppearance", uniqueId, appearance)
    return true
end
