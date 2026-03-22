RegisterNetEvent("esx:requestModel", function(model)
    ESX.Streaming.RequestModel(model)
end)

local function rebuildAccountsByName()
    local accounts = ESX.PlayerData.accounts
    local byName = {}
    if accounts then
        for i = 1, #accounts do
            if accounts[i] and accounts[i].name then
                byName[accounts[i].name] = i
            end
        end
    end
    ESX.PlayerData.accountsByName = byName
end

local function rebuildInventoryByName()
    local inventory = ESX.PlayerData.inventory
    local byName = {}
    if inventory then
        for i = 1, #inventory do
            local item = inventory[i]
            if item and item.name then
                byName[item.name] = item
            end
        end
    end
    ESX.PlayerData.inventoryByName = byName
end

RegisterNetEvent("esx:playerLoaded", function(xPlayer, isNew, skin)
    xPlayer.inventory = xPlayer.inventory or {}
    xPlayer.accounts = xPlayer.accounts or {}
    xPlayer.metadata = xPlayer.metadata or {}
    skin = skin or xPlayer.skin or {}
    ESX.PlayerData = xPlayer
    rebuildAccountsByName()
    rebuildInventoryByName()

    ESX.SpawnPlayer(skin, ESX.PlayerData.coords, function()
        TriggerEvent("esx:onPlayerSpawn")
        TriggerEvent("esx:restoreLoadout")
        TriggerServerEvent("esx:onPlayerSpawn")
        TriggerEvent("esx:loadingScreenOff")
        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
    end)

    while not DoesEntityExist(ESX.PlayerData.ped) do
        Wait(20)
    end

    ESX.PlayerLoaded = true

    local timer = GetGameTimer()
    while not HaveAllStreamingRequestsCompleted(ESX.PlayerData.ped) and (GetGameTimer() - timer) < 2000 do
        Wait(10)
    end

    ESX.ApplyPlayerClientSettings()

    ClearPedTasksImmediately(ESX.PlayerData.ped)

    Core.FreezePlayer(false)

    if IsScreenFadedOut() then
        DoScreenFadeIn(500)
    end

    if GlobalState.gameBuild and Config.EnablePlayerSyncLookAt then
        NetworkSetLocalPlayerSyncLookAt(true)
    end

    -- Statebag coords for 1000-player: clients push coords, no server position loop
    if Config.UseClientStatebagCoords then
        local lastCoords
        local pushInterval = Config.ClientStatebagCoordsInterval or 6000
        local minMove = Config.ClientStatebagCoordsMinMove or 3.0
        local function pushCoordsToStatebag()
            if not ESX.PlayerLoaded or not ESX.PlayerData.ped or not DoesEntityExist(ESX.PlayerData.ped) then
                return SetTimeout(pushInterval, pushCoordsToStatebag)
            end
            local coords = GetEntityCoords(ESX.PlayerData.ped)
            if not lastCoords or #(coords - lastCoords) > minMove then
                lastCoords = coords
                LocalPlayer.state:set("coords", { x = coords.x, y = coords.y, z = coords.z }, true)
            end
            SetTimeout(pushInterval, pushCoordsToStatebag)
        end
        SetTimeout(300, pushCoordsToStatebag)
    end
end)

local isFirstSpawn = true
ESX.SecureNetEvent("esx:onPlayerLogout", function()
    ESX.PlayerLoaded = false
    isFirstSpawn = true
end)

ESX.SecureNetEvent("esx:setMaxWeight", function(newMaxWeight)
    ESX.SetPlayerData("maxWeight", newMaxWeight)
end)

ESX.SecureNetEvent("esx:setInventory", function(newInventory)
    ESX.SetPlayerData("inventory", newInventory)
    rebuildInventoryByName()
end)

