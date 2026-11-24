-- 클로즈 테스트 UI: 피드백 창(모든 테스터) + 관리자 패널(F2, 관리자만)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local CBT = {}

local remotes, HUD
local gui, feedbackFrame, adminFrame, reportBox, feedbackBtn
local rating = 0
local modalHandler = function() end
local category = "Fun"

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function corner(p, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
end

local function button(parent, text, color, props)
	local b = make("TextButton", { Text = text, BackgroundColor3 = color or Color3.fromRGB(60, 60, 80), TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = true }, parent)
	corner(b, 8)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	return b
end

local function label(parent, props)
	local t = make("TextLabel", { BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, parent)
	for k, v in pairs(props) do
		t[k] = v
	end
	return t
end

------------------------------------------------------------------------
-- 피드백 창
------------------------------------------------------------------------
local starButtons = {}
local catButtons = {}

local function refreshFeedback()
	for i, b in ipairs(starButtons) do
		b.TextColor3 = (i <= rating) and Color3.fromRGB(255, 210, 40) or Color3.fromRGB(90, 90, 110)
	end
	for id, b in pairs(catButtons) do
		b.BackgroundColor3 = (id == category) and Color3.fromRGB(255, 46, 170) or Color3.fromRGB(60, 60, 80)
	end
end

function CBT.OpenFeedback()
	feedbackFrame.Visible = true
	modalHandler(true)
	refreshFeedback()
end

local function buildFeedback()
	feedbackFrame = make("Frame", { Size = UDim2.fromOffset(460, 330), Position = UDim2.new(0.5, -230, 0.5, -165), BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		Visible = false, ZIndex = 30 }, gui)
	corner(feedbackFrame, 14)
	make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(0, 214, 200) }, feedbackFrame)
	label(feedbackFrame, { Text = "테스트 피드백", TextSize = 22, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 30), ZIndex = 31 })
	label(feedbackFrame, { Text = "이번 판 어땠나요?", Position = UDim2.fromOffset(18, 48), Size = UDim2.new(1, -36, 0, 20), ZIndex = 31,
		TextColor3 = Color3.fromRGB(190, 190, 210), Font = Enum.Font.Gotham })
	for i = 1, 5 do
		local b = make("TextButton", { Text = tostring(i), TextSize = 30, Font = Enum.Font.GothamBlack, BackgroundTransparency = 1,
			Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(14 + (i - 1) * 42, 70), ZIndex = 31 }, feedbackFrame)
		b.MouseButton1Click:Connect(function()
			rating = i
			refreshFeedback()
		end)
		starButtons[i] = b
	end
	local cats = { { "Bug", "버그" }, { "Balance", "밸런스" }, { "Fun", "재미" }, { "Other", "기타" } }
	for i, c in ipairs(cats) do
		local b = button(feedbackFrame, c[2], nil, { Size = UDim2.fromOffset(96, 30), Position = UDim2.fromOffset(18 + (i - 1) * 106, 118), ZIndex = 31 })
		b.MouseButton1Click:Connect(function()
			category = c[1]
			refreshFeedback()
		end)
		catButtons[c[1]] = b
	end
	local box = make("TextBox", { Size = UDim2.new(1, -36, 0, 100), Position = UDim2.fromOffset(18, 158), BackgroundColor3 = Color3.fromRGB(36, 36, 50),
		TextColor3 = Color3.new(1, 1, 1), PlaceholderText = "자유롭게 적어주세요 (버그는 어디서·무엇을 하다가 생겼는지)", Text = "",
		ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, TextSize = 14, ZIndex = 31 }, feedbackFrame)
	corner(box, 8)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingRight = UDim.new(0, 8) }, box)
	local send = button(feedbackFrame, "보내기", Color3.fromRGB(0, 170, 160), { Size = UDim2.fromOffset(140, 38), Position = UDim2.new(1, -158, 1, -52), ZIndex = 31 })
	UI.CloseButton(feedbackFrame, function()
		feedbackFrame.Visible = false
		modalHandler(adminFrame ~= nil and adminFrame.Visible)
	end, 36).ZIndex = 35
	send.MouseButton1Click:Connect(function()
		if rating == 0 then
			HUD.Banner("별점을 먼저 골라주세요", Color3.fromRGB(255, 200, 80))
			return
		end
		local ok, res = pcall(function()
			return remotes.Feedback:InvokeServer(rating, category, box.Text)
		end)
		if ok and res then
			HUD.Banner(res.msg, res.ok and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(255, 120, 120))
			if res.ok then
				box.Text = ""
				rating = 0
				feedbackFrame.Visible = false
				modalHandler(adminFrame ~= nil and adminFrame.Visible)
			end
		end
	end)
end

