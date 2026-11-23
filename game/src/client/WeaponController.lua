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
local CharacterPose = require(script.Parent:WaitForChild("CharacterPose"))

local player = Players.LocalPlayer
local WC = {}

local remotes, HUD, Effects
local enabled = false
local firing = false
local firedThisPress = false
local aiming = false
local crouched = false
local running = false      -- Shift 누르는 동안
local walking = false      -- Z로 켜고 끔
local runBlockedUntil = 0  -- 쏜 직후 잠깐은 달리기 속도 안 붙음
local touchRun = false     -- 모바일 달리기 버튼
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
local thirdPerson = false -- V 키로 1인칭 ↔ 3인칭(어깨 시점) 전환
local modalGui = nil      -- 창이 열려 있는 동안 마우스를 풀어 주는 투명 버튼
local TP_ZOOM = 8         -- 3인칭 카메라 거리
local TP_OFFSET = Vector3.new(2.8, 1.5, 0) -- 어깨 너머: 캐릭터가 화면 왼쪽 아래로 비켜서 조준점을 가리지 않음

-- 3인칭이 실제로 적용 중인지 (3인칭에서도 우클릭 조준 중에는 1인칭 조준경으로 전환)
local function tpActive()
	return thirdPerson and not aiming
end

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

-- 조준 배율: 총마다 ZoomFov, 3배·6배 스코프 아이템이 있으면 더 크게. 반환: 시야각, 조준점 모양, 배율 글자
local function zoomInfo(w)
	local fov = w.ZoomFov or 56
	local buff = player:GetAttribute("ZoomBuff")
	local untilT = player:GetAttribute("ZoomUntil")
	if buff and untilT and untilT > workspace:GetServerTimeNow() then
		fov = math.min(fov, 70 / buff)
	else
		buff = nil
	end
	local sight = (w.Scope or buff) and "Scope" or (w.Sight or "Dot")
	local mag = 70 / fov
	local txt = (sight == "Scope") and string.format("%.1fx", mag) or nil
	return fov, sight, txt
end
WC.ZoomInfo = zoomInfo
local goldenSpent = false

-- 1인칭 총 모형은 1인칭일 때만, 스코프로 볼 때는 숨김
function WC.UpdateViewmodelParent()
	if not viewmodel then
		return
	end
	local w = weapon()
	local _, sight = zoomInfo(w)
	local show = enabled and not tpActive() and not (aiming and sight == "Scope")
	viewmodel.Parent = show and camera() or nil
end

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
	-- 카툰 외곽선 (셀 셰이딩 느낌)
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.fromRGB(18, 16, 28)
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = m
	if player:GetAttribute("Golden") then
		ModelKit.SetGolden(m, true)
	end
	viewmodel = m
	WC.UpdateViewmodelParent()
end

local vm = { Aim = 0, Run = 0, Crouch = 0, Phase = 0, SwayX = 0, SwayY = 0, Land = 0, LastLook = nil }
local currentStance = "Normal"
local lastPoseSent, lastPitchSent, lastStanceSent = 0, 999, ""

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
	local adsOffset = CFrame.new(0, -0.8, -1.0) -- 조준점 아래로 내려 표적이 가리지 않게
	local hum = humanoid()
	local speed = (hum and hum.RootPart) and Vector3.new(hum.RootPart.AssemblyLinearVelocity.X, 0, hum.RootPart.AssemblyLinearVelocity.Z).Magnitude or 0
	local k = 1 - math.exp(-12 * dt)
	vm.Aim = vm.Aim + ((aiming and 1 or 0) - vm.Aim) * k
	vm.Run = vm.Run + ((currentStance == "Run" and 1 or 0) - vm.Run) * k
	vm.Crouch = vm.Crouch + ((crouched and 1 or 0) - vm.Crouch) * k
	-- 걷는 속도에 맞춘 흔들림 (조준 중엔 거의 없음)
	vm.Phase = vm.Phase + dt * (4 + speed * 0.45)
	local amp = math.clamp(speed / 16, 0, 1.6) * (0.045 + vm.Run * 0.05) * (1 - vm.Aim * 0.85)
	local bob = CFrame.new(math.sin(vm.Phase) * amp, -math.abs(math.cos(vm.Phase)) * amp * 0.9, 0) * CFrame.Angles(0, 0, math.sin(vm.Phase) * amp * 0.6)
	-- 화면을 돌리면 총이 살짝 늦게 따라옴 (무게감)
	local look = cam.CFrame.LookVector
	if vm.LastLook then
		local d = cam.CFrame:VectorToObjectSpace(vm.LastLook)
		vm.SwayX = vm.SwayX + (math.clamp(d.X * 3, -0.12, 0.12) - vm.SwayX) * k
		vm.SwayY = vm.SwayY + (math.clamp(d.Y * 3, -0.12, 0.12) - vm.SwayY) * k
	end
	vm.LastLook = look
	local sway = CFrame.new(vm.SwayX * (1 - vm.Aim * 0.7), vm.SwayY * (1 - vm.Aim * 0.7), 0) * CFrame.Angles(vm.SwayY * 0.6, vm.SwayX * 0.8, 0)
	-- 달리기: 총을 비스듬히 내려 듦 / 앉기: 살짝 낮게 / 착지: 툭 내려앉음
	local runPose = CFrame.new(0.25 * vm.Run, -0.3 * vm.Run - 0.06 * vm.Crouch - vm.Land, 0.1 * vm.Run)
		* CFrame.Angles(math.rad(-18) * vm.Run, math.rad(38) * vm.Run, math.rad(12) * vm.Run)
	vm.Land = vm.Land * math.exp(-10 * dt)
	vmKick = vmKick * math.exp(-14 * dt)
	local base = hipOffset:Lerp(adsOffset, vm.Aim)
	local cf = cam.CFrame * base * runPose * sway * bob * CFrame.new(0, 0, vmKick * 0.12) * CFrame.Angles(math.rad(vmKick * 3), 0, 0)
	viewmodel:PivotTo(cf)
