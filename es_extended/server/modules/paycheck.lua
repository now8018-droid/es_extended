local societyAccountCache = {}

local function getSocietyAccount(jobName, cb)
    local cachedAccount = societyAccountCache[jobName]
    if cachedAccount ~= nil then
        return cb(cachedAccount or nil)
    end

    TriggerEvent("esx_society:getSociety", jobName, function(society)
        if society == nil then
            societyAccountCache[jobName] = false
            return cb(nil)
        end

        TriggerEvent("esx_addonaccount:getSharedAccount", society.account, function(account)
            societyAccountCache[jobName] = account or false
            cb(account)
        end)
    end)
end

local function processPaycheck(player, xPlayer)
    local jobLabel = xPlayer.job.label
    local job = xPlayer.job.grade_name
    local onDuty = xPlayer.job.onDuty
    local salary = (job == "unemployed" or onDuty) and xPlayer.job.grade_salary or ESX.Math.Round(xPlayer.job.grade_salary * Config.OffDutyPaycheckMultiplier)

    if not xPlayer.paycheckEnabled or salary <= 0 then
        return
    end

    if job == "unemployed" then
        xPlayer.addAccountMoney("bank", salary, "Welfare Check")
        TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_help", salary), "CHAR_BANK_MAZE", 9)
        if Config.LogPaycheck then
            ESX.DiscordLogFields("Paycheck", "Paycheck - Unemployment Benefits", "green", {
                { name = "Player", value = xPlayer.name, inline = true },
                { name = "ID", value = xPlayer.source, inline = true },
                { name = "Amount", value = salary, inline = true },
            })
        end
        return
    end

    if Config.EnableSocietyPayouts then
        return getSocietyAccount(xPlayer.job.name, function(account)
            if account ~= nil then
                if account.money >= salary then
                    xPlayer.addAccountMoney("bank", salary, "Paycheck")
                    account.removeMoney(salary)
                    if Config.LogPaycheck then
                        ESX.DiscordLogFields("Paycheck", "Paycheck - " .. jobLabel, "green", {
                            { name = "Player", value = xPlayer.name, inline = true },
                            { name = "ID", value = xPlayer.source, inline = true },
                            { name = "Amount", value = salary, inline = true },
                        })
                    end

                    TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
                else
                    TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), "", TranslateCap("company_nomoney"), "CHAR_BANK_MAZE", 1)
                end
            else
                xPlayer.addAccountMoney("bank", salary, "Paycheck")
                if Config.LogPaycheck then
                    ESX.DiscordLogFields("Paycheck", "Paycheck - " .. jobLabel, "green", {
                        { name = "Player", value = xPlayer.name, inline = true },
                        { name = "ID", value = xPlayer.source, inline = true },
                        { name = "Amount", value = salary, inline = true },
                    })
                end
                TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
            end
        end)
    end

    xPlayer.addAccountMoney("bank", salary, "Paycheck")
    if Config.LogPaycheck then
        ESX.DiscordLogFields("Paycheck", "Paycheck - Generic", "green", {
            { name = "Player", value = xPlayer.name, inline = true },
            { name = "ID", value = xPlayer.source, inline = true },
            { name = "Amount", value = salary, inline = true },
        })
    end
    TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
end

function StartPayCheck()
    CreateThread(function()
        while true do
            Wait(Config.PaycheckInterval)
            local players = ESX.GetExtendedPlayers()
            local chunkSize = math.max(Config.PaycheckChunkSize, 1)

            for i = 1, #players, chunkSize do
                local upper = math.min(i + chunkSize - 1, #players)
                for index = i, upper do
                    local xPlayer = players[index]
                    processPaycheck(xPlayer.source, xPlayer)
                end

                if upper < #players then
                    Wait(Config.PaycheckChunkDelay)
                end
            end
        end
    end)
end
