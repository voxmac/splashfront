-- 접속 연출 (ReplicatedFirst): 기본 로딩 화면 대신 SF 로딩 화면을 띄우고, 캐릭터가 로비에 생기면
-- 격납고 유리 천장 위에서 카메라가 떨어지듯 내려와 캐릭터 뒤에 붙으며 화면이 열림 (하늘·빈 공간이 보이지 않게)
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

local gui = Instance.new("ScreenGui")
gui.Name = "SF_Loading"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(1, 1, 1)
bg.BorderSizePixel = 0
bg.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 34, 70)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(10, 13, 28)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 5, 12)),
})
grad.Rotation = 90
grad.Parent = bg

-- 네온 사선 줄
local stripes = {}
for i = 0, 5 do
	local s = Instance.new("Frame")
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Size = UDim2.new(0, 10, 1.6, 0)
	s.Position = UDim2.new(0.08 + i * 0.17, 0, 0.5, 0)
	s.Rotation = 24
	s.BorderSizePixel = 0
	s.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(255, 40, 200) or Color3.fromRGB(240, 255, 40)
	s.BackgroundTransparency = 0.86
	s.Parent = bg
	table.insert(stripes, s)
end

local function text(props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1, 1, 1)
	t.FontFace = HEAVY
	t.TextScaled = true
	for k, v in pairs(props) do
		t[k] = v
	end
	t.Parent = bg
	return t
end
local t1 = text({ Text = "SPLASH", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromScale(0.6, 0.16),
	TextColor3 = Color3.fromRGB(255, 70, 200) })
local t2 = text({ Text = "FRONT", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.42, 0.12),
	TextColor3 = Color3.fromRGB(60, 220, 255) })
for _, t in ipairs({ t1, t2 }) do
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = Color3.fromRGB(10, 10, 24)
	st.Parent = t
end
local status = text({ Text = "격납고에 연결하는 중", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(0.5, 0.04),
	TextColor3 = Color3.fromRGB(200, 210, 240) })
local tips = {
	"바닥을 더 많이 칠한 팀이 승리해요",
	"같은 ZONE 발판에 선 친구끼리 한 팀",
	"Shift 달리기 · C 앉기 · V 1·3인칭",
	"일일·주간 미션을 깨고 코인으로 스킨을 사세요",
}
local tip = text({ Text = tips[math.random(1, #tips)], AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.9), Size = UDim2.fromScale(0.6, 0.032),
	TextColor3 = Color3.fromRGB(150, 160, 200), FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold) })

-- 진행 막대 (끝없이 흐르는 네온)
local barBg = Instance.new("Frame")
barBg.AnchorPoint = Vector2.new(0.5, 0.5)
barBg.Position = UDim2.fromScale(0.5, 0.76)
barBg.Size = UDim2.new(0.32, 0, 0, 6)
barBg.BackgroundColor3 = Color3.fromRGB(30, 38, 70)
barBg.BorderSizePixel = 0
barBg.ClipsDescendants = true
barBg.Parent = bg
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0.3, 1)
bar.BackgroundColor3 = Color3.fromRGB(240, 255, 40)
bar.BorderSizePixel = 0
bar.Parent = barBg

local done = false
task.spawn(function()
	local dots = 0
	while not done do
		local tw = TweenService:Create(bar, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Position = UDim2.fromScale(1, 0) })
		bar.Position = UDim2.fromScale(-0.3, 0)
		tw:Play()
		dots = dots % 3 + 1
		if status.Text:find("연결") or status.Text:find("불러") then
			status.Text = status.Text:gsub("%.+$", "") .. string.rep(".", dots)
		end
		task.wait(0.9)
	end
end)

-- 1) 게임 데이터 로드
if not game:IsLoaded() then
	game.Loaded:Wait()
end
status.Text = "프로필 불러오는 중"

-- 2) 로비에 캐릭터가 생길 때까지
local function lobbyCharacter()
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	-- 캐릭터가 로비에 있고, 프로필(코인)과 로비 UI까지 준비됐을 때 화면을 엶
	local pg = player:FindFirstChild("PlayerGui")
	if root and root.Position.Y > 300 and player:GetAttribute("Coins") ~= nil and pg and pg:FindFirstChild("SplashLobby") then
		return c, root
	end
	return nil
end
local char, root = lobbyCharacter()
local t0 = os.clock()
while not char and os.clock() - t0 < 60 do
	task.wait(0.1)
	char, root = lobbyCharacter()
end
task.wait(0.4) -- 로비 조명·UI가 자리 잡을 시간
status.Text = "출격!"

-- 3) 낙하 연출: 유리 천장 위 → 캐릭터 뒤 (1.9초), 화면은 밝게 열림
local cam = workspace.CurrentCamera
if char and root and cam then
	local target = root.CFrame
	-- 도착 지점 = Roblox 기본 카메라가 지금 잡고 있는 위치 (그래야 연출이 끝나고 넘겨줄 때 튀지 않음)
	cam.CameraType = Enum.CameraType.Custom
	cam.CameraSubject = char:FindFirstChildOfClass("Humanoid")
	for _ = 1, 4 do
		RunService.RenderStepped:Wait()
	end
	local endCf = cam.CFrame
	if (endCf.Position - target.Position).Magnitude > 40 then
		endCf = CFrame.lookAt(target.Position + target.LookVector * -11 + Vector3.new(0, 5, 0), target.Position + Vector3.new(0, 2, 0))
	end
	local startPos = target.Position + Vector3.new(0, 95, 18)
	local startCf = CFrame.lookAt(startPos, target.Position)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = startCf
	local fov0 = cam.FieldOfView
	cam.FieldOfView = 95
	local fade = TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	fade:Play()
	for _, d in ipairs(bg:GetDescendants()) do
		if d:IsA("TextLabel") then
			TweenService:Create(d, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			local st = d:FindFirstChildOfClass("UIStroke")
			if st then
				TweenService:Create(st, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			end
		elseif d:IsA("Frame") then
			TweenService:Create(d, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		end
	end
	local dur = 1.9
	local start = os.clock()
	while true do
		local a = math.clamp((os.clock() - start) / dur, 0, 1)
		local e = 1 - (1 - a) ^ 3 -- 처음 빠르게 떨어지고 끝에서 부드럽게 멈춤
		cam.CFrame = startCf:Lerp(endCf, e)
		cam.FieldOfView = fov0 + (95 - fov0) * (1 - e)
		if a >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	cam.FieldOfView = fov0
	cam.CFrame = endCf
	cam.CameraType = Enum.CameraType.Custom
else
	TweenService:Create(bg, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
end
done = true
task.wait(0.5)
gui:Destroy()
