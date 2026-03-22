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
Core.WriteQueue = { players = Core.SaveQueue, scheduled = false }
Core.ActivePlayerSync = {}
Core.AsyncLogQueue = { head = 1, tail = 0, items = {}, scheduled = false, dropped = 0, lastDropNoticeAt = 0 }
Core.SuspiciousPlayers = {}
Core.LoginQueue = { head = 1, tail = 0, items = {} }
Core.LoginQueueScheduled = false
Core.PlayerSyncScheduled = false
Core.EventThrottle = {}
Core.PlayerCoords = {}
Core.PlayerScopeBuckets = {}
Core.ScopeDirtyPlayers = {}
Core.ScopeWorkerScheduled = false
Core.ScopeWorkerDelayMs = nil
Core.ScopeWorkerGeneration = 0
Core.ScopeFullRebuildTimerScheduled = false
Core.ScopeRebuildJob = nil
Core.ScopeRebuildRevision = 0
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
    SetTimeout(Core.Config.Save.interval(), function()
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
    SetTimeout(Core.Config.Sync.inventoryInterval(), function()
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

local function removeSourceFromScopeBuckets(source, cachedPlayer)
    local entry = cachedPlayer or Core.PlayerCoords[source]
    if not entry then
        return
    end

    local scopedBuckets = Core.PlayerScopeBuckets[entry.routingBucket]
    if not scopedBuckets then
        return
    end

    local bucketPlayers = scopedBuckets[entry.bucketKey]
    if not bucketPlayers then
        return
    end

    for index = #bucketPlayers, 1, -1 do
        if bucketPlayers[index] == source then
            bucketPlayers[index] = bucketPlayers[#bucketPlayers]
            bucketPlayers[#bucketPlayers] = nil
            break
        end
    end

    if #bucketPlayers == 0 then
        scopedBuckets[entry.bucketKey] = nil
        if not next(scopedBuckets) then
            Core.PlayerScopeBuckets[entry.routingBucket] = nil
        end
    end
end

local function setSourceScopeEntry(source, coords, routingBucket, ped)
    local cachedPlayer = Core.PlayerCoords[source]
    if cachedPlayer then
        removeSourceFromScopeBuckets(source, cachedPlayer)
    end

    local bucketKey = getScopeBucketKey(coords)
    Core.PlayerCoords[source] = {
        coords = coords,
        ped = ped or GetPlayerPed(source),
        routingBucket = routingBucket,
        bucketKey = bucketKey,
    }

    local scopedBuckets = Core.PlayerScopeBuckets[routingBucket]
    if not scopedBuckets then
        scopedBuckets = {}
        Core.PlayerScopeBuckets[routingBucket] = scopedBuckets
    end

    local bucketPlayers = scopedBuckets[bucketKey]
    if not bucketPlayers then
        bucketPlayers = {}
        scopedBuckets[bucketKey] = bucketPlayers
    end

    bucketPlayers[#bucketPlayers + 1] = source
end

function Core.RemovePlayerScopeEntry(source)
    removeSourceFromScopeBuckets(source)
    Core.PlayerCoords[source] = nil
    Core.ScopeDirtyPlayers[source] = nil
end

local function collectScopeCoords(source)
    local ped
    if Config.UseClientStatebagCoords then
        local stateBag = Player(source).state
        local coords = stateBag and stateBag.coords
        if coords and type(coords) == "table" and coords.x and coords.y then
            return vector3(coords.x, coords.y, coords.z or 0)
        end
    end

    ped = GetPlayerPed(source)
    if ped and ped > 0 then
        return GetEntityCoords(ped), ped
    end

    return nil, ped
end

local function processScopeSource(source, useStatebag)
    if not ESX.Players[source] then
        Core.RemovePlayerScopeEntry(source)
        return
    end

    local coords, ped
    if useStatebag then
        coords, ped = collectScopeCoords(source)
    else
        ped = GetPlayerPed(source)
        if ped and ped > 0 then
            coords = GetEntityCoords(ped)
        end
    end

    if coords then
        setSourceScopeEntry(source, coords, GetPlayerRoutingBucket(source), ped)
    else
        Core.RemovePlayerScopeEntry(source)
    end
end

local function queueScopeWorker(delayMs)
    delayMs = math.max(0, delayMs or 0)

    if Core.ScopeWorkerScheduled and Core.ScopeWorkerDelayMs ~= nil and Core.ScopeWorkerDelayMs <= delayMs then
        return
    end

    Core.ScopeWorkerGeneration += 1
    local generation = Core.ScopeWorkerGeneration
    Core.ScopeWorkerScheduled = true
    Core.ScopeWorkerDelayMs = delayMs

    SetTimeout(delayMs, function()
        if generation ~= Core.ScopeWorkerGeneration then
            return
        end

        Core.ScopeWorkerScheduled = false
        Core.ScopeWorkerDelayMs = nil

        local rebuildJob = Core.ScopeRebuildJob
        if rebuildJob then
            local processed = 0
            local batchSize = Core.Config.Scope.batchSize()
            local rebuildRevision = rebuildJob.revision

            if rebuildRevision ~= Core.ScopeRebuildRevision or Core.ScopeRebuildJob ~= rebuildJob then
                queueScopeWorker(0)
                return
            end

            if rebuildJob.index == 1 then
                Core.PlayerCoords = {}
                Core.PlayerScopeBuckets = {}
            end

            while rebuildJob.index <= #rebuildJob.sources and processed < batchSize do
                if rebuildRevision ~= Core.ScopeRebuildRevision or Core.ScopeRebuildJob ~= rebuildJob then
                    queueScopeWorker(0)
                    return
                end

                local source = rebuildJob.sources[rebuildJob.index]
                rebuildJob.index += 1
                processed += 1
                processScopeSource(source, rebuildJob.useStatebag)
            end

            if rebuildRevision ~= Core.ScopeRebuildRevision or Core.ScopeRebuildJob ~= rebuildJob then
                queueScopeWorker(0)
                return
            end

            if rebuildJob.index <= #rebuildJob.sources then
                queueScopeWorker(0)
                return
            end

            Core.ScopeRebuildJob = nil
        end

        if next(Core.ScopeDirtyPlayers) then
            local processed = 0
            local batchSize = Core.Config.Scope.dirtyBatchSize()
            for source in pairs(Core.ScopeDirtyPlayers) do
                Core.ScopeDirtyPlayers[source] = nil
                processed += 1
                processScopeSource(source, Config.UseClientStatebagCoords)

                if processed >= batchSize then
                    break
                end
            end

            if next(Core.ScopeDirtyPlayers) then
                queueScopeWorker(Core.Config.Scope.dirtyFlushInterval())
            end
        end
    end)
end

local function requestScopeRebuild(useStatebag)
    local sources = {}
    for source in pairs(ESX.Players) do
        sources[#sources + 1] = source
    end

    Core.ScopeRebuildRevision += 1

    if #sources == 0 then
        Core.ScopeRebuildJob = nil
        Core.PlayerCoords = {}
        Core.PlayerScopeBuckets = {}
        return
    end

    Core.ScopeRebuildJob = {
        revision = Core.ScopeRebuildRevision,
        useStatebag = useStatebag,
        sources = sources,
        index = 1,
    }
    queueScopeWorker(0)
end

local function markScopeDirty(source)
    if not source then
        return
    end

    Core.ScopeDirtyPlayers[source] = true
    queueScopeWorker(Core.Config.Scope.dirtyFlushInterval())
end

local function scheduleScopeRebuild()
    if Core.ScopeFullRebuildTimerScheduled then
        return
    end

    Core.ScopeFullRebuildTimerScheduled = true
    local interval = math.max(
        Core.Config.Scope.playerRefreshInterval(),
        Core.Config.Scope.fullRefreshInterval()
    )

    SetTimeout(interval, function()
        Core.ScopeFullRebuildTimerScheduled = false
        requestScopeRebuild(Config.UseClientStatebagCoords)

        if next(ESX.Players) then
            scheduleScopeRebuild()
        end
    end)
end

local function StartPlayerScopeCache()
    if Config.UseClientStatebagCoords then
        AddStateBagChangeHandler("coords", "player", function(bagName, _, value)
            local source = tonumber(bagName:gsub("player:", ""))
            if source and value and value.x then
                markScopeDirty(source)
            end
        end)
        AddEventHandler("esx:playerLoaded", function(_, xPlayer)
            if xPlayer and xPlayer.source then
                markScopeDirty(xPlayer.source)
            end
        end)
        AddEventHandler("playerDropped", function()
            Core.RemovePlayerScopeEntry(source)
            if next(ESX.Players) then
                scheduleScopeRebuild()
            end
        end)
        requestScopeRebuild(true)
        scheduleScopeRebuild()
    else
        -- Legacy: polling loop (fallback for compatibility)
        CreateThread(function()
            while true do
                Wait(Core.Config.Scope.playerRefreshInterval())
                requestScopeRebuild(false)
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
    cache.nextSyncAt = GetGameTimer() + Core.Config.Sync.inventoryRateLimit()
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
        cache.nextSyncAt = now + Core.Config.Sync.inventoryRateLimit()
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

    local batchSize = Core.Config.Sync.batchSize()
    local batchDelay = Core.Config.Sync.batchDelay()
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
GlobalState.serverName = GetConvar("sv_projectName", GetConvar("sv_hostname", "ESX Server"))
