-- 📁 server/player.lua

local Players = {}
local SaveDelay = 30000 -- sauvegarde toutes les 30s

local Player = {}
Player.__index = Player

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

    print("^2[Union] Création d'un nouvel objet joueur: " .. self.name)

    self:loadFromDatabase(function()
        print("^2[Union] Joueur chargé: " .. self.name)
    end)

    return self
end

function Player:loadFromDatabase(cb)
    local identifier = self.identifier

    print("^3[Union] Chargement de l'utilisateur: " .. identifier)

    exports.oxmysql:execute('SELECT * FROM users WHERE identifier = ?', {identifier}, function(result)
        print("^3[Union] Résultat de la requête utilisateur: " .. json.encode(result))
        if result and #result > 0 then
            local user = result[1]
            self.permission = user.permission_level
            self.group = user.group
            self.userId = user.id

            exports.oxmysql:execute('UPDATE users SET last_login = NOW() WHERE id = ?', {user.id})
            self:loadCharacters(cb)
        else
            exports.oxmysql:execute('INSERT INTO users (identifier, license, name) VALUES (?, ?, ?)', {
                identifier, self.license, self.name
            }, function(insertId)
                self.userId = insertId
                if cb then cb() end
            end)
        end
    end)
end

function Player:loadCharacters(cb)
    exports.oxmysql:execute('SELECT * FROM characters WHERE user_id = ?', {self.userId}, function(chars)
        self.characters = chars or {}
        if cb then cb() end
    end)
end

function Player:selectCharacter(id, cb)
    local selected
    for _, char in ipairs(self.characters) do
        if char.id == id then selected = char break end
    end
    if not selected then return cb(false) end

    self.currentCharacter = selected
    self:loadCharacterData(function()
        local pos = vector3(selected.position_x or Config.spawnPos.x, selected.position_y or Config.spawnPos.y, selected.position_z or Config.spawnPos.z)
        local heading = selected.heading or Config.heading

        TriggerClientEvent("spawn:client:applyCharacter", self.source, selected.model, pos, heading, "casual")
        TriggerEvent("union:characterSelected", self.source, id)
        self:setupInventory()
        if cb then cb(true) end
    end)
end

function Player:loadCharacterData(cb)
    local id = self.currentCharacter.id

    exports.oxmysql:execute('SELECT * FROM character_appearances WHERE character_id = ?', {id}, function(res)
        if res and #res > 0 then
            self.currentCharacter.appearance = json.decode(res[1].skin_data)
            self.currentCharacter.faceFeatures = json.decode(res[1].face_features)
            self.currentCharacter.tattoos = json.decode(res[1].tattoos)
        end

        exports.oxmysql:execute('SELECT * FROM ox_inventory WHERE owner = ?', {tostring(id)}, function(inv)
            if not inv or #inv == 0 then
                print("^3[Union] Inventaire non trouvé pour le personnage " .. id)
            else
                print("^2[Union] Inventaire existant pour le personnage " .. id)
            end
            if cb then cb() end
        end)
    end)
end

function Player:setupInventory()
    local id = self.currentCharacter.id
    if not id then return end

    local ident = 'char:' .. id
    if exports.ox_inventory then
        if not exports.ox_inventory:GetInventory(ident) then
            print("^2[Union] Création inventaire pour " .. id)
            exports.ox_inventory:CreateInventory(ident, self.currentCharacter.firstname .. ' ' .. self.currentCharacter.lastname, 'player', 30, 50000, id)

            if not self.currentCharacter.last_played then
                for _, item in ipairs({
                    {name = 'phone', count = 1},
                    {name = 'water', count = 3},
                    {name = 'bread', count = 2}
                }) do
                    exports.ox_inventory:AddItem(ident, item.name, item.count)
                end
            end
        end

        exports.ox_inventory:SetPlayerInventory(self.source, ident)
        TriggerClientEvent("union:inventoryReady", self.source)
    else
        print("^1[Union] ERREUR: ox_inventory non disponible")
    end
