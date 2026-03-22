Core.Services = Core.Services or {}
Core.Services.Inventory = Core.Services.Inventory or {}

local mathAbs = math.abs
local mathHuge = math.huge
local InventoryService = Core.Services.Inventory

local function isFiniteNumber(value)
    return type(value) == "number" and value == value and value ~= mathHuge and value ~= -mathHuge
end

local function sanitizeInventoryItemName(itemName)
    if type(itemName) ~= "string" then
        return nil
    end

    local trimmed = itemName:match("^%s*(.-)%s*$")
    if trimmed == "" or #trimmed > 64 then
        return nil
    end

    return trimmed
end

local function emitInventoryMutationEvents(action, source, itemName, itemCount)
    if action == "remove" then
        TriggerEvent("esx:onRemoveInventoryItem", source, itemName, itemCount)
        return
    end

    TriggerEvent("esx:onAddInventoryItem", source, itemName, itemCount)
end

local function resolveInventoryLimit(item)
    if not item then
        return Config.DefaultItemLimit
    end

    if item.limit ~= nil then
        return item.limit
    end

    local itemData = ESX.Items[item.name]
    if not itemData then
        return Config.DefaultItemLimit
    end

    return itemData.limit or Config.DefaultItemLimit
end

local function buildInventoryRollbackSnapshot(item, previousCount, previousWeight)
    return {
        item = item,
        previousCount = previousCount,
        previousWeight = previousWeight,
    }
end

local function rollbackInventoryMutation(self, snapshot)
    if not snapshot or not snapshot.item then
        return
    end

    self.state.inventory[snapshot.item.name] = snapshot.previousCount
    snapshot.item.count = snapshot.previousCount
    self.weight = snapshot.previousWeight

    if not self.updateMinimalInventoryCache(snapshot.item.name, snapshot.previousCount) then
        self.markInventoryDirty()
    end
end

local function queueInventoryLog(self, kind, payload)
    Core.QueueAsyncLog(kind, payload)
end

local function ensureInventoryRuntime(self)
    if not self.inventoryQueue then
        self.inventoryQueue = {
            head = 1,
            tail = 0,
            items = {},
            processing = false,
        }
    end

    if not self.inventoryRateLimit then
        self.inventoryRateLimit = {
            windowStartedAt = 0,
            actions = 0,
            blockedUntil = 0,
            strikes = 0,
        }
    end

    return self.inventoryQueue, self.inventoryRateLimit
end

local function bindInventoryMethod(player, method)
    return function(arg1, arg2, arg3)
        if arg1 == player then
            return method(player, arg2, arg3)
        end

        return method(player, arg1, arg2)
    end
end

local function bindInventoryMutationExecutor(player, method)
    return function(arg1, arg2, arg3, arg4)
        if arg1 == player then
            return method(player, arg2, arg3, arg4)
        end

        return method(player, arg1, arg2, arg3)
    end
end

local function flagInventorySuspicion(self, reason, context)
    Core.FlagSuspiciousPlayer(self.source, reason, context)

    local threshold = math.max(1, Config.InventorySuspicionThreshold or 3)
    local suspicious = Core.SuspiciousPlayers[self.source]
    if suspicious and suspicious.score >= threshold then
        TriggerEvent("esx:inventorySuspicionThreshold", self.source, reason, context, suspicious.score)
    end
end

local function consumeInventoryRateLimit(self, actionName, itemName, count)
    local _, limiter = ensureInventoryRuntime(self)
    local now = GetGameTimer()
    local windowMs = Core.Config.Inventory.rateWindowMs()

    if limiter.blockedUntil > now then
        flagInventorySuspicion(self, "inventory_rate_blocked", {
            action = actionName,
            itemName = itemName,
            count = count,
            blockedUntil = limiter.blockedUntil,
        })
        queueInventoryLog(self, "inventory_rate_blocked", {
            source = self.source,
            action = actionName,
            itemName = itemName,
            count = count,
            blockedUntil = limiter.blockedUntil,
        })
        return false
    end

    if limiter.windowStartedAt == 0 or (now - limiter.windowStartedAt) >= windowMs then
        limiter.windowStartedAt = now
        limiter.actions = 0
    end

    limiter.actions += 1
    if limiter.actions <= Core.Config.Inventory.actionRateLimit() then
        return true
    end

    limiter.strikes += 1
    limiter.blockedUntil = now + math.max(windowMs, Core.Config.Inventory.rateBlockMs())
    flagInventorySuspicion(self, "inventory_rate_limit", {
        action = actionName,
        itemName = itemName,
        count = count,
        actions = limiter.actions,
        strikes = limiter.strikes,
    })
    queueInventoryLog(self, "inventory_rate_limit", {
        source = self.source,
        action = actionName,
        itemName = itemName,
        count = count,
        actions = limiter.actions,
        strikes = limiter.strikes,
        blockedUntil = limiter.blockedUntil,
    })
    return false
end

