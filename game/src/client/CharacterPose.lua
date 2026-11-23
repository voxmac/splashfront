-- 캐릭터 자세 (클라이언트): 경기 중인 모든 캐릭터(플레이어·봇)
--  · 조준: 총을 앞으로 겨누고 상체·머리·팔이 조준 각도(AimPitch)를 나눠서 따라감
--  · 달리기: 상체를 숙이고 총을 비스듬히 내려 듦 · 걷기: 몸을 낮추고 조심스럽게 · 앉기: 무릎을 굽힌 자세 (움직이면 종종걸음)
--  · 사격 반동: 팔이 위로 튀었다가 돌아옴
-- 애니메이션 에셋 없이 Motor6D.Transform을 Roblox 기본 애니메이션 다음 단계에서 덮어씀
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Pose = {}

local kicks = setmetatable({}, { __mode = "k" })  -- model -> 반동 각도(도)
local cache = setmetatable({}, { __mode = "k" })  -- model -> 관절
local smooth = setmetatable({}, { __mode = "k" }) -- model -> { Pitch, Run, Crouch, Walk }
local localStance = "Normal"

function Pose.Kick(model, recoil)
	if model then
		kicks[model] = math.min(28, (kicks[model] or 0) + 7 + (recoil or 1) * 2.5)
	end
end

function Pose.SetLocalStance(s)
	localStance = s or "Normal"
end

local function find(model, partName, jointName)
	local p = model:FindFirstChild(partName)
	return p and p:FindFirstChild(jointName)
end

local function jointsOf(model)
	local j = cache[model]
	if j and j.RS and j.RS.Parent then
		return j
	end
	j = {
		RS = find(model, "RightUpperArm", "RightShoulder"), LS = find(model, "LeftUpperArm", "LeftShoulder"),
		RE = find(model, "RightLowerArm", "RightElbow"), LE = find(model, "LeftLowerArm", "LeftElbow"),
		RW = find(model, "RightHand", "RightWrist"), LW = find(model, "LeftHand", "LeftWrist"),
		Waist = find(model, "UpperTorso", "Waist"), Neck = find(model, "Head", "Neck"),
		LH = find(model, "LeftUpperLeg", "LeftHip"), RH = find(model, "RightUpperLeg", "RightHip"),
		LK = find(model, "LeftLowerLeg", "LeftKnee"), RK = find(model, "RightLowerLeg", "RightKnee"),
		LA = find(model, "LeftFoot", "LeftAnkle"), RA = find(model, "RightFoot", "RightAnkle"),
	}
	if not j.RS then
		j.R6 = true
		j.RS = find(model, "Torso", "Right Shoulder")
		j.LS = find(model, "Torso", "Left Shoulder")
	end
	cache[model] = j
	return j
end

local function armed(model)
	if not model or not model:FindFirstChild("SF_Gun") then
		return false
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function rad(d)
	return math.rad(d)
end

