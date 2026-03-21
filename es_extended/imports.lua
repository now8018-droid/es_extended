local function GetESX()
    local waited = 0
    while GetResourceState("es_extended") ~= "started" and waited < 30000 do
        Wait(50)
        waited += 50
    end

    local ok, obj = pcall(function()
        return exports["es_extended"]:getSharedObject()
    end)

    if ok and obj then
        return obj
    end

    local legacy
    TriggerEvent("esx:getSharedObject", function(o)
        legacy = o
    end)

    waited = 0
    while not legacy and waited < 30000 do
        Wait(50)
        waited += 50
    end

    return legacy
end

ESX = GetESX()
if ESX then
    ESX.currentResourceName = GetCurrentResourceName()
end

OnPlayerData = function(key, val, last) end

local function TrackPedCoordsOnce()
    local esx = ESX
    if not esx or not esx.PlayerData then
        return
    end
    esx.PlayerData.coords = nil
    setmetatable(esx.PlayerData, {
        __index = function(self, key)
            if key ~= "coords" then return end
            local ped = esx.PlayerData.ped
            if ped and DoesEntityExist(ped) then
                return GetEntityCoords(ped)
            end
        end
    })
end

if not IsDuplicityVersion() then -- Only register this event for the client
    AddEventHandler("esx:setPlayerData", function(key, val, last)
        if GetInvokingResource() == "es_extended" then
            if not ESX or not ESX.PlayerData then return end
            ESX.PlayerData[key] = val
            if OnPlayerData then
                OnPlayerData(key, val, last)
            end
        end
    end)

    RegisterNetEvent("esx:playerLoaded", function(xPlayer)
        if not ESX then return end
        ESX.PlayerData = xPlayer
        while not ESX.PlayerData.ped or not DoesEntityExist(ESX.PlayerData.ped) do Wait(50) end
        ESX.PlayerLoaded = true

        TrackPedCoordsOnce()
    end)

    TrackPedCoordsOnce()

    ESX.SecureNetEvent("esx:onPlayerLogout", function()
        if not ESX then return end
        ESX.PlayerLoaded = false
        ESX.PlayerData = {}
    end)

    local external = { { "Class", "class.lua" } }
    for i = 1, #external do
        if not ESX then break end
        local module = external[i]
        local path = string.format("client/imports/%s", module[2])

        local file = LoadResourceFile("es_extended", path)
        if file then
            local fn, err = load(file, ('@@es_extended/%s'):format(path))

            if not fn or err then
                return error(('\n^1Error importing module (%s)'):format(external[i]))
            end

            ESX[module[1]] = fn()
        else
            return error(('\n^1Error loading module (%s)'):format(external[i]))
        end
    end
else
    ---@param src number
    ---@return StaticPlayer
    local function createStaticPlayer(src)
        return setmetatable({ src = src }, {
            __index = function(self, method)
                return function(...)
                    return exports.es_extended:RunStaticPlayerMethod(self.src, method, ...)
                end
            end
        })
    end

    ---@param src number|string
    ---@return StaticPlayer?
    function ESX.Player(src)
        if not ESX then return end
        if type(src) ~= "number" then
            src = ESX.GetPlayerIdFromIdentifier(src)
            if not src then return end
        elseif not ESX.IsPlayerLoaded(src) then
            return
        end

        return createStaticPlayer(src)
    end

    ---@param key? string
    ---@param val? string|string[]
    ---@return StaticPlayer[] | table<any, StaticPlayer[]>
    function ESX.ExtendedPlayers(key, val)
        local playerIds = ESX.GetExtendedPlayers(key, val, true)

        if key and type(val) == "table" then
            ---@cast playerIds table<any, number[]>
            local retVal = {}
            for group, ids in pairs(playerIds) do
                retVal[group] = {}
                for i = 1, #ids do
                    retVal[group][i] = createStaticPlayer(ids[i])
                end
            end
            return retVal
        else
            ---@cast playerIds number[]
            local retVal = {}
            for i = 1, #playerIds do
                retVal[i] = createStaticPlayer(playerIds[i])
            end
            return retVal
        end
    end
end

-- Package/Require fallback removed - ox_lib required