local function validateInventoryMutation(self, actionName, itemName, count)
    local sanitizedItemName = sanitizeInventoryItemName(itemName)
    if not sanitizedItemName then
        flagInventorySuspicion(self, "inventory_invalid_item", { action = actionName, itemName = itemName, count = count })
        return nil, nil, "invalid_item"
    end

    local itemDefinition = ESX.Items[sanitizedItemName]
    if not itemDefinition then
        flagInventorySuspicion(self, "inventory_unknown_item", { action = actionName, itemName = sanitizedItemName, count = count })
        return nil, nil, "unknown_item"
    end

    if not isFiniteNumber(count) then
        flagInventorySuspicion(self, "inventory_invalid_count", { action = actionName, itemName = sanitizedItemName, count = count })
        return nil, nil, "invalid_count"
    end

    local normalizedCount = ESX.Math.Round(count)
    if actionName == "set" then
        if normalizedCount < 0 then
            flagInventorySuspicion(self, "inventory_negative_set", { action = actionName, itemName = sanitizedItemName, count = normalizedCount })
            return nil, nil, "negative_count"
        end

        if normalizedCount > Core.Config.Inventory.maxSetCount() then
            flagInventorySuspicion(self, "inventory_set_cap_exceeded", { action = actionName, itemName = sanitizedItemName, count = normalizedCount })
            return nil, nil, "count_cap"
        end
    else
        if normalizedCount <= 0 then
            flagInventorySuspicion(self, "inventory_non_positive_delta", { action = actionName, itemName = sanitizedItemName, count = normalizedCount })
            return nil, nil, "invalid_delta"
        end

        if normalizedCount > Core.Config.Inventory.maxActionCount() then
            flagInventorySuspicion(self, "inventory_delta_cap_exceeded", { action = actionName, itemName = sanitizedItemName, count = normalizedCount })
            return nil, nil, "count_cap"
        end
    end

    return self.getInventoryItem(sanitizedItemName), normalizedCount, nil
end

local function finalizeInventoryQueue(queue)
    queue.processing = false
    if queue.head > queue.tail then
        queue.head = 1
        queue.tail = 0
    end
end

local function processInventoryQueue(self)
    local queue = self.inventoryQueue
    local processed = 0
    local maxBatchSize = Core.Config.Inventory.queueProcessBatchSize()

    while queue.head <= queue.tail and processed < maxBatchSize do
        local index = queue.head
        local entry = queue.items[index]
        queue.items[index] = nil
        queue.head = index + 1
        processed += 1

        if entry then
            local ok, result = pcall(entry.handler)
            if ok then
                entry.promise:resolve(result)
            else
                flagInventorySuspicion(self, "inventory_queue_failure", {
                    action = entry.actionName,
                    itemName = entry.itemName,
                    count = entry.count,
                    error = result,
                })
                queueInventoryLog(self, "inventory_queue_failure", {
                    source = self.source,
                    action = entry.actionName,
                    itemName = entry.itemName,
                    count = entry.count,
                    error = result,
                })
                entry.promise:resolve(false)
            end
        end
    end

    if queue.head <= queue.tail then
        SetTimeout(0, function()
            processInventoryQueue(self)
        end)
        return
    end

    finalizeInventoryQueue(queue)
end

local function ensureInventoryQueueWorker(self)
    local queue = ensureInventoryRuntime(self)
    if queue.processing then
        return
    end

    queue.processing = true
    SetTimeout(0, function()
        processInventoryQueue(self)
    end)
end

local function enqueueInventoryMutation(self, actionName, itemName, count, handler)
    if not consumeInventoryRateLimit(self, actionName, itemName, count) then
        return false
    end

    local queue = ensureInventoryRuntime(self)
    local queueSize = (queue.tail - queue.head) + 1
    if queueSize >= Core.Config.Inventory.queueMaxSize() then
        flagInventorySuspicion(self, "inventory_queue_overflow", {
            action = actionName,
            itemName = itemName,
            count = count,
            queueSize = queueSize,
        })
        queueInventoryLog(self, "inventory_queue_overflow", {
            source = self.source,
            action = actionName,
            itemName = itemName,
            count = count,
            queueSize = queueSize,
        })
        return false
    end

    local pending = promise.new()
    queue.tail += 1
    queue.items[queue.tail] = {
        actionName = actionName,
        itemName = itemName,
        count = count,
        handler = handler,
        promise = pending,
    }

    ensureInventoryQueueWorker(self)
    return Citizen.Await(pending)
end

