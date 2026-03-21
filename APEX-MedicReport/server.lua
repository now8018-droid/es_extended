local ESX = nil

local AlertCases = {}
local PhoneBlackList = {}
local DefaultCaseRemainSeconds = (Config and Config["DefaultCaseRemainSeconds"]) or 2700
local CaseOrderCounter = 0
local MedicActiveCase = {}
local AmbulancePlayers = {}

local function setAmbulancePlayer(playerId, isAmbulance)
    local pid = tonumber(playerId)
    if not pid then return end

    if isAmbulance then
        AmbulancePlayers[pid] = true
    else
        AmbulancePlayers[pid] = nil
    end
end

local function generateCaseId()
    local caseId = math.random(10000, 99999)
    local exists = true

    while exists do
        exists = false
        for _, caseData in ipairs(AlertCases) do
            if caseData.caseid == caseId then
                exists = true
                caseId = math.random(10000, 99999)
                break
            end
        end
    end

    return caseId
end

local function loadESX()
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    end

    while ESX == nil do
        TriggerEvent(Config["Router"], function(obj)
            ESX = obj
        end)
        Wait(200)
    end
end

local function getPlayerPhone(xPlayer, source)
    if xPlayer and xPlayer.get then
        local phone = xPlayer.get('phone_number')
        if phone ~= nil then
            return tostring(phone)
        end
    end

    return tostring(source)
end

local function getPlayerNameSafe(source)
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.getName then
            return xPlayer.getName()
        end
    end

    return GetPlayerName(source) or ('ID ' .. tostring(source))
end

local function getRealRespawnRemainSeconds(source)
    local playerState = Player(source) and Player(source).state
    if not playerState then
        return nil
    end

    local remain = tonumber(playerState.ambulanceRespawnRemain)
    if remain and remain >= 0 then
        return math.floor(remain)
    end

    return nil
end

local function eachAmbulance(cb)
    for playerId, _ in pairs(AmbulancePlayers) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer and xPlayer.job and xPlayer.job.name == 'ambulance' then
            cb(playerId, xPlayer)
        else
            AmbulancePlayers[playerId] = nil
        end
    end
end

local function refreshAmbulanceCache()
    if ESX == nil then
        return
    end

    AmbulancePlayers = {}

    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer and xPlayer.job and xPlayer.job.name == 'ambulance' then
            setAmbulancePlayer(playerId, true)
        end
    end
end

local function syncBlackListToAmbulance()
    eachAmbulance(function(playerId)
        TriggerClientEvent(scriptName .. ':RefreshBlackList', playerId, PhoneBlackList)
    end)
end

local function loadBlackListFromDB()
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT phone FROM nakin_medicreport_blacklist')
    end)

    if not ok then
        print('^1[nakin_medicreport] blacklist table not found, running with memory only.^0')
        return
    end

    for _, row in ipairs(rows or {}) do
        if row.phone ~= nil then
            PhoneBlackList[tostring(row.phone)] = true
        end
    end
end

local function saveBlackListNumber(phone, status)
    local phoneStr = tostring(phone)

    if status then
        local ok = pcall(function()
            MySQL.insert.await('INSERT IGNORE INTO nakin_medicreport_blacklist (phone) VALUES (?)', { phoneStr })
        end)

        if not ok then
            print('^3[nakin_medicreport] cannot persist blacklist number, table may be missing.^0')
        end
    else
        local ok = pcall(function()
            MySQL.update.await('DELETE FROM nakin_medicreport_blacklist WHERE phone = ? LIMIT 1', { phoneStr })
        end)

        if not ok then
            print('^3[nakin_medicreport] cannot delete blacklist number from db, table may be missing.^0')
        end
    end
end

local function removeCaseBySource(source)
    for i = #AlertCases, 1, -1 do
        if AlertCases[i].id == source then
            table.remove(AlertCases, i)
        end
    end
end

