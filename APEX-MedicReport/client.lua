Keys 					  = {
	["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57, 
	["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177, 
	["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
	["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
	["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
	["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70, 
	["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
	["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
	["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

ESX			    		= nil
local AllowNeedHelp		= true
local ScriptProp		= {}
local AlertData			= {}
local ScriptEntity		= {}
local AlertCaseIndexMap	= {}

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent(Config["Router"], function(obj) ESX = obj end)
		Citizen.Wait(200)
	end

	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(100)
	end
    ESX.PlayerData = ESX.GetPlayerData()
	if ESX.PlayerData and ESX.PlayerData.job and ESX.PlayerData.job.name then
		TriggerServerEvent(scriptName..':cacheJob', ESX.PlayerData.job.name)
	end
    ScriptWork()
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	if job and job.name then
		TriggerServerEvent(scriptName..':cacheJob', job.name)
	end
end)

function ScriptWork()

	print("^7 [^4Scripts^7][^2"..string.upper(GetCurrentResourceName()).."^7][^4Loaded Success^7]")

	AddEventHandler('onResourceStop', function(resource)
		if resource == GetCurrentResourceName() then
			for k,v in pairs(ScriptEntity) do DeleteEntity(v) end
		end
	end)

	function LoadAnimDict(dict)
		while (not HasAnimDictLoaded(dict)) do
			RequestAnimDict(dict)
			Citizen.Wait(10)
		end
	end

	-- RegisterCommand("al",function(source, args)
	-- 	if args[1] then
	-- 		exports['APEX-MedicReport']:SendAlert({
	-- 			text = "โดนห่อศพ "..args[1].."",
	-- 			color = "rgb(255, 0, 54, 0.5)",
	-- 			type = "bodybag"
	-- 		})
	-- 	end
	-- end)

	-- RegisterCommand("al3",function(source, args)
	-- 	exports['APEX-MedicReport']:SendAlert({
	-- 		text = "25:34",
	-- 	})
	-- end)

	-- RegisterCommand("al2",function(source, args)
	-- 	exports['APEX-MedicReport']:SendAlert()
	-- end)

	RegisterCommand("medicpreview", function(source, args)
		SendAlert({
			type = "normal"
		})
	end, false)

	RegisterCommand("medicsuccess", function(source, args)
		if not ESX.GetPlayerData().job or ESX.GetPlayerData().job.name ~= "ambulance" then
			return
		end

		local caseId = tonumber(args and args[1])
		if not caseId then
			exports['APEX-AllNotify']:AddNotify({type = "error", text = "ใช้คำสั่ง: medicsuccess [idcase]"})
			return
		end

		TriggerServerEvent(scriptName..':UpdateCase', caseId, "done")
		exports['APEX-AllNotify']:AddNotify({type = "success", text = "อัปเดตเคสเป็นปลอดภัยแล้ว"})
	end, false)

	RegisterNetEvent(scriptName..':RefreshBlackList')
	AddEventHandler(scriptName..':RefreshBlackList', function(data)
		if ESX.GetPlayerData().job.name == "ambulance" then
			BlackList = data
			SendNUIMessage({ type = 'RefreshBlackList', data = BlackList})
		end
	end)

	RegisterNetEvent(scriptName..':SetCanNeedHelp')
	AddEventHandler(scriptName..':SetCanNeedHelp', function(status)
		AllowNeedHelp = status
	end)

	function SendAlert(data)
		if AllowNeedHelp then
			-- if IsPedDeadOrDying(GetPlayerPed(-1)) then
				NeedHelp = true
				TriggerServerEvent(scriptName..':AddAlert', data)
			-- end
		else
			exports['APEX-AllNotify']:AddNotify({type = "error", text = "ไม่สามารถขอความช่วยเหลือได้"})
		end
	end

	AddEventHandler('playerSpawned', function()
		if NeedHelp then
			NeedHelp = nil
			if acase then
				TriggerServerEvent(scriptName..':UpdateCase', acase, "done")
			end
			acase = nil
		end
	end)

	local DeathReported = false
	Citizen.CreateThread(function()
		while true do
			local sleep = 2000
			local playerData = ESX and ESX.GetPlayerData and ESX.GetPlayerData()

			if playerData and playerData.job and playerData.job.name == "ambulance" then
				sleep = 800
				local ped = PlayerPedId()
				if IsEntityDead(ped) then
					if not DeathReported then
						DeathReported = true
						TriggerServerEvent(scriptName..':ReleaseAcceptedCases')
					end
				else
					DeathReported = false
				end
			else
				DeathReported = false
			end

			Citizen.Wait(sleep)
		end
	end)

	function SetNewTable()
		local newtable = {}
		AlertCaseIndexMap = {}
		for _, caseData in pairs(AlertData) do
			newtable[#newtable + 1] = caseData
			if caseData.caseid then
				AlertCaseIndexMap[tonumber(caseData.caseid)] = #newtable
			end
		end
		AlertData = newtable
	end

	function removeBrTags(inputString)
		return inputString:gsub("<br>", "")
	end


	RegisterNetEvent(scriptName..':RepeatCaseAlert')
	AddEventHandler(scriptName..':RepeatCaseAlert', function(caseData)
		if ESX.GetPlayerData().job.name ~= "ambulance" then
			return
		end

		if type(caseData) ~= 'table' then
			return
		end

		local pressCount = tonumber(caseData.pressedCount) or 1
		local previewText = "คนสลบกดเรียกเคสซ้ำ"
		if caseData.name and caseData.phone then
			previewText = ("มีคนสลบกดเรียกเคสซ้ำ"):format(caseData.name, caseData.phone, pressCount)
		end

		TriggerEvent("APEX-AllNotify:AddAlert",{
			job = "ambulance",
			text = previewText,
			waypoint = true,
			time = 12.5,
			coords = caseData.coords,
			case = caseData.caseid
		})
	end)

	RegisterNetEvent(scriptName..':AddMedicCase')
	AddEventHandler(scriptName..':AddMedicCase', function(newdata,newcase)
		if ESX.GetPlayerData().job.name == "ambulance" then
			if newcase then
				-- SendNUIMessage({type = 'AlertUI', text = removeBrTags(newcase)})
				local previewText = "คนสลบกดเรียกเคส"
				if newdata and newdata.name and newdata.phone then
					previewText = ("มีคนสลบกดเรียกเคส"):format(newdata.name, newdata.phone)
				end
				TriggerEvent("APEX-AllNotify:AddAlert",{
					job = "ambulance",
					text = previewText,
					waypoint = true,
					time = 12.5,
					coords = newdata.coords,
					case = newdata.caseid
				})
			end
			newdata.time = newdata.servertime
			newdata.remain = tonumber(newdata.remain) or Config["DefaultCaseRemainSeconds"] or 2700
			newdata.pressedCount = tonumber(newdata.pressedCount) or 1
			newdata.remaintext = string.format("%02d:%02d", math.floor(newdata.remain / 60), newdata.remain % 60)
			table.insert(AlertData, newdata)
			if newdata.caseid then
				AlertCaseIndexMap[tonumber(newdata.caseid)] = #AlertData
			end
			RefreshTabletUI()
		end
	end)

	RegisterNetEvent(scriptName..':UpdateCase')
	AddEventHandler(scriptName..':UpdateCase', function(caseid,status,text,ac,pressedCount)
		if ESX.GetPlayerData().job.name == "ambulance" then
			if status == -1 then
				AlertData = {}
				AlertCaseIndexMap = {}
			else
				local lookupCaseId = tonumber(caseid)
				local index = AlertCaseIndexMap[lookupCaseId]
				local targetCase = index and AlertData[index]

				if targetCase then
					if status == 0 then
						AlertData[index] = nil
						AlertCaseIndexMap[lookupCaseId] = nil
					else
						targetCase.text = text
						targetCase.status = status
						targetCase.pressedCount = tonumber(pressedCount) or targetCase.pressedCount
						if status == 2 and ac ~= nil then
							targetCase.ac = ac
						end
					end
				else
					for k, v in pairs(AlertData) do
						if tonumber(v.caseid) == lookupCaseId then
							AlertCaseIndexMap[lookupCaseId] = k
							if status == 0 then
								AlertData[k] = nil
								AlertCaseIndexMap[lookupCaseId] = nil
							else
								AlertData[k].text = text
								AlertData[k].status = status
								AlertData[k].pressedCount = tonumber(pressedCount) or AlertData[k].pressedCount
								if status == 2 and ac ~= nil then
									AlertData[k].ac = ac
								end
							end
							break
						end
					end
				end
			end
			RefreshTabletUI()
		end
	end)

	RegisterNetEvent(scriptName..':UpdateCaseBulk')
	AddEventHandler(scriptName..':UpdateCaseBulk', function(caseUpdates)
		if ESX.GetPlayerData().job.name ~= "ambulance" then
			return
		end

		if type(caseUpdates) ~= 'table' or #caseUpdates == 0 then
			return
		end

		for _, caseUpdate in ipairs(caseUpdates) do
			local lookupCaseId = tonumber(caseUpdate.caseid)
			local status = tonumber(caseUpdate.status)
			local text = caseUpdate.text
			local ac = caseUpdate.ac

			if lookupCaseId then
				local index = AlertCaseIndexMap[lookupCaseId]
				local targetCase = index and AlertData[index]

				if targetCase then
					if status == 0 then
						AlertData[index] = nil
						AlertCaseIndexMap[lookupCaseId] = nil
					else
						targetCase.status = status or targetCase.status
						targetCase.text = text or targetCase.text
						if status == 2 and ac ~= nil then
							targetCase.ac = ac
						end
					end
				else
					for k, v in pairs(AlertData) do
						if tonumber(v.caseid) == lookupCaseId then
							AlertCaseIndexMap[lookupCaseId] = k
							if status == 0 then
								AlertData[k] = nil
								AlertCaseIndexMap[lookupCaseId] = nil
							else
								AlertData[k].status = status or AlertData[k].status
								AlertData[k].text = text or AlertData[k].text
								if status == 2 and ac ~= nil then
									AlertData[k].ac = ac
								end
							end
							break
						end
					end
				end
			end
		end

		RefreshTabletUI()
	end)

	RegisterNetEvent(scriptName..':SyncCases')
	AddEventHandler(scriptName..':SyncCases', function(cases)
		if ESX.GetPlayerData().job.name ~= "ambulance" then
			return
		end

		AlertData = {}
		AlertCaseIndexMap = {}

		if type(cases) == 'table' then
			for _, caseData in ipairs(cases) do
				caseData.time = caseData.servertime or os.time()
				caseData.remain = tonumber(caseData.remain) or Config["DefaultCaseRemainSeconds"] or 2700
				caseData.pressedCount = tonumber(caseData.pressedCount) or 1
				caseData.remaintext = ConvertSecondsToClock(caseData.remain)
				table.insert(AlertData, caseData)
				if caseData.caseid then
					AlertCaseIndexMap[tonumber(caseData.caseid)] = #AlertData
				end
			end
		end

		RefreshTabletUI()
	end)

	function RefreshTabletUI()
		SetNewTable()
		-- print(ESX.DumpTable(AlertData))
		SendNUIMessage({type = 'RefreshCase', data = AlertData})
	end

	function UpdateCaseTimeUI()
		local timePayload = {}
		for _, v in pairs(AlertData) do
			table.insert(timePayload, {
				caseid = v.caseid,
				casetime = v.casetime,
				remaintext = v.remaintext
			})
		end

		SendNUIMessage({type = 'UpdateCaseTime', data = timePayload})
	end

	function ConvertSecondsToMinutes(seconds)
		local minutes = math.floor(seconds / 60) -- คำนวณนาที
		local remaining_seconds = seconds % 60 -- คำนวณวินาทีที่เหลือ
		return string.format("%d:%02d นาที", minutes, remaining_seconds) -- จัดรูปแบบข้อความ
	end

	function ConvertSecondsToClock(seconds)
		seconds = tonumber(seconds) or 0
		if seconds < 0 then
			seconds = 0
		end
		local minutes = math.floor(seconds / 60)
		local remaining_seconds = seconds % 60
		return string.format("%02d:%02d", minutes, remaining_seconds)
	end

	Citizen.CreateThread(function()
		while true do
			local hasCases = next(AlertData) ~= nil
			local sleep = hasCases and 1000 or 5000

			if hasCases then
				for _, v in pairs(AlertData) do
					v.time = v.time + 1
					v.casetime = ConvertSecondsToMinutes(v.time - v.servertime)
					v.remain = tonumber(v.remain) or Config["DefaultCaseRemainSeconds"] or 2700
					if v.remain > 0 and v.status ~= 3 then
						v.remain = v.remain - 1
					end
					v.remaintext = ConvertSecondsToClock(v.remain)
				end

				if ToggleUI then
					UpdateCaseTimeUI()
				end
			end

			Citizen.Wait(sleep)
		end
	end)

	function SetTablet(status)
		local Ped = PlayerPedId()
		if status then
			local anime = {
				dict = "amb@code_human_in_bus_passenger_idles@female@tablet@idle_a",
				anime = "idle_a",
				prop = "prop_cs_tablet",
				bone = 28422,
				PropPlacementPos = vector3(-0.05, 0.0, 0.0),
				PropPlacementRot = vector3(0.0, 0.0, 0.0),
			}
			LoadAnimDict(anime.dict)
			TaskPlayAnim(Ped, anime.dict ,anime.anime ,8.0, -8.0, -1, 49, 0, false, false, false )
			if not tablet then
				tablet = CreateObject(GetHashKey(anime.prop), GetEntityCoords(Ped), true, false, false)
				AttachEntityToEntity(tablet,  Ped,  GetPedBoneIndex(Ped, anime.bone), anime.PropPlacementPos,anime.PropPlacementRot,  false, false, false, false, 2, true)
				table.insert(ScriptEntity, tablet)
			end
			ESX.Streaming.RequestAnimDict(anime.dict, function()
				TaskPlayAnim(Ped, anime.dict, anime.anime, 8.0, -8, -1, 49, 0.0, false, false, false)
			end)
		else
			if tablet then
				ClearPedTasks(Ped)
				for k,v in pairs(ScriptEntity) do DeleteEntity(v) end
				tablet = nil
			end
		end
	end

	RegisterKeyMapping('ToggleTablet', 'Open Tablet', 'keyboard', "F4")

    RegisterCommand('ToggleTablet', function()
		if ESX.GetPlayerData().job.name == "ambulance" then
        	ToggleTablet(true)
		end
    end)

	RegisterNetEvent(scriptName..':UpdateId')
	AddEventHandler(scriptName..':UpdateId', function(id)
		if NeedHelp then
			acase = id
		end
	end)


	local function findCaseByCaseId(caseId)
		caseId = tonumber(caseId)
		if not caseId then
			return nil, nil
		end

		for index, caseData in pairs(AlertData) do
			if tonumber(caseData.caseid) == caseId then
				return index, caseData
			end
		end

		return nil, nil
	end

	function ToggleTablet(status)
		ToggleUI = status
		SetNuiFocus(ToggleUI, ToggleUI)
		SendNUIMessage({ type = 'Toggle', status = ToggleUI})
		SetTablet(ToggleUI)
		if not BlackList then
			TriggerServerEvent(scriptName..':LoadBlackList')
		end
	end

	RegisterNUICallback('exit', function()
		ToggleTablet(false)
	end)

	RegisterNUICallback('print', function(data)
		print(ESX.DumpTable(data.data))
	end)

	RegisterNUICallback('getcase', function(data, cb)
		if Waiting then
			if cb then cb('busy') end
			return
		end

		Waiting = true
		local _, caseData = findCaseByCaseId(data and data.caseid)
		if caseData then
			TriggerServerEvent(scriptName..':UpdateCase', caseData.caseid, "getcase")
			if cb then cb('ok') end
		else
			if cb then cb('not_found') end
		end

		Citizen.SetTimeout(1000, function()
			Waiting = false
		end)
	end)

	RegisterNUICallback('markGPS', function(data, cb)
		local _, caseData = findCaseByCaseId(data and data.caseid)
		if caseData then
			SetNewWaypoint(caseData.coords.x, caseData.coords.y)
			exports['APEX-AllNotify']:AddNotify({type = "success", text = "ปักหมุดเป้าหมายแล้ว"})
			if cb then cb('ok') end
			return
		end

		if cb then cb('not_found') end
	end)

	RegisterNetEvent(scriptName..':markGPS')
	AddEventHandler(scriptName..':markGPS', function(caseid)
		local _, caseData = findCaseByCaseId(caseid)
		if caseData then
			SetNewWaypoint(caseData.coords.x, caseData.coords.y)
		end
	end)

	RegisterNUICallback('DeleteCase', function(data, cb)
		if Waiting then
			if cb then cb('busy') end
			return
		end

		Waiting = true
		local _, caseData = findCaseByCaseId(data and data.caseid)
		if caseData and tonumber(caseData.status) == 3 then
			TriggerServerEvent(scriptName..':UpdateCase', caseData.caseid, "deletecase")
			if cb then cb('ok') end
		elseif caseData then
			exports['APEX-AllNotify']:AddNotify({type = "error", text = "ลบได้เฉพาะเคสที่ปลอดภัยแล้ว"})
			if cb then cb('invalid_status') end
		else
			if cb then cb('not_found') end
		end

		Citizen.SetTimeout(1000, function()
			Waiting = false
		end)
	end)

	RegisterNUICallback('RemoveAll', function(data, cb)
		if not Waiting then
			Waiting = true

			-- ลบเคสปลอดภัยในหน้าเราออกทันทีให้ UI อัปเดตตรงตามที่กด
			for i = #AlertData, 1, -1 do
				if tonumber(AlertData[i].status) == 3 then
					table.remove(AlertData, i)
				end
			end
			RefreshTabletUI()

			TriggerServerEvent(scriptName..':UpdateCase',-1, "deleteall")
			Citizen.Wait(1000)
			Waiting = false
		end

		if cb then cb('ok') end
	end)

	RegisterNUICallback('addblacklistnumber', function(data)
		if not Waiting then
			Waiting = true
			if data.number then
				TriggerServerEvent(scriptName..':AddBlackListNumber', tonumber(data.number), data.status)
				if data.status then
					exports['APEX-AllNotify']:AddNotify({type = "success", text = "เพิ่ม "..data.number.." ในรายการ BlackList แล้ว"})
				end
			end
			Citizen.Wait(1000)
			Waiting = false
		end
	end)

end
