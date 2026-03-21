Death = {}
Death._index = Death

function Death:ResetValues()
    self.killerEntity = nil
    self.deathCause = nil
    self.killerId = nil
    self.killerServerId = nil
end

function Death:ByPlayer()
    local victimCoords = GetEntityCoords(ESX.PlayerData.ped)
    local killerCoords = GetEntityCoords(self.killerEntity)
    local distance = #(victimCoords - killerCoords)

    local data = {
        victimCoords = { x = ESX.Math.Round(victimCoords.x, 1), y = ESX.Math.Round(victimCoords.y, 1), z = ESX.Math.Round(victimCoords.z, 1) },
        killerCoords = { x = ESX.Math.Round(killerCoords.x, 1), y = ESX.Math.Round(killerCoords.y, 1), z = ESX.Math.Round(killerCoords.z, 1) },

        killedByPlayer = true,
        deathCause = self.deathCause,
        distance = ESX.Math.Round(distance, 1),

        killerServerId = self.killerServerId,
        killerClientId = self.killerId,
    }

    TriggerEvent("esx:onPlayerDeath", data)
    TriggerServerEvent("esx:onPlayerDeath", data)
end

function Death:Natural()
    local coords = GetEntityCoords(ESX.PlayerData.ped)

    local data = {
        victimCoords = { x = ESX.Math.Round(coords.x, 1), y = ESX.Math.Round(coords.y, 1), z = ESX.Math.Round(coords.z, 1) },

        killedByPlayer = false,
        deathCause = self.deathCause,
    }

    TriggerEvent("esx:onPlayerDeath", data)
    TriggerServerEvent("esx:onPlayerDeath", data)
end

function Death:Died()
    self.killerEntity = GetPedSourceOfDeath(ESX.PlayerData.ped)
    self.deathCause = GetPedCauseOfDeath(ESX.PlayerData.ped)
    self.killerId = NetworkGetPlayerIndexFromPed(self.killerEntity)
    self.killerServerId = GetPlayerServerId(self.killerId)

    local isActive = NetworkIsPlayerActive(self.killerId)

    if self.killerEntity ~= ESX.PlayerData.ped and self.killerId and isActive then
        self:ByPlayer()
    else
        self:Natural()
    end

    self:ResetValues()
end

-- Event-driven death: CEventEntityDied for instant response; fallback for edge cases
local deathCheckScheduled = false
local function scheduleDeathCheck()
    if deathCheckScheduled then return end
    deathCheckScheduled = true
    SetTimeout(1000, function()
        deathCheckScheduled = false
        if not ESX.PlayerLoaded then
            scheduleDeathCheck()
            return
        end
        if ESX.PlayerData.dead then return end
        local ped = ESX.PlayerData.ped
        if DoesEntityExist(ped) and (IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped)) then
            Death:Died()
            return
        end
        scheduleDeathCheck()
    end)
end

AddEventHandler("gameEventTriggered", function(eventName, args)
    if eventName == "CEventEntityDied" and args[1] == PlayerPedId() then
        if ESX.PlayerLoaded and not ESX.PlayerData.dead then
            Death:Died()
        end
    end
end)

AddEventHandler("esx:onPlayerSpawn", function()
    scheduleDeathCheck()
end)