local function commitInventoryMutation(self, actionName, item, previousCount, nextCount, delta, startedAt)
    if previousCount == nextCount then
        Core.DebugDuration(("xPlayer.%sInventoryItem"):format(actionName), startedAt)
        return true
    end

    local previousWeight = self.weight
    local nextWeight = previousWeight + (item.weight * delta)
    if nextWeight < 0 then
        flagInventorySuspicion(self, "inventory_negative_weight", {
            action = actionName,
            itemName = item.name,
            delta = delta,
            previousWeight = previousWeight,
            attemptedWeight = nextWeight,
        })
        return false
    end

    if self.maxWeight and self.maxWeight >= 0 and nextWeight > self.maxWeight then
        flagInventorySuspicion(self, "inventory_weight_overflow", {
            action = actionName,
            itemName = item.name,
            delta = delta,
            attemptedWeight = nextWeight,
            maxWeight = self.maxWeight,
        })
        return false
    end

    local limit = resolveInventoryLimit(item)
    if limit ~= -1 and nextCount > limit then
        flagInventorySuspicion(self, "inventory_limit_overflow", {
            action = actionName,
            itemName = item.name,
            nextCount = nextCount,
            limit = limit,
        })
        return false
    end

    local rollbackSnapshot = buildInventoryRollbackSnapshot(item, previousCount, previousWeight)
    local mutationApplied = false
    local ok, result = pcall(function()
        self.state.inventory[item.name] = nextCount
        item.count = nextCount
        self.weight = nextWeight
        mutationApplied = true

        if not self.updateMinimalInventoryCache(item.name, nextCount) then
            self.markInventoryDirty()
        end

        Core.MarkPlayerDirty(self, "inventory")
        Core.QueueInventorySync(self, item.name, item.count, delta, item.label)
        Core.DebugCounter("inventory_mutations")

        queueInventoryLog(self, "inventory_mutation", {
            source = self.source,
            action = actionName,
            itemName = item.name,
            previousCount = previousCount,
            nextCount = nextCount,
            delta = delta,
            weight = self.weight,
            maxWeight = self.maxWeight,
        })

        if item.rare and mathAbs(delta) >= (Config.CriticalRareItemDelta or 1) then
            Core.RequestImmediateSave(self, ("critical_rare_%s"):format(actionName))
        end

        emitInventoryMutationEvents(actionName, self.source, item.name, item.count)
        Core.DebugDuration(("xPlayer.%sInventoryItem"):format(actionName), startedAt)
        return true
    end)

    if ok then
        return result
    end

    if mutationApplied then
        rollbackInventoryMutation(self, rollbackSnapshot)
    end

    flagInventorySuspicion(self, "inventory_commit_failure", {
        action = actionName,
        itemName = item.name,
        previousCount = previousCount,
        nextCount = nextCount,
        error = result,
    })
    queueInventoryLog(self, "inventory_commit_failure", {
        source = self.source,
        action = actionName,
        itemName = item.name,
        previousCount = previousCount,
        nextCount = nextCount,
        error = result,
    })

    return false
end

function InventoryService.executeInventoryMutation(self, actionName, itemName, count)
    return enqueueInventoryMutation(self, actionName, itemName, count, function()
        local startedAt = GetGameTimer()
        local item, normalizedCount = validateInventoryMutation(self, actionName, itemName, count)
        if not item then
            Core.DebugDuration(("xPlayer.%sInventoryItem"):format(actionName), startedAt)
            return false
        end

        local previousCount = self.state.inventory[item.name] or item.count or 0
        local nextCount = previousCount

        if actionName == "add" then
            nextCount = previousCount + normalizedCount
        elseif actionName == "remove" then
            if previousCount < normalizedCount then
                flagInventorySuspicion(self, "inventory_underflow_attempt", {
                    action = actionName,
                    itemName = item.name,
                    previousCount = previousCount,
                    attempted = normalizedCount,
                })
                Core.DebugDuration("xPlayer.removeInventoryItem", startedAt)
                return false
            end

            nextCount = previousCount - normalizedCount
        else
            local delta = normalizedCount - previousCount
            if mathAbs(delta) > Core.Config.Inventory.maxActionCount() then
                flagInventorySuspicion(self, "inventory_set_delta_cap_exceeded", {
                    action = actionName,
                    itemName = item.name,
                    previousCount = previousCount,
                    nextCount = normalizedCount,
                    delta = delta,
                })
                Core.DebugDuration("xPlayer.setInventoryItem", startedAt)
                return false
            end

            nextCount = normalizedCount
        end

        return commitInventoryMutation(self, actionName, item, previousCount, nextCount, nextCount - previousCount, startedAt)
    end)
end

function InventoryService.addInventoryItem(self, itemName, count)
    return InventoryService.executeInventoryMutation(self, "add", itemName, count)
end

function InventoryService.removeInventoryItem(self, itemName, count)
    return InventoryService.executeInventoryMutation(self, "remove", itemName, count)
end

function InventoryService.setInventoryItem(self, itemName, count)
    return InventoryService.executeInventoryMutation(self, "set", itemName, count)
end

function InventoryService.attach(self)
    ensureInventoryRuntime(self)

    self.executeInventoryMutation = bindInventoryMutationExecutor(self, InventoryService.executeInventoryMutation)
    self.addInventoryItem = bindInventoryMethod(self, InventoryService.addInventoryItem)
    self.removeInventoryItem = bindInventoryMethod(self, InventoryService.removeInventoryItem)
    self.setInventoryItem = bindInventoryMethod(self, InventoryService.setInventoryItem)
end
