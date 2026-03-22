ESX.OneSync = {}

local mismatchedVehicleTypes = {
    [`airtug`] = "automobile",
    [`avisa`] = "submarine",
    [`blimp`] = "heli",
    [`blimp2`] = "heli",
    [`blimp3`] = "heli",
    [`caddy`] = "automobile",
    [`caddy2`] = "automobile",
    [`caddy3`] = "automobile",
    [`chimera`] = "automobile",
    [`docktug`] = "automobile",
    [`forklift`] = "automobile",
    [`kosatka`] = "submarine",
    [`mower`] = "automobile",
    [`policeb`] = "bike",
    [`ripley`] = "automobile",
    [`rrocket`] = "automobile",
    [`sadler`] = "automobile",
    [`sadler2`] = "automobile",
    [`scrap`] = "automobile",
    [`slamtruck`] = "automobile",
    [`Stryder`] = "automobile",
    [`submersible`] = "submarine",
    [`submersible2`] = "submarine",
    [`thruster`] = "heli",
    [`towtruck`] = "automobile",
    [`towtruck2`] = "automobile",
    [`tractor`] = "automobile",
    [`tractor2`] = "automobile",
    [`tractor3`] = "automobile",
    [`trailersmall2`] = "trailer",
    [`utillitruck`] = "automobile",
    [`utillitruck2`] = "automobile",
    [`utillitruck3`] = "automobile",
}

local vehicleClassTypes = {
    [8] = "bike",
    [11] = "trailer",
    [13] = "bike",
    [14] = "boat",
    [15] = "heli",
    [16] = "plane",
    [21] = "train",
}

local function getVehicleTypeFromModel(model)
    model = type(model) == "string" and joaat(model) or model
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        return nil
    end

    if mismatchedVehicleTypes[model] then
        return mismatchedVehicleTypes[model]
    end

    local vehicleClass = GetVehicleClassFromName(model)
    return vehicleClassTypes[vehicleClass] or "automobile"
end

---@param source number|vector3
---@param closest boolean
---@param distance? number
---@param ignore? table
---@param routingBucket? number
local function getNearbyPlayers(source, closest, distance, ignore, routingBucket)
    local result = {}
    local count = 0
    local playerCoords
    ignore = ignore or {}

    if not distance then
        distance = 100
    end

    if type(source) == "number" then
        if not source then
            error("Received invalid first argument (source); should be playerId")
        end

        local cachedPlayer = Core.PlayerCoords[source]
        playerCoords = cachedPlayer and cachedPlayer.coords or GetEntityCoords(GetPlayerPed(source))

        if not playerCoords then
            error("Received nil value (playerCoords); perhaps source is nil at first place?")
        end

        routingBucket = routingBucket or (cachedPlayer and cachedPlayer.routingBucket) or GetPlayerRoutingBucket(source)
    end

    if type(source) == "vector3" then
        playerCoords = source

        if not playerCoords then
            error("Received nil value (playerCoords); perhaps source is nil at first place?")
        end
    end

    if not next(Core.PlayerScopeBuckets) then
        for _, xPlayer in pairs(ESX.Players) do
            if not ignore[xPlayer.source] and (not routingBucket or GetPlayerRoutingBucket(xPlayer.source) == routingBucket) then
                local entity = GetPlayerPed(xPlayer.source)
                local coords = GetEntityCoords(entity)

                if not closest then
                    local dist = #(playerCoords - coords)
                    if dist <= distance then
                        count = count + 1
                        result[count] = { id = xPlayer.source, ped = NetworkGetNetworkIdFromEntity(entity), coords = coords, dist = dist }
                    end
                elseif xPlayer.source ~= source then
                    local dist = #(playerCoords - coords)
                    if dist <= (result.dist or distance) then
                        result = { id = xPlayer.source, ped = NetworkGetNetworkIdFromEntity(entity), coords = coords, dist = dist }
                    end
                end
            end
        end

        return result
    end

    local bucketSpan = math.max(1, math.ceil(distance / Config.PlayerScopeBucketSize))
    local centerX = math.floor(playerCoords.x / Config.PlayerScopeBucketSize)
    local centerY = math.floor(playerCoords.y / Config.PlayerScopeBucketSize)
    local routingBuckets = routingBucket ~= nil and { [routingBucket] = true } or Core.PlayerScopeBuckets

    for bucketId in pairs(routingBuckets) do
        local scopedBuckets = Core.PlayerScopeBuckets[bucketId]
        if scopedBuckets then
            for offsetX = -bucketSpan, bucketSpan do
                for offsetY = -bucketSpan, bucketSpan do
                    local scopedPlayers = scopedBuckets[("%s:%s"):format(centerX + offsetX, centerY + offsetY)]
                    if scopedPlayers then
                        for i = 1, #scopedPlayers do
                            local playerId = scopedPlayers[i]
                            if not ignore[playerId] then
                                local xPlayer = ESX.Players[playerId]
                                local cachedPlayer = Core.PlayerCoords[playerId]

                                if xPlayer and cachedPlayer then
                                    local coords = cachedPlayer.coords
                                    if not closest then
                                        local dist = #(playerCoords - coords)
                                        if dist <= distance then
                                            count = count + 1
                                            result[count] = { id = playerId, ped = NetworkGetNetworkIdFromEntity(cachedPlayer.ped), coords = coords, dist = dist }
                                        end
                                    elseif playerId ~= source then
                                        local dist = #(playerCoords - coords)
                                        if dist <= (result.dist or distance) then
                                            result = { id = playerId, ped = NetworkGetNetworkIdFromEntity(cachedPlayer.ped), coords = coords, dist = dist }
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return result
end