local function addCase(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return
    end

    local phone = getPlayerPhone(xPlayer, source)

    if PhoneBlackList[phone] then
        return
    end


    local callerName = getPlayerNameSafe(source)
    local realRemain = getRealRespawnRemainSeconds(source)

    local existingCase = nil
    for _, caseData in ipairs(AlertCases) do
        if tonumber(caseData.id) == tonumber(source) and tonumber(caseData.status) == 1 then
            existingCase = caseData
            break
        end
    end

    if existingCase then
        existingCase.name = callerName
        existingCase.phone = phone
        existingCase.coords = GetEntityCoords(GetPlayerPed(source))
        existingCase.type = data and data.type or existingCase.type
        existingCase.color = data and data.color or existingCase.color
        existingCase.servertime = os.time()
        existingCase.remain = (data and tonumber(data.remain)) or realRemain or existingCase.remain or DefaultCaseRemainSeconds
        existingCase.pressedCount = (tonumber(existingCase.pressedCount) or 1) + 1

        existingCase.text = 'ยังไม่ได้รับความช่วยเหลือ'

        eachAmbulance(function(playerId)
            TriggerClientEvent(scriptName .. ':UpdateCase', playerId, existingCase.caseid, existingCase.status, existingCase.text, existingCase.ac, existingCase.pressedCount)
            TriggerClientEvent(scriptName .. ':RepeatCaseAlert', playerId, {
                caseid = existingCase.caseid,
                name = existingCase.name,
                phone = existingCase.phone,
                coords = existingCase.coords,
                pressedCount = existingCase.pressedCount,
            })
        end)
        TriggerClientEvent(scriptName .. ':UpdateId', source, existingCase.ac)

        TriggerClientEvent(scriptName .. ':SetCanNeedHelp', source, false)
        SetTimeout(5000, function()
            TriggerClientEvent(scriptName .. ':SetCanNeedHelp', source, true)
        end)
        return
    end

    local randomCaseId = generateCaseId()

    local caseData = {
        id = source,
        ac = randomCaseId,
        caseid = randomCaseId,
        name = callerName,
        phone = phone,
        remain = (data and tonumber(data.remain)) or realRemain or DefaultCaseRemainSeconds,
        status = 1,
        text = data and data.text or 'ต้องการความช่วยเหลือ',
        pressedCount = 1,
        type = data and data.type or 'normal',
        color = data and data.color or nil,
        coords = GetEntityCoords(GetPlayerPed(source)),
        servertime = os.time(),
        caseorder = CaseOrderCounter + 1,
    }

    CaseOrderCounter = caseData.caseorder

    table.insert(AlertCases, caseData)

    TriggerClientEvent(scriptName .. ':UpdateId', source, caseData.ac)

    eachAmbulance(function(playerId)
        TriggerClientEvent(scriptName .. ':AddMedicCase', playerId, caseData, true)
    end)

    TriggerClientEvent(scriptName .. ':SetCanNeedHelp', source, false)
    SetTimeout(5000, function()
        TriggerClientEvent(scriptName .. ':SetCanNeedHelp', source, true)
    end)
end


local function findCaseByCaseId(caseId)
    local normalizedCaseId = tonumber(caseId)
    if not normalizedCaseId then
        return nil
    end

    for _, caseData in ipairs(AlertCases) do
        if tonumber(caseData.caseid) == normalizedCaseId then
            return caseData
        end
    end

    return nil
end

local function refreshCaseForAmbulance(caseData)
    eachAmbulance(function(playerId)
        TriggerClientEvent(scriptName .. ':UpdateCase', playerId, caseData.caseid, caseData.status, caseData.text, caseData.ac, caseData.pressedCount)
    end)
end

local function refreshCaseBulkForAmbulance(caseUpdates)
    if type(caseUpdates) ~= 'table' or #caseUpdates == 0 then
        return
    end

    eachAmbulance(function(playerId)
        TriggerClientEvent(scriptName .. ':UpdateCaseBulk', playerId, caseUpdates)
    end)
end

local function syncAllCasesToAmbulance()
    eachAmbulance(function(playerId)
        TriggerClientEvent(scriptName .. ':SyncCases', playerId, AlertCases)
    end)
end

local function releaseAcceptedCasesByDoctor(doctorSource, exceptCaseId)
    local normalizedDoctorSource = tonumber(doctorSource)
    local normalizedExceptCaseId = tonumber(exceptCaseId)

    for _, caseData in ipairs(AlertCases) do
        if caseData.status == 2 and tonumber(caseData.acceptedBySource) == normalizedDoctorSource and tonumber(caseData.caseid) ~= normalizedExceptCaseId then
            caseData.status = 1
            caseData.text = 'ต้องการความช่วยเหลือ'
            caseData.acceptedBySource = nil
            refreshCaseForAmbulance(caseData)
        end
    end

    if normalizedDoctorSource then
        if normalizedExceptCaseId then
            MedicActiveCase[normalizedDoctorSource] = normalizedExceptCaseId
        else
            MedicActiveCase[normalizedDoctorSource] = nil
        end
    end
end

local function updateCase(caseId, action)
    caseId = tonumber(caseId)

    if action == 'deleteall' then
        local removedSafeCaseIds = {}

        for i = #AlertCases, 1, -1 do
            local caseData = AlertCases[i]
            if tonumber(caseData.status) == 3 then
                local acceptedSource = tonumber(caseData.acceptedBySource)
                if acceptedSource and MedicActiveCase[acceptedSource] == caseData.caseid then
                    MedicActiveCase[acceptedSource] = nil
                end

                caseData.acceptedBySource = nil
                table.insert(removedSafeCaseIds, caseData.caseid)
                table.remove(AlertCases, i)
            end
        end

        if #removedSafeCaseIds > 0 then
            local caseUpdates = {}
            for _, removedCaseId in ipairs(removedSafeCaseIds) do
                caseUpdates[#caseUpdates + 1] = { caseid = removedCaseId, status = 0 }
            end
            refreshCaseBulkForAmbulance(caseUpdates)
        end

        syncAllCasesToAmbulance()
        return
    end

    for i = #AlertCases, 1, -1 do
        local caseData = AlertCases[i]

        if caseData.caseid == caseId then
            if action == 'deletecase' then
                if caseData.status ~= 3 then
                    return
                end

                local acceptedSource = tonumber(caseData.acceptedBySource)
                if acceptedSource and MedicActiveCase[acceptedSource] == caseData.caseid then
                    MedicActiveCase[acceptedSource] = nil
                end
                caseData.acceptedBySource = nil
                table.remove(AlertCases, i)
                refreshCaseBulkForAmbulance({
                    { caseid = caseData.caseid, status = 0 }
                })
            elseif action == 'getcase' then
                if caseData.status == 3 then
                    return
                end

                local medicSource = tonumber(source)
                local currentActiveCaseId = medicSource and MedicActiveCase[medicSource] or nil
                if currentActiveCaseId and tonumber(currentActiveCaseId) ~= tonumber(caseData.caseid) then
                    local previousCase = findCaseByCaseId(currentActiveCaseId)
                    if previousCase and previousCase.status == 2 and tonumber(previousCase.acceptedBySource) == medicSource then
                        previousCase.status = 1
                        previousCase.text = 'ต้องการความช่วยเหลือ'
                        previousCase.acceptedBySource = nil
                        refreshCaseForAmbulance(previousCase)
                    end
                end

                releaseAcceptedCasesByDoctor(source, caseData.caseid)

                local previousAcceptedSource = tonumber(caseData.acceptedBySource)
                if previousAcceptedSource and MedicActiveCase[previousAcceptedSource] == caseData.caseid then
                    MedicActiveCase[previousAcceptedSource] = nil
                end

                local doctorName = getPlayerNameSafe(source)
                caseData.status = 2
                caseData.text = ('%s กำลังไป'):format(doctorName)

                caseData.acceptedBySource = medicSource or source
                if medicSource then
                    MedicActiveCase[medicSource] = caseData.caseid
                end
                refreshCaseForAmbulance(caseData)
                TriggerClientEvent(scriptName .. ':markGPS', source, caseData.caseid)
            elseif action == 'done' then
                caseData.status = 3
                caseData.text = 'ปลอดภัยแล้ว'
                local acceptedSource = tonumber(caseData.acceptedBySource)
                if acceptedSource and MedicActiveCase[acceptedSource] == caseData.caseid then
                    MedicActiveCase[acceptedSource] = nil
                end
                caseData.acceptedBySource = nil

                refreshCaseForAmbulance(caseData)
            end
            return
        end
    end
end

local function removeCasesBySource(sourceId)
    local removedCaseIds = {}

    for i = #AlertCases, 1, -1 do
        if AlertCases[i].id == sourceId then
            removedCaseIds[#removedCaseIds + 1] = AlertCases[i].caseid
            table.remove(AlertCases, i)
        end
    end

    if #removedCaseIds > 0 then
        local caseUpdates = {}
        for _, removedCaseId in ipairs(removedCaseIds) do
            caseUpdates[#caseUpdates + 1] = { caseid = removedCaseId, status = 0 }
        end
        refreshCaseBulkForAmbulance(caseUpdates)
    end
end

CreateThread(function()
    loadESX()
    refreshAmbulanceCache()
    loadBlackListFromDB()

    print(('^2[%s]^7 server loaded'):format(scriptName))
end)

RegisterNetEvent(scriptName .. ':AddAlert', function(data)
    addCase(source, data)
end)

RegisterNetEvent(scriptName .. ':UpdateCase', function(caseSource, action)
    updateCase(caseSource, action)
end)

RegisterNetEvent(scriptName .. ':ReleaseAcceptedCases', function()
    releaseAcceptedCasesByDoctor(source)
end)

RegisterNetEvent(scriptName .. ':LoadBlackList', function()
    TriggerClientEvent(scriptName .. ':RefreshBlackList', source, PhoneBlackList)
end)

RegisterNetEvent(scriptName .. ':AddBlackListNumber', function(phone, status)
    phone = tonumber(phone)
    if not phone then
        return
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not xPlayer.job or xPlayer.job.name ~= 'ambulance' then
        return
    end

    local phoneStr = tostring(phone)
    if status then
        PhoneBlackList[phoneStr] = true
    else
        PhoneBlackList[phoneStr] = nil
    end

    saveBlackListNumber(phone, status)
    syncBlackListToAmbulance()
end)

AddEventHandler('playerDropped', function()
    local src = source
    removeCasesBySource(src)
    releaseAcceptedCasesByDoctor(src)
    MedicActiveCase[tonumber(src) or src] = nil
    setAmbulancePlayer(src, false)
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer or not xPlayer.job or xPlayer.job.name ~= 'ambulance' then
        setAmbulancePlayer(playerId, false)
        return
    end

    setAmbulancePlayer(playerId, true)

    TriggerClientEvent(scriptName .. ':RefreshBlackList', playerId, PhoneBlackList)
    for _, caseData in ipairs(AlertCases) do
        TriggerClientEvent(scriptName .. ':AddMedicCase', playerId, caseData, false)
    end
end)

AddEventHandler('esx:setJob', function(sourceId, job, _lastJob)
    setAmbulancePlayer(sourceId, job and job.name == 'ambulance')
end)

RegisterNetEvent(scriptName .. ':cacheJob', function(jobName)
    setAmbulancePlayer(source, jobName == 'ambulance')
end)
