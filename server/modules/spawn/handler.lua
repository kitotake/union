-- server/modules/spawn/handler.lua
-- FIX SH-1 : ped_model (colonne réelle, pas "model").
-- FIX SH-2 : position transmise comme table JSON-sérialisable (pas vector3 brut).
-- FIX SH-3 : guard anti-double confirm avec nettoyage fiable.
-- FIX SH-4 : SpawnHandler._confirming nettoyé immédiatement à playerDropped.
-- FIX SH-5 : auto-spawn 1 personnage — le fallback ne doit PAS envoyer un 2ème
--            spawn:apply si Character.select() a déjà déclenché le premier.
--            On utilise un flag _selectSent pour garantir un seul envoi.

SpawnHandler        = {}
SpawnHandler.logger = Logger:child("SPAWN:HANDLER")

SpawnHandler._sessions   = {}
SpawnHandler._confirming = {}

local function isConnected(src)
    return GetPlayerEndpoint(src) ~= nil
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SPAWN INITIAL
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:requestInitial", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player then
        SpawnHandler.logger:error("requestInitial: joueur introuvable pour source " .. src)
        return
    end

    if player.isLoading then
        local waited = 0
        while player.isLoading and waited < 50 do
            Wait(100)
            waited = waited + 1
        end
    end

    if not isConnected(src) then
        SpawnHandler.logger:warn("requestInitial: joueur " .. src .. " déconnecté pendant l'attente")
        return
    end

    local chars = player.characters or {}

    if #chars == 0 then
        SpawnHandler.logger:info(("Joueur %s : 0 personnage → création"):format(player.name))
        TriggerClientEvent("union:spawn:noCharacters", src)
        TriggerClientEvent("kt_character:openCreator", src)
        return
    end

    if #chars == 1 then
        SpawnHandler.logger:info(("Joueur %s : 1 personnage → auto-spawn"):format(player.name))

        -- FIX SH-5 : flag local pour éviter le double envoi.
        -- Character.select() déclenche spawn:apply via TriggerClientEvent.
        -- En cas d'échec de select (DB fail, etc.), on envoie un fallback
        -- UNIQUEMENT si select() n'a pas déjà émis spawn:apply.
        local spawnSent = false

        Character.select(player, chars[1].id, function(success)
            if success then
                -- Character.select() a déjà appelé TriggerClientEvent("union:spawn:apply")
                -- dans character/main.lua — on ne renvoie rien ici.
                spawnSent = true
                SpawnHandler.logger:info(("Auto-spawn OK pour %s"):format(player.name))
            else
                SpawnHandler.logger:error("Auto-select échoué pour " .. player.name)
                -- Fallback uniquement si aucun spawn:apply n'a été émis
                if not spawnSent and isConnected(src) then
                    spawnSent = true
                    TriggerClientEvent("union:spawn:apply", src, SpawnHandler._buildCharData(chars[1]))
                end
            end
        end)

        return
    end

    SpawnHandler.logger:info(("Joueur %s : %d personnages → sélection NUI"):format(player.name, #chars))

    TriggerClientEvent("characters:openSelection", src, {
        slots      = player.slots or 1,
        characters = chars,
    })
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- No-op pour characters:playerReady
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("characters:playerReady", function()
    SpawnHandler.logger:debug("characters:playerReady reçu de src=" .. tostring(source) .. " (ignoré)")
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPER : construit charData compatible client
-- FIX SH-1 : ped_model au lieu de model (colonne réelle)
-- FIX SH-2 : position sous forme de table { x, y, z } et non vector3
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function SpawnHandler._buildCharData(char)
    local defPos = Config.spawn.defaultPosition
    local defHdg = Config.spawn.defaultHeading
    local px, py, pz, heading = defPos.x, defPos.y, defPos.z, defHdg

    if char.position then
        local ok, p = pcall(json.decode, tostring(char.position))
        if ok and p and p.x then
            px, py, pz = p.x, p.y, p.z
            heading    = p.heading or defHdg
        end
    end

    return {
        id          = char.id,
        unique_id   = char.unique_id,
        firstname   = char.firstname,
        lastname    = char.lastname,
        -- FIX SH-1 : ped_model est la colonne réelle (pas "model")
        ped_model   = char.ped_model or Config.spawn.defaultModel,
        dateofbirth = char.dateofbirth,
        -- FIX SH-2 : table JSON-sérialisable (pas vector3)
        position    = { x = px, y = py, z = pz },
        heading     = heading,
        health      = char.health    or Config.character.defaultHealth,
        armor       = char.armor     or 0,
        job         = char.job       or "unemployed",
        job_grade   = char.job_grade or 0,
    }
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RESPAWN
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:requestRespawn", function(model)
    local src    = source
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return end
    if not isConnected(src) then return end

    local char   = player.currentCharacter
    local defPos = Config.spawn.defaultPosition

    TriggerClientEvent("union:spawn:apply", src, {
        id        = char.id,
        unique_id = char.unique_id,
        -- FIX SH-1 : ped_model (colonne réelle)
        ped_model = model or char.ped_model or Config.spawn.defaultModel,
        -- FIX SH-2 : table JSON-sérialisable
        position  = { x = defPos.x, y = defPos.y, z = defPos.z },
        heading   = Config.spawn.defaultHeading,
        health    = Config.character.defaultHealth,
        armor     = 0,
    })
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CONFIRMATION CLIENT → SPAWN RÉUSSI
-- FIX SH-3 : guard anti-double
-- FIX SH-4 : nettoyage immédiat à playerDropped
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RegisterNetEvent("union:spawn:confirm", function(uniqueId)
    local src    = source
    local player = PlayerManager.get(src)
    if not player then return end

    if SpawnHandler._confirming[src] then
        SpawnHandler.logger:warn("Double confirm ignoré pour src=" .. src)
        return
    end
    SpawnHandler._confirming[src] = true

    player.isSpawned = true
    SpawnHandler.logger:info("Spawn confirmé pour " .. player.name)

    if player.currentCharacter and player.currentCharacter.unique_id then
        if OfflinePed then
            OfflinePed.remove(player.currentCharacter.unique_id)
        end
    end

    TriggerEvent("union:player:spawned", src, player.currentCharacter)

    if isConnected(src) then
        TriggerClientEvent("union:player:spawned", src, player.currentCharacter)
    end

    SetTimeout(3000, function()
        SpawnHandler._confirming[src] = nil
    end)
end)

RegisterNetEvent("union:spawn:error", function(errorType)
    local src = source
    SpawnHandler.logger:error(("Erreur spawn [%s]: %s"):format(src, tostring(errorType)))
    SpawnHandler._confirming[src] = nil
end)

-- FIX SH-4 : nettoyage IMMÉDIAT à la déconnexion
AddEventHandler("playerDropped", function()
    local src = source
    SpawnHandler._confirming[src] = nil
    SpawnHandler._sessions[src]   = nil
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS PUBLICS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function SpawnHandler.applyCharacter(player, characterData)
    if not player or not characterData then return false end
    if not isConnected(player.source) then return false end
    TriggerClientEvent("union:spawn:apply", player.source, characterData)
    return true
end

AddEventHandler("union:player:spawned", function(src, character)
    SpawnHandler.logger:info(("union:player:spawned confirmé src=%s"):format(tostring(src)))
end)

-- Gestion du restart resource côté serveur
AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and not PlayerManager.get(src) then
            local player = PlayerManager.create(src)
            if player then
                player:loadFromDatabase(function(success)
                    if success then
                        TriggerClientEvent("union:player:loaded", src)
                    else
                        DropPlayer(src, "Échec rechargement données après restart")
                    end
                end)
            end
        end
    end
end)

return SpawnHandler