end

local function muzzleCFrame()
	if tpActive() then
		local g = player.Character and player.Character:FindFirstChild("SF_Gun")
		if g then
			for _, p in ipairs(g:GetDescendants()) do
				if p:IsA("BasePart") and p:GetAttribute("Kind") == "Muzzle" then
					return p.CFrame
				end
			end
			return g:GetPivot()
		end
	end
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
	local moving = hum and hum.MoveDirection.Magnitude > 0.1
	if moving and not crouched then
		if running and not aiming then
			s = s + 1.4
		elseif not walking then
			s = s + 0.6
		end
	end
	if walking then
		s = s * 0.7
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
	local golden = player:GetAttribute("Golden") == true and not goldenSpent
	if not golden and localInk < w.InkCost then
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
	runBlockedUntil = now + 0.4
	if golden then
		goldenSpent = true
	else
		localInk = localInk - w.InkCost
	end

	local cam = camera()
	local origin = cam.CFrame.Position
	local look = cam.CFrame.LookVector
	local spread = golden and 0 or currentSpread(w)
	local range = golden and Config.GoldenRange or w.Range
	local pellets = golden and 1 or w.Pellets
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, viewmodel, workspace:FindFirstChild("ClientFX"), workspace:FindFirstChild("FX") }
	if tpActive() then
		-- 3인칭: 조준점이 가리키는 곳을 먼저 찾고, 실제 총알은 머리에서 그쪽으로
		local head = player.Character and player.Character:FindFirstChild("Head")
		if head then
			local aimHit = workspace:Raycast(origin, look * w.Range, params)
			local aimPoint = aimHit and aimHit.Position or (origin + look * w.Range)
			origin = head.Position
			local d = aimPoint - origin
			if d.Magnitude > 0.5 then
				look = d.Unit
			end
		end
	end
	local dirs = {}
	local color = golden and Color3.fromRGB(255, 205, 40) or teamColor()
	local muzzle = muzzleCFrame().Position
	local claims = {}
	for i = 1, pellets do
		local d = coneDir(look, spread)
		dirs[i] = d
		local hit = workspace:Raycast(origin, d * range, params)
		local to = hit and hit.Position or (origin + d * range)
		Effects.Tracer(muzzle, to, color, golden and 0.6 or (w.Id == "Sniper" and 0.3 or 0.16))
		if hit then
			Effects.WallSplat(hit.Instance, hit.Position, hit.Normal, color)
		end
		-- 내 화면에서 캐릭터를 맞혔으면 서버에 알림 (서버가 위치·시야를 검증해 인정)
		if hit then
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			while model and not model:FindFirstChildOfClass("Humanoid") do
				model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
			end
			if model then
				claims[i] = { Part = hit.Instance, Pos = hit.Position }
			end
		end
	end
	remotes.Fire:FireServer(w.Id, origin, dirs, claims)

	Effects.Muzzle(muzzleCFrame(), color)
	SoundBank.Play("fire_" .. string.lower(w.Id), nil, 0.55, 0.96 + math.random() * 0.08)
	-- 화면 반동은 작게(복귀 포함), 손맛은 총 모형 반동으로
	kick = math.min(kick + w.Recoil * 0.35, 4)
	vmKick = vmKick + math.min(1.5, w.Recoil * 0.4)
	CharacterPose.Kick(player.Character, w.Recoil)
	spreadExtra = math.min(w.SpreadMax, spreadExtra + w.SpreadGrow)
	Effects.Shake(w.Recoil * 0.02)
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

