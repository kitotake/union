-- shared/config/config.lua
Config = {
    -- Framework version
    version = "0.0.15",
    
    -- Debug mode
    debug = true,
    logLevel = 1, -- 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR
    
    -- ============================================
    -- SPAWN CONFIGURATION
    -- ============================================
    spawn = {
        defaultModel = "mp_m_freemode_01",
        femaleModel = "mp_f_freemode_01",
        temporaryModel = "player_zero",
        
        -- Default spawn position for first join
        defaultPosition = vector3(-268.5, -957.8, 31.2),
        defaultHeading = 90.0,
        
        -- Delays
        spawnDelay = 3000,
        saveInterval = 30000,
        timeouts = {
            modelLoad = 10000,
            collisionLoad = 10000,
        }
    },
    
    -- ============================================
    -- CHARACTER CONFIGURATION
    -- ============================================
    character = {
        -- Default character stats
        defaultHealth = 200,
        defaultArmor = 100,
        
        -- Validation
        maxCharactersPerPlayer = 5,
    },
    
    -- ============================================
    -- DISCORD WEBHOOKS
    -- ============================================
    webhooks = {
        connectionAccepted = "https://discord.com/api/webhooks/1373130231485042768/66pfKgU1SmESfA7yJ89HfAkv1mNN3Z3bdlgcIYCnc3exhb5unjIwIyfnwFcDniOAo3YA",
        connectionRejected = "https://discord.com/api/webhooks/1373130149783928832/v9K-8keDi0pks3MO0oYeR2KTyoazfAVa23q8NxSCqlPTvz0CylEYZhBOvmm4M-H2zeXO",
        playerJoined = "https://discord.com/api/webhooks/1495385331841892466/7sEwlf66EUgFArZdqkZirXlFWlrkJefxFkR99kvZCJVSLOvBmgYGj1fQ3eKbTmQFsebj",
        playerLeft = "https://discord.com/api/webhooks/1495385431867654225/YGJWHv0OoB7_BJSw1z4fzIgCZEShAccfqJcT1zbt89UZZ4ost6U83zJako2LRoF8QVVt",
    },
    
    -- ============================================
    -- LOCALIZATION
    -- ============================================
    locale = "en",
    
    -- ============================================
    -- PERMISSION SYSTEM
    -- ============================================
    permissions = {
        defaultGroup = "user",
        autoAssign = true,
    },
}

-- Export function
if IsDuplicityVersion() then
    exports("GetConfig", function() return Config end)
else
    exports("GetConfig", function() return Config end)
end

return Config