---@param source vector3|number playerId or vector3 coordinates
---@param maxDistance number
---@param ignore? table playerIds to ignore, where the key is playerId and value is true
---@param routingBucket? number
function ESX.OneSync.GetPlayersInArea(source, maxDistance, ignore, routingBucket)
    return getNearbyPlayers(source, false, maxDistance, ignore, routingBucket)
end

---@param source vector3|number playerId or vector3 coordinates
---@param maxDistance number
---@param ignore? table playerIds to ignore, where the key is playerId and value is true
---@param routingBucket? number
function ESX.OneSync.GetClosestPlayer(source, maxDistance, ignore, routingBucket)
    return getNearbyPlayers(source, true, maxDistance, ignore, routingBucket)
end

---@param vehicleModel number|string
---@param coords vector3|table
---@param heading number
---@param vehicleProperties table
---@param cb? fun(netId: number)
---@param vehicleType string?
---@return number? netId
function ESX.OneSync.SpawnVehicle(vehicleModel, coords, heading, vehicleProperties, cb, vehicleType)
    if cb and not ESX.IsFunctionReference(cb) then
        error("Invalid callback function")
    end

    vehicleModel = joaat(vehicleModel)

    local promise = not cb and promise.new()

    local function resolve(result)
        if promise then
            promise:resolve(result)
        elseif cb then
            cb(result)
        end

        return result
    end

    local function reject(err)
        if promise then
            promise:reject(err)
        end
        error(err)
    end

    CreateThread(function()
        if not vehicleType then
            local xPlayer = ESX.GetExtendedPlayers()[1]
            if xPlayer then
                vehicleType = ESX.GetVehicleType(vehicleModel, xPlayer.source)
            end

            if not vehicleType then
                vehicleType = getVehicleTypeFromModel(vehicleModel)
            end
        end

        if not vehicleType then
            return reject("Unable to resolve vehicle type for this model. Specify the vehicle type manually if needed.")
        end

        local createdVehicle = CreateVehicleServerSetter(vehicleModel, vehicleType, coords.x, coords.y, coords.z, heading)
        local tries = 0

        local hasNetOwner = next(ESX.OneSync.GetClosestPlayer(coords, 300, nil, 0) or {}) ~= nil

        while not createdVehicle or createdVehicle == 0
            or (hasNetOwner and NetworkGetEntityOwner(createdVehicle) == -1)
            or (not hasNetOwner and not DoesEntityExist(createdVehicle)) do
            Wait(200)
            tries = tries + 1
            if tries > 40 then
                return reject(("Could not spawn vehicle - ^5%s^7!"):format(vehicleModel))
            end
        end

        -- luacheck: ignore
        SetEntityOrphanMode(createdVehicle, 2)
        local networkId = NetworkGetNetworkIdFromEntity(createdVehicle)
        Entity(createdVehicle).state:set("VehicleProperties", vehicleProperties, true)

        resolve(networkId)
    end)

    if promise then
        return Citizen.Await(promise)
    end
end

