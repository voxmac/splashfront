-- 캐릭터 자세 (클라이언트): 경기 중인 모든 캐릭터(플레이어·봇)가 총을 앞으로 겨누는 자세 + 사격 반동
-- 애니메이션 에셋 없이 어깨·팔꿈치 Motor6D.Transform을 애니메이션 다음 단계에서 덮어씀
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Pose = {}

local kicks = setmetatable({}, { __mode = "k" })  -- model -> 반동 각도(도)
local cache = setmetatable({}, { __mode = "k" })  -- model -> 관절

function Pose.Kick(model, recoil)
	if model then
		kicks[model] = math.min(28, (kicks[model] or 0) + 7 + (recoil or 1) * 2.5)
	end
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
	}
	if not j.RS then
		-- R6
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

local function pose(model, pitchDeg, dt)
	local j = jointsOf(model)
	if not j.RS then
		return
	end
	local k = kicks[model] or 0
	if k > 0.05 then
		kicks[model] = k * math.exp(-14 * dt)
	end
	local raise = math.rad(90 + pitchDeg + k)
	if j.R6 then
		j.RS.Transform = CFrame.Angles(0, 0, raise)
		if j.LS then
			j.LS.Transform = CFrame.Angles(0, 0, -raise) * CFrame.Angles(math.rad(30), 0, 0)
		end
		return
	end
	-- 오른팔: 앞으로 쭉 (살짝 안쪽), 왼팔: 총 앞부분을 받치도록 안쪽으로
	j.RS.Transform = CFrame.Angles(0, math.rad(8), 0) * CFrame.Angles(raise, 0, 0)
	if j.RE then
		j.RE.Transform = CFrame.new()
	end
	if j.RW then
		j.RW.Transform = CFrame.new()
	end
	if j.LS then
		j.LS.Transform = CFrame.Angles(0, math.rad(-42), 0) * CFrame.Angles(raise - math.rad(6), 0, 0)
	end
	if j.LE then
		j.LE.Transform = CFrame.Angles(math.rad(18), 0, 0)
	end
	if j.LW then
		j.LW.Transform = CFrame.new()
	end
end

function Pose.Init()
	local signal = RunService.PreSimulation or RunService.Stepped
	signal:Connect(function(a, b)
		local dt = (type(b) == "number") and b or a -- Stepped(time, dt) / PreSimulation(dt)
		-- 내 캐릭터: 카메라 위아래 각도를 따라 총을 듦
		local cam = workspace.CurrentCamera
		local myPitch = 0
		if cam then
			myPitch = math.deg(math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1)))
		end
		for _, pl in ipairs(Players:GetPlayers()) do
			local c = pl.Character
			if c and pl:GetAttribute("InMatch") and armed(c) then
				pose(c, (pl == player) and math.clamp(myPitch, -60, 60) or 0, dt)
			end
		end
		local bots = workspace:FindFirstChild("Bots")
		if bots then
			for _, m in ipairs(bots:GetChildren()) do
				if armed(m) then
					pose(m, 0, dt)
				end
			end
		end
	end)
end

return Pose
