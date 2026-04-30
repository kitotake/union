-- shared/config/status_config.lua
-- Configuration partagée client/serveur pour le système de status

StatusConfig = {

    -- ── Limites ─────────────────────────────────────────────────────────────
    min = 0,
    max = 100,

    -- ── Valeurs de départ (lors de la création du personnage) ────────────────
    defaults = {
        hunger = 100,
        thirst = 100,
        stress = 0,
    },

    -- ── Tick de diminution (millisecondes, côté client) ──────────────────────
    -- La diminution se fait toutes les X ms dans le thread client
    tickInterval = 10000, -- 5 secondes par tick

    -- ── Taux de diminution par tick ─────────────────────────────────────────
    decay = {
        hunger = 0.2,   -- -0.5 par tick  → vide en ~16 minutes
        thirst = 0.3,   -- -1.0 par tick  → vide en ~8 minutes
    },

    -- ── Accumulation de stress par action ───────────────────────────────────
    stressGain = {
        shooting   = 2,   -- tir d'arme
        sprinting  = 0.5,   -- sprint
        fistFight  = 4,   -- bagarre à mains nues
        explosion  = 10,  -- explosion proche
        nearDeath  = 15,  -- vie < 30%
    },

    -- ── Récupération passive du stress ───────────────────────────────────────
    stressDecay = 0.3,  -- -0.3 par tick (récupération naturelle)

    -- ── Seuils pour les effets ───────────────────────────────────────────────
    effects = {
        -- Dommages si hunger ou thirst = 0
        damageOnEmpty   = true,
        damageAmount    = 2,          -- HP retirés par tick si stat = 0

        -- Effets visuels stress
        stressVisual    = true,
        stressHighThreshold  = 75,    -- début tremblements légers
        stressMaxThreshold   = 90,    -- effets intenses
    },

    -- ── Sauvegarde automatique côté serveur (ms) ─────────────────────────────
    -- La sauvegarde se fait aussi à la déconnexion (playerDropped)
    saveInterval = 300000, -- 5 minutes

    -- ── Synchronisation serveur → client (ms) ────────────────────────────────
    -- Le client envoie ses status au serveur pour sauvegarde
    syncInterval = 60000, -- 1 minute
}

return StatusConfig