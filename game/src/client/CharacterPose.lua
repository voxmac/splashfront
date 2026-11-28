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
local slashes = setmetatable({}, { __mode = "k" }) -- model -> { T = 1→0, Heavy }
local throws = setmetatable({}, { __mode = "k" })  -- model -> T 1→0 (수류탄 던지기)

function Pose.Kick(model, recoil)
	if model then
		kicks[model] = math.min(28, (kicks[model] or 0) + 7 + (recoil or 1) * 2.5)
	end
end

-- 칼 휘두르기 (다른 사람에게도 보이는 3인칭 동작)
function Pose.Slash(model, heavy)
	if model then
		slashes[model] = { T = 1, Heavy = heavy == true, Side = -((slashes[model] and slashes[model].Side) or -1) }
	end
end

-- 수류탄 던지기 (오른팔을 뒤로 젖혔다가 앞으로)
function Pose.Throw(model)
	if model then
		throws[model] = 1
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

local function knifeInHand(model)
	local k = model and model:FindFirstChild("SF_Knife")
	return k ~= nil and k:GetAttribute("InHand") == true
end

local function armed(model)
	if not model or not (model:FindFirstChild("SF_Gun") or knifeInHand(model)) then
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
		sm = { Pitch = pitchDeg, Run = 0, Crouch = 0, Walk = 0, Slide = 0, T = 0 }
		smooth[model] = sm
	end
	local k = 1 - math.exp(-12 * dt)
	sm.Pitch = sm.Pitch + (pitchDeg - sm.Pitch) * k
	sm.Run = sm.Run + (((stance == "Run") and 1 or 0) - sm.Run) * k
	sm.Crouch = sm.Crouch + (((stance == "Crouch") and 1 or 0) - sm.Crouch) * k
	sm.Walk = sm.Walk + (((stance == "Walk") and 1 or 0) - sm.Walk) * k
	sm.Slide = sm.Slide + (((stance == "Slide") and 1 or 0) - sm.Slide) * (1 - math.exp(-18 * dt))
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

	-- 칼을 든 경우: 오른팔은 칼을 앞쪽 아래로 쥐고, 휘두르면 크게 가로지름
	if knifeInHand(model) then
		local sl = slashes[model]
		local s, sweep = 0, 0
		if sl then
			sl.T = sl.T - dt / (sl.Heavy and 0.42 or 0.3)
			if sl.T <= 0 then
				slashes[model] = nil
			else
				local prog = 1 - sl.T
				s = math.sin(prog * math.pi)
				sweep = (prog - 0.5) * 2 * sl.Side
			end
		end
		local heavy = sl and sl.Heavy
		local raise = 45 + p * 0.3 - run * 25 + (heavy and 50 * s or 35 * s)
		j.RS.Transform = CFrame.Angles(0, rad(heavy and 0 or -55 * sweep), 0) * CFrame.Angles(rad(raise), 0, 0)
		if j.RE then
			j.RE.Transform = CFrame.Angles(rad(heavy and 10 * (1 - s) or 25), 0, 0)
		end
		if j.LS then
			j.LS.Transform = CFrame.Angles(0, rad(-20), 0) * CFrame.Angles(rad(35 - run * 20), 0, 0)
		end
		if j.LE then
			j.LE.Transform = CFrame.Angles(rad(40), 0, 0)
		end
	end

	-- 팔: 조준 자세 ↔ 달리기 들기 자세
	local armPitch = 90 + p * 0.35 + kick
	local runDown = run * 48
	if not knifeInHand(model) then
		j.RS.Transform = CFrame.Angles(0, rad(8 + run * 22), 0) * CFrame.Angles(rad(armPitch - runDown), 0, 0)
		if j.RE then
			j.RE.Transform = CFrame.Angles(rad(run * 25), 0, 0)
		end
		if j.LS then
			j.LS.Transform = CFrame.Angles(0, rad(-42 + run * 10), 0) * CFrame.Angles(rad(armPitch - 6 - runDown), 0, 0)
		end
		if j.LE then
			j.LE.Transform = CFrame.Angles(rad(18 + run * 20), 0, 0)
		end
	end
	if j.RW then
		j.RW.Transform = CFrame.new()
	end
	if j.LW then
		j.LW.Transform = CFrame.new()
	end

	-- 던지기: 오른팔을 머리 뒤로 젖혔다가 앞으로 내리꽂음 (다른 동작 위에 덮어씀)
	local th = throws[model]
	if th then
		th = th - dt / 0.5
		if th <= 0 then
			throws[model] = nil
		else
			throws[model] = th
			local p = 1 - th
			local raise = (p < 0.45) and (p / 0.45) * 170 or 170 - ((p - 0.45) / 0.55) * 150
			j.RS.Transform = CFrame.Angles(rad(raise), 0, rad(-15))
			if j.RE then
				j.RE.Transform = CFrame.Angles(rad((p < 0.45) and 60 or 10), 0, 0)
			end
			if j.Waist then
				j.Waist.Transform = j.Waist.Transform * CFrame.Angles(0, rad((p < 0.45) and 20 or -15), 0)
			end
		end
	end

	-- 슬라이드: 상체를 뒤로 젖히고, 오른다리는 앞으로 쭉 · 왼다리는 접어서 미끄러짐
	local slide = sm.Slide
	if slide > 0.02 then
		if j.Waist then
			j.Waist.Transform = j.Waist.Transform:Lerp(CFrame.Angles(rad(28), 0, rad(-6)), slide)
		end
		if j.Neck then
			j.Neck.Transform = j.Neck.Transform:Lerp(CFrame.Angles(rad(-18), 0, 0), slide)
		end
		if j.RH and j.RK then
			j.RH.Transform = j.RH.Transform:Lerp(CFrame.Angles(rad(75), 0, 0), slide)
			j.RK.Transform = j.RK.Transform:Lerp(CFrame.Angles(rad(-8), 0, 0), slide)
		end
		if j.LH and j.LK then
			j.LH.Transform = j.LH.Transform:Lerp(CFrame.Angles(rad(30), 0, rad(-12)), slide)
			j.LK.Transform = j.LK.Transform:Lerp(CFrame.Angles(rad(-110), 0, 0), slide)
		end
		if j.LA then
			j.LA.Transform = j.LA.Transform:Lerp(CFrame.Angles(rad(30), 0, 0), slide)
		end
		return
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
