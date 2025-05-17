-- 📁 server/player.lua

local Players = {}
local SaveDelay = 30000 -- sauvegarde toutes les 30s

-- 🔤 Générateur d'ID aléatoire
local function GenerateUniqueID(length)
    local CHARSET = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = ''
    for i = 1, length do
        local rand = math.random(#CHARSET)
        id = id .. CHARSET:sub(rand, rand)
    end
    return id
end

-- 🔄 Génère un ID unique en base
---@param callback fun(id: string)
local function GetValidUniqueID(callback)
    local function try()
        local candidate = GenerateUniqueID(12)
        exports.oxmysql:execute('SELECT COUNT(*) as count FROM characters WHERE unique_id = ?', {candidate}, function(result)
            if result[1].count == 0 then
                callback(candidate)
            else
                try()
            end
        end)
    end
    try()
end

local Player = {}
Player.__index = Player

function Player.new(source, identifier, license, discord)
    local self = setmetatable({}, Player)
    self.source = source
    self.identifier = identifier
    self.license = license
    self.discord = discord
    self.name = GetPlayerName(source)
    self.userId = license
    self.characters = {}
    self.currentCharacter = nil
    self.permission = 0
    self.group = "user"

    print("^2[Union] Joueur connecté: " .. self.name .. " (" .. license .. ")")

    self:loadCharacters(function()
        print("^2[Union] Personnages chargés pour: " .. self.name)
    end)

    return self
end

function Player:loadCharacters(cb)
    exports.oxmysql:execute('SELECT * FROM characters WHERE user_id = ?', {self.userId}, function(chars)
        self.characters = chars or {}
        if cb then cb() end
    end)
end

function Player:createCharacter(data, cb)
    -- 🔒 Validation des champs requis
    if not data.firstname or not data.lastname or not data.dateofbirth or not data.gender then
        return cb and cb(false, "Données incomplètes")
    end

    -- 🔧 Fonction de nettoyage basique
    local function EscapeSQLStr(str)
        if not str then return "" end
        return str:gsub("'", "''"):sub(1, 64)
    end

    local firstname = EscapeSQLStr(data.firstname)
    local lastname = EscapeSQLStr(data.lastname)
    local dateofbirth = EscapeSQLStr(data.dateofbirth)
    local gender = data.gender == "f" and "f" or "m"
    local model = gender == "f" and "mp_f_freemode_01" or "mp_m_freemode_01"

    GetValidUniqueID(function(uniqueID)
        exports.oxmysql:execute([[
            INSERT INTO characters 
            (user_id, unique_id, firstname, lastname, dateofbirth, gender, model, position_x, position_y, position_z, heading) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            self.userId, uniqueID, firstname, lastname, dateofbirth, gender, model,
            Config.spawnPos.x, Config.spawnPos.y, Config.spawnPos.z, Config.heading
        }, function(result)
            local characterId = result and result.insertId
            if not characterId then
                print("^1[Union] Erreur : aucun insertId reçu pour le personnage.")
                return cb and cb(false)
            end

            exports.oxmysql:execute('INSERT INTO character_appearances (character_id) VALUES (?)', {characterId}, function()
                self:loadCharacters(function()
                    if cb then cb(true, characterId, uniqueID) end
                end)
            end)
        end)
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
            self.currentCharacter.appearance = json.decode(res[1].skin_data or '{}')
            self.currentCharacter.faceFeatures = json.decode(res[1].face_features or '{}')
            self.currentCharacter.tattoos = json.decode(res[1].tattoos or '{}')
        end

        exports.oxmysql:execute('SELECT * FROM ox_inventory WHERE owner = ?', {tostring(id)}, function(inv)
            if not inv or #inv == 0 then
                print("^3[Union] Inventaire non trouvé pour " .. id)
            else
                print("^2[Union] Inventaire trouvé pour " .. id)
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
            print("^2[Union] Création d'inventaire pour " .. id)
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

function Player:saveCharacter()
    if not self.currentCharacter then return end
    local ped = GetPlayerPed(self.source)
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

    if self.currentCharacter.appearance then
        exports.oxmysql:execute([[
            UPDATE character_appearances SET 
            skin_data = ?, face_features = ?, tattoos = ? 
            WHERE character_id = ?
        ]], {
            json.encode(self.currentCharacter.appearance),
            json.encode(self.currentCharacter.faceFeatures),
            json.encode(self.currentCharacter.tattoos),
            self.currentCharacter.id
        })
    end

    print("^3[Union] Sauvegarde effectuée pour : " .. self.name)
end

function Player:disconnect()
    self:saveCharacter()
    if self.currentCharacter then
        local ident = 'char:' .. self.currentCharacter.id
        exports.ox_inventory:SaveInventory(ident)
    end
    Players[self.source] = nil
    print("^3[Union] Déconnexion de : " .. self.name)
end

-- 🔁 Sauvegarde automatique
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

-- 🌐 Exports
function GetPlayerFromId(source) return Players[source] end
function GetAllPlayers() return Players end
exports("GetPlayerFromId", GetPlayerFromId)
exports("GetAllPlayers", GetAllPlayers)
exports("GetCharacterInventoryId", function(id) return 'char:' .. id end)

-- 🔄 Événements
RegisterNetEvent("union:playerJoined", function()
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local identifier, license, discord

    for _, id in ipairs(identifiers) do
        if string.find(id, "license:") then license = id end
        if string.find(id, "discord:") then discord = id:gsub("discord:", "") end
        if not identifier and not string.find(id, "ip:") then identifier = id end
    end

    if not discord then DropPlayer(src, "Discord requis.") return end
    if not identifier or not license then DropPlayer(src, "Identifiants invalides.") return end

    Players[src] = Player.new(src, identifier, license, discord)
    TriggerClientEvent("union:playerLoaded", src)
end)

AddEventHandler("playerDropped", function()
    local src = source
    local p = GetPlayerFromId(src)
    if p then p:disconnect() end
end)

RegisterNetEvent("union:listCharacters", function()
    local src = source
    local player = GetPlayerFromId(src)
    if not player then return end

    local list = {}
    for _, char in ipairs(player.characters) do
        list[#list + 1] = {
            id = char.id,
            unique_id = char.unique_id,
            firstname = char.firstname,
            lastname = char.lastname,
            dateofbirth = char.dateofbirth,
            gender = char.gender
        }
    end

    TriggerClientEvent("union:receiveCharacterList", src, list)
end)

RegisterNetEvent("union:createCharacter", function(data)
    local src = source
    local p = GetPlayerFromId(src)
    if p then
        p:createCharacter(data, function(success, id, uniqueID)
            TriggerClientEvent("union:characterCreated", src, success, id, uniqueID)
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
