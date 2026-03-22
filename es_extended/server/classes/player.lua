---@class ESXAccount
---@field name string               # Account name (e.g., "bank", "money").
---@field money number              # Current balance in this account.
---@field label string              # Human-readable label for the account.
---@field round boolean             # Whether amounts are rounded for display.
---@field index number              # Index of the account in the player's accounts list.

---@class ESXItem
---@field name string               # Item identifier (internal name).
---@field label string              # Display name of the item.
---@field weight number             # Weight of a single unit of the item.
---@field usable boolean            # Whether the item can be used.
---@field rare boolean              # Whether the item is rare.
---@field canRemove boolean         # Whether the item can be removed from inventory.

---@class ESXInventoryItem:ESXItem
---@field count number              # Number of this item in the player's inventory.

---@class ESXJob
---@field id number                 # Job ID.
---@field name string               # Job internal name.
---@field label string              # Job display label.
---@field grade number              # Current grade/rank number.
---@field grade_name string         # Name of the current grade.
---@field grade_label string        # Label of the current grade.
---@field grade_salary number       # Salary for the current grade.
---@field skin_male table           # Skin configuration for male characters.
---@field skin_female table         # Skin configuration for female characters.
---@field onDuty boolean?           # Whether the player is currently on duty.

---@class ESXWeapon
---@field name string               # Weapon identifier (internal name).
---@field label string              # Weapon display name.

---@class ESXInventoryWeapon:ESXWeapon
---@field ammo number               # Amount of ammo in the weapon.
---@field components string[]       # List of components attached to the weapon.
---@field tintIndex number          # Current weapon tint index.

---@class ESXWeaponComponent
---@field name string               # Component identifier (internal name).
---@field label string              # Component display name.
---@field hash string|number        # Component hash or identifier.

---@class StaticPlayer
---@field src number                                              # Player's server ID.
--- Money Functions
---@field setMoney fun(money: number)                             # Set player's cash balance.
---@field getMoney fun(): number                                   # Get player's current cash balance.
---@field addMoney fun(money: number, reason: string)             # Add money to the player's cash balance.
---@field removeMoney fun(money: number, reason: string)          # Remove money from the player's cash balance.
---@field setAccountMoney fun(accountName: string, money: number, reason?: string)  # Set specific account balance.
---@field addAccountMoney fun(accountName: string, money: number, reason?: string)  # Add money to an account.
---@field removeAccountMoney fun(accountName: string, money: number, reason?: string) # Remove money from an account.
---@field getAccount fun(account: string): ESXAccount             # Get account data by name.
---@field getAccountMoney fun(accountName: string): number        # Get account balance by name.
---@field getAccounts fun(minimal?: boolean): ESXAccount[]|table<string,number>  # Get all accounts, optionally minimal.
--- Inventory Functions
---@field getInventory fun(minimal?: boolean): table<string, ESXInventoryItem>|{name:string, count:number}[]  # Get inventory, optionally minimal.
---@field getInventoryItem fun(itemName: string): ESXInventoryItem? # Get a specific item from inventory.
---@field addInventoryItem fun(itemName: string, count: number)     # Add items to inventory.
---@field removeInventoryItem fun(itemName: string, count: number)  # Remove items from inventory.
---@field setInventoryItem fun(itemName: string, count: number)     # Set item count in inventory.
---@field clearInventory fun()                                         # Clear all inventory item counts.
---@field getWeight fun(): number                                   # Get current carried weight.
---@field getMaxWeight fun(): number                                # Get maximum carry weight.
---@field setMaxWeight fun(newWeight: number)                       # Set maximum carry weight.
---@field canCarryItem fun(itemName: string, count: number): boolean # Check if player can carry more of an item.
---@field canSwapItem fun(firstItem: string, firstItemCount: number, testItem: string, testItemCount: number): boolean # Check if items can be swapped.
---@field hasItem fun(item: string): ESXInventoryItem|false, number? # Check if player has an item.
---@field getLoadout fun(minimal?: boolean): ESXInventoryWeapon[]|table<string, {ammo:number, tintIndex?:number, components?:string[]}> # Get player's weapon loadout.
--- Job Functions
---@field getJob fun(): ESXJob                                         # Get player's current job.
---@field setJob fun(newJob: string, grade: string, onDuty?: boolean)  # Set player's job and grade.
---@field setGroup fun(newGroup: string)                               # Set player's permission group.
---@field getGroup fun(): string                                       # Get player's permission group.
--- Weapon Functions
---@field addWeapon fun(weaponName: string, ammo: number)                 # Give player a weapon.
---@field removeWeapon fun(weaponName: string)                             # Remove weapon from player.
---@field hasWeapon fun(weaponName: string): boolean                       # Check if player has a weapon.
---@field getWeapon fun(weaponName: string): number?, table?               # Get weapon ammo & components.
---@field addWeaponAmmo fun(weaponName: string, ammoCount: number)        # Add ammo to a weapon.
---@field removeWeaponAmmo fun(weaponName: string, ammoCount: number)     # Remove ammo from a weapon.
---@field updateWeaponAmmo fun(weaponName: string, ammoCount: number)     # Update ammo count for a weapon.
---@field addWeaponComponent fun(weaponName: string, weaponComponent: string)    # Add component to weapon.
---@field removeWeaponComponent fun(weaponName: string, weaponComponent: string) # Remove component from weapon.
---@field hasWeaponComponent fun(weaponName: string, weaponComponent: string): boolean # Check if weapon has component.
---@field setWeaponTint fun(weaponName: string, weaponTintIndex: number) # Set weapon tint.
---@field getWeaponTint fun(weaponName: string): number                  # Get weapon tint.
--- Player State Functions
---@field getIdentifier fun(): string                              # Get player's unique identifier.
---@field getSource fun(): number                                  # Get player source/server ID.
---@field getPlayerId fun(): number                                # Alias for getSource.
---@field getName fun(): string                                     # Get player's name.
---@field setName fun(newName: string)                              # Set player's name.
---@field setCoords fun(coordinates: vector4|vector3|table)        # Teleport player to coordinates.
---@field getCoords fun(vector?: boolean, heading?: boolean): vector3|vector4|table # Get player's coordinates.
---@field isAdmin fun(): boolean                                    # Check if player is admin.
---@field kick fun(reason: string)                                  # Kick player from server.
---@field getPlayTime fun(): number                                  # Get total playtime in seconds.
---@field set fun(k: string, v: any)                                # Set custom variable.
---@field get fun(k: string): any                                    # Get custom variable.
--- Metadata Functions
---@field getMeta fun(index?: string, subIndex?: string|table): any   # Get metadata value(s).
---@field setMeta fun(index: string, value: any, subValue?: any)      # Set metadata value(s).
---@field clearMeta fun(index: string, subValues?: string|table)      # Clear metadata value(s).
--- Notification Functions
---@field showNotification fun(msg: string, notifyType?: string, length?: number, title?: string, position?: string) # Show a simple notification.
---@field showAdvancedNotification fun(sender: string, subject: string, msg: string, textureDict: string, iconType: string, flash: boolean, saveToBrief: boolean, hudColorIndex: number) # Show advanced notification.
---@field showHelpNotification fun(msg: string, thisFrame?: boolean, beep?: boolean, duration?: number) # Show help notification.
--- Misc Functions
---@field togglePaycheck fun(toggle: boolean)     # Enable/disable paycheck.
---@field isPaycheckEnabled fun(): boolean       # Check if paycheck is enabled.
---@field executeCommand fun(command: string)    # Execute a server command.
---@field triggerEvent fun(eventName: string, ...) # Trigger client event for this player.


