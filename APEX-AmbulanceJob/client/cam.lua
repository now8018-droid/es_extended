local cam = nil
local isDead = false
local camLoopRunning = false
local lastDeadState = false

local angleY = 0.0
local angleZ = 0.0

local CAMERA_FOV = 50.0
local CAMERA_RADIUS = 6.0
local CAMERA_EXTRA_RADIUS = 0.5
local CAMERA_RAYCAST_INTERVAL = 125
local CAMERA_TARGET_REFRESH_MS = 33
local CAMERA_FOCUS_REFRESH_MS = 200
local CAMERA_IDLE_WAIT_MS = 8
local CAMERA_SMOOTH_SPEED = 12.0
local CAMERA_INPUT_THRESHOLD = 0.0005
local CAMERA_MOVE_EPSILON_SQ = 0.0004

local camState = {
	playerPed = 0,
	targetCoords = nil,
	currentCoords = nil,
	desiredCoords = nil,
	lastRaycastTime = 0,
	lastTargetRefresh = 0,
	lastFocusRefresh = 0,
	collisionRadius = CAMERA_RADIUS
}

local function clamp(value, minValue, maxValue)
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end

local function distSq(a, b)
	local dx = a.x - b.x
	local dy = a.y - b.y
	local dz = a.z - b.z
	return (dx * dx) + (dy * dy) + (dz * dz)
end

local function lerpCoords(from, to, t)
	return vector3(
		from.x + (to.x - from.x) * t,
		from.y + (to.y - from.y) * t,
		from.z + (to.z - from.z) * t
	)
end

local function getPlayerPedCached()
	if camState.playerPed ~= 0 and DoesEntityExist(camState.playerPed) then
		return camState.playerPed
	end

	camState.playerPed = PlayerPedId()
	return camState.playerPed
end

local function refreshTargetCoords(now)
	local playerPed = getPlayerPedCached()
	if playerPed == 0 or not DoesEntityExist(playerPed) then
		return nil
	end

	if not camState.targetCoords or (now - camState.lastTargetRefresh) >= CAMERA_TARGET_REFRESH_MS then
		camState.targetCoords = GetEntityCoords(playerPed)
		camState.lastTargetRefresh = now
	end

	return playerPed, camState.targetCoords
end

local function updateCameraAngles()
	local mouseX = GetDisabledControlNormal(1, 1) * (IsInputDisabled(0) and 8.0 or 1.5)
	local mouseY = GetDisabledControlNormal(1, 2) * (IsInputDisabled(0) and 8.0 or 1.5)
	local hasInput = math.abs(mouseX) > CAMERA_INPUT_THRESHOLD or math.abs(mouseY) > CAMERA_INPUT_THRESHOLD

	if hasInput then
		angleZ = angleZ - mouseX
		angleY = clamp(angleY + mouseY, -89.0, 89.0)
	end

	return hasInput
end

local function calculateDesiredCameraPosition(targetCoords, radius)
	local cosY, sinY = Cos(angleY), Sin(angleY)
	local cosZ, sinZ = Cos(angleZ), Sin(angleZ)

	return vector3(
		targetCoords.x + (cosZ * cosY) * radius,
		targetCoords.y + (sinZ * cosY) * radius,
		targetCoords.z + sinY * radius
	)
end

local function refreshCollisionRadius(now, playerPed, targetCoords, behindCam)
	if (now - camState.lastRaycastTime) < CAMERA_RAYCAST_INTERVAL then
		return camState.collisionRadius
	end

	camState.lastRaycastTime = now
	camState.collisionRadius = CAMERA_RADIUS

	local rayHandle = StartShapeTestRay(
		targetCoords.x, targetCoords.y, targetCoords.z + 0.5,
		behindCam.x, behindCam.y, behindCam.z,
		-1, playerPed, 0
	)

	local _, hitBool, hitCoords = GetShapeTestResult(rayHandle)
	if hitBool then
		local dx = targetCoords.x - hitCoords.x
		local dy = targetCoords.y - hitCoords.y
		local dz = (targetCoords.z + 0.5) - hitCoords.z
		local maxDistSq = (CAMERA_RADIUS + CAMERA_EXTRA_RADIUS) * (CAMERA_RADIUS + CAMERA_EXTRA_RADIUS)
		local hitDistSq = (dx * dx) + (dy * dy) + (dz * dz)

		if hitDistSq < maxDistSq then
			camState.collisionRadius = math.sqrt(hitDistSq)
		end
	end

	return camState.collisionRadius
