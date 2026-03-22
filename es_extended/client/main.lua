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
