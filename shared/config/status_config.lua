-- shared/config/status_config.lua

StatusConfig = {
    debug = true,
    min = 0,
    max = 100,
    defaults = {
        hunger = 100,
        thirst = 100,
        stress = 0,
    },
    tickInterval = 10000,
    decay = {
        hunger = 0.15,
        thirst = 0.25,
    },
    stressDecay = 0.5,
    stressGain = {
        shooting   = 3,
        sprinting  = 0.3,
        fistFight  = 5,
        explosion  = 12,
        nearDeath  = 20,
        meleeHit   = 2,
    },
    effects = {
        damageOnEmpty = true,
        damageAmount  = 4,
        stressVisual  = true,
    },
    saveInterval = 30000,
}

return StatusConfig
