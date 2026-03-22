Core = {}
Core.Input = {}
Core.Events = {}

ESX.PlayerData = {}

-- NPC systems removed: disable ambient population/cops once on startup.
CreateThread(function()
    SetPedPopulationBudget(0)
    SetVehiclePopulationBudget(0)
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
end)
ESX.PlayerLoaded = false
ESX.playerId = PlayerId()
ESX.serverId = GetPlayerServerId(ESX.playerId)

ESX.UI = {}
ESX.UI.Menu = {}
ESX.UI.Menu.RegisteredTypes = {}
ESX.UI.Menu.Opened = {}

ESX.Game = {}
ESX.Game.Utils = {}

local DiscordPresenceState = {
    appId = nil,
    lastText = nil,
}

local function getDiscordPresenceConfig()
    return Config.DiscordRichPresence or {}
end

local function getDiscordAppId()
    local cfg = getDiscordPresenceConfig()
    local configured = tostring(cfg.appId or "")
    if configured ~= "" then
        return configured
    end

    local convarValue = GetConvar("esx:discordAppId", "")
    if convarValue ~= "" then
        return convarValue
    end

    return GetConvar("discord_app_id", "")
end

local function buildDiscordPresenceText()
    local cfg = getDiscordPresenceConfig()
    local parts = {}
    local playerData = ESX.PlayerData or {}
    local job = playerData.job or {}

    if type(cfg.statusText) == "string" and cfg.statusText ~= "" then
        parts[#parts + 1] = cfg.statusText
    end

    if cfg.showPlayerName and playerData.name then
        parts[#parts + 1] = playerData.name
    end

    if cfg.showPlayerId and ESX.serverId then
        parts[#parts + 1] = ("ID %s"):format(ESX.serverId)
    end

    if cfg.showJob and (job.label or job.name) then
        parts[#parts + 1] = job.label or job.name
    end

    return table.concat(parts, " | ")
end

local function applyDiscordRichPresence(force)
    local cfg = getDiscordPresenceConfig()
    if cfg.enabled == false then
        return
    end

    local appId = getDiscordAppId()
    if appId == "" then
        return
    end

    if force or DiscordPresenceState.appId ~= appId then
        SetDiscordAppId(appId)
        DiscordPresenceState.appId = appId

        if type(cfg.largeAssetKey) == "string" and cfg.largeAssetKey ~= "" then
            SetDiscordRichPresenceAsset(cfg.largeAssetKey)
        end

        if type(cfg.largeAssetText) == "string" and cfg.largeAssetText ~= "" then
            SetDiscordRichPresenceAssetText(cfg.largeAssetText)
        end
    end

    local presenceText = buildDiscordPresenceText()
    if presenceText ~= "" and (force or DiscordPresenceState.lastText ~= presenceText) then
        SetRichPresence(presenceText)
        DiscordPresenceState.lastText = presenceText
    end
end

local function waitForPlayerActivation()
    if not NetworkIsPlayerActive(ESX.playerId) then
        return SetTimeout(100, waitForPlayerActivation)
    end

    ESX.DisableSpawnManager()
    DoScreenFadeOut(0)
    Wait(250)
    TriggerServerEvent("esx:onPlayerJoined")
end

CreateThread(waitForPlayerActivation)

CreateThread(function()
    while true do
        local cfg = getDiscordPresenceConfig()
        if ESX.PlayerLoaded and cfg.enabled ~= false then
            applyDiscordRichPresence(false)
            Wait(tonumber(cfg.updateInterval) or 30000)
        else
            Wait(5000)
        end
    end
end)

RegisterNetEvent("esx:playerLoaded", function()
    applyDiscordRichPresence(true)
end)

RegisterNetEvent("esx:setJob", function()
    applyDiscordRichPresence(true)
end)

AddEventHandler("esx:onPlayerLogout", function()
    DiscordPresenceState.lastText = nil
    if DiscordPresenceState.appId then
        SetRichPresence("")
    end
end)
