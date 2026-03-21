Core.Services = Core.Services or {}
Core.Services.Config = Core.Services.Config or {}
Core.Config = Core.Config or {}

local ConfigService = Core.Services.Config

local function clamp(value, minValue, maxValue)
    if minValue ~= nil and value < minValue then
        value = minValue
    end

    if maxValue ~= nil and value > maxValue then
        value = maxValue
    end

    return value
end

Core.Config.Save = {
    interval = function()
        return clamp(Config.SaveInterval or 15000, 1000)
    end,
    batchSize = function()
        return clamp(Config.SaveBatchSize or 1, 1, 2)
    end,
    batchDelay = function()
        return clamp(Config.SaveBatchDelay or 8, 5, 10)
    end,
}

Core.Config.Sync = {
    inventoryInterval = function()
        return clamp(Config.InventorySyncInterval or 750, 50)
    end,
    inventoryRateLimit = function()
        return clamp(Config.InventorySyncRateLimit or 500, 50)
    end,
    batchSize = function()
        return clamp(Config.SyncBatchSize or 8, 1)
    end,
    batchDelay = function()
        return clamp(Config.SyncBatchDelay or 10, 0)
    end,
}

Core.Config.Inventory = {
    actionRateLimit = function()
        return clamp(Config.InventoryActionRateLimit or 20, 1)
    end,
    rateWindowMs = function()
        return clamp(Config.InventoryRateWindowMs or 1000, 250)
    end,
    rateBlockMs = function()
        return clamp(Config.InventoryRateBlockMs or 3000, 250)
    end,
    maxActionCount = function()
        return clamp(Config.InventoryMaxActionCount or 100, 1)
    end,
    maxSetCount = function()
        return clamp(Config.InventoryMaxSetCount or 10000, 1)
    end,
    queueMaxSize = function()
        return clamp(Config.InventoryQueueMaxSize or 128, 8)
    end,
    queueProcessBatchSize = function()
        return clamp(Config.InventoryQueueProcessBatchSize or 16, 1, 64)
    end,
}

Core.Config.Telemetry = {
    logFlushInterval = function()
        return clamp(Config.InventoryLogFlushInterval or 500, 50)
    end,
    logBatchSize = function()
        return clamp(Config.InventoryLogBatchSize or 128, 1)
    end,
    logQueueMaxSize = function()
        return clamp(Config.InventoryLogQueueMaxSize or 512, 32)
    end,
    logMode = function()
        local mode = Config.InventoryLogMode or "suspicious"
        if mode ~= "off" and mode ~= "suspicious" and mode ~= "all" then
            return "suspicious"
        end

        return mode
    end,
}

Core.Config.Scope = {
    batchSize = function()
        return clamp(Config.ScopeBatchSize or 64, 1)
    end,
    dirtyFlushInterval = function()
        return clamp(Config.ScopeDirtyFlushInterval or 250, 50)
    end,
    dirtyBatchSize = function()
        return clamp(Config.ScopeDirtyBatchSize or 128, 1)
    end,
    playerRefreshInterval = function()
        return clamp(Config.PlayerScopeRefreshInterval or 2000, 250)
    end,
    fullRefreshInterval = function()
        return clamp(Config.PlayerScopeFullRefreshInterval or 15000, 1000)
    end,
}

ConfigService.Save = Core.Config.Save
ConfigService.Sync = Core.Config.Sync
ConfigService.Inventory = Core.Config.Inventory
ConfigService.Telemetry = Core.Config.Telemetry
ConfigService.Scope = Core.Config.Scope
