-- server/modules/player/main.lua
-- FIX: le nom "Player" entre en conflit avec le native FiveM Player(source)
--      → La classe est exportée sous le nom "PlayerClass" pour que manager.lua
--        puisse l'utiliser sans ambiguïté.

PlayerClass = {}
PlayerClass.metatable = {}
PlayerClass.metatable.__index = PlayerClass
PlayerClass.logger = Logger:child("PLAYER")

function PlayerClass.new(source)
    local self = setmetatable({}, PlayerClass.metatable)

    self.source      = source
    self.identifiers = Auth.Identifier.get(source)
    self.license     = self.identifiers.license
    self.discord     = self.identifiers.discord
    self.name        = self.identifiers.name
    self.ip          = self.identifiers.ip

    self.userId           = nil
    self.characters       = {}
    self.currentCharacter = nil
    self.permission       = 0
    self.group            = "user"

    self.isLoading    = true
    self.isSpawned    = false
    self.lastActivity = os.time()

    PlayerClass.logger:info("Player created: " .. self.name .. " (" .. self.license .. ")")

    return self
end

function PlayerClass:loadFromDatabase(callback)
    if not self.license then
        PlayerClass.logger:error("Cannot load player without license")
        if callback then callback(false) end
        return
    end

    Database.fetchOne(
        "SELECT * FROM users WHERE identifier = ?",
        { self.license },
        function(result)
            if result then
                self.userId     = result.id
                self.permission = result.permission_level or 0
                self.group      = result.group or "user"

                PlayerClass.logger:info("User loaded: " .. self.name)
                self:loadCharacters(callback)
            else
                Database.insert(
                    "INSERT INTO users (identifier, discord, name) VALUES (?, ?, ?)",
                    { self.license, self.discord, self.name },
                    function(userId)
                        if userId then
                            self.userId = userId
                            PlayerClass.logger:info("New user created: " .. self.name)
                            self:loadCharacters(callback)
                        else
                            PlayerClass.logger:error("Failed to create new user")
                            if callback then callback(false) end
                        end
                    end
                )
            end
        end
    )
end

function PlayerClass:loadCharacters(callback)
    Database.fetch(
        "SELECT * FROM characters WHERE identifier = ?",
        { self.license },
        function(characters)
            self.characters = characters or {}
            PlayerClass.logger:info(#self.characters .. " characters loaded for " .. self.name)
            if callback then callback(true) end
        end
    )
end

function PlayerClass:setActivity()
    self.lastActivity = os.time()
end

function PlayerClass:getOnlineTime()
    return os.time() - self.lastActivity
end

function PlayerClass:kick(reason)
    reason = reason or "No reason provided"
    PlayerClass.logger:warn("Kicking player " .. self.name .. ": " .. reason)
    Auth.Webhooks.playerKicked(self.source, reason)
    DropPlayer(self.source, reason)
end

function PlayerClass:ban(reason, duration)
    reason   = reason   or "No reason provided"
    duration = duration or 0
    PlayerClass.logger:warn("Banning player " .. self.name .. ": " .. reason)

    Database.execute(
        "UPDATE users SET banned = 1 WHERE id = ?",
        { self.userId },
        function()
            Auth.Webhooks.playerBanned(self.license, reason, duration)
            self:kick("You have been banned: " .. reason)
        end
    )
end

function PlayerClass:notify(message, type, duration)
    ServerUtils.notifyPlayer(self.source, message, type, duration)
end

function PlayerClass:isAdmin()
    return self.permission >= 2 or self.group == "admin"
end

function PlayerClass:isModerator()
    return self.permission >= 1 or self.group == "moderator"
end

function PlayerClass:hasPermission(permission)
    return PermissionSystem.hasPermission(self.source, permission)
end

-- Alias rétrocompatible (certains modules utilisent encore "Player" directement)
-- ATTENTION : ce alias est défini APRÈS le native Player(), donc il l'écrase.
-- C'est intentionnel ici car on charge main.lua avant manager.lua.
-- manager.lua utilise PlayerClass.new() pour éviter toute ambiguïté future.
Player = PlayerClass

return PlayerClass