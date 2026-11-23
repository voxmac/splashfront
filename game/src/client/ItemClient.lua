-- 미션 보상 아이템 (클라이언트): F 사용 · G 순서 바꾸기 · 제트팩 추진(Space) · 연막탄 조준점
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local SoundBank = require(script.Parent:WaitForChild("SoundBank"))

local player = Players.LocalPlayer
local ItemClient = {}

local remotes, HUD
local lastJetSound = 0

local function aimPoint()
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("ClientFX"), workspace:FindFirstChild("PaintLayer") }
	local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 75, params)
	return hit and hit.Position or (cam.CFrame.Position + cam.CFrame.LookVector * 75)
end

local function items()
	local s = player:GetAttribute("Items") or ""
	local out = {}
	for x in string.gmatch(s, "[^,]+") do
		table.insert(out, x)
	end
	return out
end

local function useItem()
	if not player:GetAttribute("InMatch") then
		return
	end
	local list = items()
	if #list == 0 then
		HUD.Banner("아이템이 없어요 — 미션을 성공하면 받아요", Color3.fromRGB(200, 200, 220))
		return
	end
	remotes.UseItem:FireServer("use", aimPoint())
	SoundBank.Play("ui_buy", nil, 0.5)
end

local function onAction(name, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if name == "SF_UseItem" then
		useItem()
	elseif name == "SF_CycleItem" then
		remotes.UseItem:FireServer("cycle")
	end
	return Enum.ContextActionResult.Sink
end

function ItemClient.Init(remoteFolder, hud)
	remotes = remoteFolder
	HUD = hud
	local function bind()
		if player:GetAttribute("InMatch") then
			ContextActionService:BindAction("SF_UseItem", onAction, true, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
			ContextActionService:BindAction("SF_CycleItem", onAction, false, Enum.KeyCode.G, Enum.KeyCode.DPadRight)
			ContextActionService:SetTitle("SF_UseItem", "아이템")
			ContextActionService:SetPosition("SF_UseItem", UDim2.new(1, -170, 1, -300))
		else
			ContextActionService:UnbindAction("SF_UseItem")
			ContextActionService:UnbindAction("SF_CycleItem")
		end
	end
	player:GetAttributeChangedSignal("InMatch"):Connect(bind)
	bind()

	-- 새 아이템 획득 연출
	player:GetAttributeChangedSignal("LastItem"):Connect(function()
		local v = player:GetAttribute("LastItem")
		local id = v and string.match(v, "^(%w+):")
		if id then
			HUD.ItemToast(id)
		end
	end)
	for _, a in ipairs({ "Items", "JetpackUntil", "ShieldUntil", "ZoomBuff", "Golden" }) do
		player:GetAttributeChangedSignal(a):Connect(function()
			HUD.UpdateItems()
		end)
	end

	-- 제트팩: 효과 시간 동안 Space(모바일은 점프 버튼)를 누르고 있으면 상승
	RunService.Heartbeat:Connect(function(dt)
		local untilT = player:GetAttribute("JetpackUntil")
		if not untilT or workspace:GetServerTimeNow() > untilT then
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.Health <= 0 then
			return
		end
		local thrusting = UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
			or (UserInputService.TouchEnabled and hum.Jump)
		if thrusting then
			local v = root.AssemblyLinearVelocity
			local up = math.min(v.Y + (workspace.Gravity + Config.JetpackThrust) * dt, Config.JetpackMaxRise)
			root.AssemblyLinearVelocity = Vector3.new(v.X, up, v.Z)
			if hum:GetState() ~= Enum.HumanoidStateType.Freefall and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
				hum:ChangeState(Enum.HumanoidStateType.Freefall)
			end
			if os.clock() - lastJetSound > 0.35 then
				lastJetSound = os.clock()
				SoundBank.Play("zipline_ride", root.Position, 0.35, 1.6)
			end
		end
	end)
	HUD.UpdateItems()
end

return ItemClient
