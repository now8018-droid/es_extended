SetMapName("San Andreas")
SetGameType("ESX Legacy")

local oneSyncState = GetConvar("onesync", "off")
local newPlayer = "INSERT INTO `users` SET `accounts` = ?, `identifier` = ?, `group` = ?"
local loadPlayer = "SELECT `accounts`, `job`, `job_grade`, `group`, `position`, `inventory`, `skin`, `loadout`, `metadata`, `version`"
local missingSteamMessage = "Steam must be running to join this server"

if Config.StartingInventoryItems then
    newPlayer = newPlayer .. ", `inventory` = ?"
end

if Config.Identity then
    loadPlayer = loadPlayer .. ", `firstname`, `lastname`, `dateofbirth`, `sex`, `height`"
end

loadPlayer = loadPlayer .. " FROM `users` WHERE identifier = ?"

local function createESXPlayer(identifier, playerId)
    local accounts = {}

    for account, money in pairs(Config.StartingAccountMoney) do
        accounts[account] = money
    end

    local defaultGroup = "user"
    if Core.IsPlayerAdmin(playerId) then
        print(("[^2INFO^0] Player ^5%s^0 Has been granted admin permissions via ^5Ace Perms^7."):format(playerId))
        defaultGroup = "admin"
    end
    local parameters = { json.encode(accounts), identifier, defaultGroup }

    if Config.StartingInventoryItems then
        table.insert(parameters, json.encode(Config.StartingInventoryItems))
    end

    MySQL.prepare(newPlayer, parameters, function()
        loadESXPlayer(identifier, playerId, true)
    end)
end


local function onPlayerJoined(playerId)
    local identifier = ESX.GetIdentifier(playerId)
    if not identifier then
        return DropPlayer(playerId, missingSteamMessage)
    end

    if ESX.GetPlayerFromIdentifier(identifier) then
        DropPlayer(
            playerId,
            ("there was an error loading your character!\nError code: identifier-active-ingame\n\nThis error is caused by a player on this server who has the same Steam Hex as you have. Make sure you are not playing on the same Steam account.\n\nYour Steam Hex: %s"):format(
                identifier
            )
        )
    else
        Core.EnqueueLogin(playerId, function()
            MySQL.scalar("SELECT 1 FROM users WHERE identifier = ?", { identifier }, function(result)
                if GetPlayerPing(playerId) <= 0 then
                    return
                end

                if result then
                    loadESXPlayer(identifier, playerId, false)
                else
                    createESXPlayer(identifier, playerId)
                end
            end)
        end)
    end
end

---@param playerId number
---@param reason string
---@param cb function?
local function onPlayerDropped(playerId, reason, cb)
    local p = not cb and promise:new()
    local function resolve()
        if cb then
            return cb()
        elseif(p) then
            return p:resolve()
        end
    end

    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then
        return resolve()
    end

    TriggerEvent("esx:playerDropped", playerId, reason)
    local job = xPlayer.getJob().name
    local currentJob = Core.JobsPlayerCount[job]
    Core.JobsPlayerCount[job] = ((currentJob and currentJob > 0) and currentJob or 1) - 1

    if Core.PlayersByJob[job] then
        Core.PlayersByJob[job][playerId] = nil
    end

    GlobalState[("%s:count"):format(job)] = Core.JobsPlayerCount[job]

    -- Force latest disconnect position into immediate save to prevent rollback to old coords.
    if xPlayer.dirtyFlags then
        xPlayer.dirtyFlags.position = true
    end

    Core.SavePlayer(xPlayer, function()
        Core.LastDisconnectAt[xPlayer.identifier] = os.time() * 1000
        GlobalState["playerCount"] = GlobalState["playerCount"] - 1
        ESX.Players[playerId] = nil
        Core.playersByIdentifier[xPlayer.identifier] = nil
        Core.PlayerCache[playerId] = nil
        Core.ActivePlayerSync[playerId] = nil
        Core.RemovePlayerScopeEntry(playerId)
        Core.ClearSuspiciousPlayer(playerId)
        Core.EventThrottle[playerId] = nil

        resolve()
    end, true)

    if p then
        return Citizen.Await(p)
    end
