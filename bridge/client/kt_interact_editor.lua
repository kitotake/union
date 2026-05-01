-- union/bridge/client/kt_interact_editor.lua

KT = KT or {}
KT.Interact = KT.Interact or {}

local isEditorMode = false
local previewCoords = nil

-- Editor Command
RegisterCommand('ktinteract', function(source, args)
    isEditorMode = not isEditorMode
    print("^2[KT Interact] ^7Editor mode: " .. (isEditorMode and "^2ENABLED" or "^1DISABLED") .. "^7")
end, false)

-- Main Editor Thread
Citizen.CreateThread(function()
    while true do
        Wait(0)

        if isEditorMode then
            -- Raycast + preview logic here later
            DrawMarker(2, GetEntityCoords(PlayerPedId()) + vector3(0.0, 0.0, 1.0), 
                       0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                       0.3, 0.3, 0.2, 255, 100, 100, 200, false, true)
        end
    end
end)

print("^2[BRIDGE] 'kt_interact_editor' initialized^7")