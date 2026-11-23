-- 1인칭 사격 컨트롤: 뷰모델, 반동·탄퍼짐, 조준(ADS/스코프), 스페셜, 앉기, 바닥 색에 따른 이동속도
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ModelKit = require(ReplicatedStorage.Shared.ModelKit)
local SoundBank = require(script.Parent:WaitForChild("SoundBank"))

local player = Players.LocalPlayer
local WC = {}

local remotes, HUD, Effects
local enabled = false
local firing = false
local firedThisPress = false
local aiming = false
local crouched = false
local lastFire = 0
local spreadExtra = 0
local localInk = Config.InkMax
local viewmodel = nil
local kick = 0           -- 화면 반동(도)
local vmKick = 0         -- 뷰모델 반동
local baseHip = nil
local speedTimer = 0
local cellsFolder = nil
local uiMode = false

local function camera()
	return workspace.CurrentCamera
end

local function weapon()
	return Weapons.Get(player:GetAttribute("Weapon"))
end

local function teamColor()
	return player:GetAttribute("TeamColor") or Color3.new(1, 1, 1)
end

local function humanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

------------------------------------------------------------------------
-- 뷰모델
------------------------------------------------------------------------
local vmMuzzle = nil      -- 총구 표식 파트 (Blender 모델의 _Muzzle 또는 대체 모델)
local vmLength = 1.5

local function buildViewmodel()
	if viewmodel then
		viewmodel:Destroy()
	end
	local w = weapon()
	local skin = Cosmetics.ById[player:GetAttribute("Skin") or ""]
	local m, muzzle = ModelKit.Gun(w.Id, teamColor(), skin, skin and Cosmetics.MaterialOf(skin.Material) or nil)
	m.Name = "Viewmodel"
	m:PivotTo(CFrame.new())
	local _, size = m:GetBoundingBox()
	vmLength = math.max(size.Z, 0.8)
	vmMuzzle = muzzle
	m.Parent = camera()
	viewmodel = m
end

local function placeViewmodel(dt)
	if not viewmodel then
		return
	end
	local w = weapon()
	local cam = camera()
	local scoped = aiming and w.Scope
	for _, p in ipairs(viewmodel:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("Kind") ~= "Anchor" and p:GetAttribute("Kind") ~= "Muzzle" then
			p.LocalTransparencyModifier = scoped and 1 or 0
		end
	end
	-- Anchor(손잡이) 기준 위치: 오른쪽 아래(허리 사격) / 화면 가운데(조준)
	local hipOffset = CFrame.new(0.85, -0.95, -1.25)
	local adsOffset = CFrame.new(0, -0.62, -0.95)
	local offset = aiming and adsOffset or hipOffset
	local t = os.clock()
	local hum = humanoid()
	local moving = hum and hum.MoveDirection.Magnitude > 0.1
	local bob = moving and CFrame.new(math.sin(t * 9) * 0.05, math.abs(math.cos(t * 9)) * 0.05, 0) or CFrame.new()
	vmKick = vmKick * math.exp(-14 * dt)
	local cf = cam.CFrame * offset * bob * CFrame.new(0, 0, vmKick * 0.12) * CFrame.Angles(math.rad(vmKick * 3), 0, 0)
	viewmodel:PivotTo(cf)
end

local function muzzleCFrame()
	if vmMuzzle and vmMuzzle.Parent then
		return vmMuzzle.CFrame
	end
	return camera().CFrame
end

------------------------------------------------------------------------
-- 사격
------------------------------------------------------------------------
local function coneDir(dir, degrees)
	if degrees <= 0 then
		return dir
	end
	local r = math.rad(degrees)
	local a = math.random() * math.pi * 2
	local m = math.sqrt(math.random()) * r
	return (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(math.cos(a) * m, math.sin(a) * m, 0)).LookVector
end

local function currentSpread(w)
	local s = w.Spread + spreadExtra
	if w.HipSpread and not aiming then
		s = w.HipSpread
	end
	if aiming then
		s = s * 0.5
	end
	local hum = humanoid()
	if hum and hum.MoveDirection.Magnitude > 0.1 and not crouched then
		s = s + 0.6
	end
	if crouched then
		s = s * 0.8
	end
	return s
end

local function fire()
	local w = weapon()
	local now = os.clock()
	if now - lastFire < w.FireInterval then
		return
	end
	if localInk < w.InkCost then
		if now - lastFire > 0.35 then
			lastFire = now
			SoundBank.Play("low_ink", nil, 0.6)
			HUD.Banner("잉크 부족! 우리 색 위에서 빠르게 충전돼요", Color3.fromRGB(255, 120, 120))
		end
		return
	end
	local hum = humanoid()
	if not hum or hum.Health <= 0 then
		return
	end
	lastFire = now
	localInk = localInk - w.InkCost

	local cam = camera()
	local origin = cam.CFrame.Position
	local look = cam.CFrame.LookVector
	local spread = currentSpread(w)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, viewmodel, workspace:FindFirstChild("ClientFX"), workspace:FindFirstChild("FX") }
	local dirs = {}
	local color = teamColor()
	local muzzle = muzzleCFrame().Position
	for i = 1, w.Pellets do
		local d = coneDir(look, spread)
		dirs[i] = d
		local hit = workspace:Raycast(origin, d * w.Range, params)
		local to = hit and hit.Position or (origin + d * w.Range)
		Effects.Tracer(muzzle, to, color, w.Id == "Sniper" and 0.3 or 0.16)
	end
	remotes.Fire:FireServer(w.Id, origin, dirs)

	Effects.Muzzle(muzzleCFrame(), color)
	SoundBank.Play("fire_" .. string.lower(w.Id), nil, 0.55, 0.96 + math.random() * 0.08)
	kick = kick + w.Recoil
	vmKick = vmKick + math.min(1.5, w.Recoil * 0.35)
	spreadExtra = math.min(w.SpreadMax, spreadExtra + w.SpreadGrow)
	Effects.Shake(w.Recoil * 0.05)