local applyViewRef = nil
local function setAim(on)
	aiming = on
	local w = weapon()
	local fov = 70
	if on then
		fov = zoomInfo(w)
	end
	TweenService:Create(camera(), TweenInfo.new(0.12), { FieldOfView = fov }):Play()
	-- 확대한 만큼 감도를 낮춰 정밀 조준
	UserInputService.MouseDeltaSensitivity = on and math.clamp(fov / 70, 0.15, 1) or 1
	if thirdPerson and applyViewRef then
		applyViewRef() -- 3인칭 ↔ 1인칭 조준 전환
	end
	WC.UpdateViewmodelParent()
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
	-- Shift를 누르고 있으면 달리기 (입력 이벤트를 놓쳐도 키 상태로 한 번 더 확인)
	running = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL3) or touchRun
	local mode = "일반"
	if crouched then
		speed = speed * Config.CrouchSpeedMul
		mode = "앉기"
	elseif running and not aiming and os.clock() > runBlockedUntil and hum.MoveDirection.Magnitude > 0.1 then
		speed = speed * Config.RunSpeedMul
		mode = "달리기"
	elseif walking then
		speed = speed * Config.WalkSpeedMul
		mode = "걷기"
	end
	if aiming then
		speed = speed * 0.75
	end
	hum.WalkSpeed = speed
	if HUD and HUD.SetMove then
		HUD.SetMove(mode)
	end
	currentStance = (mode == "앉기" and "Crouch") or (mode == "달리기" and "Run") or (mode == "걷기" and "Walk") or "Normal"
	CharacterPose.SetLocalStance(currentStance)
end

------------------------------------------------------------------------
-- 켜기 / 끄기
------------------------------------------------------------------------
local bindAll, unbindAll

local function setModal(on)
	if not modalGui then
		modalGui = Instance.new("ScreenGui")
		modalGui.Name = "SF_Modal"
		modalGui.ResetOnSpawn = false
		modalGui.DisplayOrder = -10
		local b = Instance.new("TextButton")
		b.Name = "Modal"
		b.Size = UDim2.fromOffset(1, 1)
		b.BackgroundTransparency = 1
		b.Text = ""
		b.Modal = true -- 1인칭에서도 마우스 커서를 풀어 줌 (Roblox 공식 방법)
		b.Parent = modalGui
		modalGui.Parent = player:WaitForChild("PlayerGui")
	end
	modalGui.Enabled = on
end

-- 카메라를 강제로 바깥으로 빼서 1인칭 잠금을 확실히 풀기
local function zoomOut(dist)
	player.CameraMinZoomDistance = dist
	player.CameraMaxZoomDistance = math.max(dist, 20)
	task.delay(0.15, function()
		if not enabled or uiMode then
			player.CameraMinZoomDistance = 0.5
			player.CameraMaxZoomDistance = 40
		end
	end)
end

-- 현재 상태(1인칭/3인칭/창 열림)에 맞게 카메라 적용
local function applyView()
	local hum = humanoid()
	if not enabled then
		return
	end
	if uiMode then
		player.CameraMode = Enum.CameraMode.Classic
		UserInputService.MouseIconEnabled = true
		setModal(true)
		return
	end
	setModal(false)
	if tpActive() then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = TP_ZOOM
		player.CameraMinZoomDistance = TP_ZOOM
		if hum then
			hum.CameraOffset = TP_OFFSET
			hum.AutoRotate = false
		end
	else
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 40
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		if hum then
			hum.CameraOffset = Vector3.zero
			hum.AutoRotate = true
		end
	end
	UserInputService.MouseIconEnabled = false
	WC.UpdateViewmodelParent()
end

applyViewRef = applyView

function WC.ToggleView()
	thirdPerson = not thirdPerson
	applyView()
	if HUD and HUD.Banner then
		HUD.Banner(thirdPerson and "3인칭 시점 [V]" or "1인칭 시점 [V]", Color3.fromRGB(200, 220, 255))
	end
end