---@class xPlayer:StaticPlayer
--- Properties
---@field accounts table<string, ESXAccount> # Hashmap of the player's accounts.
---@field coords table              # Player's coordinates {x, y, z, heading}.
---@field group string              # Player permission group.
---@field identifier string         # Unique identifier (Steam Hex).
---@field inventory table<string, ESXInventoryItem> # Player's inventory items keyed by item name.
---@field job ESXJob                # Player's current job.
---@field loadout table<string, ESXInventoryWeapon> # Player's current weapons keyed by weapon name.
---@field name string               # Player's display name.
---@field playerId number           # Player's ID (server ID).
---@field source number             # Player's source (alias for playerId).
---@field variables table           # Custom player variables.
---@field weight number             # Current carried weight.
---@field maxWeight number          # Maximum carry weight.
---@field metadata table            # Custom metadata table.
---@field lastPlaytime number       # Last recorded playtime in seconds.
---@field paycheckEnabled boolean   # Whether paycheck is enabled.
---@field admin boolean             # Whether the player is an admin.

---@param playerId number
---@param identifier string
---@param group string
---@param accounts table<string, number|ESXAccount>|ESXAccount[]
---@param inventory table
---@param weight number
---@param job ESXJob
---@param loadout ESXInventoryWeapon[]
---@param name string
---@param coords vector4|{x: number, y: number, z: number, heading: number}
---@param metadata table
---@return xPlayer
local stringLower = string.lower
local getItemLimit

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

local function normalizeAccountName(accountName)
    if type(accountName) ~= "string" then
        return nil
    end

    return stringLower(accountName)
end

local function createAccountEntry(accountName, money, config, index)
    return {
        name = accountName,
        money = money or 0,
        label = config and config.label or accountName,
        round = config and (config.round ~= false) or true,
        index = index,
    }
