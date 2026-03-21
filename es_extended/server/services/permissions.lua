Core.Services = Core.Services or {}
Core.Services.Permission = Core.Services.Permission or {}

local function sanitizePrincipalSegment(value)
    if type(value) ~= "string" then
        return nil
    end

    local trimmed = value:match("^%s*(.-)%s*$")
    if trimmed == "" or #trimmed > 128 then
        return nil
    end

    if trimmed:find("[^%w_:%-%.]") then
        return nil
    end

    return trimmed
end

local function runPrincipalCommand(action, identifier, group)
    local sanitizedIdentifier = sanitizePrincipalSegment(identifier)
    local sanitizedGroup = sanitizePrincipalSegment(group)
    if not sanitizedIdentifier or not sanitizedGroup then
        return false
    end

    ExecuteCommand(("%s identifier.%s group.%s"):format(action, sanitizedIdentifier, sanitizedGroup))
    return true
end

function Core.Services.Permission.attachPlayerGroup(identifier, group)
    return runPrincipalCommand("add_principal", identifier, group)
end

function Core.Services.Permission.detachPlayerGroup(identifier, group)
    return runPrincipalCommand("remove_principal", identifier, group)
end

function Core.Services.Permission.changePlayerGroup(identifier, oldGroup, newGroup)
    if oldGroup and oldGroup ~= newGroup then
        Core.Services.Permission.detachPlayerGroup(identifier, oldGroup)
    end

    return Core.Services.Permission.attachPlayerGroup(identifier, newGroup)
end