local function pose(model, pitchDeg, stance, dt)
	local j = jointsOf(model)
	if not j.RS then
		return
	end
	local sm = smooth[model]
	if not sm then
		sm = { Pitch = pitchDeg, Run = 0, Crouch = 0, Walk = 0, T = 0 }
		smooth[model] = sm
	end
	local k = 1 - math.exp(-12 * dt)
	sm.Pitch = sm.Pitch + (pitchDeg - sm.Pitch) * k
	sm.Run = sm.Run + (((stance == "Run") and 1 or 0) - sm.Run) * k
	sm.Crouch = sm.Crouch + (((stance == "Crouch") and 1 or 0) - sm.Crouch) * k
	sm.Walk = sm.Walk + (((stance == "Walk") and 1 or 0) - sm.Walk) * k
	local kick = kicks[model] or 0
	if kick > 0.05 then
		kicks[model] = kick * math.exp(-14 * dt)
	end
	local p = sm.Pitch
	local run, crouch, walk = sm.Run, sm.Crouch, sm.Walk

	if j.R6 then
		local raise = rad(90 + p * 0.8 + kick - run * 45)
		j.RS.Transform = CFrame.Angles(0, 0, raise)
		if j.LS then
			j.LS.Transform = CFrame.Angles(0, 0, -raise) * CFrame.Angles(rad(30), 0, 0)
		end
		return
	end

	-- 상체·머리가 조준 각도의 일부를 맡음 (달리기는 앞으로 숙임, 걷기는 살짝 웅크림)
	if j.Waist then
		j.Waist.Transform = CFrame.Angles(rad(p * 0.3 - run * 14 - walk * 6 - crouch * 8), 0, 0)
	end
	if j.Neck then
		j.Neck.Transform = CFrame.Angles(rad(p * 0.35 + run * 10 + crouch * 6), 0, 0)
	end

	-- 팔: 조준 자세 ↔ 달리기 들기 자세
	local armPitch = 90 + p * 0.35 + kick
	local runDown = run * 48
	j.RS.Transform = CFrame.Angles(0, rad(8 + run * 22), 0) * CFrame.Angles(rad(armPitch - runDown), 0, 0)
	if j.RE then
		j.RE.Transform = CFrame.Angles(rad(run * 25), 0, 0)
	end
	if j.RW then
		j.RW.Transform = CFrame.new()
	end
	if j.LS then
		j.LS.Transform = CFrame.Angles(0, rad(-42 + run * 10), 0) * CFrame.Angles(rad(armPitch - 6 - runDown), 0, 0)
	end
	if j.LE then
		j.LE.Transform = CFrame.Angles(rad(18 + run * 20), 0, 0)
	end
	if j.LW then
		j.LW.Transform = CFrame.new()
	end

	-- 앉기: 무릎을 굽힘 (움직이면 좌우 번갈아 종종걸음). 기본 걷기 다리 동작 위에 섞음
	if crouch > 0.02 then
		local root = model:FindFirstChild("HumanoidRootPart")
		local v = root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude or 0
		sm.T = sm.T + dt * (v > 1 and 7 or 0)
		local step = (v > 1) and math.sin(sm.T) * 14 or 0
		for _, side in ipairs({ { j.LH, j.LK, j.LA, 1 }, { j.RH, j.RK, j.RA, -1 } }) do
			local hip, knee, ankle, sgn = side[1], side[2], side[3], side[4]
			if hip and knee then
				local h = (70 + step * sgn) * crouch
				hip.Transform = hip.Transform:Lerp(CFrame.Angles(rad(h), 0, 0), crouch)
				knee.Transform = knee.Transform:Lerp(CFrame.Angles(rad(-105 * crouch), 0, 0), crouch)
				if ankle then
					ankle.Transform = ankle.Transform:Lerp(CFrame.Angles(rad(35 * crouch), 0, 0), crouch)
				end
			end
		end
	end
end

function Pose.Init()
	local signal = RunService.PreSimulation or RunService.Stepped
	signal:Connect(function(a, b)
		local dt = (type(b) == "number") and b or a -- Stepped(time, dt) / PreSimulation(dt)
		local cam = workspace.CurrentCamera
		local myPitch = 0
		if cam then
			myPitch = math.deg(math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1)))
		end
		for _, pl in ipairs(Players:GetPlayers()) do
			local c = pl.Character
			if c and pl:GetAttribute("InMatch") and armed(c) then
				if pl == player then
					pose(c, math.clamp(myPitch, -70, 70), localStance, dt)
				else
					pose(c, pl:GetAttribute("AimPitch") or 0, pl:GetAttribute("Stance") or "Normal", dt)
				end
			end
		end
		local bots = workspace:FindFirstChild("Bots")
		if bots then
			for _, m in ipairs(bots:GetChildren()) do
				if armed(m) then
					pose(m, m:GetAttribute("AimPitch") or 0, "Normal", dt)
				end
			end
		end
	end)
end

return Pose
