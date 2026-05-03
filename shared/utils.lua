-- shared/utils.lua
-- FIXES:
--   #1 : Utils.hasPermission — appel corrigé de PermissionSystem.HasPermission
--        (majuscule incorrecte) → PermissionSystem.hasPermission

Utils = {}

function Utils.log(tag, message, level)
    level = level or "INFO"
    local colors = { DEBUG="^5", INFO="^2", WARN="^3", ERROR="^1" }
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
    if maxLen then str = str:sub(1, maxLen) end
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

function Utils.validateDate(date)
    if not date then return false end
    local year, month, day = date:match("(%d+)-(%d+)-(%d+)")
    if not year or not month or not day then return false end
    local y, m, d = tonumber(year), tonumber(month), tonumber(day)
    if y < 1900 or y > 2006 then return false end
    if m < 1 or m > 12 then return false end
    if d < 1 or d > 31 then return false end
    return true
end

-- FIX #1 : correction de la casse (hasPermission, pas HasPermission)
function Utils.hasPermission(permission)
    if IsDuplicityVersion() then
        return PermissionSystem.hasPermission(source, permission)
    else
        return false
    end
end

return Utils
