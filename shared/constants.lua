-- shared/constants.lua
Constants = {
    -- Player states
    PLAYER_STATE = {
        SPAWNING = "spawning",
        SPAWNED = "spawned",
        DEAD = "dead",
        LOADING = "loading",
    },
    
    -- Character states
    CHARACTER_STATE = {
        CREATING = "creating",
        CREATED = "created",
        SELECTED = "selected",
        DELETING = "deleting",
    },
    
    -- Job grades (standard structure)
    JOB_GRADES = {
        UNEMPLOYED = 0,
        RECRUIT = 1,
        OFFICER = 2,
        SERGEANT = 3,
        LIEUTENANT = 4,
        COMMANDER = 5,
    },
    
    -- Gender
    GENDER = {
        MALE = "m",
        FEMALE = "f",
    },
    
    -- Default animation dictionaries
    ANIMATIONS = {
        COMBAT = "combat@damage@rb_writhe",
        SCENARIO = "mini@corruption",
    },
    
    -- Weapons
    WEAPONS = {
        UNARMED = "WEAPON_UNARMED",
        PISTOL = "WEAPON_PISTOL",
        CARBINE = "WEAPON_CARBINERIFLE",
        SNIPER = "WEAPON_SNIPERRIFLE",
    },
    
    -- Event names (for consistency)
    EVENTS = {
        -- Client
        PLAYER_SPAWNED = "union:player:spawned",
        CHARACTER_CREATED = "union:character:created",
        CHARACTER_SELECTED = "union:character:selected",
        
        -- Server
        PLAYER_JOINED = "union:player:joined",
        PLAYER_DISCONNECTED = "union:player:disconnected",
        CHARACTER_LOADED = "union:character:loaded",
    },
}

return Constants