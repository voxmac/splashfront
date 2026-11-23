-- 맵 장치(클라이언트): 점프패드 발사, 집라인 탑승
-- 캐릭터 물리는 클라이언트 소유라서 플레이어 이동은 여기서 처리 (봇은 서버 MapBuilder가 처리)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local SoundBank = require(script.Parent:WaitForChild("SoundBank"))

local player = Players.LocalPlayer
local MapInteract = {}

local Effects
local lastPad = 0
local riding = nil -- { From, To, T, Len }
local rideSound = nil
local ZIP_SPEED = 48
local HANG = 3.5

local function rootAndHum()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

local function checkPads()
	if os.clock() - lastPad < 0.8 then
		return
	end
	local root, hum = rootAndHum()
	if not root or not hum or hum.Health <= 0 then
		return
	end
	for _, pad in ipairs(CollectionService:GetTagged("SF_JumpPad")) do
		local localPos = pad.CFrame:PointToObjectSpace(root.Position)
		if math.abs(localPos.X) < pad.Size.X / 2 + 0.5 and math.abs(localPos.Z) < pad.Size.Z / 2 + 0.5 and localPos.Y > 0 and localPos.Y < 5 then
			local launch = pad:GetAttribute("Launch")
			if launch then
				lastPad = os.clock()
				root.AssemblyLinearVelocity = launch
				hum:ChangeState(Enum.HumanoidStateType.Freefall)
				Effects.Splash(pad.Position + Vector3.new(0, 1, 0), pad.Color, 3)
				SoundBank.Play("jump_pad", nil, 0.8)
				return
			end
		end
	end
end

local function stopRide(jumpOff)
	if not riding then
		return
	end
	local root, hum = rootAndHum()
	local dir = (riding.To - riding.From).Unit
	riding = nil
	if rideSound then
		rideSound:Destroy()
		rideSound = nil
	end
	SoundBank.Play("land", nil, 0.5)
	if root then
		root.AssemblyLinearVelocity = dir * ZIP_SPEED * 0.6 + Vector3.new(0, jumpOff and 30 or 0, 0)
	end
	if hum then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function startRide(pole)
	local from, to = pole:GetAttribute("ZipFrom"), pole:GetAttribute("ZipTo")
	local root, hum = rootAndHum()
	if not from or not to or not root or not hum or hum.Health <= 0 or riding then
		return
	end
	riding = { From = from, To = to, T = 0, Len = (to - from).Magnitude }
	hum.PlatformStand = true
	SoundBank.Play("zipline_start", nil, 0.7)
	rideSound = SoundBank.Play("zipline_ride", nil, 0.45, 1, true)
end

local function updateRide(dt)
	if not riding then
		return
	end
	local root, hum = rootAndHum()
	if not root or not hum or hum.Health <= 0 then
		riding = nil
		if rideSound then
			rideSound:Destroy()
			rideSound = nil
		end
		return
	end
	riding.T = riding.T + (ZIP_SPEED * dt) / riding.Len
	if riding.T >= 1 then
		stopRide(false)
		return
	end
	local p = riding.From:Lerp(riding.To, riding.T) - Vector3.new(0, HANG, 0)
	-- 위치만 강제하고 회전은 그대로 → 1인칭으로 주변을 보며 공중에서 사격 가능
	root.CFrame = CFrame.new(p) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = (riding.To - riding.From).Unit * ZIP_SPEED
end

function MapInteract.Init(effects)
	Effects = effects
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local pole = prompt.Parent
		if pole and CollectionService:HasTag(pole, "SF_Zipline") then
			startRide(pole)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and riding and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA) then
			stopRide(true) -- 스페이스로 중간에 뛰어내리기
		end
	end)
	player.CharacterAdded:Connect(function()
		riding = nil
		if rideSound then
			rideSound:Destroy()
			rideSound = nil
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		updateRide(dt)
		if not riding then
			checkPads()
		end
	end)
end

function MapInteract.IsRiding()
	return riding ~= nil
end

return MapInteract