---@param model number|string
---@param coords vector3|table
---@param heading number
---@param cb? fun(netId: number)
---@return number? netId
function ESX.OneSync.SpawnObject(model, coords, heading, cb)
    if type(model) == "string" then
        model = joaat(model)
    end

    local promise = not cb and promise.new()
    local objectCoords = type(coords) == "vector3" and coords or vector3(coords.x, coords.y, coords.z)

    local function resolve(result)
        if promise then
            promise:resolve(result)
        elseif cb then
            cb(result)
        end
    end

    local function reject(err)
        if promise then
            promise:reject(err)
        end
        error(err)
    end

    CreateThread(function()
        local entity = CreateObject(model, objectCoords.x, objectCoords.y, objectCoords.z, true, true, false)
        local tries = 0

        while not DoesEntityExist(entity) do
            Wait(200)
            
            tries = tries + 1

            if tries > 40 then
                return reject(("Could not spawn object - ^5%s^7!"):format(entity))
            end
        end

        local networkId = NetworkGetNetworkIdFromEntity(entity)

        SetEntityHeading(entity, heading)
        resolve(networkId)
    end)

    if promise then
        return Citizen.Await(promise)
    end
end

---@param model number|string
---@param coords vector3|table
---@param heading number
---@param cb? fun(netId: number)
---@return number? netId
function ESX.OneSync.SpawnPed(model, coords, heading, cb)
    if cb then
        cb(nil)
    end
    return nil
end

---@param model number|string
---@param vehicle number entityId
---@param seat number
---@param cb? fun(netId: number)
---@return number? netId
function ESX.OneSync.SpawnPedInVehicle(model, vehicle, seat, cb)
    if cb then
        cb(nil)
    end
    return nil
end

local function getNearbyEntities(entities, coords, modelFilter, maxDistance, isPed)
    local nearbyEntities = {}
    coords = type(coords) == "number" and GetEntityCoords(GetPlayerPed(coords)) or vector3(coords.x, coords.y, coords.z)
    for _, entity in pairs(entities) do
        if not isPed or (isPed and not IsPedAPlayer(entity)) then
            if not modelFilter or modelFilter[GetEntityModel(entity)] then
                local entityCoords = GetEntityCoords(entity)
                if not maxDistance or #(coords - entityCoords) <= maxDistance then
                    nearbyEntities[#nearbyEntities + 1] = NetworkGetNetworkIdFromEntity(entity)
                end
            end
        end
    end

    return nearbyEntities
end

---@param coords vector3
---@param maxDistance number
---@param modelFilter table models to ignore, where the key is the model hash and the value is true
---@return table
function ESX.OneSync.GetPedsInArea(coords, maxDistance, modelFilter)
    return {}
end

---@param coords vector3
---@param maxDistance number
---@param modelFilter table models to ignore, where the key is the model hash and the value is true
---@return table
function ESX.OneSync.GetObjectsInArea(coords, maxDistance, modelFilter)
    return getNearbyEntities(GetAllObjects(), coords, modelFilter, maxDistance)
end

---@param coords vector3
---@param maxDistance number
---@param modelFilter table | nil models to ignore, where the key is the model hash and the value is true
---@return table
function ESX.OneSync.GetVehiclesInArea(coords, maxDistance, modelFilter)
    return getNearbyEntities(GetAllVehicles(), coords, modelFilter, maxDistance)
end

local function getClosestEntity(entities, coords, modelFilter, isPed)
    local distance, closestEntity, closestCoords = 100, 0, vector3(0, 0, 0)
    coords = type(coords) == "number" and GetEntityCoords(GetPlayerPed(coords)) or vector3(coords.x, coords.y, coords.z)

    for _, entity in pairs(entities) do
        if not isPed or (isPed and not IsPedAPlayer(entity)) then
            if not modelFilter or modelFilter[GetEntityModel(entity)] then
                local entityCoords = GetEntityCoords(entity)
                local dist = #(coords - entityCoords)
                if dist < distance then
                    closestEntity, distance, closestCoords = entity, dist, entityCoords
                end
            end
        end
    end

    return NetworkGetNetworkIdFromEntity(closestEntity), distance, closestCoords
end

---@param coords vector3
---@param modelFilter table models to ignore, where the key is the model hash and the value is true
---@return number entityId, number distance, vector3 coords
function ESX.OneSync.GetClosestPed(coords, modelFilter)
    return 0, 100.0, vector3(0, 0, 0)
end

---@param coords vector3
---@param modelFilter table models to ignore, where the key is the model hash and the value is true
---@return number entityId, number distance, vector3 coords
function ESX.OneSync.GetClosestObject(coords, modelFilter)
    return getClosestEntity(GetAllObjects(), coords, modelFilter)
end

---@param coords vector3
---@param modelFilter table models to ignore, where the key is the model hash and the value is true
---@return number entityId, number distance, vector3 coords
function ESX.OneSync.GetClosestVehicle(coords, modelFilter)
    return getClosestEntity(GetAllVehicles(), coords, modelFilter)
end
