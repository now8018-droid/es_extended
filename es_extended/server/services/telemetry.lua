Core.Services = Core.Services or {}
Core.Services.Telemetry = Core.Services.Telemetry or {}

function Core.Services.Telemetry.flushAsyncLogQueue()
    local queue = Core.AsyncLogQueue
    queue.scheduled = false

    local batch = {}
    local batchSize = Core.Config.Telemetry.logBatchSize()
    local count = 0

    while queue.head <= queue.tail and count < batchSize do
        local index = queue.head
        local entry = queue.items[index]
        queue.items[index] = nil
        queue.head = index + 1

        if entry then
            count += 1
            batch[count] = entry
        end
    end

    if queue.head > queue.tail then
        queue.head = 1
        queue.tail = 0
    end

    if count > 0 then
        if queue.dropped > 0 then
            count += 1
            batch[count] = {
                kind = "inventory_log_backpressure",
                payload = {
                    dropped = queue.dropped,
                },
                createdAt = os.time(),
                tick = GetGameTimer(),
            }
            queue.dropped = 0
        end

        TriggerEvent("esx:asyncInventoryLogBatch", batch)
        Core.DebugCounter("inventory_async_logs", count)
    end

    if queue.head <= queue.tail then
        queue.scheduled = true
        SetTimeout(Core.Config.Telemetry.logFlushInterval(), Core.Services.Telemetry.flushAsyncLogQueue)
    end
end

function Core.Services.Telemetry.scheduleAsyncLogFlush()
    if Core.AsyncLogQueue.scheduled then
        return
    end

    Core.AsyncLogQueue.scheduled = true
    SetTimeout(Core.Config.Telemetry.logFlushInterval(), Core.Services.Telemetry.flushAsyncLogQueue)
end

function Core.Services.Telemetry.queueAsyncLog(kind, payload)
    local mode = Core.Config.Telemetry.logMode()
    if mode == "off" then
        return
    end

    if mode ~= "all" and kind == "inventory_mutation" then
        return
    end

    local queue = Core.AsyncLogQueue
    local queueSize = (queue.tail - queue.head) + 1
    if queueSize >= Core.Config.Telemetry.logQueueMaxSize() then
        queue.dropped += 1
        queue.lastDropNoticeAt = GetGameTimer()
        return
    end

    queue.tail += 1
    queue.items[queue.tail] = {
        kind = kind,
        payload = payload,
        createdAt = os.time(),
        tick = GetGameTimer(),
    }

    Core.Services.Telemetry.scheduleAsyncLogFlush()
end

function Core.Services.Telemetry.flagSuspiciousPlayer(source, reason, context)
    if not source then
        return
    end

    local entry = Core.SuspiciousPlayers[source] or { score = 0, lastReason = nil, lastContext = nil, updatedAt = 0 }
    entry.score += 1
    entry.lastReason = reason
    entry.lastContext = context
    entry.updatedAt = GetGameTimer()
    Core.SuspiciousPlayers[source] = entry

    Core.Services.Telemetry.queueAsyncLog("inventory_suspicious", {
        source = source,
        reason = reason,
        context = context,
        score = entry.score,
    })

    TriggerEvent("esx:inventorySuspiciousActivity", source, reason, context, entry.score)
end

function Core.Services.Telemetry.clearSuspiciousPlayer(source)
    if source then
        Core.SuspiciousPlayers[source] = nil
    end
end

Core.QueueAsyncLog = Core.Services.Telemetry.queueAsyncLog
Core.FlagSuspiciousPlayer = Core.Services.Telemetry.flagSuspiciousPlayer
Core.ClearSuspiciousPlayer = Core.Services.Telemetry.clearSuspiciousPlayer