------------------------------------------------------------------------
-- 관리자 패널
------------------------------------------------------------------------
local function admin(action, arg)
	local ok, res = pcall(function()
		return remotes.Admin:InvokeServer(action, arg)
	end)
	if ok and res then
		local text = tostring(res.msg)
		if string.find(text, "\n") then
			reportBox.Text = text
		else
			HUD.Banner(text, res.ok and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(255, 120, 120))
		end
	end
end

local function buildAdmin()
	if adminFrame then
		adminFrame:Destroy()
	end
	adminFrame = make("Frame", { Size = UDim2.fromOffset(900, 500), Position = UDim2.new(0.5, -450, 0.5, -250), BackgroundColor3 = Color3.fromRGB(16, 16, 24),
		BackgroundTransparency = 0.05, Visible = false, ZIndex = 40 }, gui)
	corner(adminFrame, 12)
	make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 196, 0) }, adminFrame)
	local dev = player:GetAttribute("DevTools") == true
	label(adminFrame, { Text = (dev and "개발자 패널 (F2) · 빌드 " or "운영자 패널 (F2) · 빌드 ") .. Config.Build, TextSize = 18, Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -80, 0, 26), ZIndex = 41 })
	UI.CloseButton(adminFrame, function()
		CBT.ToggleAdmin()
	end, 32).ZIndex = 45
	local argBox = make("TextBox", { Size = UDim2.fromOffset(120, 30), Position = UDim2.fromOffset(14, 40), BackgroundColor3 = Color3.fromRGB(36, 36, 50),
		TextColor3 = Color3.new(1, 1, 1), PlaceholderText = "숫자 입력", Text = "", Font = Enum.Font.Code, TextSize = 15, ZIndex = 41 }, adminFrame)
	corner(argBox, 6)
	label(adminFrame, { Text = "<- 시간/코인/개봉 수/레이팅 값", Position = UDim2.fromOffset(142, 40), Size = UDim2.fromOffset(300, 30), ZIndex = 41,
		TextSize = 13, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(170, 170, 190) })
	local cmds = {
		{ "time", "남은 시간 설정" }, { "endMatch", "경기 즉시 종료" }, { "coins", "코인 지급" }, { "unlockAll", "무기 전부 해금" },
		{ "crate", "무료 크레이트 개봉" }, { "special", "스페셜 100%" }, { "bots", "봇 채우기 토글" }, { "fastMissions", "빠른 미션 토글" },
		{ "rankedBots", "봇 랭크반영 토글" }, { "rating", "레이팅 설정" }, { "resetProfile", "내 데이터 초기화" },
		{ "nextMap", "다음 맵 변경" }, { "balance", "밸런스 리포트" }, { "feedback", "피드백 보기" },
	}
	local shown = {}
	for _, c in ipairs(cmds) do
		if dev or Config.OpsCommands[c[1]] then
			table.insert(shown, c)
		end
	end
	if not dev then
		argBox.PlaceholderText = "맵 번호"
	end
	for i, c in ipairs(shown) do
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)
		local color = (c[1] == "balance" or c[1] == "feedback") and Color3.fromRGB(0, 140, 130)
			or (c[1] == "resetProfile" or c[1] == "endMatch") and Color3.fromRGB(150, 50, 70) or nil
		local b = button(adminFrame, c[2], color, { Size = UDim2.fromOffset(128, 32), Position = UDim2.fromOffset(14 + col * 134, 80 + row * 38), ZIndex = 41,
			TextSize = 13 })
		b.MouseButton1Click:Connect(function()
			admin(c[1], argBox.Text ~= "" and argBox.Text or nil)
		end)
	end
	reportBox = make("TextLabel", { Size = UDim2.fromOffset(532, 220), Position = UDim2.fromOffset(14, 266), BackgroundColor3 = Color3.fromRGB(28, 28, 40),
		TextColor3 = Color3.fromRGB(220, 230, 240), Font = Enum.Font.Code, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = "밸런스 리포트 / 피드백 결과가 여기 표시됩니다", ZIndex = 41 }, adminFrame)
	corner(reportBox, 6)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }, reportBox)

	-- 오른쪽: 운영 설정 (부활 시간·경기 시간·아이템 유지 시간…) — 바꾸면 저장되어 모든 서버에 적용
	local side = make("Frame", { Size = UDim2.fromOffset(326, 446), Position = UDim2.fromOffset(560, 40), BackgroundColor3 = Color3.fromRGB(24, 26, 40),
		ZIndex = 41 }, adminFrame)
	corner(side, 8)
	label(side, { Text = "운영 설정 (저장 · 모든 서버 적용)", TextSize = 15, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 24), ZIndex = 42, TextColor3 = Color3.fromRGB(255, 220, 90) })
	local list = make("ScrollingFrame", { Size = UDim2.new(1, -12, 1, -40), Position = UDim2.fromOffset(6, 34), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 42 }, side)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, list)
	local function refreshSettings()
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local ok, res = pcall(function()
			return remotes.Admin:InvokeServer("settings")
		end)
		if not ok or not res or not res.ok or type(res.msg) ~= "table" then
			label(list, { Text = "설정을 불러오지 못했어요", TextSize = 14, Size = UDim2.new(1, 0, 0, 24), ZIndex = 43 })
			return
		end
		for i, r in ipairs(res.msg) do
			local row = make("Frame", { Size = UDim2.new(1, -6, 0, 32), BackgroundColor3 = Color3.fromRGB(34, 38, 58), LayoutOrder = i, ZIndex = 43 }, list)
			corner(row, 6)
			label(row, { Text = r.Name, TextSize = 13, Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -150, 1, 0), ZIndex = 44 })
			local val = label(row, { Text = tostring(r.Value), TextSize = 15, Font = Enum.Font.GothamBlack, Position = UDim2.new(1, -104, 0, 0),
				Size = UDim2.fromOffset(60, 32), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 44, TextColor3 = Color3.fromRGB(120, 230, 255) })
			local function change(dir)
				local nv = math.clamp((tonumber(r.Value) or 0) + dir * r.Step, r.Min, r.Max)
				if nv == r.Value then
					return
				end
				admin("setSetting", r.Key .. "=" .. nv)
				r.Value = nv
				val.Text = tostring(nv)
			end
			local minus = button(row, "-", Color3.fromRGB(150, 50, 70), { Size = UDim2.fromOffset(34, 26), Position = UDim2.new(1, -142, 0, 3), ZIndex = 44,
				TextSize = 18 })
			minus.MouseButton1Click:Connect(function()
				change(-1)
			end)
			local plus = button(row, "+", Color3.fromRGB(0, 150, 100), { Size = UDim2.fromOffset(34, 26), Position = UDim2.new(1, -40, 0, 3), ZIndex = 44,
				TextSize = 18 })
			plus.MouseButton1Click:Connect(function()
				change(1)
			end)
		end
	end
	adminFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if adminFrame.Visible then
			task.spawn(refreshSettings)
		end
	end)