end

local function updateCameraFrame(now)
	local playerPed, targetCoords = refreshTargetCoords(now)
	if not playerPed or not targetCoords or not cam then
		return CAMERA_IDLE_WAIT_MS
	end

	DisableFirstPersonCamThisFrame()

	local hasInput = updateCameraAngles()
	local maxRadius = CAMERA_RADIUS + CAMERA_EXTRA_RADIUS
	local collisionProbe = calculateDesiredCameraPosition(targetCoords, maxRadius)
	local collisionRadius = refreshCollisionRadius(now, playerPed, targetCoords, collisionProbe)
	local desiredCoords = calculateDesiredCameraPosition(targetCoords, collisionRadius)

	camState.desiredCoords = desiredCoords
	if not camState.currentCoords then
		camState.currentCoords = desiredCoords
	else
		local lerpFactor = clamp(GetFrameTime() * CAMERA_SMOOTH_SPEED, 0.0, 1.0)
		camState.currentCoords = lerpCoords(camState.currentCoords, desiredCoords, lerpFactor)
	end

	SetCamCoord(cam, camState.currentCoords.x, camState.currentCoords.y, camState.currentCoords.z)
	PointCamAtCoord(cam, targetCoords.x, targetCoords.y, targetCoords.z + 0.5)

	if (now - camState.lastFocusRefresh) >= CAMERA_FOCUS_REFRESH_MS
		or distSq(camState.currentCoords, desiredCoords) > CAMERA_MOVE_EPSILON_SQ
	then
		SetFocusArea(camState.currentCoords.x, camState.currentCoords.y, camState.currentCoords.z, 0.0, 0.0, 0.0)
		camState.lastFocusRefresh = now
	end

	if hasInput or distSq(camState.currentCoords, desiredCoords) > CAMERA_MOVE_EPSILON_SQ then
		return 0
	end

	return CAMERA_IDLE_WAIT_MS
end

local function startCamLoop()
	if camLoopRunning then return end
	camLoopRunning = true

	CreateThread(function()
		while isDead and cam do
			local waitMs = updateCameraFrame(GetGameTimer())
			Wait(waitMs)
		end

		camLoopRunning = false
	end)
end

function StartDeathCam()
	local playerPed = PlayerPedId()
	local coords = GetEntityCoords(playerPed)

	camState.playerPed = playerPed
	camState.targetCoords = coords
	camState.currentCoords = nil
	camState.desiredCoords = nil
	camState.lastRaycastTime = 0
	camState.lastTargetRefresh = 0
	camState.lastFocusRefresh = 0
	camState.collisionRadius = CAMERA_RADIUS

	ClearFocus()
	cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords, 0.0, 0.0, 0.0, CAMERA_FOV)
	SetCamActive(cam, true)
	RenderScriptCams(true, true, 1000, true, false)
	startCamLoop()
end

function EndDeathCam()
	ClearFocus()
	RenderScriptCams(false, false, 0, true, false)

	if cam then
		DestroyCam(cam, false)
		cam = nil
	end

	camState.playerPed = 0
	camState.targetCoords = nil
	camState.currentCoords = nil
	camState.desiredCoords = nil
	camState.lastRaycastTime = 0
	camState.lastTargetRefresh = 0
	camState.lastFocusRefresh = 0
	camState.collisionRadius = CAMERA_RADIUS
end

-- ใช้ OnPlayerData callback แทน polling เพื่อลด CPU usage
function OnPlayerData(key, val)
	if key == 'dead' then
		local dead = val or false
		if dead and not lastDeadState then
			isDead = true
			StartDeathCam()
			lastDeadState = true
		elseif not dead and lastDeadState then
			isDead = false
			EndDeathCam()
			lastDeadState = false
		end
	end
end

-- Fallback: ตรวจสอบเมื่อเริ่มต้น (กรณีที่ OnPlayerData ยังไม่ถูกเรียก)
CreateThread(function()
	while not ESX or not ESX.PlayerData do
		Wait(100)
	end

	local initialDead = ESX.PlayerData.dead or false
	if initialDead and not lastDeadState then
		isDead = true
		StartDeathCam()
		lastDeadState = true
	end
end)