end

function Player:createCharacter(data, cb)
    if not data.firstname or not data.lastname or not data.dateofbirth or not data.gender then
        return cb(false, "Données incomplètes")
    end

    local model = data.gender == "f" and "mp_f_freemode_01" or "mp_m_freemode_01"

    exports.oxmysql:execute([[INSERT INTO characters
        (user_id, firstname, lastname, dateofbirth, gender, model, position_x, position_y, position_z, heading)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        self.userId, data.firstname, data.lastname, data.dateofbirth, data.gender, model,
        Config.spawnPos.x, Config.spawnPos.y, Config.spawnPos.z, Config.heading
    }, function(id)
        self:loadCharacters(function()
            if cb then cb(true, id) end
        end)
    end)
end

function Player:saveCharacter()
    if not self.currentCharacter then return end
    local ped = GetPlayerPed(self.source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local health = GetEntityHealth(ped)
    local armor = GetPedArmour(ped)

    exports.oxmysql:execute([[UPDATE characters SET
        position_x = ?, position_y = ?, position_z = ?, heading = ?,
        health = ?, armor = ?, last_played = NOW()
        WHERE id = ?]], {
        coords.x, coords.y, coords.z, heading,
        health, armor, self.currentCharacter.id
    })

    if self.currentCharacter.appearance then
        exports.oxmysql:execute([[UPDATE character_appearances SET
            skin_data = ?, face_features = ?, tattoos = ?
            WHERE character_id = ?]], {
            json.encode(self.currentCharacter.appearance),
            json.encode(self.currentCharacter.faceFeatures),
            json.encode(self.currentCharacter.tattoos),
            self.currentCharacter.id
        })
    end

    print("^3[Union] Données sauvegardées pour: " .. self.name)
end

function Player:disconnect()
    self:saveCharacter()
    if self.currentCharacter then
        local ident = 'char:' .. self.currentCharacter.id
        exports.ox_inventory:SaveInventory(ident)
    end
    Players[self.source] = nil
    print("^3[Union] Joueur déconnecté: " .. self.name)
end

-- 🔁 Boucle de sauvegarde
CreateThread(function()
    while true do
        Wait(SaveDelay)
        for _, p in pairs(Players) do
            if p.currentCharacter then
                p:saveCharacter()
            end
        end
    end
end)

-- 🌐 Exports et accès global
function GetPlayerFromId(source) return Players[source] end
function GetAllPlayers() return Players end
exports("GetPlayerFromId", GetPlayerFromId)
exports("GetAllPlayers", GetAllPlayers)
exports("GetCharacterInventoryId", function(id) return 'char:' .. id end)

-- 🔄 Événements serveur
RegisterNetEvent("union:playerJoined", function()
    local src = source
    local id = GetPlayerIdentifier(src, 0)
    local license = GetPlayerIdentifier(src, 1)
    if not id then DropPlayer(src, "Identifiant Steam introuvable.") return end
    Players[src] = Player.new(src, id, license)
    TriggerClientEvent("union:playerLoaded", src)
end)

AddEventHandler("playerDropped", function()
    local src = source
    local p = GetPlayerFromId(src)
    if p then p:disconnect() end
end)

RegisterNetEvent("union:createCharacter", function(data)
    local src = source
    local p = GetPlayerFromId(src)
    if p then
        p:createCharacter(data, function(success, id)
            TriggerClientEvent("union:characterCreated", src, success, id)
        end)
    end
end)

RegisterNetEvent("union:selectCharacter", function(id)
    local src = source
    local p = GetPlayerFromId(src)
    if p then
        p:selectCharacter(id, function(success)
            TriggerClientEvent("union:characterSelected", src, success)
        end)
    end
end)

RegisterNetEvent("union:openInventory", function()
    local src = source
    local p = GetPlayerFromId(src)
    if p and p.currentCharacter then
        TriggerClientEvent('ox_inventory:openInventory', src, 'player')
    end
end)