end

local function special()
	if (player:GetAttribute("Special") or 0) < 1 then
		HUD.Banner("스페셜 게이지가 부족해요 — 더 칠하세요!", Color3.fromRGB(255, 220, 80))
		return
	end
	local cam = camera()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, viewmodel, workspace:FindFirstChild("ClientFX") }
	local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 70, params)
	local target = hit and hit.Position or (cam.CFrame.Position + cam.CFrame.LookVector * 70)
	remotes.Special:FireServer(target)
end

local function setAim(on)
	aiming = on
	local w = weapon()
	local fov = 70
	if on then
		fov = w.Scope and w.ScopeFov or 56
	end
	TweenService:Create(camera(), TweenInfo.new(0.12), { FieldOfView = fov }):Play()
	UserInputService.MouseDeltaSensitivity = (on and w.Scope) and 0.35 or 1
end

local function setCrouch(on)
	local hum = humanoid()
	if not hum then
		return
	end
	if baseHip == nil then
		baseHip = hum.HipHeight
	end
	crouched = on
	hum.HipHeight = on and math.max(0.4, baseHip - 1.1) or baseHip
end

------------------------------------------------------------------------
-- 바닥 색 → 이동 속도
------------------------------------------------------------------------
local function updateSpeed()
	local hum = humanoid()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		return
	end
	local active = ReplicatedStorage:FindFirstChild("ActiveCells")
	cellsFolder = active and active.Value
	if not cellsFolder then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { cellsFolder }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
	local owner = hit and hit.Instance:GetAttribute("Owner") or 0
	local mine = player:GetAttribute("OwnerId")
	local speed = Config.WalkSpeed
	if owner ~= 0 and owner == mine then
		speed = Config.WalkSpeedOwn
	elseif owner ~= 0 then
		speed = Config.WalkSpeedEnemy
	end
	if crouched then
		speed = speed * Config.CrouchSpeedMul
	end
	if aiming then
		speed = speed * 0.75
	end
	hum.WalkSpeed = speed
end

------------------------------------------------------------------------
-- 켜기 / 끄기
------------------------------------------------------------------------
local bindAll, unbindAll

local function enable()
	if enabled then
		return
	end
	enabled = true
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	UserInputService.MouseIconEnabled = false
	localInk = player:GetAttribute("Ink") or Config.InkMax
	buildViewmodel()
	if uiMode then
		WC.SetUIMode(true)
	else
		bindAll()
	end
