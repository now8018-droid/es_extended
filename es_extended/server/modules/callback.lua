---@diagnostic disable: duplicate-set-field

-- =============================================
-- MARK: Variables
-- =============================================

Callbacks = {}

Callbacks.requests = {}
Callbacks.storage = {}
Callbacks.id = 0
Callbacks.requestsByPlayer = {}

-- =============================================
-- MARK: Internal Functions
-- =============================================

function Callbacks:Register(name, resource, cb)
    self.storage[name] = {
        resource = resource,
        cb = cb
    }
end

function Callbacks:Execute(cb, ...)
    local success, errorString = pcall(cb, ...)

    if not success then
        print(("[^1ERROR^7] Failed to execute Callback with RequestId: ^5%s^7"):format(self.currentId))
        print("^3Callback Error:^7 " .. tostring(errorString))  -- just log, don't throw
        self.currentId = nil
        return
    end

    self.currentId = nil
end

function Callbacks:Trigger(player, event, cb, invoker, ...)
    local requestId = self.id
    self.requests[self.id] = {
        id = requestId,
        player = player,
        await = type(cb) == "boolean",
        cb = cb or promise:new(),
        startedAt = GetGameTimer(),
        event = event,
    }
    self.requestsByPlayer[player] = self.requestsByPlayer[player] or {}
    self.requestsByPlayer[player][requestId] = true
    local table = self.requests[self.id]
    Core.DebugCounter("server_callback_request_count")

    TriggerClientEvent("esx:triggerClientCallback", player, event, requestId, invoker, ...)

    self.id += 1

    return table.cb
end

function Callbacks:ServerRecieve(player, event, requestId, invoker, ...)
    self.currentId = requestId

    if not self.storage[event] then
        return error(("Server Callback with requestId ^5%s^1 Was Called by ^5%s^1 but does not exist."):format(event, invoker))
    end

    local returnCb = function(...)
        TriggerClientEvent("esx:serverCallback", player, requestId, invoker, ...)
    end
    local callback = self.storage[event].cb

    self:Execute(callback, player, returnCb, ...)
end

function Callbacks:RecieveClient(requestId, invoker, ...)
    self.currentId = requestId

    if not self.requests[self.currentId] then
        return error(("Client Callback with requestId ^5%s^1 Was Called by ^5%s^1 but does not exist."):format(self.currentId, invoker))
    end

    local callback = self.requests[self.currentId]
    Core.DebugDuration(("server_callback:%s"):format(callback.event or "unknown"), callback.startedAt or GetGameTimer())

    self.requests[requestId] = nil
    local playerRequests = self.requestsByPlayer[callback.player]
    if playerRequests then
        playerRequests[requestId] = nil
        if not next(playerRequests) then
            self.requestsByPlayer[callback.player] = nil
        end
    end
    if callback.await then
        callback.cb:resolve({ ... })
    else
        self:Execute(callback.cb, ...)
    end
end

-- =============================================
-- MARK: ESX Functions
-- =============================================

---@param player number playerId
---@param eventName string
---@param callback function
---@param ... any
function ESX.TriggerClientCallback(player, eventName, callback, ...)
    local invokingResource = GetInvokingResource()
    local invoker = (invokingResource and invokingResource ~= "Unknown") and invokingResource or "es_extended"

    Callbacks:Trigger(player, eventName, callback, invoker, ...)
end

---@param player number playerId
---@param eventName string
---@param ... any
---@return ...
function ESX.AwaitClientCallback(player, eventName, ...)
    local invokingResource = GetInvokingResource()
    local invoker = (invokingResource and invokingResource ~= "Unknown") and invokingResource or "es_extended"

    local p = Callbacks:Trigger(player, eventName, false, invoker, ...)
    if not p then return end

    SetTimeout(15000, function()
        if p.state == "pending" then
            p:reject("Server Callback Timed Out")
        end
    end)

    Citizen.Await(p)

    return table.unpack(p.value)
end

---@param eventName string
---@param callback function
---@return nil
function ESX.RegisterServerCallback(eventName, callback)
    local invokingResource = GetInvokingResource()
    local invoker = (invokingResource and invokingResource ~= "Unknown") and invokingResource or "es_extended"

    Callbacks:Register(eventName, invoker, callback)
end

---@param eventName string
---@return boolean
function ESX.DoesServerCallbackExist(eventName)
    return Callbacks.storage[eventName] ~= nil
end

-- =============================================
-- MARK: Events
-- =============================================

RegisterNetEvent("esx:clientCallback", function(requestId, invoker, ...)
    Callbacks:RecieveClient(requestId, invoker, ...)
end)

RegisterNetEvent("esx:triggerServerCallback", function(eventName, requestId, invoker, ...)
    local source = source
    Callbacks:ServerRecieve(source, eventName, requestId, invoker, ...)
end)

AddEventHandler("onResourceStop", function(resource)
    for k, v in pairs(Callbacks.storage) do
        if v.resource == resource then
            Callbacks.storage[k] = nil
        end
    end
end)

AddEventHandler("playerDropped", function()
    local playerId = source
    local requestIds = Callbacks.requestsByPlayer[playerId]
    if not requestIds then
        return
    end

    for requestId in pairs(requestIds) do
        local request = Callbacks.requests[requestId]
        if request and request.await and request.cb and request.cb.state == "pending" then
            request.cb:reject("Client Callback Cancelled")
        end

        Callbacks.requests[requestId] = nil
    end

    Callbacks.requestsByPlayer[playerId] = nil
end)
