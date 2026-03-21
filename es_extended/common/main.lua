ESX = {}

exports("getSharedObject", function()
    return ESX
end)

AddEventHandler("esx:getSharedObject", function(cb)
    if ESX.IsFunctionReference(cb) then
        cb(ESX)
    end
end)

if IsDuplicityVersion() then
    exports("RunStaticPlayerMethod", function(src, method, ...)
        if type(src) ~= "number" or type(method) ~= "string" then
            return
        end

        local players = ESX.Players
        local xPlayer = players and players[src]
        if not xPlayer then
            return
        end

        local fn = xPlayer[method]
        if type(fn) ~= "function" then
            return
        end

        return fn(xPlayer, ...)
    end)
end
