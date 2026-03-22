local DiscordActivityState = {
    appId = 0,
    lastPresence = nil,
    lastAssetText = nil,
    lastEndpoint = nil,
}

local function getDiscordActivityConfig()
    return Config.DiscordActivity or {}
end

local function getDiscordActivityAppId()
    local cfg = getDiscordActivityConfig()
    local appId = tonumber(cfg.appId) or 0
    if appId > 0 then
        return appId
    end

    local convarValue = tonumber(GetConvar("esx:discordAppId", "0")) or 0
    if convarValue > 0 then
        return convarValue
    end

    return tonumber(GetConvar("discord_app_id", "0")) or 0
end

local function getActivityTokens()
    local playerData = ESX.PlayerData or {}
    local serverEndpoint = GetCurrentServerEndpoint() or ""
    local serverName = GlobalState.serverName or GetConvar("sv_projectName", GetConvar("sv_hostname", "ESX Server"))
    local serverPlayers = tonumber(GlobalState.playerCount) or #GetActivePlayers()
    local serverMaxPlayers = GetConvarInt("sv_maxclients", 48)

    return {
        server_name = tostring(serverName or "ESX Server"),
        server_endpoint = tostring(serverEndpoint),
        player_name = tostring(playerData.name or GetPlayerName(PlayerId()) or "Unknown"),
        player_id = tostring(ESX.serverId or GetPlayerServerId(PlayerId())),
        server_players = tostring(serverPlayers),
        server_maxplayers = tostring(serverMaxPlayers),
    }
end

local function resolveActivityTemplate(template)
    if type(template) ~= "string" or template == "" then
        return ""
    end

    local tokens = getActivityTokens()
    return (template:gsub("{(.-)}", function(key)
        return tokens[key] or ""
    end))
end

local function applyDiscordButtons(cfg)
    local buttons = cfg.buttons or {}
    for index = 1, math.min(#buttons, 2) do
        local button = buttons[index]
        local label = button and resolveActivityTemplate(button.label)
        local url = button and resolveActivityTemplate(button.url)

        if label ~= "" and url ~= "" then
            SetDiscordRichPresenceAction(index - 1, label, url)
        end
    end
end

local function applyDiscordActivity(force)
    local cfg = getDiscordActivityConfig()
    local appId = getDiscordActivityAppId()
    if appId <= 0 then
        return
    end

    if force or DiscordActivityState.appId ~= appId then
        SetDiscordAppId(appId)
        DiscordActivityState.appId = appId

        if type(cfg.assetName) == "string" and cfg.assetName ~= "" then
            SetDiscordRichPresenceAsset(cfg.assetName)
        end

        applyDiscordButtons(cfg)
    end

    local assetText = resolveActivityTemplate(cfg.assetText)
    if assetText ~= "" and (force or DiscordActivityState.lastAssetText ~= assetText) then
        SetDiscordRichPresenceAssetText(assetText)
        DiscordActivityState.lastAssetText = assetText
    end

    local presenceText = resolveActivityTemplate(cfg.presence)
    if presenceText ~= "" and (force or DiscordActivityState.lastPresence ~= presenceText) then
        SetRichPresence(presenceText)
        DiscordActivityState.lastPresence = presenceText
    end
end

CreateThread(function()
    while true do
        local cfg = getDiscordActivityConfig()
        if ESX.PlayerLoaded then
            applyDiscordActivity(false)
            Wait(tonumber(cfg.refresh) or (1 * 60 * 1000))
        else
            Wait(5000)
        end
    end
end)

RegisterNetEvent("esx:playerLoaded", function()
    applyDiscordActivity(true)
end)

RegisterNetEvent("esx:setJob", function()
    applyDiscordActivity(true)
end)

AddEventHandler("esx:onPlayerLogout", function()
    DiscordActivityState.lastPresence = nil
    DiscordActivityState.lastAssetText = nil
    if DiscordActivityState.appId > 0 then
        SetRichPresence("")
    end
end)
