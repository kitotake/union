-- shared/config/status_config.lua

StatusConfig = {

    -- ── DEBUG ─────────────────────────────────────────────────────────────
    debug = true,

    -- ── Limites ───────────────────────────────────────────────────────────
    min = 0,
    max = 100,

    -- ── Valeurs par défaut ────────────────────────────────────────────────
    defaults = {
        hunger = 100,
        thirst = 100,
        stress = 0,
    },

    -- ── Tick ──────────────────────────────────────────────────────────────
    tickInterval = 10000,      -- 10 secondes

    -- ── Décroissance par tick ─────────────────────────────────────────────
    decay = {
        hunger = 0.8,   -- augmente un peu pour un sentiment plus réaliste
        thirst = 1.2,
    },

    -- ── Stress ────────────────────────────────────────────────────────────
    stressDecay = 0.5,

    stressGain = {
        shooting   = 3,
        sprinting  = 0.3,
        fistFight  = 5,
        explosion  = 12,
        nearDeath  = 20,
        meleeHit   = 2,
    },

    -- ── Effets ────────────────────────────────────────────────────────────
    effects = {
        damageOnEmpty = true,
        damageAmount  = 4,           -- un peu plus punitif
        stressVisual  = true,
    },

    -- ── Sauvegarde ────────────────────────────────────────────────────────
    saveInterval = 300000,   -- 5 minutes
}

return StatusConfig