end

local function normalizeAccountsTable(rawAccounts)
    local accounts = {}

    if type(rawAccounts) ~= "table" then
        return accounts
    end

    if #rawAccounts > 0 then
        for i = 1, #rawAccounts do
            local entry = rawAccounts[i]
            if entry and entry.name then
                accounts[normalizeAccountName(entry.name)] = entry.money or 0
            end
        end

        return accounts
    end

    for accountName, value in pairs(rawAccounts) do
        local normalizedName = normalizeAccountName(accountName)
        if normalizedName then
            if type(value) == "table" then
                accounts[normalizedName] = value.money or value.amount or 0
            else
                accounts[normalizedName] = value or 0
            end
        end
    end

    return accounts
end

function getItemLimit(itemName)
    local item = ESX.Items[itemName]
    if not item then
        return Config.DefaultItemLimit
    end

    return item.limit or Config.DefaultItemLimit
end

local function normalizeInventoryEntry(name, count, metadata)
    local itemData = ESX.Items[name]
    local usable = Core.UsableItemsCallbacks[name] ~= nil

    return {
        name = name,
        count = count or 0,
        label = itemData and itemData.label or name,
        limit = itemData and (itemData.limit or Config.DefaultItemLimit) or 0,
        metadata = metadata or {},
        weight = itemData and itemData.weight or 0,
        usable = usable,
        rare = itemData and itemData.rare or false,
        canRemove = itemData and itemData.canRemove ~= false or false,
    }
end

local function normalizeInventoryTable(rawInventory)
    local counts, metadata = {}, {}

    if type(rawInventory) ~= "table" then
        return counts, metadata
    end

    if #rawInventory > 0 then
        for i = 1, #rawInventory do
            local entry = rawInventory[i]
            if entry and entry.name then
                counts[entry.name] = entry.count or 0
                metadata[entry.name] = entry.metadata or {}
            end
        end

        return counts, metadata
    end

    for itemName, value in pairs(rawInventory) do
        if type(value) == "table" then
            counts[itemName] = value.count or value.amount or 0
            metadata[itemName] = value.metadata or {}
        else
            counts[itemName] = value or 0
        end
    end

    return counts, metadata
end

