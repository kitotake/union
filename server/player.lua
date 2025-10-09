local SaveDelay = 30000
Players = {}

local function IsUniqueIDInUse(uniqueID)
    local p = promise.new()

    MySQL.Async.fetchScalar("SELECT 1 FROM characters WHERE unique_id = ?", {uniqueID}, function(result)
        p:resolve(result ~= nil)
    end)

    return Citizen.Await(p)
end

-- Générateur d'ID unique
local function GenerateUniqueID(length)
    local CHARSET = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = ''
    for i = 1, length do
        local rand = math.random(#CHARSET)
        id = id .. CHARSET:sub(rand, rand)
    end
    return id
end

local function GetValidUniqueID(callback)
    local function try()
        local candidate = GenerateUniqueID(12)
        exports.oxmysql:execute('SELECT COUNT(*) as count FROM characters WHERE unique_id = ?', {candidate}, function(result)
            if result and result[1] and result[1].count == 0 then
                callback(candidate)
            else
                try()
            end
        end)
    end
    try()
end

-- Classe Player
local Player = {}
Player.__index = Player

function Player.new(source, license, discord)
    local self = setmetatable({}, Player)
    self.source = source
    self.license = license
    self.discord = discord
    self.name = GetPlayerName(source)
    self.characters = {}
    self.currentCharacter = nil
    self.permission = 0
    self.group = "user"

    print("^2[UNION] Joueur connecté: " .. self.name .. " (" .. license .. ")")
    
    -- Charger les personnages
    self:loadCharacters()
    
    return self
end


function Player:loadFromDatabase(cb)
    local identifier = self.identifier

    print("^3[Union] Chargement de l'utilisateur: " .. identifier)

    exports.oxmysql:execute('SELECT * FROM users WHERE identifier = ?', {identifier}, function(result)
        print("^3[Union] Résultat de la requête utilisateur: " .. json.encode(result))
        if result and #result > 0 then
            local user = result[1]Add commentMore actions
            self.permission = user.permission_level
            self.group = user.group
            self.userId = user.id

            exports.oxmysql:execute('UPDATE users SET last_login = NOW() WHERE id = ?', {user.id})
            self:loadCharacters(cb)
        else
            exports.oxmysql:execute('INSERT INTO users (identifier, name) VALUES (?, ?, ?)', {
                identifier, self.license, self.name
            }, function(insertId)
                self.userId = insertId
                if cb then cb() end
            end)
        end
    end)
end


function Player:loadCharacters(cb)
    exports.oxmysql:execute('SELECT * FROM characters WHERE identifier = ?', {self.license}, function(chars)
        self.characters = chars or {}
        print("^2[UNION] " .. #self.characters .. " personnages chargés pour " .. self.name)
        if cb then cb() end
    end)
end

function Player:createCharacter(data, cb)
    if not data.firstname or not data.lastname or not data.dateofbirth or not data.gender then
        return cb and cb(false, "Données incomplètes")
    end

    local function cleanString(str)
        if not str then return "" end
        return str:gsub("'", "''"):sub(1, 64)
    end

    local identifier = GetPlayerIdentifierByType(src, "license")
    local firstname = cleanString(data.firstname)
    local lastname = cleanString(data.lastname)
    local dateofbirth = cleanString(data.dateofbirth)
    local gender = data.gender == "f" and "f" or "m"
    local model = gender == "f" and Config.femaleModel or Config.defaultModel

    GetValidUniqueID(function(uniqueID)
        exports.oxmysql:execute([[
            INSERT INTO characters 
            (identifier, unique_id, firstname, lastname, dateofbirth, gender, model, position_x, position_y, position_z, heading) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            self.license, uniqueID, firstname, lastname, dateofbirth, gender, model,
            Config.spawnPos.x, Config.spawnPos.y, Config.spawnPos.z, Config.heading
        }, function(result)
            if result and result.insertId then
                -- Créer l'apparence par défaut
                exports.oxmysql:execute('INSERT INTO character_appearances (character_id) VALUES (?)', {result.insertId}, function()
                    self:loadCharacters(function()
                        if cb then cb(true, result.insertId, uniqueID) end
                    end)
                end)
            else
                print("^1[UNION] Erreur création personnage")
                if cb then cb(false) end
            end
        end)
    end)
end

function Player:selectCharacter(id, cb)
    local selected = nil
    for _, char in ipairs(self.characters) do
        if char.id == id then 
            selected = char 
            break 
        end
    end
    
    if not selected then 
        return cb and cb(false) 
    end

    self.currentCharacter = selected
    
    -- Spawn du personnage
    local pos = vector3(
        selected.position_x or Config.spawnPos.x,
        selected.position_y or Config.spawnPos.y,
        selected.position_z or Config.spawnPos.z
    )
    local heading = selected.heading or Config.heading

    TriggerClientEvent("spawn:client:applyCharacter", self.source, selected.model, pos, heading, "casual")
        
    if cb then cb(true) end
end


function Player:saveCharacter()
    if not self.currentCharacter then return end
    
    local ped = GetPlayerPed(self.source)
    if not DoesEntityExist(ped) then return end
    
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local health = GetEntityHealth(ped)
    local armor = GetPedArmour(ped)

    exports.oxmysql:execute([[
        UPDATE characters SET 
        position_x = ?, position_y = ?, position_z = ?, heading = ?, 
        health = ?, armor = ?, last_played = NOW() 
        WHERE id = ?
    ]], {
        coords.x, coords.y, coords.z, heading,
        health, armor, self.currentCharacter.id
    })
end

function Player:disconnect()
    self:saveCharacter()
    if self.currentCharacter  then
        local ident = 'char:' .. self.currentCharacter.id
    end
    Players[self.source] = nil
    print("^3[UNION] Déconnexion: " .. self.name)
end

-- Sauvegarde automatique
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

function GetPlayerFromId(source) 
    return Players and Players[source] or nil
end

function GetAllPlayers() 
    return Players or {}
end

exports("GetPlayerFromId", GetPlayerFromId)
exports("GetAllPlayers", GetAllPlayers)

-- Events
RegisterNetEvent("union:playerJoined", function()
    local src = source
    local license = GetPlayerIdentifierByType(src, "license")
    local discord = GetPlayerIdentifierByType(src, "discord")
    
    if not license or not discord then
        DropPlayer(src, "Identifiants requis manquants")
        return
    end
    
    Players[src] = Player.new(src, license, discord)
    TriggerClientEvent("union:playerLoaded", src)
end)

AddEventHandler("playerDropped", function()
    local src = source
    local player = GetPlayerFromId(src)
    if player then
        player:disconnect()
    end
end)

RegisterNetEvent("union:playerJoined", function()
    local src = source
    local license = GetPlayerIdentifierByType(src, "license")
    local discord = GetPlayerIdentifierByType(src, "discord")
    
    if not license or not discord then
        DropPlayer(src, "Identifiants requis manquants")
        return
    end

    Players[src] = Player.new(src, license, discord)

    -- Retarde l'émission jusqu'à ce que les personnages soient chargés
    local player = Players[src]
    player:loadCharacters(function()
        TriggerClientEvent("union:playerLoaded", src)
    end)
end)

RegisterNetEvent("union:createCharacter", function(data)
    local src = source
    local player = GetPlayerFromId(src)
    if player then
        player:createCharacter(data, function(success, id, uniqueID)
            TriggerClientEvent("union:characterCreated", src, success, id, uniqueID)
        end)
    end
end)

RegisterNetEvent("union:selectCharacter", function(id)
    local src = source
    local player = GetPlayerFromId(src)
    if player then
        player:selectCharacter(id, function(success)
            TriggerClientEvent("union:characterSelected", src, success)
        end)
    end
end)    