local function enable()
	if enabled then
		return
	end
	enabled = true
	localInk = player:GetAttribute("Ink") or Config.InkMax
	buildViewmodel()
	if uiMode then
		WC.SetUIMode(true)
	else
		applyView()
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
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	setModal(uiMode)
	zoomOut(12) -- 로비에서는 3인칭 + 마우스 자유
	if viewmodel then
		viewmodel:Destroy()
		viewmodel = nil
	end
	local hum = humanoid()
	if hum then
		hum.WalkSpeed = Config.WalkSpeed
		hum.CameraOffset = Vector3.zero
		hum.AutoRotate = true
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
		if crouched then
			running = false
		end
	elseif name == "SF_Run" then
		touchRun = (inputState == Enum.UserInputState.Begin) and UserInputService.TouchEnabled
		running = (inputState == Enum.UserInputState.Begin)
		if running and crouched then
			setCrouch(false)
		end
		updateSpeed()
	elseif name == "SF_Walk" and began then
		walking = not walking
		HUD.Banner(walking and "걷기 (조용히 · 정밀 사격) [Z]" or "일반 이동", Color3.fromRGB(200, 220, 255))
		updateSpeed()
	elseif name == "SF_View" and began then
		WC.ToggleView()
	end
	return Enum.ContextActionResult.Sink
end