function CreateExtendedPlayer(playerId, identifier, group, accounts, inventory, weight, job, loadout, name, coords, metadata)
    ---@diagnostic disable-next-line: missing-fields
    local self = {} ---@type xPlayer

    self.accounts = {}
    self.accountsByName = self.accounts
    self.accountList = {}
    self.accountArrayDirty = true
    self.coords = coords
    self.group = group
    self.identifier = identifier
    self.inventory = {}
    self.inventoryList = {}
    self.inventoryArrayDirty = false
    self.inventoryMinimal = {}
    self.inventoryMinimalDirty = true
    self.job = job
    self.loadout = {}
    self.loadoutList = {}
    self.name = name
    self.playerId = playerId
    self.source = playerId
    self.variables = {}
    self.weight = weight
    self.maxWeight = Config.MaxWeight
    self.metadata = metadata
    self.state = {
        money = self.accounts,
        inventory = {},
        job = job,
        metadata = metadata,
    }
    self.lastPlaytime = self.metadata.lastPlaytime or 0
    self.paycheckEnabled = true
    self.admin = Core.IsPlayerAdmin(playerId)
    if type(self.metadata.jobDuty) ~= "boolean" then
        self.metadata.jobDuty = self.job.name ~= "unemployed" and Config.DefaultJobDuty or false
    end
    job.onDuty = self.metadata.jobDuty

    Core.Services.Permission.attachPlayerGroup(self.identifier, self.group)

    local normalizedAccounts = normalizeAccountsTable(accounts)
    local accountIndex = 0

    for accountName, data in pairs(Config.Accounts) do
        accountIndex += 1
        self.accounts[accountName] = createAccountEntry(
            accountName,
            normalizedAccounts[accountName] or Config.StartingAccountMoney[accountName] or 0,
            data,
            accountIndex
        )
    end

    for accountName, money in pairs(normalizedAccounts) do
        if accountName and not self.accounts[accountName] then
            accountIndex += 1
            self.accounts[accountName] = createAccountEntry(accountName, money, Config.Accounts[accountName], accountIndex)
        end
    end

    local inventoryCounts, inventoryMetadata = normalizeInventoryTable(inventory)
    for itemName, itemData in pairs(ESX.Items) do
        local normalizedItem = normalizeInventoryEntry(itemName, inventoryCounts[itemName] or 0, inventoryMetadata[itemName])
        self.inventory[itemName] = normalizedItem
        self.inventoryList[#self.inventoryList + 1] = normalizedItem
        self.state.inventory[itemName] = normalizedItem.count
    end

    local stateBag = Player(self.source).state

    for i = 1, #(loadout or {}) do
        local weapon = loadout[i]
        if weapon and weapon.name then
            self.loadout[weapon.name] = weapon
            self.loadoutList[#self.loadoutList + 1] = weapon
            stateBag:set(("ammo:%s"):format(weapon.name), weapon.ammo or 0, true)
        end
    end

    table.sort(self.inventoryList, function(a, b)
        return a.label < b.label
    end)

    stateBag:set("identifier", self.identifier, false)
    stateBag:set("job", self.job, true)
    stateBag:set("group", self.group, true)
    stateBag:set("name", self.name, true)

    Core.BindPlayerCache(self)

    local metadataSyncScheduled = false
    local function scheduleMetadataSync()
        if metadataSyncScheduled then
            return
        end

        metadataSyncScheduled = true
        SetTimeout(250, function()
            metadataSyncScheduled = false
            self.triggerEvent("esx:updatePlayerData", "metadata", self.metadata)
        end)
    end

    Core.Services.Inventory.attach(self)

    function self.markInventoryDirty()
        self.inventoryMinimalDirty = true
    end

    function self.updateMinimalInventoryCache(name, count)
        if self.inventoryMinimalDirty then
            return false
        end

        if type(name) ~= "string" or type(count) ~= "number" then
            self.markInventoryDirty()
            return false
        end

        local item = self.inventory[name]
        if not item then
            self.markInventoryDirty()
            return false
        end

        local snapshot = self.inventoryMinimal
        local foundIndex

        for i = 1, #snapshot do
            local snapshotItem = snapshot[i]
            if not snapshotItem or snapshotItem.name == nil or type(snapshotItem.count) ~= "number" then
                self.markInventoryDirty()
                return false
            end

            if snapshotItem.name == name then
                if foundIndex then
                    self.markInventoryDirty()
                    return false
                end

                foundIndex = i
            end
        end

        if foundIndex then
            if count <= 0 then
                table.remove(snapshot, foundIndex)
            else
                snapshot[foundIndex].count = count
            end
            return true
        end

        if count > 0 then
            snapshot[#snapshot + 1] = {
                name = name,
                count = count,
            }
        end

        return true
    end

    function self.triggerEvent(eventName, ...)
        assert(type(eventName) == "string", "eventName should be string!")
        TriggerClientEvent(eventName, self.source, ...)
    end

    function self.togglePaycheck(toggle)
        self.paycheckEnabled = toggle
    end

    function self.isPaycheckEnabled()
        return self.paycheckEnabled
    end

    function self.isAdmin()
        return Core.IsPlayerAdmin(self.source)
    end

    function self.setCoords(coordinates)
        local ped <const> = GetPlayerPed(self.source)

        SetEntityCoords(ped, coordinates.x, coordinates.y, coordinates.z, false, false, false, false)
        SetEntityHeading(ped, coordinates.w or coordinates.heading or 0.0)
        Core.MarkPlayerDirty(self, "position")
    end

    function self.getCoords(vector, heading)
        local ped <const> = GetPlayerPed(self.source)
        local entityCoords <const> = GetEntityCoords(ped)
        local entityHeading <const> = GetEntityHeading(ped)

        local coordinates = { x = entityCoords.x, y = entityCoords.y, z = entityCoords.z }

        if vector then
            coordinates = (heading and vector4(entityCoords.x, entityCoords.y, entityCoords.z, entityHeading) or entityCoords)
        else
            if heading then
                coordinates.heading = entityHeading
            end
        end

        return coordinates
    end

    function self.kick(reason)
        DropPlayer(self.source --[[@as string]], reason)
    end

    function self.getPlayTime()
        -- luacheck: ignore
        return self.lastPlaytime + GetPlayerTimeOnline(self.source --[[@as string]])
    end

    function self.setMoney(money)
        assert(type(money) == "number", "money should be number!")
        money = ESX.Math.Round(money)
        self.setAccountMoney("money", money)
    end

    function self.getMoney()
        return self.getAccountMoney("money")
    end

    function self.addMoney(money, reason)
        money = ESX.Math.Round(money)
        self.addAccountMoney("money", money, reason)
    end

    function self.removeMoney(money, reason)
        money = ESX.Math.Round(money)
        self.removeAccountMoney("money", money, reason)
    end

    function self.getIdentifier()
        return self.identifier
    end

    function self.setGroup(newGroup)
        local lastGroup = self.group

        self.group = newGroup
        Core.MarkPlayerDirty(self, "group")

        TriggerEvent("esx:setGroup", self.source, self.group, lastGroup)
        self.triggerEvent("esx:setGroup", self.group, lastGroup)
        Player(self.source).state:set("group", self.group, true)

        Core.Services.Permission.changePlayerGroup(self.identifier, lastGroup, self.group)
    end

    function self.getGroup()
        return self.group
    end

    function self.set(k, v)
        local current = self.variables[k]
        if current == v then
            return
        end

        self.variables[k] = v

        if v == nil then
            self.triggerEvent("esx:updatePlayerData", "variables", { __remove = { k } })
            return
        end

        self.triggerEvent("esx:updatePlayerData", "variables", { [k] = v })
    end

    function self.get(k)
        return self.variables[k]
    end

    function self.getAccounts(minimal)
        if minimal then
            local minimalAccounts = {}

            for accountName, account in pairs(self.accounts) do
                minimalAccounts[accountName] = account.money
            end

            return minimalAccounts
        end

        if not self.accountArrayDirty then
            return self.accountList
        end

        local accountList = {}
        local nextIndex = 0

        for accountName in pairs(Config.Accounts) do
            local account = self.accounts[accountName]
            if account then
                nextIndex += 1
                account.index = nextIndex
                accountList[nextIndex] = account
            end
        end

        for accountName, account in pairs(self.accounts) do
            if not Config.Accounts[accountName] then
                nextIndex += 1
                account.index = nextIndex
                accountList[nextIndex] = account
            end
        end

        self.accountList = accountList
        self.accountArrayDirty = false

        return self.accountList
    end

    function self.getAccount(account)
        local accountName = normalizeAccountName(account)
        local cachedAccount = accountName and self.accounts[accountName]
        if cachedAccount then
            return cachedAccount
        end

        return {
            name = accountName or account,
            money = 0,
            label = "Unknown",
            round = true,
        }
    end

    function self.getAccountMoney(accountName)
        local normalizedName = normalizeAccountName(accountName)
        local account = normalizedName and self.accounts[normalizedName]
        return account and account.money or 0
    end

    function self.getInventory(minimal)
        if not minimal then
            return self.inventory
        end

        if not self.inventoryMinimalDirty then
            return self.inventoryMinimal
        end

        local snapshot = {}
        local invalidState = false

        for name, item in pairs(self.inventory) do
            if item and item.name == name and type(item.count) == "number" then
                if item.count > 0 then
                    snapshot[#snapshot + 1] = {
                        name = item.name,
                        count = item.count,
                    }
                end
            elseif item ~= nil then
                invalidState = true
            end
        end

        self.inventoryMinimal = snapshot
        self.inventoryMinimalDirty = invalidState

        return snapshot
    end

    function self.getJob()
        return self.job
    end

    function self.getLoadout(minimal)
        if not minimal then
            return self.loadoutList
        end
        local minimalLoadout = {}

        for weaponName, v in pairs(self.loadout) do
            minimalLoadout[weaponName] = { ammo = v.ammo }
            if v.tintIndex > 0 then
                minimalLoadout[weaponName].tintIndex = v.tintIndex
            end

            if #v.components > 0 then
                local components = {}

                for _, component in ipairs(v.components) do
                    if component ~= "clip_default" then
                        components[#components + 1] = component
                    end
                end

                if #components > 0 then
                    minimalLoadout[weaponName].components = components
                end
            end
        end

        return minimalLoadout
    end

    function self.getName()
        return self.name
    end

    function self.setName(newName)
        self.name = newName
        Core.MarkPlayerDirty(self, "name")
        Player(self.source).state:set("name", self.name, true)
    end

    function self.setAccountMoney(accountName, money, reason)
        reason = reason or "unknown"
        if type(money) ~= "number" then
            error(("Tried To Set Account ^5%s^1 For Player ^5%s^1 To An Invalid Number -> ^5%s^1"):format(accountName, self.playerId, money))
            return
        end
        if money < 0 then
            error(("Tried To Set Account ^5%s^1 For Player ^5%s^1 To An Invalid Number -> ^5%s^1"):format(accountName, self.playerId, money))
            return false
        end

        local normalizedName = normalizeAccountName(accountName)
        if not normalizedName then
            return false
        end

        local account = self.accounts[normalizedName]
        if not account then
            self.accountArrayDirty = true
            account = createAccountEntry(normalizedName, 0, Config.Accounts[normalizedName], #self.accountList + 1)
            self.accounts[normalizedName] = account
        end

        local previousMoney = account.money or 0
        money = account.round and ESX.Math.Round(money) or money
        account.money = money
        if normalizedName == "money" then
            self.cache.money = money
        end
        Core.MarkPlayerDirty(self, "accounts")
        Core.DebugCounter("account_mutations")

        Core.QueueAccountSync(self, account)
        TriggerEvent("esx:setAccountMoney", self.source, normalizedName, money, reason)
        if math.abs(money - previousMoney) >= (Config.CriticalMoneySaveThreshold or 50000) then
            Core.RequestImmediateSave(self, "critical_account_set")
        end
        return true
    end

    function self.addAccountMoney(accountName, money, reason)
        reason = reason or "Unknown"
        if type(money) ~= "number" then
            error(("Tried To Set Account ^5%s^1 For Player ^5%s^1 To An Invalid Number -> ^5%s^1"):format(accountName, self.playerId, money))
            return
        end
        if money <= 0 then
            error(("Tried To Set Account ^5%s^1 For Player ^5%s^1 To An Invalid Number -> ^5%s^1"):format(accountName, self.playerId, money))
            return false
        end

        local normalizedName = normalizeAccountName(accountName)
        local account = normalizedName and self.accounts[normalizedName]
        if not account then
            return false
        end

        money = account.round and ESX.Math.Round(money) or money
        account.money = account.money + money
        if normalizedName == "money" then
            self.cache.money = account.money
        end
        Core.MarkPlayerDirty(self, "accounts")
        Core.DebugCounter("account_mutations")

        Core.QueueAccountSync(self, account)
        TriggerEvent("esx:addAccountMoney", self.source, normalizedName, money, reason)
        if money >= (Config.CriticalMoneySaveThreshold or 50000) then
            Core.RequestImmediateSave(self, "critical_account_add")
        end
        return true
    end

    function self.removeAccountMoney(accountName, money, reason)
        reason = reason or "Unknown"
        if type(money) ~= "number" then
            error(("Tried To Set Account ^5%s^1 For Player ^5%s^1 To An Invalid Number -> ^5%s^1"):format(accountName, self.playerId, money))
            return
        end
        if money <= 0 then
            error(("Tried To Set Account ^5%s^1 For Player ^5%s^1 To An Invalid Number -> ^5%s^1"):format(accountName, self.playerId, money))
            return false
        end

        local normalizedName = normalizeAccountName(accountName)
        local account = normalizedName and self.accounts[normalizedName]
        if not account then
            return false
        end

        money = account.round and ESX.Math.Round(money) or money
        account.money = account.money - money
        if account.money < 0 then
            account.money = 0
        end
        if normalizedName == "money" then
            self.cache.money = account.money
        end
        Core.MarkPlayerDirty(self, "accounts")
        Core.DebugCounter("account_mutations")

        Core.QueueAccountSync(self, account)
        TriggerEvent("esx:removeAccountMoney", self.source, normalizedName, money, reason)
        if money >= (Config.CriticalMoneySaveThreshold or 50000) then
            Core.RequestImmediateSave(self, "critical_account_remove")
        end
        return true
    end

    function self.getInventoryItem(itemName)
        local inventoryItem = self.inventory[itemName]
        if inventoryItem then
            inventoryItem.count = self.state.inventory[itemName] or inventoryItem.count or 0
            return inventoryItem
        end

        if not ESX.Items[itemName] then
            return normalizeInventoryEntry(itemName, 0, {})
        end

        inventoryItem = normalizeInventoryEntry(itemName, 0, {})
        self.inventory[itemName] = inventoryItem
        self.inventoryList[#self.inventoryList + 1] = inventoryItem
        self.inventoryArrayDirty = true
        self.markInventoryDirty()
        self.state.inventory[itemName] = 0

        return inventoryItem
    end

    function self.clearInventory()
        local inventoryState = self.state.inventory

        for itemName, item in pairs(self.inventory) do
            inventoryState[itemName] = 0
            item.count = 0
        end

        self.weight = 0
        self.inventoryMinimal = {}
        self.inventoryMinimalDirty = false
        Core.MarkPlayerDirty(self, "inventory")
        Core.DebugCounter("inventory_mutations")
    end

    function self.getWeight()
        return self.weight
    end

    function self.getSource()
        return self.source
    end
    self.getPlayerId = self.getSource

    function self.getMaxWeight()
        return self.maxWeight
    end

    function self.canCarryItem(itemName, count)
        local itemDefinition = ESX.Items[itemName]
        if not itemDefinition then
            print(('[^3WARNING^7] Item ^5"%s"^7 was used but does not exist!'):format(itemName))
            return false
        end

        if type(count) ~= "number" or count <= 0 then
            return false
        end

        local item = self.getInventoryItem(itemName)
        local limit = item.limit or getItemLimit(itemName)

        return limit == -1 or (item.count + count) <= limit
    end

    function self.canSwapItem(firstItem, firstItemCount, testItem, testItemCount)
        local firstItemObject = self.getInventoryItem(firstItem)
        if not firstItemObject then
            return false
        end
        local testItemObject = self.getInventoryItem(testItem)
        if not testItemObject then
            return false
        end

        if firstItemObject.count < firstItemCount then
            return false
        end

        local limit = testItemObject.limit or getItemLimit(testItem)
        if limit == -1 then
            return true
        end

        return (testItemObject.count + testItemCount) <= limit
    end

    function self.setMaxWeight(newWeight)
        self.maxWeight = newWeight
        self.triggerEvent("esx:setMaxWeight", self.maxWeight)
    end

    function self.setJob(newJob, grade, onDuty)
        grade = tostring(grade)
        local lastJob = self.job

        if not ESX.DoesJobExist(newJob, grade) then
            return print(("[ESX] [^3WARNING^7] Ignoring invalid ^5.setJob()^7 usage for ID: ^5%s^7, Job: ^5%s^7"):format(self.source, newJob))
        end

        if newJob == "unemployed" then
            onDuty = false
        end

        if type(onDuty) ~= "boolean" then
            onDuty = Config.DefaultJobDuty
        end

        local jobObject, gradeObject = ESX.Jobs[newJob], ESX.Jobs[newJob].grades[grade]

        self.job = {
            id = jobObject.id,
            name = jobObject.name,
            label = jobObject.label,
            onDuty = onDuty,

            grade = tonumber(grade) or 0,
            grade_name = gradeObject.name,
            grade_label = gradeObject.label,
            grade_salary = gradeObject.salary,

            skin_male = decodeOptionalJsonTable(gradeObject.skin_male),
            skin_female = decodeOptionalJsonTable(gradeObject.skin_female),
        }
        self.state.job = self.job

        self.metadata.jobDuty = onDuty
        Core.MarkPlayerDirty(self, "job")
        TriggerEvent("esx:setJob", self.source, self.job, lastJob)
        self.triggerEvent("esx:setJob", self.job, lastJob)
        Player(self.source).state:set("job", self.job, true)
    end

    function self.addWeapon(weaponName, ammo)
        if not self.hasWeapon(weaponName) then
            local weaponConfig <const> = GetWeaponConfig(weaponName)
            if not weaponConfig then
                return
            end

            local weapon = {
                name = weaponName,
                ammo = ammo,
                label = weaponConfig.label or weaponName,
                components = {},
                tintIndex = 0,
            }
            self.loadout[weaponName] = weapon
            self.loadoutList[#self.loadoutList + 1] = weapon

            GiveWeaponToPed(GetPlayerPed(self.source), joaat(weaponName), ammo, false, false)
            Core.MarkPlayerDirty(self, "loadout")
            Player(self.source).state:set(("ammo:%s"):format(weaponName), ammo, true)
            TriggerEvent("esx:onAddWeapon", self.source, weaponName, ammo)
        end
    end

    function self.addWeaponComponent(weaponName, weaponComponent)
        local weapon = self.loadout[weaponName]

        if weapon then
            local componentLabel <const> = ESX.GetWeaponComponentLabel(weaponName, weaponComponent)

            if componentLabel and not self.hasWeaponComponent(weaponName, weaponComponent) then
                weapon.components[#weapon.components + 1] = weaponComponent
                GiveWeaponComponentToPed(GetPlayerPed(self.source), joaat(weaponName), joaat(weaponComponent))
                Core.MarkPlayerDirty(self, "loadout")
                TriggerEvent("esx:onAddWeaponComponent", self.source, weaponName, weaponComponent)
            end
        end
    end

    function self.addWeaponAmmo(weaponName, ammoCount)
        local weapon = self.loadout[weaponName]

        if weapon then
            weapon.ammo = weapon.ammo + ammoCount
            AddAmmoToPed(GetPlayerPed(self.source), joaat(weaponName), ammoCount)
            Core.MarkPlayerDirty(self, "loadout")
            Player(self.source).state:set(("ammo:%s"):format(weaponName), weapon.ammo, true)
            TriggerEvent("esx:onAddWeaponAmmo", self.source, weaponName, ammoCount)
        end
    end

    function self.updateWeaponAmmo(weaponName, ammoCount)
        local weapon = self.loadout[weaponName]

        if weapon then
            weapon.ammo = ammoCount
            Core.MarkPlayerDirty(self, "loadout")
            Player(self.source).state:set(("ammo:%s"):format(weaponName), weapon.ammo, true)
        end
    end

    function self.setWeaponTint(weaponName, weaponTintIndex)
        local weapon = self.loadout[weaponName]

        if weapon then
            weapon.tintIndex = weaponTintIndex
            SetPedWeaponTintIndex(GetPlayerPed(self.source), joaat(weaponName), weaponTintIndex)
            Core.MarkPlayerDirty(self, "loadout")
            TriggerEvent("esx:onSetWeaponTint", self.source, weaponName, weaponTintIndex)
        end
    end

    function self.getWeaponTint(weaponName)
        local weapon = self.loadout[weaponName]

        return weapon and weapon.tintIndex or 0
    end

    function self.removeWeapon(weaponName)
        local weapon = self.loadout[weaponName]

        if weapon then
            for i = 1, #self.loadoutList, 1 do
                if self.loadoutList[i].name == weaponName then
                    table.remove(self.loadoutList, i)
                    break
                end
            end

            self.loadout[weaponName] = nil
            RemoveWeaponFromPed(GetPlayerPed(self.source), joaat(weaponName))
            Core.MarkPlayerDirty(self, "loadout")
            Player(self.source).state:set(("ammo:%s"):format(weaponName), nil, true)
            TriggerEvent("esx:onRemoveWeapon", self.source, weaponName)
        end
    end

    function self.removeWeaponComponent(weaponName, weaponComponent)
        local weapon = self.loadout[weaponName]

        if weapon then
            local componentLabel <const> = ESX.GetWeaponComponentLabel(weaponName, weaponComponent)

            if componentLabel and self.hasWeaponComponent(weaponName, weaponComponent) then
                for i = 1, #weapon.components, 1 do
                    if weapon.components[i] == weaponComponent then
                        table.remove(weapon.components, i)
                        break
                    end
                end

                RemoveWeaponComponentFromPed(GetPlayerPed(self.source), joaat(weaponName), joaat(weaponComponent))
                Core.MarkPlayerDirty(self, "loadout")
                TriggerEvent("esx:onRemoveWeaponComponent", self.source, weaponName, weaponComponent)
            end
        end
    end

    function self.removeWeaponAmmo(weaponName, ammoCount)
        local weapon = self.loadout[weaponName]

        if weapon then
            weapon.ammo = weapon.ammo - ammoCount
            AddAmmoToPed(GetPlayerPed(self.source), joaat(weaponName), -ammoCount)
            Core.MarkPlayerDirty(self, "loadout")
            Player(self.source).state:set(("ammo:%s"):format(weaponName), weapon.ammo, true)
            TriggerEvent("esx:onRemoveWeaponAmmo", self.source, weaponName, ammoCount)
        end
    end

    function self.hasWeaponComponent(weaponName, weaponComponent)
        local weapon = self.loadout[weaponName]

        if weapon then
            for i = 1, #weapon.components, 1 do
                if weapon.components[i] == weaponComponent then
                    return true
                end
            end
        end

        return false
    end

    function self.hasWeapon(weaponName)
        return self.loadout[weaponName] ~= nil
    end

    function self.hasItem(itemName)
        local item = self.getInventoryItem(itemName)

        if item and item.count > 0 then
            return item, item.count
        end

        return false, 0
    end

    function self.getWeapon(weaponName)
        local weapon = self.loadout[weaponName]

        if weapon then
            return weapon.ammo, weapon.components
        end

        return nil
    end

    function self.showNotification(msg, notifyType, length, title, position)
        self.triggerEvent("esx:showNotification", msg, notifyType, length, title, position)
    end

    function self.showAdvancedNotification(sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex)
        self.triggerEvent("esx:showAdvancedNotification", sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex)
    end

    function self.showHelpNotification(msg, thisFrame, beep, duration)
        self.triggerEvent("esx:showHelpNotification", msg, thisFrame, beep, duration)
    end

    function self.getMeta(index, subIndex)
        if not index then
            return self.metadata
        end

        if type(index) ~= "string" then
            return
        end

        local meta = self.metadata[index]

        if meta and subIndex then
            if type(subIndex) == "string" then
                return meta[subIndex]
            elseif type(subIndex) == "table" then
                local results = {}
                for i = 1, #subIndex do
                    results[subIndex[i]] = meta[subIndex[i]]
                end
                return results
            end
        end

        return meta
    end

    function self.setMeta(index, value, subValue)
        if not index or type(index) ~= "string" then
            return
        end

        if subValue then
            if type(self.metadata[index]) ~= "table" then
                self.metadata[index] = {}
            end
            self.metadata[index][value] = subValue
        else
            self.metadata[index] = value
        end

        Core.MarkPlayerDirty(self, "metadata")
        scheduleMetadataSync()
    end

    function self.clearMeta(index, subValues)
        if not index or type(index) ~= "string" then
            return
        end

        if subValues then
            if type(self.metadata[index]) ~= "table" then
                return
            end

            if type(subValues) == "string" then
                self.metadata[index][subValues] = nil
            elseif type(subValues) == "table" then
                for i = 1, #subValues do
                    self.metadata[index][subValues[i]] = nil
                end
            end
        else
            self.metadata[index] = nil
        end

        Core.MarkPlayerDirty(self, "metadata")
        scheduleMetadataSync()
    end

    return self
end
