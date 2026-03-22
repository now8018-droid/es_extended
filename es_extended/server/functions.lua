---@param msg string
---@return nil
function ESX.Trace(msg)
    if Config.EnableDebug then
        print(("[^2TRACE^7] %s^7"):format(msg))
    end
end

--- Triggers an event for one or more clients.
---@param eventName string The name of the event to trigger.
---@param playerIds table|number If a number, represents a single player ID. If a table, represents an array of player IDs.
---@param ... any Additional arguments to pass to the event handler.
function ESX.TriggerClientEvent(eventName, playerIds, ...)
    if type(playerIds) == "number" then
        TriggerClientEvent(eventName, playerIds, ...)
        return
    end

    local payload = msgpack.pack_args(...)
    local payloadLength = #payload

    for i = 1, #playerIds do
        TriggerClientEventInternal(eventName, playerIds[i], payload, payloadLength)
    end
end

---@param name string | table
---@param group string | table
---@param cb function
---@param allowConsole? boolean
---@param suggestion? table
function ESX.RegisterCommand(name, group, cb, allowConsole, suggestion)
    if type(name) == "table" then
        for _, v in ipairs(name) do
            ESX.RegisterCommand(v, group, cb, allowConsole, suggestion)
        end
        return
    end

    if Core.RegisteredCommands[name] then
        print(('[^3WARNING^7] Command ^5"%s" ^7already registered, overriding command'):format(name))

        if Core.RegisteredCommands[name].suggestion then
            TriggerClientEvent("chat:removeSuggestion", -1, ("/%s"):format(name))
        end

        local suggestions = GlobalState.suggestions
        if suggestions and suggestions[name] then
            suggestions[name] = nil
            GlobalState.suggestions = suggestions
        end
    end

    if suggestion then
        if not suggestion.arguments then
            suggestion.arguments = {}
        end
        if not suggestion.help then
            suggestion.help = ""
        end

        TriggerClientEvent("chat:addSuggestion", -1, ("/%s"):format(name), suggestion.help, suggestion.arguments)

        local suggestions = GlobalState.suggestions or {}
        suggestions[name] = suggestion
        GlobalState.suggestions = suggestions
    else
        local suggestions = GlobalState.suggestions
        if suggestions and suggestions[name] then
            suggestions[name] = nil
            GlobalState.suggestions = suggestions
        end
    end

    Core.RegisteredCommands[name] = { group = group, cb = cb, allowConsole = allowConsole, suggestion = suggestion }

    RegisterCommand(name, function(playerId, args)
        local command = Core.RegisteredCommands[name]

        if not command.allowConsole and playerId == 0 then
            print(("[^3WARNING^7] ^5%s^0"):format(TranslateCap("commanderror_console")))
        else
            local xPlayer, err = ESX.Players[playerId], nil

            if command.suggestion then
                if command.suggestion.validate then
                    if #args ~= #command.suggestion.arguments then
                        err = TranslateCap("commanderror_argumentmismatch", #args, #command.suggestion.arguments)
                    end
                end

                if not err and command.suggestion.arguments then
                    local newArgs = {}

                    for k, v in ipairs(command.suggestion.arguments) do
                        if v.type then
                            if v.type == "number" then
                                local newArg = tonumber(args[k])

                                if newArg then
                                    newArgs[v.name] = newArg
                                else
                                    err = TranslateCap("commanderror_argumentmismatch_number", k)
                                end
                            elseif v.type == "player" or v.type == "playerId" then
                                local targetPlayer = tonumber(args[k])

                                if args[k] == "me" then
                                    targetPlayer = playerId
                                end

                                if targetPlayer then
                                    local xTargetPlayer = ESX.GetPlayerFromId(targetPlayer)

                                    if xTargetPlayer then
                                        if v.type == "player" then
                                            newArgs[v.name] = xTargetPlayer
                                        else
                                            newArgs[v.name] = targetPlayer
                                        end
                                    else
                                        err = TranslateCap("commanderror_invalidplayerid")
                                    end
                                else
                                    err = TranslateCap("commanderror_argumentmismatch_number", k)
                                end
                            elseif v.type == "string" then
                                local newArg = tonumber(args[k])
                                if not newArg then
                                    newArgs[v.name] = args[k]
                                else
                                    err = TranslateCap("commanderror_argumentmismatch_string", k)
                                end
                            elseif v.type == "item" then
                                if ESX.Items[args[k]] then
                                    newArgs[v.name] = args[k]
                                else
                                    err = TranslateCap("commanderror_invaliditem")
                                end
                            elseif v.type == "weapon" then
                                if ESX.GetWeapon(args[k]) then
                                    newArgs[v.name] = string.upper(args[k])
                                else
                                    err = TranslateCap("commanderror_invalidweapon")
                                end
                            elseif v.type == "any" then
                                newArgs[v.name] = args[k]
                            elseif v.type == "merge" then
                                local length = 0
                                for i = 1, k - 1 do
                                    length = length + string.len(args[i]) + 1
                                end
                                local merge = table.concat(args, " ")

                                newArgs[v.name] = string.sub(merge, length)
                            elseif v.type == "coordinate" then
                                local coord = tonumber(args[k]:match("(-?%d+%.?%d*)"))
                                if not coord then
                                    err = TranslateCap("commanderror_argumentmismatch_number", k)
                                else
                                    newArgs[v.name] = coord
                                end
                            end
                        end
                        
                        if ESX.IsFunctionReference(v.Validator?.validate) and not err then
                            local candidate = newArgs[v.name]
                            local ok, res = pcall(v.Validator.validate, candidate)
                            if not ok or res ~= true then
                                err = v.Validator.err or TranslateCap("commanderror_argumentmismatch")
                            end
                        end

                        --backwards compatibility
                        if v.validate ~= nil and not v.validate then
                            err = nil
                        end

                        if err then
                            break
                        end
                    end

                    args = newArgs
                end
            end

            if err then
                if playerId == 0 then
                    print(("[^3WARNING^7] %s^7"):format(err))
                else
                    xPlayer.showNotification(err)
                end
            else
                cb(xPlayer or false, args, function(msg)
                    if playerId == 0 then
                        print(("[^3WARNING^7] %s^7"):format(msg))
                    else
                        xPlayer.showNotification(msg)
                    end
                end)
            end
        end
    end, true)

    if type(group) == "table" then
        for _, v in ipairs(group) do
            Core.Services.Ace.allowCommand(v, name)
        end
    else
        Core.Services.Ace.allowCommand(group, name)
    end
end

local function updateHealthAndArmorInMetadata(xPlayer)
    local ped = GetPlayerPed(xPlayer.source)
    if not ped or ped == 0 then
        return
    end

    xPlayer.state.metadata.health = GetEntityHealth(ped)
    xPlayer.state.metadata.armor = GetPedArmour(ped)
    xPlayer.state.metadata.lastPlaytime = xPlayer.getPlayTime()
    xPlayer.metadata = xPlayer.state.metadata
end

local savePlayerQuery = "UPDATE `users` SET `accounts` = ?, `job` = ?, `job_grade` = ?, `group` = ?, `position` = ?, `inventory` = ?, `loadout` = ?, `metadata` = ?, `version` = `version` + 1 WHERE `identifier` = ? AND `version` = ?"

local function serializeAccountState(xPlayer)
    local accounts = {}
    for accountName, account in pairs(xPlayer.state.money) do
        accounts[accountName] = account.money
    end
    return accounts
end

--- Delta save: encode only dirty fields; reuse cached strings for unchanged data.
--- forcePosition=true is used on disconnect/immediate saves to persist latest coords.
local function buildPlayerSaveQuery(xPlayer, forcePosition)
    updateHealthAndArmorInMetadata(xPlayer)
    local d = xPlayer.dirtyFlags
    local enc = xPlayer.cache and xPlayer.cache.lastSavedEncoded

    local accountsEnc = d.money and json.encode(serializeAccountState(xPlayer)) or (enc and enc.accounts) or json.encode(serializeAccountState(xPlayer))
    local coordsEnc = (forcePosition or d.position) and json.encode(xPlayer.getCoords(false, true)) or (enc and enc.position) or json.encode(xPlayer.getCoords(false, true))
    local invEnc = d.inventory and json.encode(xPlayer.getInventory(true)) or (enc and enc.inventory) or json.encode(xPlayer.getInventory(true))
    local loadoutEnc = d.loadout and json.encode(xPlayer.getLoadout(true)) or (enc and enc.loadout) or json.encode(xPlayer.getLoadout(true))
    local metaEnc = d.metadata and json.encode(xPlayer.state.metadata) or (enc and enc.metadata) or json.encode(xPlayer.state.metadata)

    return {
        query = savePlayerQuery,
        values = {
            accountsEnc,
            xPlayer.state.job.name,
            xPlayer.state.job.grade,
            xPlayer.group,
            coordsEnc,
            invEnc,
            loadoutEnc,
            metaEnc,
            xPlayer.identifier,
            xPlayer.version or 0,
        },
    }
end

--- Take snapshot of current state for rollback. Called before save attempt.
function Core.SnapshotPlayer(xPlayer)
    local cache = xPlayer.cache
    if not cache then return end
    cache.lastSaved = {
        accounts = serializeAccountState(xPlayer),
        inventory = ESX.Table.Clone(xPlayer.getInventory(true)),
        loadout = ESX.Table.Clone(xPlayer.getLoadout(true)),
        metadata = ESX.Table.Clone(xPlayer.state.metadata),
        job = ESX.Table.Clone(xPlayer.job),
        group = xPlayer.group,
        name = xPlayer.name,
        position = ESX.Table.Clone(xPlayer.getCoords(false, true)),
        version = xPlayer.version or 0,
    }
end

--- Revert in-memory state to lastSaved. Called on DB write failure.
function Core.RevertToLastSaved(xPlayer)
    local cache = xPlayer.cache
    local saved = cache and cache.lastSaved
    if not saved then return end

    for k, v in pairs(saved.accounts or {}) do
        if type(v) == "number" and xPlayer.accounts[k] then
            xPlayer.accounts[k].money = v
        end
    end
    for name in pairs(xPlayer.state.inventory) do
        xPlayer.state.inventory[name] = nil
    end
    for name, item in pairs(xPlayer.inventory) do
        if item then item.count = 0 end
    end
    for i = 1, #(saved.inventory or {}) do
        local it = saved.inventory[i]
        if it and it.name then
            xPlayer.state.inventory[it.name] = it.count
            local item = xPlayer.inventory[it.name]
            if item then
                item.count = it.count
            end
        end
    end
    xPlayer.loadout = {}
    xPlayer.loadoutList = {}
    for name, w in pairs(saved.loadout or {}) do
        if type(w) == "table" then
            local weaponConfig = GetWeaponConfig(name)
            if weaponConfig then
                xPlayer.loadout[name] = {
                    name = name,
                    ammo = w.ammo or 0,
                    label = weaponConfig.label or name,
                    components = w.components or {},
                    tintIndex = w.tintIndex or 0,
                }
                xPlayer.loadoutList[#xPlayer.loadoutList + 1] = xPlayer.loadout[name]
            else
                print(("[^3WARNING^7] Ignoring unknown cached loadout weapon for ^5%s^7: ^5%s^7"):format(xPlayer.identifier, tostring(name)))
            end
        end
    end
    xPlayer.state.metadata = ESX.Table.Clone(saved.metadata or {})
    xPlayer.metadata = xPlayer.state.metadata
    xPlayer.job = ESX.Table.Clone(saved.job or xPlayer.job)
    xPlayer.state.job = xPlayer.job
    xPlayer.group = saved.group or xPlayer.group
    xPlayer.name = saved.name or xPlayer.name
    xPlayer.inventoryMinimalDirty = true
    local moneyAcc = xPlayer.accounts and (xPlayer.accounts.money or xPlayer.accounts["money"])
    if moneyAcc then
        cache.money = moneyAcc.money
    end
    Player(xPlayer.source).state:set("job", xPlayer.job, true)
    Player(xPlayer.source).state:set("group", xPlayer.group, true)
    Player(xPlayer.source).state:set("name", xPlayer.name, true)
    cache.lastSavedEncoded = nil
end

--- Update lastSavedEncoded after successful save. Enables delta encode on next save.
local function updateLastSavedEncoded(xPlayer, queryValues)
    local cache = xPlayer.cache
    if not cache then return end
    cache.lastSavedEncoded = cache.lastSavedEncoded or {}
    cache.lastSavedEncoded.accounts = queryValues[1]
    cache.lastSavedEncoded.position = queryValues[5]
    cache.lastSavedEncoded.inventory = queryValues[6]
    cache.lastSavedEncoded.loadout = queryValues[7]
    cache.lastSavedEncoded.metadata = queryValues[8]
    xPlayer.version = (xPlayer.version or 0) + 1
    if cache.lastSaved then
        cache.lastSaved.version = xPlayer.version
    end
end

local function flushPlayerQueries(queries, onComplete)
    if #queries == 0 then
        if onComplete then
            onComplete(true)
        end
        return
    end

    local startedAt = GetGameTimer()
    Core.DebugCounter("db_flush_requests")
    local index = 1
    local success = true

    local function runNext()
        local query = queries[index]
        if not query then
            Core.DebugDuration("db_flush", startedAt)
            if onComplete then
                onComplete(success)
            end
            return
        end

        MySQL.update(query.query, query.values, function(affectedRows)
            if not affectedRows or affectedRows <= 0 then
                success = false
                Core.DebugDuration("db_flush", startedAt)
                if onComplete then
                    onComplete(false)
                end
                return
            end

            index += 1
            runNext()
        end)
    end

    runNext()
end

local function hasDirtyFlags(xPlayer)
    for _, dirty in pairs(xPlayer.dirtyFlags) do
        if dirty then
            return true
        end
    end

    return false
end

local function runGCStep()
    local stepKb = Config.GCStepSize or 0
    if stepKb > 0 and collectgarbage and collectgarbage("count") then
        pcall(collectgarbage, "step", stepKb)
    end
end

function Core.RequestImmediateSave(xPlayer, reason)
    if not xPlayer or not xPlayer.cache then
        return
    end

    local now = GetGameTimer()
    if (xPlayer.cache.lastImmediateSaveAt or 0) > now then
        return
    end

    xPlayer.cache.lastImmediateSaveAt = now + (Config.CriticalSaveCooldownMs or 1500)
    Core.SavePlayer(xPlayer, nil, true)
end

---@param xPlayer table
---@param cb? function
---@param immediate? boolean
---@return nil
function Core.SavePlayer(xPlayer, cb, immediate)
    if not xPlayer.spawned then
        return cb and cb()
    end

    if not immediate then
        Core.WriteQueue.players[xPlayer.source] = xPlayer
        return cb and cb()
    end

    if xPlayer.isSaving then
        xPlayer.cache.pendingImmediateSave = true
        return SetTimeout(10, function()
            Core.SavePlayer(xPlayer, cb, true)
        end)
    end

    xPlayer.isSaving = true

    Core.SnapshotPlayer(xPlayer)
    local q = buildPlayerSaveQuery(xPlayer, true)

    flushPlayerQueries({ q }, function(success)
        xPlayer.isSaving = false
        if success then
            updateLastSavedEncoded(xPlayer, q.values)
            Core.ClearPlayerDirtyFlags(xPlayer)
            print(('[^2INFO^7] Saved player ^5"%s^7"'):format(xPlayer.name))
            TriggerEvent("esx:playerSaved", xPlayer.playerId, xPlayer)
        else
            Core.RevertToLastSaved(xPlayer)
            print(("[^1WARN^7] Save failed for ^5%s^7, rolled back"):format(xPlayer.name))
        end

        if xPlayer.cache and xPlayer.cache.pendingImmediateSave then
            xPlayer.cache.pendingImmediateSave = false
            Core.RequestImmediateSave(xPlayer, "pending")
        end

        if cb then
            cb(success)
        end
    end)
end

--- Save queue: 1-2 jobs per tick, 5-10ms between. No batch spikes.
---@param cb? function
---@return nil
function Core.SavePlayers(cb)
    local toSave = {}
    for source, xPlayer in pairs(Core.WriteQueue.players) do
        if xPlayer and xPlayer.spawned and hasDirtyFlags(xPlayer) then
            toSave[#toSave + 1] = { source = source, xPlayer = xPlayer }
        else
            Core.WriteQueue.players[source] = nil
        end
    end

    if #toSave == 0 then
        return cb and cb(true)
    end

    local batchSize = Core.Config.Save.batchSize()
    local batchDelay = Core.Config.Save.batchDelay()
    local totalSaved = 0

    local function processBatch(startIndex)
        local endIndex = math.min(startIndex + batchSize - 1, #toSave)
        local parameters = {}
        local batchEntries = {}

        for i = startIndex, endIndex do
            local entry = toSave[i]
            if entry.xPlayer.isSaving then
                goto continue
            end
            entry.xPlayer.isSaving = true
            Core.SnapshotPlayer(entry.xPlayer)
            local q = buildPlayerSaveQuery(entry.xPlayer, false)
            parameters[#parameters + 1] = q
            batchEntries[#batchEntries + 1] = { source = entry.source, xPlayer = entry.xPlayer, query = q }
            ::continue::
        end

        if #batchEntries == 0 then
            if endIndex < #toSave then
                return SetTimeout(batchDelay, function()
                    processBatch(endIndex + 1)
                end)
            end
            if type(cb) == "function" then
                return cb(true)
            end
            return
        end

        local queries = {}
        for i = 1, #parameters do
            queries[i] = { query = parameters[i].query, values = parameters[i].values }
        end

        flushPlayerQueries(queries, function(success)
            for i = 1, #batchEntries do
                local entry = batchEntries[i]
                local xPlayer = ESX.Players[entry.source]
                if xPlayer then
                    xPlayer.isSaving = false
                    if success then
                        updateLastSavedEncoded(xPlayer, entry.query.values)
                        Core.ClearPlayerDirtyFlags(xPlayer)
                        totalSaved += 1
                        TriggerEvent("esx:playerSaved", xPlayer.playerId, xPlayer)
                    else
                        Core.RevertToLastSaved(xPlayer)
                    end

                    if xPlayer.cache and xPlayer.cache.pendingImmediateSave then
                        xPlayer.cache.pendingImmediateSave = false
                        Core.RequestImmediateSave(xPlayer, "pending")
                    end
                end
            end

            runGCStep()

            if endIndex < #toSave then
                SetTimeout(batchDelay, function()
                    processBatch(endIndex + 1)
                end)
            else
                if type(cb) == "function" then
                    cb(success)
                else
                    print(("[^2INFO^7] Saved ^5%s^7 %s"):format(totalSaved, totalSaved ~= 1 and "players" or "player"))
                end
            end
        end)
    end

    processBatch(1)
end

ESX.GetPlayers = GetPlayers

local function checkTable(key, val, xPlayer, xPlayers, minimal)
    for valIndex = 1, #val do
        local value = val[valIndex]
        if not xPlayers[value] then
            xPlayers[value] = {}
        end

        if (key == "job" and xPlayer.job.name == value) or xPlayer[key] == value then
            xPlayers[value][#xPlayers[value] + 1] = (minimal and xPlayer.source or xPlayer)
        end
    end
end

---@param key? string
---@param val? string|table
---@param minimal? boolean
---@return xPlayer[]|number[]|table<any, xPlayer[]>|table<any, number[]>
function ESX.GetExtendedPlayers(key, val, minimal)
    if not key then
        if not minimal then
            return ESX.Table.ToArray(ESX.Players)
        end

        local xPlayers = {}
        local index = 1
        for src, _ in pairs(ESX.Players) do
            xPlayers[index] = src
            index += 1
        end

        return xPlayers
    end

    local xPlayers = {}
    if type(val) == "table" then
        for _, xPlayer in pairs(ESX.Players) do
            checkTable(key, val, xPlayer, xPlayers, minimal)
        end

        return xPlayers
    end

    for _, xPlayer in pairs(ESX.Players) do
        if (key == "job" and xPlayer.job.name == val) or xPlayer[key] == val then
            xPlayers[#xPlayers + 1] = (minimal and xPlayer.source or xPlayer)
        end
    end

    return xPlayers
end

---@param key? string
---@param val? string|table
---@return number | table
function ESX.GetNumPlayers(key, val)
    if not key then
        return #GetPlayers()
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

---@param source number
---@return xPlayer?
function ESX.GetPlayerFromId(source)
    return ESX.Players[tonumber(source)]
end

---@param identifier string
---@return xPlayer?
function ESX.GetPlayerFromIdentifier(identifier)
    return Core.playersByIdentifier[identifier]
end

---@param identifier string
---@return number playerId
function ESX.GetPlayerIdFromIdentifier(identifier)
    return Core.playersByIdentifier[identifier]?.source
end

---@param source number
---@return boolean
---@diagnostic disable-next-line: duplicate-set-field
function ESX.IsPlayerLoaded(source)
    return ESX.Players[source] ~= nil
end

---@param playerId number | string
---@return string?
function ESX.GetIdentifier(playerId)
    local fxDk = GetConvarInt("sv_fxdkMode", 0)
    if fxDk == 1 then
        return "steam:esx-debug"
    end

    playerId = tostring(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)

    for i = 1, #identifiers do
        local identifier = string.lower(identifiers[i])
        if identifier:sub(1, 6) == "steam:" then
            return identifier
        end
    end
end

---@param model string|number
---@param player number
---@param cb function?
---@return string?
---@diagnostic disable-next-line: duplicate-set-field
function ESX.GetVehicleType(model, player, cb)
    if cb and not ESX.IsFunctionReference(cb) then
        error("Invalid callback function")
    end

    local promise = not cb and promise.new()
    local function resolve(result)
        if promise then
            promise:resolve(result)
        elseif cb then
            cb(result)
        end

        return result
    end

    model = type(model) == "string" and joaat(model) or model

    if Core.vehicleTypesByModel[model] then
        return resolve(Core.vehicleTypesByModel[model])
    end

    ESX.TriggerClientCallback(player, "esx:GetVehicleType", function(vehicleType)
        Core.vehicleTypesByModel[model] = vehicleType
        resolve(vehicleType)
    end, model)

    if promise then
        return Citizen.Await(promise)
    end
end

---@param name string
---@param title string
---@param color string
---@param message string
---@return nil
function ESX.DiscordLog(name, title, color, message)
    local webHook = Config.DiscordLogs.Webhooks[name] or Config.DiscordLogs.Webhooks.default
    local embedData = {
        {
            ["title"] = title,
            ["color"] = Config.DiscordLogs.Colors[color] or Config.DiscordLogs.Colors.default,
            ["footer"] = {
                ["text"] = "| ESX Logs | " .. os.date(),
                ["icon_url"] =
                "https://cdn.discordapp.com/attachments/944789399852417096/1020099828266586193/blanc-800x800.png",
            },
            ["description"] = message,
            ["author"] = {
                ["name"] = "ESX Framework",
                ["icon_url"] = "https://cdn.discordapp.com/emojis/939245183621558362.webp?size=128&quality=lossless",
            },
        },
    }
    PerformHttpRequest(
        webHook,
        function()
            return
        end,
        "POST",
        json.encode({
            username = "Logs",
            embeds = embedData,
        }),
        {
            ["Content-Type"] = "application/json",
        }
    )
end

---@param name string
---@param title string
---@param color string
---@param fields table
---@return nil
function ESX.DiscordLogFields(name, title, color, fields)
    for i = 1, #fields do
        local field = fields[i]
        field.value = tostring(field.value)
    end

    local webHook = Config.DiscordLogs.Webhooks[name] or Config.DiscordLogs.Webhooks.default
    local embedData = {
        {
            ["title"] = title,
            ["color"] = Config.DiscordLogs.Colors[color] or Config.DiscordLogs.Colors.default,
            ["footer"] = {
                ["text"] = "| ESX Logs | " .. os.date(),
                ["icon_url"] =
                "https://cdn.discordapp.com/attachments/944789399852417096/1020099828266586193/blanc-800x800.png",
            },
            ["fields"] = fields,
            ["description"] = "",
            ["author"] = {
                ["name"] = "ESX Framework",
                ["icon_url"] = "https://cdn.discordapp.com/emojis/939245183621558362.webp?size=128&quality=lossless",
            },
        },
    }
    PerformHttpRequest(
        webHook,
        function()
            return
        end,
        "POST",
        json.encode({
            username = "Logs",
            embeds = embedData,
        }),
        {
            ["Content-Type"] = "application/json",
        }
    )
end

---@return nil
function ESX.RefreshJobs()
    Core.JobsLoaded = false

    local Jobs = {}
    local jobs = MySQL.query.await("SELECT * FROM jobs")

    for _, v in ipairs(jobs) do
        Jobs[v.name] = v
        Jobs[v.name].grades = {}
    end

    local jobGrades = MySQL.query.await("SELECT * FROM job_grades")

    for _, v in ipairs(jobGrades) do
        if Jobs[v.job_name] then
            Jobs[v.job_name].grades[tostring(v.grade)] = v
        else
            print(('[^3WARNING^7] Ignoring job grades for ^5"%s"^0 due to missing job'):format(v.job_name))
        end
    end

    for _, v in pairs(Jobs) do
        if ESX.Table.SizeOf(v.grades) == 0 then
            Jobs[v.name] = nil
            print(('[^3WARNING^7] Ignoring job ^5"%s"^0 due to no job grades found'):format(v.name))
        end
    end

    if not Jobs then
        -- Fallback data, if no jobs exist
        ESX.Jobs["unemployed"] = { name = "unemployed", label = "Unemployed", whitelisted = false, grades = { ["0"] = { grade = 0, name = "unemployed", label = "Unemployed", salary = 200, skin_male = {}, skin_female = {} } } }
    else
        ESX.Jobs = Jobs
    end

    TriggerEvent("esx:jobsRefreshed")
    Core.JobsLoaded = true
end

---@param item string
---@param cb function
---@return nil
function ESX.RegisterUsableItem(item, cb)
    Core.UsableItemsCallbacks[item] = cb
end

---@param source number
---@param item string
---@param ... any
---@return nil
function ESX.UseItem(source, item, ...)
    if ESX.Items[item] then
        local itemCallback = Core.UsableItemsCallbacks[item]

        if itemCallback then
            local success, result = pcall(itemCallback, source, item, ...)

            if not success then
                return result and print(result) or
                print(('[^3WARNING^7] An error occured when using item ^5"%s"^7! This was not caused by ESX.'):format(
                item))
            end
        end
    else
        print(('[^3WARNING^7] Item ^5"%s"^7 was used but does not exist!'):format(item))
    end
end

---@param index string
---@param overrides table
---@return nil
function ESX.RegisterPlayerFunctionOverrides(index, overrides)
    Core.PlayerFunctionOverrides[index] = overrides
end

---@param index string
---@return nil
function ESX.SetPlayerFunctionOverride(index)
    if not index or not Core.PlayerFunctionOverrides[index] then
        return print("[^3WARNING^7] No valid index provided.")
    end

    Config.PlayerFunctionOverride = index
end

---@param item string
---@return string?
---@diagnostic disable-next-line: duplicate-set-field
function ESX.GetItemLabel(item)
    if ESX.Items[item] then
        return ESX.Items[item].label
    else
        print(("[^3WARNING^7] Attemting to get invalid Item -> ^5%s^7"):format(item))
    end
end

---@return table
function ESX.GetJobs()
    while not Core.JobsLoaded do
        Citizen.Wait(200)
    end

    return ESX.Jobs
end

---@return table
function ESX.GetItems()
    return ESX.Items
end

---@return table
function ESX.GetUsableItems()
    local Usables = {}
    for k in pairs(Core.UsableItemsCallbacks) do
        Usables[k] = true
    end
    return Usables
end

if not Config.CustomInventory then
    ---@param itemType string
    ---@param name string
    ---@param count integer
    ---@param label string
    ---@param playerId number
    ---@param components? string | table
    ---@param tintIndex? integer
    ---@param coords? table | vector3
    ---@return nil
    function ESX.CreatePickup(itemType, name, count, label, playerId, components, tintIndex, coords)
        if not Config.EnablePickupSystem then
            return
        end
        local pickupId = (Core.PickupId == 65635 and 0 or Core.PickupId + 1)
        local xPlayer = ESX.Players[playerId]
        coords = ((type(coords) == "vector3" or type(coords) == "vector4") and coords.xyz or xPlayer.getCoords(true))

        Core.Pickups[pickupId] = { type = itemType, name = name, count = count, label = label, coords = coords }

        if itemType == "item_weapon" then
            Core.Pickups[pickupId].components = components
            Core.Pickups[pickupId].tintIndex = tintIndex
        end

        TriggerClientEvent("esx:createPickup", -1, pickupId, label, coords, itemType, name, components, tintIndex)
        Core.PickupId = pickupId
    end

    local function refreshPlayerInventories()
        local xPlayers = ESX.GetExtendedPlayers()
        for i = 1, #xPlayers do
            local xPlayer = xPlayers[i]
            local minimalInv = xPlayer.getInventory(true)

            for i = #minimalInv, 1, -1 do
                local snapshotItem = minimalInv[i]
                if snapshotItem and not ESX.Items[snapshotItem.name] then
                    xPlayer.setInventoryItem(snapshotItem.name, 0)
                    table.remove(minimalInv, i)
                end
            end

            for itemName, itemData in pairs(ESX.Items) do
                local inventoryItem = xPlayer.getInventoryItem(itemName)
                inventoryItem.label = itemData.label
                inventoryItem.weight = itemData.weight or 0
                inventoryItem.limit = itemData.limit or Config.DefaultItemLimit
                inventoryItem.usable = Core.UsableItemsCallbacks[itemName] ~= nil
                inventoryItem.rare = itemData.rare
                inventoryItem.canRemove = itemData.canRemove
            end

            xPlayer.markInventoryDirty()
            TriggerClientEvent("esx:setInventory", xPlayer.source, xPlayer.inventoryList)
        end
    end

    ---@return number newItemCount
    function ESX.RefreshItems()
        ESX.Items = {}

        local items = MySQL.query.await("SELECT * FROM items")
        local itemCount = #items
        for i = 1, itemCount do
            local item = items[i]
            ESX.Items[item.name] = {
                label = item.label,
                weight = item.weight,
                limit = item.limit or Config.DefaultItemLimit,
                rare = item.rare,
                canRemove = item.can_remove
            }
        end
        refreshPlayerInventories()

        return itemCount
    end

    ---@param items { name: string, label: string, weight?: number, rare?: boolean, canRemove?: boolean }[]
    function ESX.AddItems(items)
        local toInsert = {}
        local toInsertIndex = 1

        for i = 1, #items do
            local item = items[i]
            local name = item.name
            local label = item.label
            local weight = item.weight or 1
            local rare = item.rare or false
            local canRemove = item.canRemove ~= false

            if type(name) ~= "string" then
                print(("^1[AddItems]^0 Invalid item name: %s"):format(name))
                goto continue
            end

            if ESX.Items[name] then
                goto continue
            end

            if type(label) ~= "string" then
                print(("^1[AddItems]^0 Invalid label for item '%s'"):format(name))
                goto continue
            end

            if type(weight) ~= "number" then
                print(("^1[AddItems]^0 Invalid weight for item '%s'"):format(name))
                goto continue
            end

            if type(rare) ~= "boolean" then
                print(("^1[AddItems]^0 Invalid rare flag for item '%s'"):format(name))
                goto continue
            end

            if type(canRemove) ~= "boolean" then
                print(("^1[AddItems]^0 Invalid canRemove flag for item '%s'"):format(name))
                goto continue
            end

            toInsert[toInsertIndex] = {
                name = name,
                label = label,
                weight = weight,
                rare = rare,
                canRemove = canRemove,
            }
            toInsertIndex += 1

            ::continue::
        end

        if #toInsert > 0 then
            MySQL.prepare.await(
            "INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES (?, ?, ?, ?, ?)",
                toInsert)

            for i = 1, #toInsert do
                local row = toInsert[i]
                ESX.Items[row.name] = {
                    label = row.label,
                    weight = row.weight,
                    rare = row.rare,
                    canRemove = row.canRemove,
                }
            end

            refreshPlayerInventories()
        end
    end
end

-- Custom inventory: โหลตาราง items ให้ ESX.Items (label/weight) โดยไม่ดันซิงค์ไป client กระเป๋าเดิม
if Config.CustomInventory then
    function ESX.RefreshItems()
        ESX.Items = {}
        local items = MySQL.query.await("SELECT * FROM items") or {}
        for i = 1, #items do
            local item = items[i]
            ESX.Items[item.name] = {
                label = item.label,
                weight = item.weight,
                limit = item.limit or Config.DefaultItemLimit,
                rare = item.rare,
                canRemove = item.can_remove,
            }
        end
        return #items
    end

    function ESX.AddItems(items)
        local toInsert = {}
        local toInsertIndex = 1

        for i = 1, #items do
            local item = items[i]
            local name = item.name
            local label = item.label
            local weight = item.weight or 1
            local rare = item.rare or false
            local canRemove = item.canRemove ~= false

            if type(name) ~= "string" then
                print(("^1[AddItems]^0 Invalid item name: %s"):format(name))
                goto continue
            end

            if ESX.Items[name] then
                goto continue
            end

            if type(label) ~= "string" then
                print(("^1[AddItems]^0 Invalid label for item '%s'"):format(name))
                goto continue
            end

            if type(weight) ~= "number" then
                print(("^1[AddItems]^0 Invalid weight for item '%s'"):format(name))
                goto continue
            end

            if type(rare) ~= "boolean" then
                print(("^1[AddItems]^0 Invalid rare flag for item '%s'"):format(name))
                goto continue
            end

            if type(canRemove) ~= "boolean" then
                print(("^1[AddItems]^0 Invalid canRemove flag for item '%s'"):format(name))
                goto continue
            end

            toInsert[toInsertIndex] = {
                name = name,
                label = label,
                weight = weight,
                rare = rare,
                canRemove = canRemove,
            }
            toInsertIndex += 1

            ::continue::
        end

        if #toInsert > 0 then
            MySQL.prepare.await(
                "INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES (?, ?, ?, ?, ?)",
                toInsert
            )

            for i = 1, #toInsert do
                local row = toInsert[i]
                ESX.Items[row.name] = {
                    label = row.label,
                    weight = row.weight,
                    rare = row.rare,
                    canRemove = row.canRemove,
                }
            end
        end
    end
end

---@param job string
---@param grade string
---@return boolean
function ESX.DoesJobExist(job, grade)
    while not Core.JobsLoaded do
        Citizen.Wait(200)
    end

    return (ESX.Jobs[job] and ESX.Jobs[job].grades[tostring(grade)] ~= nil) or false
end

---@param playerSrc number
---@return boolean
function Core.IsPlayerAdmin(playerSrc)
    if type(playerSrc) ~= "number" then
        return false
    end

    if IsPlayerAceAllowed(playerSrc --[[@as string]], "command") or GetConvar("sv_lan", "") == "true" then
        return true
    end

    local xPlayer = ESX.GetPlayerFromId(playerSrc)
    return xPlayer and Config.AdminGroups[xPlayer.getGroup()] or false
end

---@param owner string
---@param plate string
---@param coords vector4
---@return CExtendedVehicle?
function ESX.CreateExtendedVehicle(owner, plate, coords)
    return Core.vehicleClass.new(owner, plate, coords)
end

---@param plate string
---@return CExtendedVehicle?
function ESX.GetExtendedVehicleFromPlate(plate)
    return Core.vehicleClass.getFromPlate(plate)
end