end

local function disable()
	enabled = false
	firing = false
	unbindAll()
	setAim(false)
	setCrouch(false)
	player.CameraMode = Enum.CameraMode.Classic
	UserInputService.MouseIconEnabled = true
	if viewmodel then
		viewmodel:Destroy()
		viewmodel = nil
	end
	local hum = humanoid()
	if hum then
		hum.WalkSpeed = Config.WalkSpeed
	end
end

local function onAction(name, inputState)
	if not enabled then
		return Enum.ContextActionResult.Pass
	end
	local began = inputState == Enum.UserInputState.Begin
	if name == "SF_Fire" then
		firing = began
		if began then
			firedThisPress = false
		end
	elseif name == "SF_Aim" then
		setAim(began)
	elseif name == "SF_Special" and began then
		special()
	elseif name == "SF_Crouch" and began then
		setCrouch(not crouched)
	end
	return Enum.ContextActionResult.Sink
end

bindAll = function()
	ContextActionService:BindAction("SF_Fire", onAction, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("SF_Aim", onAction, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	ContextActionService:BindAction("SF_Special", onAction, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("SF_Crouch", onAction, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("SF_Fire", "발사")
	ContextActionService:SetTitle("SF_Aim", "조준")
	ContextActionService:SetTitle("SF_Special", "스페셜")
	ContextActionService:SetTitle("SF_Crouch", "앉기")
	ContextActionService:SetPosition("SF_Fire", UDim2.new(1, -150, 1, -150))
	ContextActionService:SetPosition("SF_Aim", UDim2.new(1, -230, 1, -110))
	ContextActionService:SetPosition("SF_Special", UDim2.new(1, -230, 1, -190))
	ContextActionService:SetPosition("SF_Crouch", UDim2.new(1, -90, 1, -220))
end

unbindAll = function()
	for _, n in ipairs({ "SF_Fire", "SF_Aim", "SF_Special", "SF_Crouch" }) do
		ContextActionService:UnbindAction(n)
	end
end

-- 피드백/관리자 창이 열려 있는 동안 1인칭 잠금 해제
function WC.SetUIMode(on)
	uiMode = on
	if not enabled then
		return
	end
	if on then
		firing = false
		setAim(false)
		unbindAll()
		player.CameraMode = Enum.CameraMode.Classic
		UserInputService.MouseIconEnabled = true
	else
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		UserInputService.MouseIconEnabled = false
		bindAll()
	end
end

function WC.Init(remoteFolder, hud, effects)
	remotes = remoteFolder
	HUD = hud
	Effects = effects

	player:GetAttributeChangedSignal("InMatch"):Connect(function()
		if player:GetAttribute("InMatch") then
			enable()
		else
			disable()
		end
	end)
	player:GetAttributeChangedSignal("Ink"):Connect(function()
		localInk = player:GetAttribute("Ink") or localInk
	end)
	player:GetAttributeChangedSignal("Skin"):Connect(function()
		if enabled then
			buildViewmodel()
		end
	end)
	player.CharacterAdded:Connect(function(char)
		baseHip = nil
		crouched = false
		aiming = false
		if enabled then
			task.defer(buildViewmodel)
		end
		local hum = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			firing = false
			setAim(false)
		end)
	end)

	-- 카메라 반동: 기본 카메라 갱신 직후에 덧붙임
	RunService:BindToRenderStep("SF_Recoil", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not enabled then
			return
		end
		kick = kick * math.exp(-10 * dt)
		local cam = camera()
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(kick), 0, 0) * Effects.ShakeOffset(dt)
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not enabled then
			return
		end
		local w = weapon()
		if firing then
			if w.Auto or not firedThisPress then
				local before = lastFire
				fire()
				if lastFire ~= before then
					firedThisPress = true
				end
			end
		end
		if os.clock() - lastFire > 0.15 then
			spreadExtra = math.max(0, spreadExtra - dt * 8)
		end
		placeViewmodel(dt)
		speedTimer = speedTimer + dt
		if speedTimer > 0.1 then
			speedTimer = 0
			updateSpeed()
		end
		HUD.Update(currentSpread(w) * 7, w.Id, aiming and w.Scope == true)
	end)
end

return WC