ESX.SecureNetEvent("esx:updateInventory", function(updates)
    local inventory = ESX.PlayerData.inventory
    local inventoryByName = ESX.PlayerData.inventoryByName
    if not inventory then return end

    if not inventoryByName then
        inventoryByName = {}
        for i = 1, #inventory do
            local item = inventory[i]
            if item and item.name then
                inventoryByName[item.name] = item
            end
        end
        ESX.PlayerData.inventoryByName = inventoryByName
    end

    for i = 1, #updates do
        local update = updates[i]
        local item = inventoryByName and inventoryByName[update.name]
        if item then
            item.count = update.count
        else
            inventory[#inventory + 1] = update
            inventoryByName[update.name] = inventory[#inventory]
        end
    end
    ESX.SetPlayerData("inventory", inventory)
end)

local function onPlayerSpawn()
    ESX.SetPlayerData("ped", PlayerPedId())
    ESX.SetPlayerData("dead", false)
end

AddEventHandler("playerSpawned", onPlayerSpawn)
AddEventHandler("esx:onPlayerSpawn", function()
    onPlayerSpawn()

    if isFirstSpawn then
        isFirstSpawn = false

        local metadata = ESX.PlayerData.metadata
        if metadata and metadata.health and (metadata.health > 0 or Config.SaveDeathStatus) then
            SetEntityHealth(ESX.PlayerData.ped, metadata.health)
        end

        if metadata and metadata.armor and metadata.armor > 0 then
            SetPedArmour(ESX.PlayerData.ped, metadata.armor)
        end
    end
end)

AddEventHandler("esx:onPlayerDeath", function()
    ESX.SetPlayerData("ped", PlayerPedId())
    ESX.SetPlayerData("dead", true)
end)

local isResyncingPlayerCache = false

local function resyncPlayerCacheFromServer(cb)
    if isResyncingPlayerCache then
        return cb and cb()
    end

    isResyncingPlayerCache = true
    ESX.TriggerServerCallback("esx:getPlayerData", function(payload)
        isResyncingPlayerCache = false

        if not payload then
            return cb and cb()
        end

        ESX.SetPlayerData("identifier", payload.identifier)
        ESX.SetPlayerData("job", payload.job)
        ESX.SetPlayerData("money", payload.money)
        ESX.SetPlayerData("metadata", payload.metadata)

        if payload.accounts then
            ESX.SetPlayerData("accounts", payload.accounts)
        end

        if payload.inventory then
            ESX.SetPlayerData("inventory", payload.inventory)
        end

        if payload.loadout then
            ESX.SetPlayerData("loadout", payload.loadout)
        end

        if payload.position then
            ESX.SetPlayerData("coords", payload.position)
        end

        if cb then
            cb()
        end
    end, true)
end

AddEventHandler("skinchanger:modelLoaded", function()
    local function tryResync()
        if not ESX.PlayerLoaded then
            return SetTimeout(100, tryResync)
        end
        resyncPlayerCacheFromServer(function()
            TriggerEvent("esx:restoreLoadout")
        end)
    end
    tryResync()
end)

local function restorePedLoadoutFromPlayerData()
    local ped = PlayerPedId()
    local loadout = ESX.PlayerData.loadout or {}

    RemoveAllPedWeapons(ped, true)

    for i = 1, #loadout do
        local weapon = loadout[i]
        if weapon and weapon.name then
            local weaponHash = joaat(weapon.name)
            local ammo = tonumber(weapon.ammo) or 0

            GiveWeaponToPed(ped, weaponHash, ammo, false, false)

            local components = weapon.components or {}
            for componentIndex = 1, #components do
                local componentName = components[componentIndex]
                if componentName and componentName ~= "clip_default" then
                    GiveWeaponComponentToPed(ped, weaponHash, joaat(componentName))
                end
            end

            if weapon.tintIndex and weapon.tintIndex > 0 then
                SetPedWeaponTintIndex(ped, weaponHash, weapon.tintIndex)
            end

            SetPedAmmo(ped, weaponHash, ammo)
        end
    end

    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
end

AddEventHandler("esx:restoreLoadout", function()
    ESX.SetPlayerData("ped", PlayerPedId())

    if Config.CustomInventory and not Config.RestoreLoadoutWithCustomInventory then
        return
    end

    restorePedLoadoutFromPlayerData()
end)

---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler("VehicleProperties", nil, function(bagName, _, value)
    if not value then return end
    bagName = bagName:gsub("entity:", "")
    local netId = tonumber(bagName)
    if not netId then
        error("Tried to set vehicle properties with invalid netId")
        return
    end

    local function tryApply(tries)
        if NetworkDoesEntityExistWithNetworkId(netId) then
            local vehicle = NetToVeh(netId)
            if NetworkGetEntityOwner(vehicle) == ESX.playerId then
                ESX.Game.SetVehicleProperties(vehicle, value)
            end
            return
        end
        if tries > 20 then
            return error(("Invalid entity - ^5%s^7!"):format(netId))
        end
        SetTimeout(100, function() tryApply(tries + 1) end)
    end
    tryApply(0)
end)

ESX.SecureNetEvent("esx:setAccountMoney", function(account)
    local accounts = ESX.PlayerData.accounts
    local idx = ESX.PlayerData.accountsByName and ESX.PlayerData.accountsByName[account.name]
    if idx then
        accounts[idx] = account
    else
        accounts[#accounts + 1] = account
        if not ESX.PlayerData.accountsByName then
            ESX.PlayerData.accountsByName = {}
        end
        ESX.PlayerData.accountsByName[account.name] = #accounts
    end
    ESX.SetPlayerData("accounts", accounts)
end)

ESX.SecureNetEvent("esx:updateAccounts", function(updates)
    local accounts = ESX.PlayerData.accounts
    local accountsByName = ESX.PlayerData.accountsByName
    if not accounts then return end

    if not accountsByName then
        accountsByName = {}
        for i = 1, #accounts do
            if accounts[i] and accounts[i].name then
                accountsByName[accounts[i].name] = i
            end
        end
        ESX.PlayerData.accountsByName = accountsByName
    end

    for i = 1, #updates do
        local update = updates[i]
        local idx = accountsByName and accountsByName[update.name]
        if idx then
            accounts[idx] = update
        else
            accounts[#accounts + 1] = update
            accountsByName[update.name] = #accounts
        end
    end
    ESX.SetPlayerData("accounts", accounts)
end)

ESX.SecureNetEvent("esx:setJob", function(Job)
    ESX.SetPlayerData("job", Job)
end)

ESX.SecureNetEvent("esx:setGroup", function(group)
    ESX.SetPlayerData("group", group)
end)

ESX.SecureNetEvent("esx:registerSuggestions", function()
    local suggestions = GlobalState.suggestions
    if not suggestions then return end

    for name, suggestion in pairs(suggestions) do
        TriggerEvent("chat:addSuggestion", ("/%s"):format(name), suggestion.help, suggestion.arguments)
    end
end)

ESX.RegisterClientCallback("esx:GetVehicleType", function(cb, model)
    cb(ESX.GetVehicleTypeClient(model))
end)

ESX.SecureNetEvent('esx:updatePlayerData', function(key, val)
    if key == "variables" and type(val) == "table" then
        local variables = ESX.PlayerData.variables
        if type(variables) ~= "table" then
            variables = {}
        end

        if type(val.__remove) == "table" then
            for i = 1, #val.__remove do
                variables[val.__remove[i]] = nil
            end
        else
            for k, v in pairs(val) do
                variables[k] = v
            end
        end

        ESX.SetPlayerData("variables", variables)
        return
    end

    ESX.SetPlayerData(key, val)
end)

---@param command string
ESX.SecureNetEvent("esx:executeCommand", function(command)
    ExecuteCommand(command)
end)

AddEventHandler("onResourceStop", function(resource)
    if Core.Events[resource] then
        for i = 1, #Core.Events[resource] do
            RemoveEventHandler(Core.Events[resource][i])
        end
    end
end)
