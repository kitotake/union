-- server/player.lua

local Players = {}
local SaveDelay = 30000 -- Sauvegarde toutes les 30 secondes

-- Classe Player
local Player = {}
Player.__index = Player



-- Créer un nouveau joueur
function Player.new(source, identifier, license)
    local self = setmetatable({}, Player)
    self.source = source
    self.identifier = identifier
    self.license = license
    self.name = GetPlayerName(source)
    self.permission = 0
    self.group = "user"
    self.characters = {}
    self.currentCharacter = nil
    
    -- Charger les données du joueur depuis SQL
    self:loadFromDatabase(function()
        print("^2[Union] Joueur chargé: " .. self.name)
    end)
    
    return self
end

-- Charger les données du joueur depuis la base de données
function Player:loadFromDatabase(callback)
    local self = self
    local identifier = self.identifier
    
    exports.oxmysql:execute('SELECT * FROM users WHERE identifier = ?', {identifier}, function(result)
        if result and #result > 0 then
            local userData = result[1]
            self.permission = userData.permission_level
            self.group = userData.group
            self.userId = userData.id
            
            -- Mise à jour de la dernière connexion
            exports.oxmysql:execute('UPDATE users SET last_login = NOW() WHERE id = ?', {userData.id})
            
            -- Charger les personnages du joueur
            self:loadCharacters(callback)
        else
            -- Créer un nouvel utilisateur
            exports.oxmysql:execute('INSERT INTO users (identifier, license, name) VALUES (?, ?, ?)', 
                {identifier, self.license, self.name}, function(insertId)
                self.userId = insertId
                self.permission = 0
                self.group = "user"
                
                if callback then callback() end
            end)
        end
    end)
end

-- Charger les personnages du joueur
function Player:loadCharacters(callback)
    local self = self
    
    exports.oxmysql:execute('SELECT * FROM characters WHERE user_id = ?', {self.userId}, function(result)
        if result and #result > 0 then
            self.characters = result
            if callback then callback() end
        else
            if callback then callback() end
        end
    end)
end

-- Sélectionner un personnage
function Player:selectCharacter(characterId, callback)
    local character = nil
    
    for i, char in ipairs(self.characters) do
        if char.id == characterId then
            character = char
            break
        end
    end
    
    if not character then
        if callback then callback(false) end
        return
    end
    
    self.currentCharacter = character
    
    -- Charger les données supplémentaires (inventaire, apparence, etc.)
    self:loadCharacterData(function()
        local position = vector3(character.position_x or Config.spawnPos.x, 
                                character.position_y or Config.spawnPos.y, 
                                character.position_z or Config.spawnPos.z)
        local heading = character.heading or Config.heading
        
        -- Déclencher l'événement de spawn avec les données du personnage
        TriggerClientEvent("spawn:client:applyCharacter", self.source, character.model, position, heading, "casual")
        
        -- Déclencher un événement pour que d'autres ressources soient informées
        TriggerEvent("union:characterSelected", self.source, characterId)
        
        -- Initialiser l'inventaire du joueur
        self:setupInventory()
        
        if callback then callback(true) end
    end)
end

