-- ============================================================
--  -- client/modules/character/characterManager.lua
--  Système de gestion de personnages - Côté Client
-- ============================================================

local currentCharacter = nil   -- données du personnage actif
local isSpawning       = false -- verrou anti-spawn multiple
local nuiOpen          = false -- état du menu NUI

-- ============================================================
--  Utilitaires
-- ============================================================

--- Attend que le modèle d'un ped soit chargé en mémoire
local function loadModel(modelHash)
    if not IsModelValid(modelHash) then
        print(("[CHARACTERS] Modèle invalide : %s"):format(modelHash))
        return false
    end
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) do
        Wait(50)
        timeout = timeout + 50
        if timeout > 10000 then
            print("[CHARACTERS] Timeout chargement du modèle")
            return false
        end
    end
    return true
end

--- Téléporte le joueur et ajuste le sol si nécessaire
local function safeSetPosition(x, y, z, heading)
    local ped = PlayerPedId()
    NetworkResurrectLocalPlayer(x, y, z, heading, true, false)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading)
    -- Ajustement sol pour éviter le spawn sous la map
    RequestCollisionAtCoord(x, y, z)
    Wait(500)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 1.0, false)
    if found and groundZ > z - 2.0 then
        SetEntityCoordsNoOffset(ped, x, y, groundZ + 0.1, false, false, false)
    end
end

--- Applique le skin depuis le JSON stocké en BDD
local function applySkin(skinJson)
    if not skinJson then return end
    local ok, skin = pcall(json.decode, skinJson)
    if not ok or type(skin) ~= "table" then return end

    -- Exemple de compatibilité basique (à adapter à votre système de skin)
    -- Si vous utilisez fivem-appearance, qb-clothing, illenium-appearance, etc.,
    -- remplacez ce bloc par l'export correspondant.
    local ped = PlayerPedId()
    if skin.components then
        for _, comp in ipairs(skin.components) do
            SetPedComponentVariation(ped, comp.component, comp.drawable, comp.texture, comp.palette or 0)
        end
    end
    if skin.props then
        for _, prop in ipairs(skin.props) do
            SetPedPropIndex(ped, prop.anchor, prop.drawable, prop.texture, true)
        end
    end
end

-- ============================================================
--  Spawn d'un personnage (utilisé par autoSpawn et doSpawn)
-- ============================================================
local function spawnCharacter(char)
    if isSpawning then return end
    isSpawning = true

    -- Ferme le NUI si ouvert
    if nuiOpen then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "close" })
        nuiOpen = false
    end

    -- 1. Chargement du modèle
    local modelName = char.model or "mp_m_freemode_01"
    local modelHash = GetHashKey(modelName)
    local loaded    = loadModel(modelHash)

    if not loaded then
        modelHash = GetHashKey("mp_m_freemode_01")
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(100) end
    end

    -- 2. Changement de modèle
    local ped = PlayerPedId()
    SetPlayerModel(PlayerId(), modelHash)
    SetModelAsNoLongerNeeded(modelHash)
    ped = PlayerPedId()  -- refresh après changement de modèle

    -- 3. Application du skin
    applySkin(char.skin)

    -- 4. Position sécurisée
    local x, y, z, h = char.x, char.y, char.z, char.heading or 0.0
    safeSetPosition(x, y, z, h)

    -- 5. Restauration état ped
    SetPlayerInvincible(PlayerId(), false)
    SetPedCanRagdoll(ped, true)
    NetworkResurrectLocalPlayer(x, y, z, h, true, false)

    -- 6. Confirmation au serveur
    currentCharacter = char
    TriggerServerEvent("characters:spawnConfirmed", char.id)

    Wait(200)
    isSpawning = false

    print(("[CHARACTERS] Spawn OK : %s (%s)"):format(char.name, char.model))
end

-- ============================================================
--  Événements reçus depuis le serveur
-- ============================================================

--- Spawn automatique (un seul personnage)
RegisterNetEvent("characters:autoSpawn", function(char)
    Wait(1000) -- laisse le client se stabiliser
    spawnCharacter(char)
end)

--- Ouverture de l'interface de sélection (plusieurs personnages)
RegisterNetEvent("characters:openSelection", function(data)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action     = "openSelection",
        slots      = data.slots,
        characters = data.characters
    })
    nuiOpen = true
end)

--- Ouverture de l'interface de création (aucun personnage)
RegisterNetEvent("characters:openCreation", function(data)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openCreation",
        slots  = data.slots
    })
    nuiOpen = true
end)

--- Spawn déclenché après sélection validée côté serveur
RegisterNetEvent("characters:doSpawn", function(char)
    spawnCharacter(char)
end)

--- Message d'erreur serveur
RegisterNetEvent("characters:error", function(msg)
    SendNUIMessage({ action = "showError", message = msg })
end)

-- ============================================================
--  Rappel NUI → Client
-- ============================================================

--- Le joueur clique sur "Jouer" dans le menu
RegisterNUICallback("selectCharacter", function(data, cb)
    if not data.charId then
        cb({ ok = false })
        return
    end
    TriggerServerEvent("characters:selectCharacter", data.charId)
    cb({ ok = true })
end)

--- Le joueur ferme le menu (si autorisé)
RegisterNUICallback("closeMenu", function(_, cb)
    -- On ne permet pas de fermer sans avoir sélectionné
    cb({ ok = false, reason = "Vous devez sélectionner un personnage." })
end)

-- ============================================================
--  Initialisation : signale au serveur que le client est prêt
-- ============================================================
AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(2000)  -- attend que le client soit pleinement chargé
    TriggerServerEvent("characters:playerReady")
end)