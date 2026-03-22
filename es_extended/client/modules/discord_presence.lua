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
    local statusCfg = cfg.status or {}
    local parts = {}
    local playerData = ESX.PlayerData or {}
    local job = playerData.job or {}

    if type(statusCfg.text) == "string" and statusCfg.text ~= "" then
        parts[#parts + 1] = statusCfg.text
    end

    if statusCfg.showPlayerName and playerData.name then
        parts[#parts + 1] = playerData.name
    end

    if statusCfg.showPlayerId and ESX.serverId then
        parts[#parts + 1] = ("ID %s"):format(ESX.serverId)
    end

    if statusCfg.showJob and (job.label or job.name) then
        parts[#parts + 1] = job.label or job.name
    end

    return table.concat(parts, " | ")
end

local function applyDiscordButtons(cfg)
    local buttons = cfg.buttons or {}
    for index = 1, math.min(#buttons, 2) do
        local button = buttons[index]
        if button and type(button.label) == "string" and button.label ~= "" and type(button.url) == "string" and button.url ~= "" then
            SetDiscordRichPresenceAction(index - 1, button.label, button.url)
        end
    end
end

local function applyDiscordAssets(cfg)
    local assets = cfg.assets or {}
    local largeAsset = assets.large or {}
    local smallAsset = assets.small or {}

    if type(largeAsset.key) == "string" and largeAsset.key ~= "" then
        SetDiscordRichPresenceAsset(largeAsset.key)
    end

    if type(largeAsset.text) == "string" and largeAsset.text ~= "" then
        SetDiscordRichPresenceAssetText(largeAsset.text)
    end

    if type(smallAsset.key) == "string" and smallAsset.key ~= "" then
        SetDiscordRichPresenceAssetSmall(smallAsset.key)
    end

    if type(smallAsset.text) == "string" and smallAsset.text ~= "" then
        SetDiscordRichPresenceAssetSmallText(smallAsset.text)
    end
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
        applyDiscordAssets(cfg)
        applyDiscordButtons(cfg)
    end

    local presenceText = buildDiscordPresenceText()
    if presenceText ~= "" and (force or DiscordPresenceState.lastText ~= presenceText) then
        SetRichPresence(presenceText)
        DiscordPresenceState.lastText = presenceText
    end
end

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
