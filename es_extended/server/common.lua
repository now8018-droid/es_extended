ESX.Players = {}
ESX.Jobs = {}
ESX.Items = {}
Core = {}
Core.JobsPlayerCount = {}
Core.UsableItemsCallbacks = {}
Core.RegisteredCommands = {}
Core.Pickups = {}
Core.PickupId = 0
Core.PlayerFunctionOverrides = {}
Core.DatabaseConnected = false
Core.playersByIdentifier = {}
Core.PlayersByJob = {}
Core.JobsLoaded = false
Core.PlayerCache = {}
Core.SaveQueue = {}
Core.WriteQueue = { players = Core.SaveQueue, interval = Config.SaveInterval, scheduled = false }
Core.ActivePlayerSync = {}
Core.LoginQueue = { head = 1, tail = 0, items = {} }
Core.LoginQueueScheduled = false
Core.PlayerSyncScheduled = false
Core.EventThrottle = {}
Core.PlayerCoords = {}
Core.PlayerScopeBuckets = {}
Core.DetectedWeapons = {}
Core.WeaponScanCache = {}
Core.Performance = {
    counters = {},
    slowPaths = {},
}
Core.LastDisconnectAt = {}

---@type table<string, CVehicleData>
Core.vehicles = {}
Core.vehicleTypesByModel = {}

RegisterNetEvent("esx:onPlayerSpawn", function()
    ESX.Players[source].spawned = true
end)

if Config.CustomInventory then
    SetConvarReplicated("inventory:framework", "esx")
    SetConvarReplicated("inventory:weight", tostring(Config.MaxWeight * 1000))
end

local function StartDBSync()
    Core.WriteQueue.scheduled = false
end

local function StartInventorySync()
    Core.PlayerSyncScheduled = false
end

local function scheduleWriteQueueFlush()
    if Core.WriteQueue.scheduled then
        return
    end

    Core.WriteQueue.scheduled = true
    SetTimeout(Core.WriteQueue.interval, function()
        Core.WriteQueue.scheduled = false
        Core.SavePlayers()

        if next(Core.WriteQueue.players) then
            scheduleWriteQueueFlush()
        end
    end)
end

local function schedulePlayerSyncFlush()
    if Core.PlayerSyncScheduled then
        return
    end

    Core.PlayerSyncScheduled = true
    SetTimeout(Config.InventorySyncInterval, function()
        Core.PlayerSyncScheduled = false
        Core.FlushPendingPlayerSync()

        if next(Core.ActivePlayerSync) then
            schedulePlayerSyncFlush()
        end
    end)
end

local function getScopeBucketKey(coords)
    return ("%s:%s"):format(
        math.floor(coords.x / Config.PlayerScopeBucketSize),
        math.floor(coords.y / Config.PlayerScopeBucketSize)
    )
end