end
AddEventHandler("esx:onPlayerDropped", onPlayerDropped)


local function waitForJobsThenJoin(source)
    if not next(ESX.Jobs) then
        return SetTimeout(50, function() waitForJobsThenJoin(source) end)
    end
    if not ESX.Players[source] then
        onPlayerJoined(source)
    end
end

RegisterNetEvent("esx:onPlayerJoined", function()
    waitForJobsThenJoin(source)
end)

AddEventHandler("playerConnecting", function(_, _, deferrals)
    local playerId = source
    deferrals.defer()
    Wait(1) -- Required
    local identifier

    -- luacheck: ignore
    if not SetEntityOrphanMode then
        return deferrals.done(("[ESX] ESX Requires a minimum Artifact version of 10188, Please update your server."))
    end

    if oneSyncState == "off" or oneSyncState == "legacy" then
        return deferrals.done(("[ESX] ESX Requires Onesync Infinity to work. This server currently has Onesync set to: %s"):format(oneSyncState))
    end

    if not Core.DatabaseConnected then
        return deferrals.done("[ESX] OxMySQL Was Unable To Connect to your database. Please make sure it is turned on and correctly configured in your server.cfg")
    end

    local success = pcall(function()
        identifier = ESX.GetIdentifier(playerId)
    end)

    if not success or not identifier then
        return deferrals.done(missingSteamMessage)
    end

    local lastDisconnectAt = Core.LastDisconnectAt[identifier]
    local reconnectCooldown = Config.ReconnectCooldownMs or 5000
    local now = os.time() * 1000
    if lastDisconnectAt and (now - lastDisconnectAt) < reconnectCooldown then
        return deferrals.done(("[ESX] Reconnect throttled. Please wait %ss"):format(math.ceil((reconnectCooldown - (now - lastDisconnectAt)) / 1000)))
    end

    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)

    if not xPlayer then
        return deferrals.done()
    end

    if GetPlayerPing(xPlayer.source --[[@as string]]) > 0 then
        return deferrals.done(
            ("[ESX] There was an error loading your character!\nError code: identifier-active\n\nThis error is caused by a player on this server who has the same Steam Hex as you have. Make sure you are not playing on the same Steam account.\n\nYour Steam Hex: %s"):format(identifier)
        )
    end

    deferrals.update(("[ESX] Cleaning stale player entry..."):format(identifier))
    onPlayerDropped(xPlayer.source, "esx_stale_player_obj")
    deferrals.done()
end)

local function decodePlayerField(value, fallback)
    if not value or value == "" then
        return fallback
    end

    local ok, decoded = pcall(json.decode, value)
    if not ok or decoded == nil or type(decoded) ~= type(fallback) then
        return fallback
    end

    return decoded
end

local function decodeOptionalJsonTable(value)
    if not value or value == "" then
        return {}
    end

    local ok, decoded = pcall(json.decode, value)
    if not ok or type(decoded) ~= "table" then
        return {}
    end

    return decoded
end

