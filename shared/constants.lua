-- shared/constants.lua
Constants = {
    PLAYER_STATE = {
        SPAWNING = "spawning",
        SPAWNED = "spawned",
        DEAD = "dead",
        LOADING = "loading",
    },
    CHARACTER_STATE = {
        CREATING = "creating",
        CREATED = "created",
        SELECTED = "selected",
        DELETING = "deleting",
    },
    JOB_GRADES = {
        UNEMPLOYED = 0,
        RECRUIT = 1,
        OFFICER = 2,
        SERGEANT = 3,
        LIEUTENANT = 4,
        COMMANDER = 5,
    },
    ANIMATIONS = {
        COMBAT = "combat@damage@rb_writhe",
        SCENARIO = "mini@corruption",
    },
    WEAPONS = {
        UNARMED = "WEAPON_UNARMED",
        PISTOL = "WEAPON_PISTOL",
        CARBINE = "WEAPON_CARBINERIFLE",
        SNIPER = "WEAPON_SNIPERRIFLE",
    },
    EVENTS = {
        PLAYER_SPAWNED = "union:player:spawned",
        CHARACTER_CREATED = "union:character:created",
        CHARACTER_SELECTED = "union:character:selected",
        CHARACTER_RELOADED = "union:character:reloaded",
        PLAYER_JOINED = "union:player:joined",
        PLAYER_DISCONNECTED = "union:player:disconnected",
        CHARACTER_LOADED = "union:character:loaded",
    },
}

return Constants
