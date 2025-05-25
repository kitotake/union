Utils = {}

function Utils.log(tag, msg)
    print(string.format("^6[%s]^0 %s", tag, msg))
end

function Utils.loadAnimDict(dict)
    if not dict or dict == "" then return false end
    RequestAnimDict(dict)
    local startTime = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if GetGameTimer() - startTime > 5000 then
            Utils.log("ERROR", "Échec chargement animdict: " .. dict)
            return false
        end
    end
    return true
end