bindAll = function()
	ContextActionService:BindAction("SF_Fire", onAction, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("SF_Aim", onAction, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	ContextActionService:BindAction("SF_Special", onAction, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("SF_Crouch", onAction, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("SF_Run", onAction, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("SF_Walk", onAction, false, Enum.KeyCode.Z)
	ContextActionService:SetTitle("SF_Run", "달리기")
	ContextActionService:SetPosition("SF_Run", UDim2.new(1, -170, 1, -220))
	ContextActionService:BindAction("SF_View", onAction, true, Enum.KeyCode.V, Enum.KeyCode.DPadUp)
	ContextActionService:SetTitle("SF_Fire", "발사")
	ContextActionService:SetTitle("SF_Aim", "조준")
	ContextActionService:SetTitle("SF_Special", "스페셜")
	ContextActionService:SetTitle("SF_Crouch", "앉기")
	ContextActionService:SetPosition("SF_Fire", UDim2.new(1, -150, 1, -150))
	ContextActionService:SetPosition("SF_Aim", UDim2.new(1, -230, 1, -110))
	ContextActionService:SetPosition("SF_Special", UDim2.new(1, -230, 1, -190))
	ContextActionService:SetPosition("SF_Crouch", UDim2.new(1, -90, 1, -220))
	ContextActionService:SetTitle("SF_View", "시점")
	ContextActionService:SetPosition("SF_View", UDim2.new(1, -90, 1, -300))
end

unbindAll = function()
	running = false
	for _, n in ipairs({ "SF_Fire", "SF_Aim", "SF_Special", "SF_Crouch", "SF_View", "SF_Run", "SF_Walk" }) do
		ContextActionService:UnbindAction(n)
	end
end

-- 피드백/관리자 창이 열려 있는 동안 1인칭 잠금 해제
function WC.SetUIMode(on)
	uiMode = on
	if not enabled then
		-- 로비: 카메라는 이미 3인칭, 커서만 확실히 풀어 줌
		setModal(on)
		if on then
			zoomOut(12)
		end
		return
	end
	if on then
		firing = false
		setAim(false)
		unbindAll()
		applyView()
	else
		applyView()
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
	player:GetAttributeChangedSignal("Golden"):Connect(function()
		if player:GetAttribute("Golden") then
			goldenSpent = false
			HUD.Banner("황금총 장전! 다음 1발은 맞으면 즉사", Color3.fromRGB(255, 210, 60))
		end
		if enabled then
			buildViewmodel()
		end
	end)
	player:GetAttributeChangedSignal("ZoomBuff"):Connect(function()
		if aiming then
			setAim(true)
		end
	end)
	player:GetAttributeChangedSignal("Skin"):Connect(function()
		if enabled then
			buildViewmodel()
		end
	end)
	-- 무기가 바뀌면(스폰 지점 교체) 1인칭 총 모형·잉크 갱신
	player:GetAttributeChangedSignal("Weapon"):Connect(function()
		if enabled then
			setAim(false)
			spreadExtra = 0
			localInk = Config.InkMax
			buildViewmodel()
			SoundBank.Play("ui_buy", nil, 0.5)
		end
	end)
	-- 스폰 지점 무기 교체: 숫자 1~6 = 무기 목록 순서, T = 다음 보유 무기
	local NUM = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }
	local function ownedList()
		local s = "," .. (player:GetAttribute("Owned") or "") .. ","
		local out = {}
		for _, w in ipairs(Weapons.List) do
			if string.find(s, "," .. w.Id .. ",", 1, true) then
				table.insert(out, w.Id)
			end
		end
		return out
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not enabled or uiMode then
			return
		end
		local target = nil
		for i, k in ipairs(NUM) do
			if input.KeyCode == k then
				local w = Weapons.List[i]
				target = w and w.Id
			end
		end
		if input.KeyCode == Enum.KeyCode.T then
			local list = ownedList()
			local cur = player:GetAttribute("Weapon")
			for i, id in ipairs(list) do
				if id == cur then
					target = list[(i % #list) + 1]
				end
			end
			target = target or list[1]
		end
		if not target or target == player:GetAttribute("Weapon") then
			return
		end
		if not player:GetAttribute("SpawnZone") then
			HUD.Banner("무기 교체는 스폰 지점에서만 가능해요 (부활 직후 " .. Config.WeaponSwitchGrace .. "초)", Color3.fromRGB(255, 200, 90))
			return
		end
		remotes.SwitchWeapon:FireServer(target)
	end)
	player.CharacterAdded:Connect(function(char)
		baseHip = nil
		crouched = false
		aiming = false
		if enabled then
			task.defer(function()
				buildViewmodel()
				applyView()
			end)
		end
		local hum = char:WaitForChild("Humanoid")
		hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed then
				vm.Land = 0.18 -- 착지할 때 총이 툭 내려앉음
			end
		end)
		hum.Died:Connect(function()
			firing = false
			setAim(false)
		end)
	end)

	-- 카메라 반동: 기본 카메라 갱신 직후에 덧붙임
	RunService:BindToRenderStep("SF_Mouse", Enum.RenderPriority.Camera.Value + 2, function()
		if uiMode then
			-- 창이 열려 있으면 어떤 시점이든 커서 자유
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			return
		end
		if not enabled then
			return
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if tpActive() and root then
			-- 어깨 시점: 몸이 카메라가 보는 방향을 따라 돎
			local look = camera().CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		end
		-- 1인칭: 내 헬멧·가방·손에 든 총이 화면을 가리지 않게 숨김
		if char then
			local hide = tpActive() and 0 or 1
			for _, n in ipairs({ "SF_Helmet", "SF_Backpack", "SF_Gun", "SF_Armor", "SF_Jetpack" }) do
				local g = char:FindFirstChild(n)
				if g then
					for _, p in ipairs(g:GetDescendants()) do
						if p:IsA("BasePart") then
							p.LocalTransparencyModifier = hide
						end
					end
				end
			end
		end
	end)

	-- 카메라 반동: 기본 카메라는 매 프레임 '지난 프레임 카메라 방향'에서 출발하므로
	-- 반동을 통째로 매번 더하면 계속 쌓여 하늘로 솟구침(0.5 버그). 지난 프레임에 더한 만큼 빼고 새 값만 적용
	local lastOffset = CFrame.new()
	RunService:BindToRenderStep("SF_Recoil", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local cam = camera()
		if not enabled or uiMode then
			lastOffset = CFrame.new()
			kick = 0
			return
		end
		kick = kick * math.exp(-14 * dt) -- 빠르게 원위치 (조준점 복귀)
		local offset = CFrame.Angles(math.rad(kick), 0, 0) * Effects.ShakeOffset(dt)
		cam.CFrame = cam.CFrame * lastOffset:Inverse() * offset
		lastOffset = offset
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
		-- 달릴 때 시야가 살짝 넓어져 속도감 (조준 중엔 조준 배율 유지)
		if not aiming then
			local cam = camera()
			local target = (currentStance == "Run") and 78 or 70
			cam.FieldOfView = cam.FieldOfView + (target - cam.FieldOfView) * (1 - math.exp(-8 * dt))
		end
		-- 내 조준 각도·자세를 다른 사람에게 공유 (상체가 조준 방향을 따라 움직이게)
		local t = os.clock()
		if t - lastPoseSent > 0.12 and remotes:FindFirstChild("Pose") then
			local pitch = math.deg(math.asin(math.clamp(camera().CFrame.LookVector.Y, -1, 1)))
			if math.abs(pitch - lastPitchSent) >= 2 or currentStance ~= lastStanceSent then
				lastPoseSent, lastPitchSent, lastStanceSent = t, pitch, currentStance
				remotes.Pose:FireServer(pitch, currentStance)
			end
		end
		speedTimer = speedTimer + dt
		if speedTimer > 0.1 then
			speedTimer = 0
			updateSpeed()
		end
		local _, sight, ztxt = zoomInfo(w)
		HUD.Update(currentSpread(w) * 7, w.Id, aiming and sight or nil, aiming and ztxt or nil)
	end)
end

return WC