end

function CBT.ToggleAdmin()
	if not player:GetAttribute("IsAdmin") or not adminFrame then
		return
	end
	adminFrame.Visible = not adminFrame.Visible
	modalHandler(adminFrame.Visible or feedbackFrame.Visible)
end

-- 창이 열리면 1인칭 마우스 잠금을 풀기 위해 WeaponController에 알림
function CBT.SetModalHandler(fn)
	modalHandler = fn
end

function CBT.Init(remoteFolder, hud)
	remotes = remoteFolder
	HUD = hud
	gui = make("ScreenGui", { Name = "SplashCBT", ResetOnSpawn = false, DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling },
		player:WaitForChild("PlayerGui"))
	buildFeedback()
	-- 서버가 DevTools 속성을 넣을 때까지 잠깐 대기 (정식 서버면 운영 명령만 표시)
	task.spawn(function()
		local t0 = os.clock()
		while player:GetAttribute("DevTools") == nil and os.clock() - t0 < 5 do
			task.wait(0.1)
		end
		buildAdmin()
		-- 서버가 DevTools(Studio)를 늦게 알려 주면 버튼 목록을 다시 만듦
		player:GetAttributeChangedSignal("DevTools"):Connect(function()
			local open = adminFrame and adminFrame.Visible
			buildAdmin()
			adminFrame.Visible = open or false
		end)
	end)

	-- 항상 보이는 피드백 버튼 (로비 + 결과 화면)
	-- 0.5: 왼쪽 아래 피드백 버튼 제거 (채팅창 자리). 피드백은 F4 또는 결과 화면 안내로
	feedbackBtn = nil
	label(gui, { Text = (Config.CBT.Enabled and "CLOSED BETA · " or "SPLASH FRONT v") .. Config.Build, Position = UDim2.new(1, -220, 0, 2), Size = UDim2.fromOffset(204, 20), TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(200, 200, 220), Font = Enum.Font.GothamBold })

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F2 then
			CBT.ToggleAdmin()
		elseif input.KeyCode == Enum.KeyCode.F4 and Config.CBT.Enabled then
			CBT.OpenFeedback()
		end
	end)

end

-- 결과 화면이 뜰 때 피드백 유도
function CBT.OnResults()
	if not Config.CBT.Enabled then
		return
	end
	HUD.Banner("이번 판 어땠나요? 피드백 [F4]", Color3.fromRGB(0, 214, 200))
end

return CBT