-- Charger les données supplémentaires du personnage (inventaire, apparence, etc.)
function Player:loadCharacterData(callback)
    local self = self
    local characterId = self.currentCharacter.id
    
    -- Charger l'apparence
    exports.oxmysql:execute('SELECT * FROM character_appearances WHERE character_id = ?', {characterId}, function(result)
        if result and #result > 0 then
            self.currentCharacter.appearance = json.decode(result[1].skin_data)
            self.currentCharacter.faceFeatures = json.decode(result[1].face_features)
            self.currentCharacter.tattoos = json.decode(result[1].tattoos)
        end
                    
        -- -- Charger les comptes bancaires
        -- exports.oxmysql:execute('SELECT * FROM bank_accounts WHERE owner_type = "character" AND owner_id = ?', {characterId}, function(bankResult)
        --     if bankResult and #bankResult > 0 then
        --         self.currentCharacter.bankAccounts = bankResult
        --     else
        --         -- Créer un compte bancaire par défaut
        --         local accountNumber = "C" .. string.format("%09d", characterId)
        --         exports.oxmysql:execute('INSERT INTO bank_accounts (account_number, owner_type, owner_id, type, balance) VALUES (?, ?, ?, ?, ?)', 
        --             {accountNumber, "character", characterId, "personal", 1000}, function(bankId)
        --             self.currentCharacter.bankAccounts = {{
        --                 id = bankId,
        --                 account_number = accountNumber,
        --                 type = "personal",
        --                 balance = 1000
        --             }}
        --         end)
        --     end
            
            -- Vérifier l'existence de l'inventaire du personnage
            exports.oxmysql:execute('SELECT * FROM ox_inventory WHERE owner = ?', {tostring(characterId)}, function(invResult)
                if not invResult or #invResult == 0 then
                    -- On ne créé pas l'inventaire ici, il sera créé lors du setupInventory
                    print("^3[Union] Inventaire non trouvé pour le personnage " .. characterId .. ", sera créé lors de la première connexion")
                else
                    print("^2[Union] Inventaire trouvé pour le personnage " .. characterId)
                end
                
                if callback then callback() end
            end)
        end)
end

-- Configurer l'inventaire du joueur
function Player:setupInventory()
    local self = self
    local characterId = self.currentCharacter.id
    
    if not characterId then return end
    
    -- Identifier unique pour ox_inventory
    local identifier = 'char:' .. characterId
    
    -- Vérifier si ox_inventory est disponible
    if exports.ox_inventory then
        -- Vérifier si l'inventaire existe déjà
        local inventory = exports.ox_inventory:GetInventory(identifier)
        
        if not inventory then
            -- Créer un nouvel inventaire pour le personnage
            print("^2[Union] Création d'un nouvel inventaire pour le personnage " .. characterId)
            exports.ox_inventory:CreateInventory(identifier, self.currentCharacter.firstname .. ' ' .. self.currentCharacter.lastname, 'player', 30, 50000, characterId)
            
            -- Ajouter des items par défaut pour les nouveaux joueurs
            -- Vous pouvez personnaliser cette liste
            local defaultItems = {
                {name = 'phone', count = 1},
                {name = 'water', count = 3},
                {name = 'bread', count = 2}
            }
            
            -- Vérifier si c'est un nouveau personnage (jamais joué avant)
            if not self.currentCharacter.last_played then
                for _, item in ipairs(defaultItems) do
                    exports.ox_inventory:AddItem(identifier, item.name, item.count)
                end
            end
        end
        
        -- Associer l'inventaire au joueur
        exports.ox_inventory:SetPlayerInventory(self.source, identifier)
        
        -- Informer le client que l'inventaire est prêt
        TriggerClientEvent("union:inventoryReady", self.source)
    else
        print("^1[Union] ERREUR: ox_inventory n'est pas disponible!")
    end
end

-- Créer un nouveau personnage
function Player:createCharacter(data, callback)
    local self = self
    
    -- Validations de base
    if not data.firstname or not data.lastname or not data.dateofbirth or not data.gender then
        if callback then callback(false, "Données incomplètes") end
        return
    end
    
    -- Déterminer le modèle en fonction du genre
    local model = "mp_m_freemode_01"
    if data.gender == "f" then
        model = "mp_f_freemode_01"
    end
    
    -- Insertion dans la base de données
    exports.oxmysql:execute('INSERT INTO characters (user_id, firstname, lastname, dateofbirth, gender, model, position_x, position_y, position_z, heading) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', 
        {self.userId, data.firstname, data.lastname, data.dateofbirth, data.gender, model, 
         Config.spawnPos.x, Config.spawnPos.y, Config.spawnPos.z, Config.heading}, function(characterId)
        
        -- Recharger les personnages du joueur
        self:loadCharacters(function()
            if callback then callback(true, characterId) end
        end)
    end)
end

-- Sauvegarder les données du personnage
function Player:saveCharacter()
    local self = self
    if not self.currentCharacter then return end
    
    -- Récupérer la position actuelle du joueur
    local ped = GetPlayerPed(self.source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local health = GetEntityHealth(ped)
    local armor = GetPedArmour(ped)
    
    -- Mettre à jour les données du personnage
    exports.oxmysql:execute('UPDATE characters SET position_x = ?, position_y = ?, position_z = ?, heading = ?, health = ?, armor = ?, last_played = NOW() WHERE id = ?', 
        {coords.x, coords.y, coords.z, heading, health, armor, self.currentCharacter.id})
    
    -- Sauvegarder l'apparence si modifiée
    if self.currentCharacter.appearance then
        exports.oxmysql:execute('UPDATE character_appearances SET skin_data = ?, face_features = ?, tattoos = ? WHERE character_id = ?', 
            {json.encode(self.currentCharacter.appearance), json.encode(self.currentCharacter.faceFeatures), json.encode(self.currentCharacter.tattoos), self.currentCharacter.id})
    end
    
    -- L'inventaire est sauvegardé automatiquement par ox_inventory
    
    print("^3[Union] Données du personnage sauvegardées pour: " .. self.name)
end

-- Obtenir des informations sur le joueur
function Player:getInfo()
    return {
        source = self.source,
        name = self.name,
        permission = self.permission,
        group = self.group,
        characterCount = #self.characters
    }
end

-- Obtenir des informations sur le personnage actuel
function Player:getCharacterInfo()
    if not self.currentCharacter then return nil end
    
    return {
        id = self.currentCharacter.id,
        firstname = self.currentCharacter.firstname,
        lastname = self.currentCharacter.lastname,
        job = self.currentCharacter.job,
        job_grade = self.currentCharacter.job_grade,
        model = self.currentCharacter.model
    }
end

-- Déconnexion du joueur
function Player:disconnect()
    -- Sauvegarder les données avant déconnexion
    self:saveCharacter()
    
    -- Désassocier l'inventaire si nécessaire
    -- ox_inventory gère cela automatiquement, mais on peut le faire explicitement
    if self.currentCharacter then
        local characterId = self.currentCharacter.id
        local identifier = 'char:' .. characterId
        exports.ox_inventory:SaveInventory(identifier)
    end
    
    -- Supprimer de la liste des joueurs actifs
    Players[self.source] = nil
    print("^3[Union] Joueur déconnecté: " .. self.name)
end

-- Fonctions globales

-- Récupérer un joueur par ID source
function GetPlayerFromId(source)
    return Players[source]
end

-- Récupérer tous les joueurs connectés
function GetAllPlayers()
    return Players
end

-- Connexion d'un joueur
RegisterNetEvent("union:playerJoined")
AddEventHandler("union:playerJoined", function()
    local source = source
    local identifier = GetPlayerIdentifier(source, 0) -- steam
    local license = GetPlayerIdentifier(source, 1) -- license
    
    if not identifier then
        DropPlayer(source, "Impossible de récupérer votre identifiant Steam.")
        return
    end
    
    -- Créer une instance de joueur
    Players[source] = Player.new(source, identifier, license)
    
    -- Informer le client que le chargement est terminé
    TriggerClientEvent("union:playerLoaded", source)
end)

-- Événement de déconnexion
AddEventHandler("playerDropped", function(reason)
    local source = source
    local player = GetPlayerFromId(source)
    
    if player then
        player:disconnect()
    end
end)

-- Création d'un personnage
RegisterNetEvent("union:createCharacter")
AddEventHandler("union:createCharacter", function(data)
    local source = source
    local player = GetPlayerFromId(source)
    
    if player then
        player:createCharacter(data, function(success, result)
            TriggerClientEvent("union:characterCreated", source, success, result)
        end)
    end
end)

-- Sélection d'un personnage
RegisterNetEvent("union:selectCharacter")
AddEventHandler("union:selectCharacter", function(characterId)
    local source = source
    local player = GetPlayerFromId(source)
    
    if player then
        player:selectCharacter(characterId, function(success)
            TriggerClientEvent("union:characterSelected", source, success)
        end)
    end
end)

-- Événement pour ouvrir l'inventaire du joueur
RegisterNetEvent("union:openInventory")
AddEventHandler("union:openInventory", function()
    local source = source
    local player = GetPlayerFromId(source)
    
    if player and player.currentCharacter then
        TriggerClientEvent('ox_inventory:openInventory', source, 'player')
    end
end)

-- Sauvegarde automatique des joueurs
CreateThread(function()
    while true do
        Wait(SaveDelay)
        
        for _, player in pairs(Players) do
            if player.currentCharacter then
                player:saveCharacter()
            end
        end
    end
end)

-- Exporter les fonctions pour d'autres ressources
exports("GetPlayerFromId", GetPlayerFromId)
exports("GetAllPlayers", GetAllPlayers)
exports("GetCharacterInventoryId", function(characterId)
    return 'char:' .. characterId
end)

