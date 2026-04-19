-- server/modules/auth/identifiers.lua
Auth.Identifier = {}
Auth.Identifier.logger = Logger:child("AUTH:IDENTIFIER")

function Auth.Identifier.sync(source)
    local license = GetPlayerIdentifierByType(source, "license")
    local discord = GetPlayerIdentifierByType(source, "discord")
    local fivem = GetPlayerIdentifierByType(source, "fivem")
    local ip = ServerUtils.getPlayerIP(source)
    
    Auth.tempIdentifiers[source] = {
        license = license,
        discord = discord,
        fivem = fivem,
        ip = ip,
        name = GetPlayerName(source),
    }
    
    return Auth.tempIdentifiers[source]
end

function Auth.Identifier.get(source, idType)
    local identifiers = Auth.tempIdentifiers[source]
    if not identifiers then
        identifiers = Auth.Identifier.sync(source)
    end
    
    if idType then
        return identifiers[idType]
    end
    
    return identifiers
end

function Auth.Identifier.validate(identifiers)
    if not identifiers.license or identifiers.license == "" then
        return false, "Missing FiveM License"
    end
    
    if not identifiers.discord or identifiers.discord == "" then
        return false, "Missing Discord Account"
    end
    
    if not identifiers.ip or identifiers.ip == "" then
        return false, "Could not determine IP address"
    end
    
    return true, nil
end

function Auth.Identifier.getLicense(source)
    return Auth.Identifier.get(source, "license")
end

function Auth.Identifier.getDiscord(source)
    return Auth.Identifier.get(source, "discord")
end

function Auth.Identifier.getIP(source)
    return Auth.Identifier.get(source, "ip")
end

function Auth.Identifier.getName(source)
    return Auth.Identifier.get(source, "name")
end