local function buildPlayerLoadPayload(identifier, playerId, result)
    local payload = {
        accounts = {},
        inventory = decodePlayerField(result.inventory, {}),
        loadout = {},
        weight = 0,
        name = GetPlayerName(playerId),
        identifier = identifier,
        firstName = "John",
        lastName = "Doe",
        dateofbirth = "01/01/2000",
        height = 120,
        dead = false,
        variables = {},
        metadata = decodePlayerField(result.metadata, {}),
    }

    local accounts = decodePlayerField(result.accounts, {})
    local normalizedAccounts = {}
    if #accounts > 0 then
        for i = 1, #accounts do
            local account = accounts[i]
            if account and account.name then
                normalizedAccounts[string.lower(account.name)] = account.money or 0
            end
        end
    else
        for accountName, money in pairs(accounts) do
            if type(accountName) == "string" then
                if type(money) == "table" then
                    normalizedAccounts[string.lower(accountName)] = money.money or money.amount or 0
                else
                    normalizedAccounts[string.lower(accountName)] = money or 0
                end
            end
        end
    end

    for accountName in pairs(Config.Accounts) do
        payload.accounts[accountName] = normalizedAccounts[accountName] or Config.StartingAccountMoney[accountName] or 0
    end

    for accountName, money in pairs(normalizedAccounts) do
        if payload.accounts[accountName] == nil then
            payload.accounts[accountName] = money or 0
        end
    end

    local job, grade = result.job, tostring(result.job_grade)
    if not ESX.DoesJobExist(job, grade) then
        print(("[^3WARNING^7] Ignoring invalid job for ^5%s^7 [job: ^5%s^7, grade: ^5%s^7]"):format(identifier, job, grade))
        job, grade = "unemployed", "0"
    end

    local jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]
    payload.job = {
        id = jobObject.id,
        name = jobObject.name,
        label = jobObject.label,
        grade = tonumber(grade),
        grade_name = gradeObject.name,
        grade_label = gradeObject.label,
        grade_salary = gradeObject.salary,
        skin_male = decodeOptionalJsonTable(gradeObject.skin_male),
        skin_female = decodeOptionalJsonTable(gradeObject.skin_female),
    }

    -- โหลด loadout จาก DB เสมอ (เซิร์ฟใช้ xPlayer / payload; การให้อาวุธบน ped เป็นของกระเป๋าคัสตอมเมื่อ CustomInventory)
    local loadout = decodePlayerField(result.loadout, {})
    for name, weapon in pairs(loadout) do
        local weaponConfig = GetWeaponConfig(name)
        if weaponConfig then
            payload.loadout[#payload.loadout + 1] = {
                name = name,
                ammo = weapon.ammo,
                label = weaponConfig.label or name,
                components = weapon.components or {},
                tintIndex = weapon.tintIndex or 0,
            }
        else
            print(("[^3WARNING^7] Ignoring unknown loadout weapon for ^5%s^7: ^5%s^7"):format(identifier, tostring(name)))
        end
    end

    payload.group = result.group == "superadmin" and "admin" or (result.group or "user")
    if result.group == "superadmin" then
        print("[^3WARNING^7] ^5Superadmin^7 detected, setting group to ^5admin^7")
    end

    payload.coords = decodePlayerField(result.position, Config.DefaultSpawns[ESX.Math.Random(1, #Config.DefaultSpawns)])
    payload.skin = decodePlayerField(result.skin, { sex = (result.sex == "f") and 1 or 0 })
    if type(payload.skin) == "table" and payload.skin.sex == nil and result.sex then
        payload.skin.sex = (result.sex == "f") and 1 or 0
    end

    if result.firstname and result.firstname ~= "" then
        payload.firstName = result.firstname
        payload.lastName = result.lastname
        payload.name = ("%s %s"):format(result.firstname, result.lastname)
        payload.variables.firstName = result.firstname
        payload.variables.lastName = result.lastname

        if result.dateofbirth then
            payload.dateofbirth = result.dateofbirth
            payload.variables.dateofbirth = result.dateofbirth
        end

        if result.sex then
            payload.sex = result.sex
            payload.variables.sex = result.sex
        end

        if result.height then
            payload.height = result.height
            payload.variables.height = result.height
        end
    end

    return payload
end

local function syncLoadedPlayer(xPlayer, payload, playerId, isNew)
    payload.inventory = xPlayer.inventoryList
    payload.accounts = xPlayer.getAccounts()
    payload.loadout = xPlayer.getLoadout()
    payload.metadata = xPlayer.metadata
    payload.money = xPlayer.getMoney()
    payload.maxWeight = xPlayer.getMaxWeight()
    payload.variables = xPlayer.variables or payload.variables or {}

    Player(playerId).state:set("isAdmin", Core.IsPlayerAdmin(playerId), true)
    local skin = payload.skin or {}

    TriggerEvent("esx:playerLoaded", playerId, xPlayer, isNew)
    xPlayer.triggerEvent("esx:playerLoaded", payload, isNew, skin)

    if not Config.CustomInventory and Config.EnablePickupSystem then
        xPlayer.triggerEvent("esx:createMissingPickups", Core.Pickups)
    end

    xPlayer.triggerEvent("esx:registerSuggestions")
    print(('[^2INFO^0] Player ^5"%s"^0 has connected to the server. ID: ^5%s^7'):format(xPlayer.getName(), playerId))
end

function loadESXPlayer(identifier, playerId, isNew)
    MySQL.prepare(loadPlayer, { identifier }, function(result)
        if not result or GetPlayerPing(playerId) <= 0 then
            return
        end

        local cachedByIdentifier = Core.playersByIdentifier[identifier]
        local dbVersion = tonumber(result.version) or 0
        if cachedByIdentifier and cachedByIdentifier.version and cachedByIdentifier.version ~= dbVersion then
            print(("[^3WARNING^7] Cache/version mismatch for %s (cache=%s db=%s), refreshing from DB"):format(identifier, cachedByIdentifier.version, dbVersion))
        end

        local payload = buildPlayerLoadPayload(identifier, playerId, result)
        local xPlayer = CreateExtendedPlayer(
            playerId,
            identifier,
            payload.group,
            payload.accounts,
            payload.inventory,
            payload.weight,
            payload.job,
            payload.loadout,
            payload.name,
            payload.coords,
            payload.metadata
        )

        GlobalState["playerCount"] = (GlobalState["playerCount"] or 0) + 1
        ESX.Players[playerId] = xPlayer
        Core.playersByIdentifier[identifier] = xPlayer
        xPlayer.version = dbVersion

        xPlayer.name = payload.name
        xPlayer.variables = payload.variables or {}
        xPlayer.skin = payload.skin
        Player(playerId).state:set("name", xPlayer.name, true)

        syncLoadedPlayer(xPlayer, payload, playerId, isNew)
    end)
end

AddEventHandler("chatMessage", function(playerId, _, message)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer and message:sub(1, 1) == "/" and playerId > 0 then
        CancelEvent()
        local commandName = message:sub(1):gmatch("%w+")()
        xPlayer.showNotification(TranslateCap("commanderror_invalidcommand", commandName))
    end
end)

---@param reason string
AddEventHandler("playerDropped", function(reason)
    onPlayerDropped(source --[[@as number]], reason)
    GlobalState.playerCount = ESX.GetNumPlayers()
end)

AddEventHandler("esx:playerLoaded", function(_, xPlayer, isNew)
    local job = xPlayer.getJob().name
    local jobKey = ("%s:count"):format(job)

    Core.JobsPlayerCount[job] = (Core.JobsPlayerCount[job] or 0) + 1
    Core.PlayersByJob[job] = Core.PlayersByJob[job] or {}
    Core.PlayersByJob[job][xPlayer.source] = true
    GlobalState.playerCount = ESX.GetNumPlayers()

    GlobalState[jobKey] = Core.JobsPlayerCount[job]
    if isNew then
        Player(xPlayer.source).state:set('isNew', true, false)
    end
end)

AddEventHandler("esx:setJob", function(playerId, job, lastJob)
    local lastJobKey = ("%s:count"):format(lastJob.name)
    local jobKey = ("%s:count"):format(job.name)
    local currentLastJob = Core.JobsPlayerCount[lastJob.name]

    Core.JobsPlayerCount[lastJob.name] = ((currentLastJob and currentLastJob > 0) and currentLastJob or 1) - 1
    Core.JobsPlayerCount[job.name] = (Core.JobsPlayerCount[job.name] or 0) + 1

    if Core.PlayersByJob[lastJob.name] then
        Core.PlayersByJob[lastJob.name][playerId] = nil
    end
    Core.PlayersByJob[job.name] = Core.PlayersByJob[job.name] or {}
    Core.PlayersByJob[job.name][playerId] = true

    GlobalState[lastJobKey] = Core.JobsPlayerCount[lastJob.name]
    GlobalState[jobKey] = Core.JobsPlayerCount[job.name]
end)

AddEventHandler("esx:playerLogout", function(playerId, cb)
    onPlayerDropped(playerId, "esx_player_logout", cb)
    TriggerClientEvent("esx:onPlayerLogout", playerId)
end)

---@param key? string
---@param val? string|table
---@param minimal? boolean
---@return xPlayer[]|number[]|table<any, xPlayer[]>|table<any, number[]>
function ESX.GetExtendedPlayers(key, val, minimal)
    if not key then
        if not minimal then
            local xPlayers = {}
            for _, xPlayer in pairs(ESX.Players) do
                xPlayers[#xPlayers + 1] = xPlayer
            end
            return xPlayers
        end

        local xPlayers = {}
        for src in pairs(ESX.Players) do
            xPlayers[#xPlayers + 1] = src
        end

        return xPlayers
    end

    if key == "job" then
        if type(val) == "table" then
            local results = {}
            for i = 1, #val do
                local job = val[i]
                results[job] = {}
                local players = Core.PlayersByJob[job]
                if players then
                    for src in pairs(players) do
                        results[job][#results[job] + 1] = (minimal and src or ESX.Players[src])
                    end
                end
            end
            return results
        end

        local xPlayers = {}
        local players = Core.PlayersByJob[val]
        if players then
            for src in pairs(players) do
                xPlayers[#xPlayers + 1] = (minimal and src or ESX.Players[src])
            end
        end
        return xPlayers
    end

    local xPlayers = {}
    if type(val) == "table" then
        for _, xPlayer in pairs(ESX.Players) do
            for _, v in pairs(val) do
                if xPlayer[key] == v then
                    xPlayers[#xPlayers + 1] = (minimal and xPlayer.source or xPlayer)
                    break
                end
            end
        end

        return xPlayers
    end

    for _, xPlayer in pairs(ESX.Players) do
        if xPlayer[key] == val then
            xPlayers[#xPlayers + 1] = (minimal and xPlayer.source or xPlayer)
        end
    end

    return xPlayers
end

function ESX.GetNumPlayers(key, val)
    if not key then
        return GlobalState["playerCount"] or 0
    end

    if type(val) == "table" then
        local numPlayers = {}
        if key == "job" then
            for _, v in ipairs(val) do
                numPlayers[v] = (Core.JobsPlayerCount[v] or 0)
            end
            return numPlayers
        end

        local filteredPlayers = ESX.GetExtendedPlayers(key, val)
        for i, v in pairs(filteredPlayers) do
            numPlayers[i] = (#v or 0)
        end
        return numPlayers
    end

    if key == "job" then
        return (Core.JobsPlayerCount[val] or 0)
    end

    return #ESX.GetExtendedPlayers(key, val)
end

local function buildCallbackPlayerData(xPlayer, fullPayload)
    local payload = {
        identifier = xPlayer.identifier,
        job = xPlayer.getJob(),
        money = xPlayer.getMoney(),
        metadata = xPlayer.getMeta(),
    }

    if fullPayload then
        payload.accounts = xPlayer.getAccounts()
        payload.inventory = xPlayer.inventoryList
        payload.loadout = xPlayer.getLoadout()
        payload.position = xPlayer.getCoords(true)
    else
        payload.accounts = xPlayer.getAccounts(true)
        payload.inventory = xPlayer.getInventory(true)
        payload.loadout = xPlayer.getLoadout(true)
    end

    return payload
end

local function getCallbackTargetPlayer(source, target)
    return ESX.Players[target or source]
end

ESX.RegisterServerCallback("esx:getPlayerData", function(source, cb, fullPayload)
    local xPlayer = getCallbackTargetPlayer(source)

    if not xPlayer then
        return
    end

    cb(buildCallbackPlayerData(xPlayer, fullPayload == true))
end)

ESX.RegisterServerCallback("esx:getOtherPlayerData", function(_, cb, target, fullPayload)
    local xPlayer = getCallbackTargetPlayer(nil, target)

    if not xPlayer then
        return
    end

    cb(buildCallbackPlayerData(xPlayer, fullPayload == true))
end)

ESX.RegisterServerCallback("esx:getPlayerNames", function(source, cb, players)
    players[source] = nil

    for playerId, _ in pairs(players) do
        local xPlayer = ESX.Players[playerId]

        if xPlayer then
            players[playerId] = xPlayer.name
        else
            players[playerId] = nil
        end
    end

    cb(players)
end)

if GetResourceState("esx_skin") ~= "started" then
    ESX.RegisterServerCallback("esx_skin:getPlayerSkin", function(source, cb)
        local xPlayer = ESX.Players[source]
        if not xPlayer then
            return cb(nil, nil)
        end

        local skin = xPlayer.skin
        local jobSkin = {}
        local job = xPlayer.getJob()
        if job then
            jobSkin.skin_male = job.skin_male or {}
            jobSkin.skin_female = job.skin_female or {}
        end

        cb(skin or {}, jobSkin)
    end)

    RegisterNetEvent("esx_skin:save", function(skin)
        local source = source
        local xPlayer = ESX.Players[source]
        if not xPlayer or type(skin) ~= "table" then
            return
        end

        xPlayer.skin = skin

        local skinEncoded = json.encode(skin)
        if Config.Identity then
            local sex = (skin.sex == 1 or skin.sex == "f") and "f" or "m"
            MySQL.update("UPDATE `users` SET `skin` = ?, `sex` = ? WHERE `identifier` = ?", { skinEncoded, sex, xPlayer.identifier })
        else
            MySQL.update("UPDATE `users` SET `skin` = ? WHERE `identifier` = ?", { skinEncoded, xPlayer.identifier })
        end
    end)
end

ESX.RegisterServerCallback("esx:spawnVehicle", function(source, cb, vehData)
    local ped = GetPlayerPed(source)
    ESX.OneSync.SpawnVehicle(vehData.model or `ADDER`, vehData.coords or GetEntityCoords(ped), vehData.coords.w or 0.0, vehData.props or {}, function(id)
        if vehData.warp then
            local vehicle = NetworkGetEntityFromNetworkId(id)
            local function tryWarp(timeout)
                if GetVehiclePedIsIn(ped, false) == vehicle or timeout > 15 then
                    return cb(id)
                end
                TaskWarpPedIntoVehicle(ped, vehicle, -1)
                SetTimeout(10, function() tryWarp(timeout + 1) end)
            end
            tryWarp(0)
        else
            cb(id)
        end
    end)
end)

AddEventHandler("txAdmin:events:scheduledRestart", function(eventData)
    if eventData.secondsRemaining == 60 then
        CreateThread(function()
            Wait(50000)
            Core.SavePlayers()
        end)
    end
end)

AddEventHandler("txAdmin:events:serverShuttingDown", function()
    Core.SavePlayers()
end)

local DoNotUse = {
    ["essentialmode"] = true,
    ["es_admin2"] = true,
    ["basic-gamemode"] = true,
    ["mapmanager"] = true,
    ["fivem-map-skater"] = true,
    ["fivem-map-hipster"] = true,
    ["qb-core"] = true,
    ["default_spawnpoint"] = true,
}

AddEventHandler("onResourceStart", function(key)
    if DoNotUse[string.lower(key)] then
        while GetResourceState(key) ~= "started" do
            Wait(50)
        end

        StopResource(key)
        error(("WE STOPPED A RESOURCE THAT WILL BREAK ^1ESX^1, PLEASE REMOVE ^5%s^1"):format(key))
    end
    -- luacheck: ignore
    if not SetEntityOrphanMode then
        CreateThread(function()
            while true do
                error("ESX Requires a minimum Artifact version of 10188, Please update your server.")
                Wait(60 * 1000)
            end
        end)
    end
end)

for key in pairs(DoNotUse) do
    if GetResourceState(key) == "started" or GetResourceState(key) == "starting" then
        StopResource(key)
        error(("WE STOPPED A RESOURCE THAT WILL BREAK ^1ESX^1, PLEASE REMOVE ^5%s^1"):format(key))
    end
end
