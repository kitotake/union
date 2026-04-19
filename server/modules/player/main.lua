-- server/modules/player/main.lua
Player = {}
Player.metatable = {}
Player.metatable.__index = Player
Player.logger = Logger:child("PLAYER")

function Player.new(source)
    local self = setmetatable({}, Player.metatable)
    
    self.source = source
    self.identifiers = Auth.Identifier.get(source)
    self.license = self.identifiers.license
    self.discord = self.identifiers.discord
    self.name = self.identifiers.name
    self.ip = self.identifiers.ip
    
    self.userId = nil
    self.characters = {}
    self.currentCharacter = nil
    self.permission = 0
    self.group = "user"
    
    self.isLoading = true
    self.isSpawned = false
    self.lastActivity = os.time()
    
    Player.logger:info("Player created: " .. self.name .. " (" .. self.license .. ")")
    
    return self
end

function Player:loadFromDatabase(callback)
    if not self.license then
        Player.logger:error("Cannot load player without license")
        if callback then callback(false) end
        return
    end
    
    Database.fetchOne(
        "SELECT * FROM users WHERE identifier = ?",
        {self.license},
        function(result)
            if result then
                self.userId = result.id
                self.permission = result.permission_level or 0
                self.group = result.group or "user"
                
                Database.execute(
                    "UPDATE users SET last_login = NOW() WHERE id = ?",
                    {self.userId},
                    function() end
                )
                
                Player.logger:info("User loaded: " .. self.name)
                self:loadCharacters(callback)
            else
                Database.insert(
                    "INSERT INTO users (identifier, discord, name) VALUES (?, ?, ?)",
                    {self.license, self.discord, self.name},
                    function(userId)
                        if userId then
                            self.userId = userId
                            Player.logger:info("New user created: " .. self.name)
                            self:loadCharacters(callback)
                        else
                            Player.logger:error("Failed to create new user")
                            if callback then callback(false) end
                        end
                    end
                )
            end
        end
    )
end

function Player:loadCharacters(callback)
    Database.fetch(
        "SELECT * FROM characters WHERE identifier = ?",
        {self.license},
        function(characters)
            self.characters = characters or {}
            Player.logger:info(#self.characters .. " characters loaded for " .. self.name)
            if callback then callback(true) end
        end
    )
end

function Player:setActivity()
    self.lastActivity = os.time()
end

function Player:getOnlineTime()
    return os.time() - self.lastActivity
end

function Player:kick(reason)
    reason = reason or "No reason provided"
    Player.logger:warn("Kicking player " .. self.name .. ": " .. reason)
    Auth.Webhooks.playerKicked(self.source, reason)
    DropPlayer(self.source, reason)
end

function Player:ban(reason, duration)
    reason = reason or "No reason provided"
    duration = duration or 0
    Player.logger:warn("Banning player " .. self.name .. ": " .. reason)
    
    Database.execute(
        "UPDATE users SET banned = 1 WHERE id = ?",
        {self.userId},
        function()
            Auth.Webhooks.playerBanned(self.license, reason, duration)
            self:kick("You have been banned: " .. reason)
        end
    )
end

function Player:notify(message, type, duration)
    ServerUtils.notifyPlayer(self.source, message, type, duration)
end

function Player:isAdmin()
    return self.permission >= 2 or self.group == "admin"
end

function Player:isModerator()
    return self.permission >= 1 or self.group == "moderator"
end

function Player:hasPermission(permission)
    -- FIXME : était HasPermission (H majuscule) → n'existait pas
    return PermissionSystem.hasPermission(self.source, permission)
end

return Player