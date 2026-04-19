-- shared/utils.lua
Utils = {}

function Utils.log(tag, message, level)
    level = level or "INFO"
    local colors = {
        DEBUG = "^5",
        INFO = "^2",
        WARN = "^3",
        ERROR = "^1",
    }
    local color = colors[level] or "^7"
    print(color .. "[" .. level .. "|" .. tag .. "] " .. message .. "^7")
end

function Utils.dump(data, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    
    if type(data) == "table" then
        for k, v in pairs(data) do
            if type(v) == "table" then
                print(prefix .. k .. " = {")
                Utils.dump(v, indent + 1)
                print(prefix .. "}")
            else
                print(prefix .. k .. " = " .. tostring(v))
            end
        end
    else
        print(prefix .. tostring(data))
    end
end

function Utils.safeString(str, maxLen)
    if not str then return "" end
    str = tostring(str):gsub("'", "''")
    if maxLen then
        str = str:sub(1, maxLen)
    end
    return str
end

function Utils.merge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            Utils.merge(target[k], v)
        else
            target[k] = v
        end
    end
    return target
end

function Utils.hasPermission(permission)
    if IsDuplicityVersion() then
        -- Server-side permission check
        return PermissionSystem.HasPermission(source, permission)
    else
        -- Client-side check (async)
        return false
    end
end

return Utils