-- Event-driven: when UseClientStatebagCoords, clients push coords to statebag.
-- Batched to avoid CPU spikes when many players.
local function rebuildScopeFromStatebag()
    local sources = {}
    for source in pairs(ESX.Players) do
        sources[#sources + 1] = source
    end
    if #sources == 0 then
        Core.PlayerCoords = {}
        Core.PlayerScopeBuckets = {}
        return
    end

    local scopedPlayers = {}
    local scopeBuckets = {}
    local bucketSize = Config.PlayerScopeBucketSize
    local batchSize = math.max(1, Config.ScopeBatchSize or 64)
    local idx = 1

    local function processChunk()
        for _ = 1, batchSize do
            if idx > #sources then
                Core.PlayerCoords = scopedPlayers
                Core.PlayerScopeBuckets = scopeBuckets
                return
            end
            local source = sources[idx]
            idx += 1
            local stateBag = Player(source).state
            local coords = stateBag.coords
            if coords and type(coords) == "table" and coords.x and coords.y then
                local bucketKey = ("%s:%s"):format(
                    math.floor(coords.x / bucketSize),
                    math.floor(coords.y / bucketSize)
                )
                local routingBucket = GetPlayerRoutingBucket(source)
                scopedPlayers[source] = {
                    coords = vector3(coords.x, coords.y, coords.z or 0),
                    ped = GetPlayerPed(source),
                    routingBucket = routingBucket,
                    bucketKey = bucketKey,
                }
                scopeBuckets[routingBucket] = scopeBuckets[routingBucket] or {}
                scopeBuckets[routingBucket][bucketKey] = scopeBuckets[routingBucket][bucketKey] or {}
                scopeBuckets[routingBucket][bucketKey][#scopeBuckets[routingBucket][bucketKey] + 1] = source
            end
        end
        SetTimeout(0, processChunk)
    end
    processChunk()
end

local function rebuildScopeFromServerLoop()
    local sources = {}
    for source in pairs(ESX.Players) do
        sources[#sources + 1] = source
    end
    if #sources == 0 then
        Core.PlayerCoords = {}
        Core.PlayerScopeBuckets = {}
        return
    end

    local scopedPlayers = {}
    local scopeBuckets = {}
    local batchSize = math.max(1, Config.ScopeBatchSize or 64)
    local idx = 1

    local function processChunk()
        for _ = 1, batchSize do
            if idx > #sources then
                Core.PlayerCoords = scopedPlayers
                Core.PlayerScopeBuckets = scopeBuckets
                return
            end
            local source = sources[idx]
            idx += 1
            local ped = GetPlayerPed(source)
            if ped and ped > 0 then
                local coords = GetEntityCoords(ped)
                local routingBucket = GetPlayerRoutingBucket(source)
                local bucketKey = getScopeBucketKey(coords)
                scopedPlayers[source] = {
                    coords = coords,
                    ped = ped,
                    routingBucket = routingBucket,
                    bucketKey = bucketKey,
                }
                scopeBuckets[routingBucket] = scopeBuckets[routingBucket] or {}
                scopeBuckets[routingBucket][bucketKey] = scopeBuckets[routingBucket][bucketKey] or {}
                scopeBuckets[routingBucket][bucketKey][#scopeBuckets[routingBucket][bucketKey] + 1] = source
            end
        end
        SetTimeout(0, processChunk)
    end
    processChunk()
end

local scopeRebuildScheduled = false
local function scheduleScopeRebuild()
    if scopeRebuildScheduled then return end
    scopeRebuildScheduled = true
    local interval = Config.PlayerScopeRefreshInterval or 2000
    SetTimeout(interval, function()
        scopeRebuildScheduled = false
        if Config.UseClientStatebagCoords then
            rebuildScopeFromStatebag()
        else
            rebuildScopeFromServerLoop()
        end
        if next(ESX.Players) then
            scheduleScopeRebuild()
        end
    end)
end

local function StartPlayerScopeCache()
    if Config.UseClientStatebagCoords then
        -- Event-driven: immediate individual update + debounced full rebuild
        AddStateBagChangeHandler("coords", "player", function(bagName, _, value)
            local source = tonumber(bagName:gsub("player:", ""))
            if source and value and value.x then
                local coords = vector3(value.x, value.y, value.z or 0)
                local routingBucket = GetPlayerRoutingBucket(source)
                local bucketKey = getScopeBucketKey(coords)
                
                Core.PlayerCoords[source] = {
                    coords = coords,
                    ped = GetPlayerPed(source),
                    routingBucket = routingBucket,
                    bucketKey = bucketKey,
                }
            end

            if not scopeRebuildScheduled and next(ESX.Players) then
                scheduleScopeRebuild()
            end
        end)
        AddEventHandler("esx:playerLoaded", function(_, xPlayer)
            if xPlayer and xPlayer.source and not scopeRebuildScheduled then
                scheduleScopeRebuild()
            end
        end)
        AddEventHandler("playerDropped", function()
            if not scopeRebuildScheduled and next(ESX.Players) then
                scheduleScopeRebuild()
            end
        end)
        scheduleScopeRebuild()
    else
        -- Legacy: polling loop (fallback for compatibility)
        CreateThread(function()
            while true do
                Wait(Config.PlayerScopeRefreshInterval or 500)
                rebuildScopeFromServerLoop()
            end
        end)
    end
end

function Core.GetScopeBucketKey(coords)
    return getScopeBucketKey(coords)
end

--- O(1) coords lookup: statebag when UseClientStatebagCoords, else PlayerCoords cache, else GetEntityCoords
function Core.GetPlayerCoords(source)
    local cached = Core.PlayerCoords[source]
    if cached and cached.coords then
        return cached.coords
    end
    if Config.UseClientStatebagCoords then
        local state = Player(source).state.coords
        if state and type(state) == "table" and state.x then
            return vector3(state.x, state.y, state.z or 0)
        end
    end
    local ped = GetPlayerPed(source)
    if ped and ped > 0 then
        return GetEntityCoords(ped)
    end
    return vector3(0, 0, 0)
end

local function processLoginQueue()
    Core.LoginQueueScheduled = false

    local processed = 0
    while processed < Config.LoginQueueBatchSize and Core.LoginQueue.head <= Core.LoginQueue.tail do
        local index = Core.LoginQueue.head
        local queueEntry = Core.LoginQueue.items[index]
        Core.LoginQueue.items[index] = nil
        Core.LoginQueue.head = index + 1

        if queueEntry and GetPlayerPing(queueEntry.playerId) > 0 then
            queueEntry.handler()
            processed += 1
        end
    end

    if Core.LoginQueue.head > Core.LoginQueue.tail then
        Core.LoginQueue.head = 1
        Core.LoginQueue.tail = 0
        return
    end

    Core.LoginQueueScheduled = true
    SetTimeout(Config.LoginQueueInterval, processLoginQueue)
end

local function StartLoginQueue()
    Core.LoginQueueScheduled = false
end

function Core.EnqueueLogin(playerId, handler)
    Core.LoginQueue.tail += 1
    Core.LoginQueue.items[Core.LoginQueue.tail] = {
        playerId = playerId,
        handler = handler,
    }

    if not Core.LoginQueueScheduled then
        Core.LoginQueueScheduled = true
        SetTimeout(Config.LoginQueueInterval, processLoginQueue)
    end
end

function Core.DebugCounter(name, amount)
    if not Config.EnablePerformanceDebug then
        return
    end

    Core.Performance.counters[name] = (Core.Performance.counters[name] or 0) + (amount or 1)
end

function Core.DebugDuration(name, startedAt)
    if not Config.EnablePerformanceDebug then
        return
    end

    local elapsed = GetGameTimer() - startedAt
    if elapsed < Config.SlowFunctionWarningMs then
        return
    end

    local entry = Core.Performance.slowPaths[name] or { count = 0, max = 0 }
    entry.count += 1
    entry.max = math.max(entry.max, elapsed)
    Core.Performance.slowPaths[name] = entry

    print(("[^3PERF^7] %s took %sms (count=%s, max=%sms)"):format(name, elapsed, entry.count, entry.max))
end

function Core.BindPlayerCache(xPlayer)
    local cache = {
        identifier = xPlayer.identifier,
        money = 0,
        state = xPlayer.state,
        accounts = xPlayer.state.money,
        accountLookup = xPlayer.state.money,
        job = xPlayer.state.job,
        inventory = xPlayer.state.inventory,
        inventoryList = xPlayer.inventoryList,
        metadata = xPlayer.state.metadata,
        lastSync = 0,
        dirty = {
            money = false,
            group = false,
            inventory = false,
            job = false,
            loadout = false,
            metadata = false,
            name = false,
            position = false,
        },
        pendingSync = {
            accounts = {},
            inventory = {},
        },
        nextSyncAt = 0,
        ammoSync = {
            acceptedAt = {},
            lastClientAmmo = {},
        },
        -- Snapshot for rollback; updated only after successful DB write
        lastSaved = nil,
        lastSavedEncoded = nil,
        lastImmediateSaveAt = 0,
    }
    cache.dirtyFlags = cache.dirty

    local account = xPlayer.state.money.money
    cache.money = account and account.money or 0

    xPlayer.cache = cache
    xPlayer.dirtyFlags = cache.dirty
    xPlayer.dirty = cache.dirty
    xPlayer.isSaving = false
    Core.PlayerCache[xPlayer.source] = cache

    return cache
end

function Core.MarkPlayerDirty(xPlayer, flag)
    local cache = (xPlayer and xPlayer.cache) or Core.PlayerCache[xPlayer.source]
    if not cache then
        return
    end

    if flag == "accounts" then
        flag = "money"
    end

    cache.dirtyFlags[flag] = true
    Core.WriteQueue.players[xPlayer.source] = xPlayer
    scheduleWriteQueueFlush()
end

function Core.ClearPlayerDirtyFlags(xPlayer)
    local cache = (xPlayer and xPlayer.cache) or Core.PlayerCache[xPlayer.source]
    if not cache then
        return
    end

    for key in pairs(cache.dirtyFlags) do
        cache.dirtyFlags[key] = false
    end

    Core.WriteQueue.players[xPlayer.source] = nil
end

local function markPlayerSyncActive(source, cache)
    cache.nextSyncAt = GetGameTimer() + Config.InventorySyncRateLimit
    Core.ActivePlayerSync[source] = true
    schedulePlayerSyncFlush()
end

function Core.QueueAccountSync(xPlayer, account)
    local cache = (xPlayer and xPlayer.cache) or Core.PlayerCache[xPlayer.source]
    if not cache or not account then
        return
    end

    cache.pendingSync.accounts[account.name] = {
        name = account.name,
        money = account.money,
        label = account.label,
        round = account.round,
        index = account.index,
    }

    markPlayerSyncActive(xPlayer.source, cache)
end

function Core.QueueInventorySync(xPlayer, itemName, count, delta, displayLabel)
    local cache = (xPlayer and xPlayer.cache) or Core.PlayerCache[xPlayer.source]
    if not cache then
        return
    end

    cache.pendingSync.inventory[itemName] = {
        name = itemName,
        count = count,
        delta = delta,
        label = displayLabel,
    }
    markPlayerSyncActive(xPlayer.source, cache)
end

local function flushOnePlayerSync(source, cache, now)
    local pendingAccounts = cache.pendingSync.accounts
    if next(pendingAccounts) then
        local updates = {}
        local updateIndex = 1
        for accountName, payload in pairs(pendingAccounts) do
            updates[updateIndex] = payload
            updateIndex += 1
            pendingAccounts[accountName] = nil
        end
        if updateIndex > 1 then
            TriggerClientEvent("esx:updateAccounts", source, updates)
            Core.DebugCounter("account_sync_batches")
        end
    end

    local pendingInventory = cache.pendingSync.inventory
    if next(pendingInventory) then
        local updates = {}
        local updateIndex = 1
        for itemName, payload in pairs(pendingInventory) do
            updates[updateIndex] = payload
            updateIndex += 1
            pendingInventory[itemName] = nil
        end
        if updateIndex > 1 then
            TriggerClientEvent("esx:updateInventory", source, updates)
            Core.DebugCounter("inventory_sync_batches")
        end
    end

    cache.lastSync = now
    if not next(pendingAccounts) and not next(pendingInventory) then
        Core.ActivePlayerSync[source] = nil
    else
        cache.nextSyncAt = now + Config.InventorySyncRateLimit
    end
end

local syncFlushScheduled = false
function Core.FlushPendingPlayerSync()
    local now = GetGameTimer()
    local eligible = {}
    for source in pairs(Core.ActivePlayerSync) do
        local cache = Core.PlayerCache[source]
        if not cache then
            Core.ActivePlayerSync[source] = nil
        elseif cache.nextSyncAt <= now then
            eligible[#eligible + 1] = { source = source, cache = cache }
        end
    end

    local batchSize = math.max(1, Config.SyncBatchSize or 8)
    local batchDelay = math.max(0, Config.SyncBatchDelay or 10)
    local stepKb = Config.GCStepSize or 0
    local function runGC()
        if stepKb > 0 and collectgarbage and collectgarbage("count") then
            pcall(collectgarbage, "step", stepKb)
        end
    end

    for i = 1, math.min(batchSize, #eligible) do
        local entry = eligible[i]
        flushOnePlayerSync(entry.source, entry.cache, now)
    end

    if #eligible > batchSize then
        if not syncFlushScheduled then
            syncFlushScheduled = true
            SetTimeout(batchDelay, function()
                syncFlushScheduled = false
                runGC()
                Core.FlushPendingPlayerSync()
            end)
        end
    elseif next(Core.ActivePlayerSync) and not syncFlushScheduled then
        syncFlushScheduled = true
        SetTimeout(batchDelay, function()
            syncFlushScheduled = false
            Core.FlushPendingPlayerSync()
        end)
    end
end

function Core.AllowPlayerEvent(playerId, eventName, cooldown)
    local now = GetGameTimer()
    local playerThrottle = Core.EventThrottle[playerId]

    if not playerThrottle then
        playerThrottle = {}
        Core.EventThrottle[playerId] = playerThrottle
    end

    local nextAllowed = playerThrottle[eventName] or 0
    if nextAllowed > now then
        return false
    end

    playerThrottle[eventName] = now + cooldown
    return true
end

local function extractWeaponNamesFromMeta(content)
    local detected = {}
    if not content or content == "" then
        return detected
    end

    for weaponName in content:gmatch("<Name>%s*(WEAPON_[%u%d_]+)%s*</Name>") do
        detected[weaponName] = true
    end

    for weaponName in content:gmatch("WEAPON_[%u%d_]+") do
        detected[weaponName] = true
    end

    return detected
end

local function getWeaponAutoDefaults(weaponName)
    local inferredType = "unknown"
    local patterns = Config.WeaponTypeNamePatterns or {}
    local upperName = string.upper(weaponName)

    for weaponType, entries in pairs(patterns) do
        for i = 1, #entries do
            if upperName:find(entries[i], 1, true) then
                inferredType = weaponType
                goto foundType
            end
        end
    end

    ::foundType::
    local defaults = (Config.WeaponTypeDefaults and Config.WeaponTypeDefaults[inferredType]) or Config.WeaponTypeDefaults.unknown
    return inferredType, defaults
end

local function detectWeaponsInResource(resourceName)
    if Core.WeaponScanCache[resourceName] then
        return
    end

    Core.WeaponScanCache[resourceName] = true
    local discovered = {}

    for i = 1, #Config.WeaponAutoDetectFiles do
        local fileName = Config.WeaponAutoDetectFiles[i]
        local content = LoadResourceFile(resourceName, fileName)
        if content then
            local weaponNames = extractWeaponNamesFromMeta(content)
            for weaponName in pairs(weaponNames) do
                discovered[weaponName] = true
            end
        end
    end

    for weaponName in pairs(discovered) do
        if not Core.DetectedWeapons[weaponName] then
            local weaponType, defaults = getWeaponAutoDefaults(weaponName)
            RegisterAddonWeapon(weaponName, {
                label = weaponName,
                type = weaponType,
                maxAmmo = defaults.maxAmmo,
                minFireInterval = defaults.minFireInterval,
                maxRange = defaults.maxRange,
                minDamage = defaults.minDamage,
                maxDamage = defaults.maxDamage,
                spreadTolerance = defaults.spreadTolerance,
                recoilTolerance = defaults.recoilTolerance,
            })
            Core.DetectedWeapons[weaponName] = true
        end
    end
end

function Core.ScanAddonWeapons()
    if not Config.WeaponAutoDetect then
        return
    end

    local resourceCount = GetNumResources()
    for i = 0, resourceCount - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if resourceName and resourceName ~= GetCurrentResourceName() then
            detectWeaponsInResource(resourceName)
        end
    end
end

AddEventHandler("onServerResourceStart", function(resourceName)
    if Config.WeaponAutoDetect then
        detectWeaponsInResource(resourceName)
    end
end)

local function tuneGC()
    if collectgarbage then
        pcall(collectgarbage, "setpause", 110)
        pcall(collectgarbage, "setstepmul", 200)
    end
end

local function startPeriodicGC()
    local stepKb = Config.GCStepSize or 0
    if stepKb <= 0 then return end
    CreateThread(function()
        while true do
            Wait(5000)
            pcall(collectgarbage, "step", stepKb)
        end
    end)
end

MySQL.ready(function()
    Core.DatabaseConnected = true

    ESX.RefreshItems()

    ESX.RefreshJobs()
    Core.ScanAddonWeapons()

    print(("[^2INFO^7] ESX ^5Legacy %s^0 initialized!"):format(GetResourceMetadata(GetCurrentResourceName(), "version", 0)))

    GlobalState.gameBuild = tonumber(GetConvar("sv_enforceGameBuild", "1604"))
    GlobalState.suggestions = {}
    tuneGC()
    StartDBSync()
    StartInventorySync()
    StartLoginQueue()
    StartPlayerScopeCache()
    startPeriodicGC()
    if Config.EnablePaycheck then
        StartPayCheck()
    end
end)

RegisterNetEvent("esx:clientLog", function(msg)
    if Config.EnableDebug then
        print(("[^2TRACE^7] %s^7"):format(msg))
    end
end)

RegisterNetEvent("esx:ReturnVehicleType", function(Type, Request)
    if Core.ClientCallbacks[Request] then
        Core.ClientCallbacks[Request](Type)
        Core.ClientCallbacks[Request] = nil
    end
end)

GlobalState.playerCount = 0
