-- union/bridge/client/kt_interact_data.lua

KT = KT or {}
KT.Interact = KT.Interact or {}

-- ==================== CONFIG ====================
KT.Interact.Config = {
    Debug = true,
    CheckInterval = 500,           -- ms
    DefaultDistance = 3.0,
    Key = 38,                      -- E key
    DrawDistance = 15.0,
}

-- ==================== DATA ====================
KT.Interact.Registered = {}        -- All registered interactions
KT.Interact.Active = {}            -- Nearby / active ones
KT.Interact.Current = nil          -- Currently focused interaction

print("^2[BRIDGE] 'kt_interact_data' initialized^7")