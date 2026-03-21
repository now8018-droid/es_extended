Core.Services = Core.Services or {}
Core.Services.Ace = Core.Services.Ace or {}

local function sanitizeAceSegment(value)
    if type(value) ~= "string" then
        return nil
    end

    local trimmed = value:match("^%s*(.-)%s*$")
    if trimmed == "" or #trimmed > 64 then
        return nil
    end

    if trimmed:find("[^%w_%-%.]") then
        return nil
    end

    return trimmed
end

function Core.Services.Ace.allowCommand(group, commandName)
    local sanitizedGroup = sanitizeAceSegment(group)
    local sanitizedCommand = sanitizeAceSegment(commandName)
    if not sanitizedGroup or not sanitizedCommand then
        return false
    end

    ExecuteCommand(("add_ace group.%s command.%s allow"):format(sanitizedGroup, sanitizedCommand))
    return true
end
