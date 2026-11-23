-- 경기 HUD: 타이머·점수바·미션·조준선·히트마커·잉크·스페셜·체력·킬피드·결과
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local ModelKit = require(ReplicatedStorage.Shared.ModelKit)
local UI = require(script.Parent:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local HUD = {}

local gui, top, timerLbl, modeLbl, barHolder, missionFrame, missionLbl, missionTimer
local cross = {}
local hitmarker, inkBar, inkFill, specialFill, specialLbl, healthFill, healthLbl
local feed, banner, vignette, splashed, results, scope, weaponLbl, flagLbl, inkLbl, switchBar
local sightDot, sightHolo, scopeZoomLbl, itemBar, itemSlots, buffLbl, toast
local portraits, questBox, streakFrame, streakLbl, elimGui, elimFrame, rewardList, xpFill, xpLbl, levelLbl, inkPips, inkNum
local weaponCard, itemCard, myStreak = nil, nil, 0
local thumbCache = {}
local boardSig = ""
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local DARKP = Color3.fromRGB(14, 12, 24)
local leaveConfirm, moveLbl
local MOVE_ICON = { ["일반"] = "🧍 일반", ["달리기"] = "🏃 달리기", ["걷기"] = "🚶 걷기", ["앉기"] = "🧎 앉기" }
local MOVE_COLOR = { ["일반"] = Color3.fromRGB(230, 230, 240), ["달리기"] = Color3.fromRGB(255, 200, 80), ["걷기"] = Color3.fromRGB(140, 220, 255),
	["앉기"] = Color3.fromRGB(170, 255, 170) }
function HUD.SetMove(mode)
	if moveLbl then
		moveLbl.Text = MOVE_ICON[mode] or mode
		moveLbl.TextColor3 = MOVE_COLOR[mode] or Color3.new(1, 1, 1)
	end
end
local leaveModal = function() end
local leaveConfirmFn = function() end

function HUD.SetLeaveHandler(onModal, onConfirm)
	leaveModal = onModal
	leaveConfirmFn = onConfirm
end

function HUD.AskLeave()
	if not leaveConfirm or not player:GetAttribute("InMatch") then
		return
	end
	leaveConfirm.Visible = not leaveConfirm.Visible
	leaveModal(leaveConfirm.Visible)
end
local ITEM_DEF = {}
for _, it in ipairs(Config.Items) do
	ITEM_DEF[it.Id] = it
end
local state = nil

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function corner(parent, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

local function text(parent, props)
	local t = make("TextLabel", {
		BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack,
		TextScaled = true, TextStrokeTransparency = 0.5, Text = "",
	}, parent)
	for k, v in pairs(props) do
		t[k] = v
	end
	return t
end

function HUD.Build()
	gui = make("ScreenGui", { Name = "SplashHUD", ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

	-- 상단 가운데: 모래시계 타이머 · 모드 · (팀전) 점수 막대 · TOP 5 초상화
	top = make("Frame", { Size = UDim2.new(0, 600, 0, 196), Position = UDim2.new(0.5, -300, 0, 6), BackgroundTransparency = 1 }, gui)
	local pill = make("Frame", { Size = UDim2.fromOffset(190, 46), Position = UDim2.new(0.5, -95, 0, 0), BackgroundColor3 = DARKP, BackgroundTransparency = 0.2 }, top)
	corner(pill, 23)
	make("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Transparency = 0.75 }, pill)
	UI.Icon(pill, "hourglass", "⌛", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(12, 6) })
	timerLbl = text(pill, { Size = UDim2.new(1, -60, 1, -8), Position = UDim2.fromOffset(50, 4), Text = "5:00", Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.6 })
	modeLbl = text(top, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 48), Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(240, 240, 250), TextStrokeTransparency = 0.4 })
	barHolder = make("Frame", { Size = UDim2.new(0, 420, 0, 16), Position = UDim2.new(0.5, -210, 0, 70),
		BackgroundColor3 = DARKP, BackgroundTransparency = 0.25, ClipsDescendants = true }, top)
	corner(barHolder, 8)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, barHolder)
	portraits = make("Frame", { Size = UDim2.new(1, 0, 0, 100), Position = UDim2.new(0, 0, 0, 92), BackgroundTransparency = 1 }, top)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, portraits)
	flagLbl = text(gui, { Size = UDim2.new(0, 460, 0, 22), Position = UDim2.new(0.5, -230, 0, 202), Font = Enum.Font.GothamBold })

	-- 오른쪽 위: 로비로 나가기 [L] + 확인 창
	local leaveBtn = make("TextButton", { Size = UDim2.fromOffset(120, 36), Position = UDim2.new(1, -136, 0, 12), BackgroundColor3 = DARKP, BackgroundTransparency = 0.2,
		Text = "", AutoButtonColor = true }, gui)
	corner(leaveBtn, 18)
	text(leaveBtn, { Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5), Text = "⎋ 로비  [L]", Font = Enum.Font.GothamBlack, TextStrokeTransparency = 1 })
	leaveBtn.MouseButton1Click:Connect(function()
		HUD.AskLeave()
	end)
	leaveConfirm = make("Frame", { Size = UDim2.fromOffset(420, 170), Position = UDim2.new(0.5, -210, 0.4, -85), BackgroundColor3 = Color3.fromRGB(20, 18, 34),
		Visible = false, ZIndex = 60 }, gui)
	corner(leaveConfirm, 16)
	make("UIStroke", { Thickness = 3, Color = Color3.fromRGB(255, 90, 120) }, leaveConfirm)
	text(leaveConfirm, { Size = UDim2.new(1, -40, 0, 34), Position = UDim2.fromOffset(20, 16), Text = "로비로 나갈까요?", ZIndex = 61 })
	text(leaveConfirm, { Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 54), Text = "지금 나가면 이번 판 보상·레이팅은 받지 못해요", TextScaled = false,
		TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 220), ZIndex = 61 })
	for i, o in ipairs({ { "나가기", Color3.fromRGB(230, 60, 100), true }, { "계속하기", Color3.fromRGB(60, 58, 86), false } }) do
		local b = make("TextButton", { Size = UDim2.fromOffset(170, 48), Position = UDim2.new(0, 30 + (i - 1) * 190, 1, -66), BackgroundColor3 = o[2], Text = o[1],
			TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack, TextSize = 20, ZIndex = 61 }, leaveConfirm)
		corner(b, 10)
		b.MouseButton1Click:Connect(function()
			leaveConfirm.Visible = false
			leaveModal(false)
			if o[3] then
				leaveConfirmFn()
			end
		end)
	end
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.L and player:GetAttribute("InMatch") then
			HUD.AskLeave()
		end
	end)

	-- 왼쪽 위: 일일·주간 퀘스트 카드
	questBox = make("Frame", { Size = UDim2.fromOffset(380, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(16, 56), BackgroundTransparency = 1 }, gui)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, questBox)

	-- 왼쪽: 연속 처치 불꽃
	streakFrame = make("Frame", { Size = UDim2.fromOffset(120, 120), Position = UDim2.new(0, 20, 0.62, 0), BackgroundTransparency = 1, Visible = false }, gui)
	UI.Icon(streakFrame, "flame", "🔥", { Size = UDim2.fromScale(1, 1) })
	streakLbl = text(streakFrame, { Size = UDim2.new(1, 0, 0.46, 0), Position = UDim2.new(0, 0, 0.5, 0), Text = "x2", Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 1 })
	make("UIStroke", { Thickness = 4, Color = Color3.fromRGB(150, 20, 40) }, streakLbl)

	-- 왼쪽 아래: 조작키 안내
	local keys = make("Frame", { Size = UDim2.new(0, 0, 0, 36), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0, 16, 1, -16),
		AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1 }, gui)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, keys)
	for i, k in ipairs({ { "⇧", "달리기" }, { "Z", "걷기" }, { "C", "앉기" }, { "Q", "스페셜" }, { "🖱", "조준" }, { "F", "아이템" }, { "V", "시점" } }) do
		local chip = make("Frame", { Size = UDim2.fromOffset(92, 34), BackgroundColor3 = DARKP, BackgroundTransparency = 0.3, LayoutOrder = i }, keys)
		corner(chip, 8)
		local key = make("Frame", { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(5, 5), BackgroundColor3 = Color3.fromRGB(240, 240, 248) }, chip)
		corner(key, 5)
		text(key, { Size = UDim2.fromScale(1, 1), Text = k[1], TextColor3 = Color3.fromRGB(20, 20, 30), TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
		text(chip, { Size = UDim2.new(1, -38, 1, -12), Position = UDim2.fromOffset(34, 6), Text = k[2], TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBold, TextStrokeTransparency = 1 })
	end

	-- 미션
	missionFrame = make("Frame", { Size = UDim2.new(0, 380, 0, 56), Position = UDim2.new(0.5, -190, 0, 228),
		BackgroundColor3 = Color3.fromRGB(255, 196, 40), BackgroundTransparency = 0.1, Visible = false }, gui)
	corner(missionFrame, 10)
	missionLbl = text(missionFrame, { Size = UDim2.new(1, -70, 1, -8), Position = UDim2.new(0, 10, 0, 4), TextColor3 = Color3.fromRGB(30, 20, 0),
		TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold })
	missionTimer = text(missionFrame, { Size = UDim2.new(0, 56, 1, -8), Position = UDim2.new(1, -62, 0, 4), TextColor3 = Color3.fromRGB(30, 20, 0),
		TextStrokeTransparency = 1 })

	-- 조준선
	for i = 1, 4 do
		cross[i] = make("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5) }, gui)
		make("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.4 }, cross[i])
	end
	make("Frame", { Size = UDim2.fromOffset(3, 3), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Dot" }, gui)
	hitmarker = make("Frame", { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, Visible = false }, gui)
	for i = 1, 4 do
		local f = make("Frame", { Size = UDim2.fromOffset(10, 3), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
			BackgroundColor3 = Color3.new(1, 1, 1), Rotation = 45 + 90 * i }, hitmarker)
		local a = math.rad(45 + 90 * i)
		f.Position = UDim2.new(0.5, math.cos(a) * 10, 0.5, math.sin(a) * 10)
	end

	-- 이동 상태 (일반 / 달리기 / 걷기 / 앉기)
	moveLbl = text(gui, { Size = UDim2.fromOffset(120, 22), Position = UDim2.new(0.5, 160, 1, -80), Text = "🧍 일반", Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 16 })

	-- 하단 가운데: 체력 + 레벨 경험치 막대
	local hb = make("Frame", { Size = UDim2.fromOffset(300, 12), Position = UDim2.new(0.5, -150, 1, -72), BackgroundColor3 = DARKP, BackgroundTransparency = 0.25 }, gui)
	corner(hb, 6)
	healthFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(90, 255, 140), BorderSizePixel = 0 }, hb)
	corner(healthFill, 6)
	healthLbl = text(gui, { Size = UDim2.fromOffset(60, 22), Position = UDim2.new(0.5, -216, 1, -78), Text = "100", Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Right })
	local xb = make("Frame", { Size = UDim2.fromOffset(470, 28), Position = UDim2.new(0.5, -235, 1, -48), BackgroundColor3 = DARKP, BackgroundTransparency = 0.15 }, gui)
	corner(xb, 14)
	make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 190, 80), Transparency = 0.3 }, xb)
	xpFill = make("Frame", { Size = UDim2.fromScale(0.3, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, xb)
	corner(xpFill, 14)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 210, 90)) }, xpFill)
	levelLbl = text(xb, { Size = UDim2.new(0.4, 0, 1, -8), Position = UDim2.fromOffset(14, 4), Text = "레벨 1", TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack, TextStrokeTransparency = 0.5, ZIndex = 2 })
	xpLbl = text(xb, { Size = UDim2.new(0.45, 0, 1, -10), Position = UDim2.new(0.55, -46, 0, 5), Text = "0 / 100 XP", TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.5, ZIndex = 2 })
	UI.Icon(xb, "chest", "🧰", { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -30, 0.5, -22), ZIndex = 3 })

	-- 오른쪽 아래: 잉크(탄) 칸 + 숫자, 슬롯 카드 [1 무기] [Q 스페셜] [F 아이템]
	local ammo = make("Frame", { Size = UDim2.fromOffset(300, 44), Position = UDim2.new(1, -16, 1, -128), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1 }, gui)
	inkPips = {}
	for i = 1, 10 do
		local pip = make("Frame", { Size = UDim2.fromOffset(12, 26), Position = UDim2.fromOffset((i - 1) * 15, 10), BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0 }, ammo)
		corner(pip, 4)
		make("UIStroke", { Thickness = 1.5, Color = DARKP, Transparency = 0.2 }, pip)
		inkPips[i] = pip
	end
	inkNum = text(ammo, { Size = UDim2.fromOffset(140, 44), Position = UDim2.new(1, -140, 0, 0), Text = "100", Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Right, RichText = true })
	local slots = make("Frame", { Size = UDim2.fromOffset(470, 96), Position = UDim2.new(1, -16, 1, -24), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1 }, gui)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder }, slots)
	local function card(order, key, wide)
		local c = make("Frame", { Size = UDim2.fromOffset(wide and 170 or 140, 96), BackgroundColor3 = Color3.fromRGB(28, 26, 44), BackgroundTransparency = 0.12,
			LayoutOrder = order }, slots)
		corner(c, 12)
		make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(230, 230, 245), Transparency = 0.6 }, c)
		make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 190)), Rotation = 90 }, c)
		local badge = make("Frame", { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromRGB(240, 240, 248), ZIndex = 3 }, c)
		corner(badge, 6)
		text(badge, { Size = UDim2.fromScale(1, 1), Text = key, TextColor3 = DARKP, TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack, ZIndex = 4 })
		local pic = make("Frame", { Size = UDim2.new(1, -12, 1, -32), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1 }, c)
		local name = text(c, { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0, 6, 1, -24), Text = "", Font = Enum.Font.GothamBlack,
			TextStrokeTransparency = 0.5, ZIndex = 3 })
		return c, pic, name
	end
	local wc, wpic, wname = card(1, "1", true)
	weaponCard = { Frame = wc, Pic = wpic, Name = wname }
	weaponLbl = wname
	local sc, spic, sname = card(2, "Q")
	UI.Icon(spic, "bomb", "💣", { Size = UDim2.fromScale(1, 1) })
	local sb = make("Frame", { Size = UDim2.new(1, -16, 0, 6), Position = UDim2.new(0, 8, 1, -30), BackgroundColor3 = DARKP, ZIndex = 3 }, sc)
	corner(sb, 3)
	specialFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 220, 60), BorderSizePixel = 0, ZIndex = 3 }, sb)
	corner(specialFill, 3)
	specialLbl = sname
	local ic, ipic, iname = card(3, "F")
	itemCard = { Frame = ic, Pic = ipic, Name = iname }

	-- 킬피드
	feed = make("Frame", { Size = UDim2.new(0, 470, 0, 260), Position = UDim2.new(1, -486, 0, 56), BackgroundTransparency = 1 }, gui)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 4) }, feed)

	-- 배너 / 처치 / 피격
	local notifyGui = make("ScreenGui", { Name = "SplashNotify", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10 }, player.PlayerGui)
	banner = text(notifyGui, { Size = UDim2.new(0, 700, 0, 40), Position = UDim2.new(0.5, -350, 0.28, 0), TextTransparency = 1, TextStrokeTransparency = 1 })
	splashed = text(gui, { Size = UDim2.new(0, 500, 0, 60), Position = UDim2.new(0.5, -250, 0.62, 0), Text = "",
		TextTransparency = 1, TextStrokeTransparency = 1 })
	-- 처치 배너: [멀티킬 칩] / 제거됨 / 💀 상대 이름 + 보상 줄
	elimGui = notifyGui
	elimFrame = make("Frame", { Size = UDim2.fromOffset(520, 130), Position = UDim2.new(0.5, -260, 0.6, 0), BackgroundTransparency = 1, Visible = false }, notifyGui)
	rewardList = make("Frame", { Size = UDim2.fromOffset(520, 80), Position = UDim2.new(0.5, -260, 0.6, 134), BackgroundTransparency = 1 }, notifyGui)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 2) }, rewardList)
	vignette = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0 }, gui)
	local grad = make("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 0.2) }) }, vignette)
	grad.Name = "Grad"

	-- 저격 조준경
	-- 스코프: 원 바깥을 검게 가리고(굵은 테두리), 가운데 십자선·눈금·빨간 점
	scope = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 5, ClipsDescendants = true }, gui)
	local ring = make("Frame", { Size = UDim2.new(0, 0, 0.86, 0), SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 5 }, scope)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, ring)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
	make("UIStroke", { Thickness = 2400, Color = Color3.fromRGB(4, 4, 8), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
	local inner = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6 }, ring)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, inner)
	make("UIStroke", { Thickness = 5, Color = Color3.fromRGB(20, 20, 26) }, inner)
	make("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0, ZIndex = 6 }, ring)
	make("Frame", { Size = UDim2.new(0, 2, 1, 0), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0, ZIndex = 6 }, ring)
	for k = 1, 4 do
		for _, sgn in ipairs({ -1, 1 }) do
			make("Frame", { Size = UDim2.fromOffset(10, 2), Position = UDim2.new(0.5, 0, 0.5, sgn * k * 22), AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 6 }, ring)
			make("Frame", { Size = UDim2.fromOffset(2, 10), Position = UDim2.new(0.5, sgn * k * 22, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 6 }, ring)
		end
	end
	local rd = make("Frame", { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 40, 60), BorderSizePixel = 0, ZIndex = 7 }, ring)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, rd)
	scopeZoomLbl = text(scope, { Size = UDim2.fromOffset(120, 30), Position = UDim2.new(0.5, 40, 0.5, 40), Text = "", Font = Enum.Font.GothamBlack, ZIndex = 8,
		TextColor3 = Color3.fromRGB(255, 220, 80), TextXAlignment = Enum.TextXAlignment.Left })

	-- 레드닷(점) / 홀로(원 + 점) 조준점: 우클릭 조준 시
	sightDot = make("Frame", { Size = UDim2.fromOffset(7, 7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 40, 60), BorderSizePixel = 0, Visible = false, ZIndex = 4 }, gui)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, sightDot)
	make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 120, 130), Transparency = 0.5 }, sightDot)
	sightHolo = make("Frame", { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, Visible = false, ZIndex = 4 }, gui)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, sightHolo)
	make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 60, 80), Transparency = 0.15 }, sightHolo)

	itemSlots = {}
	buffLbl = text(gui, { Size = UDim2.new(0, 700, 0, 22), Position = UDim2.new(0.5, -350, 1, -100), Text = "", Font = Enum.Font.GothamBlack,
		RichText = true })

	-- 스폰 지점 무기 교체 바 (1~6 / T)
	switchBar = make("Frame", { Size = UDim2.new(0, 0, 0, 54), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0.5, 0, 1, -160),
		AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(10, 10, 16), BackgroundTransparency = 0.2, Visible = false }, gui)
	corner(switchBar, 12)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7) }, switchBar)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center }, switchBar)

	-- 결과창
	results = make("Frame", { Size = UDim2.new(0, 1000, 0, 580), Position = UDim2.new(0.5, -500, 0.5, -290),
		BackgroundColor3 = Color3.fromRGB(18, 18, 26), BackgroundTransparency = 0.05, Visible = false, ZIndex = 10 }, gui)
	corner(results, 16)
	make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 255, 255), Transparency = 0.7 }, results)
end

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

for _, a in ipairs({ "SpawnZone", "Owned", "Weapon", "InMatch" }) do
	player:GetAttributeChangedSignal(a):Connect(function()
		HUD.UpdateSwitch()
	end)
end

function HUD.OnState(s)
	state = s
	local inMatch = player:GetAttribute("InMatch") == true
	gui.Enabled = inMatch
	if not inMatch then
		return
	end
	modeLbl.Text = (s.ModeName or "") .. " · " .. (s.MapName or "")
	HUD.RenderBoard(s.Board or {})
	-- 점수바
	for _, c in ipairs(barHolder:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local total = 0
	for _, t in ipairs(s.Teams) do
		total = total + math.max(0, t.Score)
	end
	for i, t in ipairs(s.Teams) do
		local share = (total > 0) and (t.Score / total) or (1 / math.max(1, #s.Teams))
		local f = make("Frame", { Size = UDim2.new(share, 0, 1, 0), BackgroundColor3 = t.Color, BorderSizePixel = 0, LayoutOrder = i }, barHolder)
		if share > 0.12 then
			local label = (s.Mode == "Flag") and string.format("%s %.0f", t.Name, t.Score)
				or string.format("%.0f점 · 칠 %.0f%%", t.Score, t.Coverage or 0)
			text(f, { Size = UDim2.fromScale(1, 1), Text = label, Font = Enum.Font.GothamBold })
		end
	end
	-- 깃발
	if s.Mode == "Flag" and s.Flags then
		local parts = {}
		for _, f in ipairs(s.Flags) do
			local who = "중립"
			for _, t in ipairs(s.Teams) do
				if t.OwnerId == f.Owner then
					who = t.Name
				end
			end
			local p = (f.Progress > 0) and string.format(" (%d%%)", math.floor(f.Progress * 100)) or ""
			table.insert(parts, f.Name .. ": " .. who .. p)
		end
		flagLbl.Text = table.concat(parts, "   ")
	else
		flagLbl.Text = ""
	end
	-- 미션
	if s.Mission then
		missionFrame.Visible = true
		missionLbl.Text = "⚡ " .. s.Mission.Name .. " — " .. s.Mission.Desc .. " (+" .. s.Mission.Bonus .. ")"
	else
		missionFrame.Visible = false
	end
	timerLbl.TextColor3 = s.FinalSplash and Color3.fromRGB(255, 220, 60) or Color3.new(1, 1, 1)
end

-- 매 프레임 갱신 (WeaponController에서 호출)
function HUD.Update(spreadPx, weaponId, sight, zoomText)
	local scoped = sight == "Scope"
	if not gui.Enabled then
		return
	end
	if state then
		timerLbl.Text = fmtTime(state.EndsAt - workspace:GetServerTimeNow())
		if state.Mission then
			missionTimer.Text = tostring(math.max(0, math.ceil(state.Mission.EndsAt - workspace:GetServerTimeNow())))
		end
	end
	local gap = 6 + spreadPx
	local len = 9
	cross[1].Size = UDim2.fromOffset(2, len)
	cross[1].Position = UDim2.new(0.5, 0, 0.5, -gap - len / 2)
	cross[2].Size = UDim2.fromOffset(2, len)
	cross[2].Position = UDim2.new(0.5, 0, 0.5, gap + len / 2)
	cross[3].Size = UDim2.fromOffset(len, 2)
	cross[3].Position = UDim2.new(0.5, -gap - len / 2, 0.5, 0)
	cross[4].Size = UDim2.fromOffset(len, 2)
	cross[4].Position = UDim2.new(0.5, gap + len / 2, 0.5, 0)
	for i = 1, 4 do
		cross[i].Visible = sight == nil
	end
	scope.Visible = scoped
	scopeZoomLbl.Text = zoomText or ""
	sightDot.Visible = sight == "Dot" or sight == "Holo"
	sightHolo.Visible = sight == "Holo"
	-- 효과 남은 시간
	local now = workspace:GetServerTimeNow()
	local parts = {}
	local ju, su, zu = player:GetAttribute("JetpackUntil"), player:GetAttribute("ShieldUntil"), player:GetAttribute("ZoomUntil")
	if ju and ju > now then
		table.insert(parts, string.format('<font color="#FFB050">🚀 제트팩 %d초 (Space)</font>', math.ceil(ju - now)))
	end
	if su and su > now then
		table.insert(parts, string.format('<font color="#70C8FF">🛡 무적 %d초</font>', math.ceil(su - now)))
	end
	if zu and zu > now then
		table.insert(parts, string.format('<font color="#90FF90">🔭 %d배 줌 %d초</font>', player:GetAttribute("ZoomBuff") or 1, math.ceil(zu - now)))
	end
	if player:GetAttribute("Golden") then
		table.insert(parts, '<font color="#FFD040">✨ 황금총 장전 — 다음 1발 즉사</font>')
	end
	buffLbl.Text = table.concat(parts, "   ")

	local color = player:GetAttribute("TeamColor") or Color3.new(1, 1, 1)
	local ink = math.clamp((player:GetAttribute("Ink") or 100) / Config.InkMax, 0, 1)
	local low = ink < 0.15
	for i, pip in ipairs(inkPips) do
		local on = ink >= (i - 0.5) / 10
		pip.BackgroundColor3 = on and (low and Color3.fromRGB(255, 70, 70) or color) or Color3.fromRGB(60, 58, 80)
		pip.BackgroundTransparency = on and 0 or 0.4
	end
	inkNum.Text = string.format('%d<font size="20">%%</font>', math.floor(ink * 100))
	inkNum.TextColor3 = low and Color3.fromRGB(255, 120, 120) or Color3.new(1, 1, 1)
	local sp = player:GetAttribute("Special") or 0
	specialFill.Size = UDim2.fromScale(math.clamp(sp, 0, 1), 1)
	specialLbl.Text = sp >= 1 and "준비 완료!" or string.format("크로마 봄 %d%%", math.floor(sp * 100))
	specialLbl.TextColor3 = sp >= 1 and Color3.fromRGB(255, 225, 80) or Color3.new(1, 1, 1)
	local w = Weapons.Get(weaponId)
	weaponLbl.Text = player:GetAttribute("Golden") and "✨ 황금총" or w.Class
	-- 경험치
	local lv, xp, need = player:GetAttribute("Level") or 1, player:GetAttribute("XP") or 0, player:GetAttribute("XPNeed") or 100
	levelLbl.Text = "레벨 " .. lv
	xpLbl.Text = string.format("%d / %d XP", xp, need)
	xpFill.Size = UDim2.fromScale(math.clamp(xp / math.max(1, need), 0.04, 1), 1)

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local hp = hum.Health / math.max(1, hum.MaxHealth)
		healthFill.Size = UDim2.fromScale(math.clamp(hp, 0, 1), 1)
		healthFill.BackgroundColor3 = hp < 0.35 and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(90, 255, 140)
		healthLbl.Text = tostring(math.ceil(hum.Health))
	end
end

function HUD.Hitmarker(head, killed)
	hitmarker.Visible = true
	local c = killed and Color3.fromRGB(255, 60, 60) or (head and Color3.fromRGB(255, 210, 40) or Color3.new(1, 1, 1))
	for _, f in ipairs(hitmarker:GetChildren()) do
		f.BackgroundColor3 = c
	end
	hitmarker.Size = UDim2.fromOffset(40, 40)
	TweenService:Create(hitmarker, TweenInfo.new(0.12), { Size = UDim2.fromOffset(26, 26) }):Play()
	local token = {}
	HUD._hitToken = token
	task.delay(0.18, function()
		if HUD._hitToken == token then
			hitmarker.Visible = false
		end
	end)
	if killed then
		splashed.TextColor3 = player:GetAttribute("TeamColor") or Color3.new(1, 1, 1)
		splashed.TextTransparency = 0
		splashed.TextStrokeTransparency = 0.3
		splashed.Size = UDim2.new(0, 620, 0, 76)
		TweenService:Create(splashed, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(0, 500, 0, 60) }):Play()
		task.delay(0.9, function()
			TweenService:Create(splashed, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end)
	end
end

function HUD.DamageFlash(color)
	vignette.BackgroundColor3 = color or Color3.fromRGB(255, 40, 40)
	vignette.BackgroundTransparency = 0.25
	TweenService:Create(vignette, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
end

function HUD.Banner(msg, color)
	banner.Text = msg
	banner.TextColor3 = color or Color3.new(1, 1, 1)
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.4
	local token = {}
	HUD._bannerToken = token
	task.delay(2.6, function()
		if HUD._bannerToken == token then
			TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- 킬피드 (오른쪽 위): [🔥연속] [처치자] [총 아이콘] [피해자] 칩
local function chip(parent, txt, bg, fg, w, order)
	local c = make("Frame", { Size = UDim2.fromOffset(w, 30), BackgroundColor3 = bg, LayoutOrder = order }, parent)
	corner(c, 8)
	text(c, { Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Text = txt, Font = Enum.Font.GothamBlack, TextColor3 = fg or Color3.new(1, 1, 1),
		TextStrokeTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd })
	return c
end

function HUD.KillFeed(d)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = -math.floor(os.clock() * 100) }, feed)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4),
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, row)
	if d.Killer then
		if (d.KillerStreak or 0) >= 2 then
			local sc = chip(row, "    x" .. d.KillerStreak, Color3.fromRGB(255, 200, 40), Color3.fromRGB(120, 20, 10), 64, 1)
			UI.Icon(sc, "flame", "🔥", { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(4, 3), ZIndex = 3 })
		end
		local kc = chip(row, d.Killer, d.KillerColor or Color3.fromRGB(80, 80, 100), Color3.new(1, 1, 1), 140, 2)
		make("UIStroke", { Thickness = 1.5, Color = Color3.new(1, 1, 1), Transparency = (d.KillerPlayer == player) and 0 or 1 }, kc)
		local gun = make("Frame", { Size = UDim2.fromOffset(70, 30), BackgroundColor3 = Color3.fromRGB(245, 245, 250), LayoutOrder = 3 }, row)
		corner(gun, 8)
		if d.WeaponId then
			UI.GunImage(gun, d.WeaponId, Color3.fromRGB(60, 60, 70))
		end
		if d.Head then
			UI.Icon(gun, "target", "🎯", { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -18, 0, 0), ZIndex = 3 })
		end
	end
	local vc = chip(row, d.Victim, Color3.fromRGB(40, 38, 58), d.VictimColor, 140, 4)
	make("UIStroke", { Thickness = 2, Color = d.VictimColor or Color3.new(1, 1, 1) }, vc)
	local kids = {}
	for _, c in ipairs(feed:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(kids, c)
		end
	end
	table.sort(kids, function(a, b)
		return a.LayoutOrder > b.LayoutOrder
	end)
	if #kids > 6 then
		kids[1]:Destroy()
	end
	task.delay(7, function()
		if row.Parent then
			row:Destroy()
		end
	end)
	if d.VictimPlayer == player then
		myStreak = 0
		streakFrame.Visible = false
		HUD.DeathCard(d)
	end
end

-- 내가 당했을 때: [처치자 이름] + 총 그림(텍스트 대신 3D 이미지) + 헤드샷 표시 + 부활 카운트다운
local deathCard = nil
function HUD.DeathCard(d)
	if deathCard then
		deathCard:Destroy()
	end
	local parent = elimGui or gui
	local c = make("Frame", { Size = UDim2.fromOffset(400, 150), Position = UDim2.new(0.5, -200, 0.26, 0), BackgroundColor3 = DARKP, BackgroundTransparency = 0.1 }, parent)
	deathCard = c
	corner(c, 16)
	make("UIStroke", { Thickness = 3, Color = d.KillerColor or Color3.fromRGB(255, 80, 110) }, c)
	UI.Icon(c, "skull", "💀", { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(16, 7) })
	text(c, { Size = UDim2.new(1, -60, 0, 26), Position = UDim2.fromOffset(50, 8), Text = "스플래시 당했다!", Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 120, 150), TextXAlignment = Enum.TextXAlignment.Left })
	local who = make("Frame", { Size = UDim2.fromOffset(170, 36), Position = UDim2.fromOffset(16, 46), BackgroundColor3 = d.KillerColor or Color3.fromRGB(90, 90, 110) }, c)
	corner(who, 10)
	text(who, { Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Text = d.Killer or "낙사", Font = Enum.Font.GothamBlack, TextStrokeTransparency = 0.6,
		TextTruncate = Enum.TextTruncate.AtEnd })
	local pic = make("Frame", { Size = UDim2.fromOffset(190, 80), Position = UDim2.fromOffset(196, 40), BackgroundColor3 = Color3.fromRGB(240, 240, 248) }, c)
	corner(pic, 12)
	make("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 192, 210)), Rotation = 90 }, pic)
	if d.WeaponId then
		UI.GunImage(pic, d.WeaponId, d.KillerColor or Color3.fromRGB(60, 60, 70))
	else
		text(pic, { Size = UDim2.fromScale(1, 1), Text = "🕳", TextStrokeTransparency = 1 })
	end
	if d.Head then
		local hb = make("Frame", { Size = UDim2.fromOffset(84, 26), Position = UDim2.new(1, -90, 0, 4), BackgroundColor3 = Color3.fromRGB(255, 200, 40), ZIndex = 3 }, pic)
		corner(hb, 8)
		UI.Icon(hb, "target", "🎯", { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(4, 3), ZIndex = 4 })
		text(hb, { Size = UDim2.new(1, -30, 1, -6), Position = UDim2.fromOffset(26, 3), Text = "헤드샷", TextColor3 = Color3.fromRGB(60, 30, 0),
			TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack, ZIndex = 4 })
	end
	local cd = text(c, { Size = UDim2.fromOffset(170, 30), Position = UDim2.fromOffset(16, 90), Text = "", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(210, 210, 230) })
	task.spawn(function()
		for t = Config.RespawnTime, 1, -1 do
			if not c.Parent then
				return
			end
			cd.Text = t .. "초 후 부활"
			task.wait(1)
		end
		if c.Parent then
			c:Destroy()
		end
	end)
end

-- 내가 처치했을 때: 화면 가운데 '제거됨' 배너 + 보상 줄 + 연속 처치 불꽃
local MULTI = { [2] = "더블 킬", [3] = "트리플 킬", [4] = "쿼드 킬", [5] = "펜타 킬" }
function HUD.Elim(d)
	myStreak = d.Streak or (myStreak + 1)
	for _, c in ipairs(elimFrame:GetChildren()) do
		c:Destroy()
	end
	elimFrame.Visible = true
	local y = 0
	local m = (d.Multi or 1) >= 2 and (MULTI[math.min(d.Multi, 5)] or (d.Multi .. "연속 킬")) or nil
	if m then
		local mc = make("Frame", { Size = UDim2.fromOffset(110, 28), Position = UDim2.new(0.5, -55, 0, 0), BackgroundColor3 = Color3.fromRGB(255, 70, 120) }, elimFrame)
		corner(mc, 8)
		text(mc, { Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), Text = m, TextStrokeTransparency = 1, Font = Enum.Font.GothamBlack })
		y = 32
	end
	local big = text(elimFrame, { Size = UDim2.new(1, 0, 0, 58), Position = UDim2.fromOffset(0, y), Text = "제거됨", Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 1 })
	make("UIStroke", { Thickness = 4, Color = Color3.fromRGB(230, 40, 110) }, big)
	for _, side in ipairs({ -1, 1 }) do
		text(elimFrame, { Size = UDim2.fromOffset(70, 44), Position = UDim2.new(0.5, side * 150 - 35, 0, y + 8), Text = "///", Font = Enum.Font.GothamBlack,
			TextColor3 = Color3.fromRGB(255, 70, 120), TextStrokeTransparency = 1 })
	end
	text(elimFrame, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, y + 60), Text = "💀 " .. tostring(d.Victim), Font = Enum.Font.GothamBlack,
		TextColor3 = d.VictimColor or Color3.fromRGB(255, 120, 160), TextStrokeTransparency = 0.6 })
	local scale = make("UIScale", { Scale = 1.35 }, elimFrame)
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local token = {}
	HUD._elimToken = token
	task.delay(2.2, function()
		if HUD._elimToken == token then
			elimFrame.Visible = false
		end
	end)
	-- 보상 줄
	local line = make("Frame", { Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		LayoutOrder = -math.floor(os.clock() * 100) }, rewardList)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder }, line)
	UI.Icon(line, d.Head and "target" or "skull", d.Head and "🎯" or "💀", { Size = UDim2.fromOffset(24, 24), LayoutOrder = 1 })
	local lt = text(line, { Size = UDim2.new(0, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = string.format("%s%s 제거", d.Head and "헤드샷! " or "",
		tostring(d.Victim)), Font = Enum.Font.GothamBlack, TextScaled = false, TextSize = 19, LayoutOrder = 2 })
	UI.Icon(line, "coin", "🪙", { Size = UDim2.fromOffset(22, 22), LayoutOrder = 3 })
	text(line, { Size = UDim2.new(0, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = string.format("+%d  ·  +%d XP", d.Coins or 0, d.XP or 0),
		Font = Enum.Font.GothamBlack, TextScaled = false, TextSize = 19, TextColor3 = Color3.fromRGB(255, 220, 90), LayoutOrder = 4 })
	task.delay(3, function()
		if line.Parent then
			line:Destroy()
		end
	end)
	local n = 0
	for _, c in ipairs(rewardList:GetChildren()) do
		if c:IsA("Frame") then
			n = n + 1
		end
	end
	if n > 3 then
		local oldest, ol = nil, math.huge
		for _, c in ipairs(rewardList:GetChildren()) do
			if c:IsA("Frame") and -c.LayoutOrder < ol then
				oldest, ol = c, -c.LayoutOrder
			end
		end
		if oldest then
			oldest:Destroy()
		end
	end
	-- 연속 처치 불꽃
	streakFrame.Visible = myStreak >= 2
	streakLbl.Text = "x" .. myStreak
	if myStreak >= 2 then
		local sc = streakFrame:FindFirstChildOfClass("UIScale") or make("UIScale", {}, streakFrame)
		sc.Scale = 1.4
		TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

-- 상단 TOP 5 초상화 (플레이어는 Roblox 얼굴 사진, 봇은 팀 색 카드)
local function thumb(userId, img)
	if thumbCache[userId] then
		img.Image = thumbCache[userId]
		return
	end
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and url then
			thumbCache[userId] = url
			if img.Parent then
				img.Image = url
			end
		end
	end)
end

function HUD.RenderBoard(board)
	local sig = ""
	for _, b in ipairs(board) do
		sig = sig .. b.Name .. b.Kills .. (b.Streak or 0) .. tostring(b.OwnerId)
	end
	if sig == boardSig then
		return
	end
	boardSig = sig
	for _, c in ipairs(portraits:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, b in ipairs(board) do
		local cardF = make("Frame", { Size = UDim2.fromOffset(72, 100), BackgroundTransparency = 1, LayoutOrder = i }, portraits)
		text(cardF, { Size = UDim2.new(1, 0, 0, 26), Text = tostring(b.Kills), Font = Enum.Font.FredokaOne })
		local pic = make("Frame", { Size = UDim2.fromOffset(68, 68), Position = UDim2.fromOffset(2, 28), BackgroundColor3 = b.Color }, cardF)
		corner(pic, 10)
		make("UIStroke", { Thickness = 3, Color = (i == 1) and Color3.fromRGB(255, 210, 60) or Color3.new(1, 1, 1) }, pic)
		make("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 170)), Rotation = 90 }, pic)
		if b.UserId then
			local img = make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop }, pic)
			corner(img, 10)
			thumb(b.UserId, img)
		else
			text(pic, { Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.1), Text = string.upper(string.sub(b.Name, 1, 1)),
				Font = Enum.Font.FredokaOne })
			text(pic, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -16), Text = "BOT", Font = Enum.Font.GothamBlack, TextStrokeTransparency = 0.4 })
		end
		text(cardF, { Size = UDim2.fromOffset(34, 22), Position = UDim2.new(1, -30, 1, -20), Text = "#" .. i, Font = Enum.Font.FredokaOne, ZIndex = 3,
			TextColor3 = (i == 1) and Color3.fromRGB(255, 220, 80) or Color3.new(1, 1, 1) })
		if i == 1 then
			UI.Icon(cardF, "crown", "👑", { Size = UDim2.fromOffset(32, 30), Position = UDim2.fromOffset(-10, 12), ZIndex = 3, Rotation = -20 })
		end
		if (b.Streak or 0) >= 3 then
			text(cardF, { Size = UDim2.fromOffset(40, 22), Position = UDim2.new(0, -6, 1, -20), Text = "🔥" .. b.Streak, ZIndex = 3, Font = Enum.Font.GothamBlack })
		end
	end
end

-- 왼쪽 위 퀘스트 카드 (미완료 우선 3개)
function HUD.UpdateQuests()
	if not questBox then
		return
	end
	local ok, list = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Quests") or "[]")
	end)
	if not ok or type(list) ~= "table" then
		return
	end
	table.sort(list, function(a, b)
		if a.Done ~= b.Done then
			return not a.Done
		end
		if a.Period ~= b.Period then
			return a.Period == "Daily"
		end
		return (a.P / math.max(1, a.Goal)) > (b.P / math.max(1, b.Goal))
	end)
	for _, c in ipairs(questBox:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i = 1, math.min(3, #list) do
		local q = list[i]
		local cardF = make("Frame", { Size = UDim2.fromOffset(380, 58), BackgroundColor3 = DARKP, BackgroundTransparency = 0.2, LayoutOrder = i }, questBox)
		corner(cardF, 10)
		UI.Icon(cardF, q.Done and "check" or "quest", q.Done and "✅" or "📅", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(8, 9) })
		text(cardF, { Size = UDim2.new(1, -170, 0, 20), Position = UDim2.fromOffset(54, 8), Text = string.format("[%s] %s", q.Period == "Daily" and "일일" or "주간", q.Name),
			Font = Enum.Font.GothamBlack, TextScaled = false, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 1 })
		text(cardF, { Size = UDim2.fromOffset(100, 18), Position = UDim2.new(1, -184, 0, 9), Text = string.format("%d / %d", q.P, q.Goal), TextScaled = false,
			TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 1 })
		local bar = make("Frame", { Size = UDim2.new(1, -150, 0, 7), Position = UDim2.fromOffset(54, 36), BackgroundColor3 = Color3.fromRGB(60, 58, 82) }, cardF)
		corner(bar, 4)
		local fill = make("Frame", { Size = UDim2.fromScale(math.clamp(q.P / math.max(1, q.Goal), 0, 1), 1),
			BackgroundColor3 = q.Done and Color3.fromRGB(120, 255, 170) or Color3.fromRGB(80, 210, 255), BorderSizePixel = 0 }, bar)
		corner(fill, 4)
		UI.Icon(cardF, "coin", "🪙", { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -90, 0.5, -12) })
		text(cardF, { Size = UDim2.fromOffset(56, 26), Position = UDim2.new(1, -62, 0.5, -13), Text = "+" .. q.Reward, Font = Enum.Font.GothamBlack,
			TextColor3 = Color3.fromRGB(255, 220, 90), TextXAlignment = Enum.TextXAlignment.Left })
	end
end
player:GetAttributeChangedSignal("Quests"):Connect(function()
	HUD.UpdateQuests()
end)

-- 무기 카드 그림 (무기·스킨·황금총이 바뀔 때)
function HUD.RefreshWeaponCard()
	if not weaponCard then
		return
	end
	for _, c in ipairs(weaponCard.Pic:GetChildren()) do
		c:Destroy()
	end
	local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
	if player:GetAttribute("Golden") then
		UI.ModelImage(weaponCard.Pic, ModelKit.Item("Golden"), UDim2.fromScale(1, 1))
	else
		UI.GunImage(weaponCard.Pic, player:GetAttribute("Weapon") or "Pistol", player:GetAttribute("TeamColor"), Cosmetics.ById[player:GetAttribute("Skin") or ""])
	end
end
for _, a in ipairs({ "Weapon", "Skin", "Golden", "TeamColor" }) do
	player:GetAttributeChangedSignal(a):Connect(function()
		HUD.RefreshWeaponCard()
	end)
end
-- 경기 중엔 채팅창을 왼쪽 가운데로 (왼쪽 아래는 조작키 안내), 로비에선 왼쪽 아래
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	local cfg = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if cfg then
		cfg.VerticalAlignment = player:GetAttribute("InMatch") and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Bottom
	end
	if not player:GetAttribute("InMatch") and leaveConfirm and leaveConfirm.Visible then
		leaveConfirm.Visible = false
		leaveModal(false)
	end
	if player:GetAttribute("InMatch") then
		myStreak = 0
		if streakFrame then
			streakFrame.Visible = false
		end
		HUD.RefreshWeaponCard()
		HUD.UpdateQuests()
	end
end)

-- 첫 경기 안내 (온보딩)
local TIPS = {
	"🎨 바닥을 우리 색으로 칠하세요 — 칠한 면적이 곧 점수!",
	"⚡ 우리 색 위에서는 빨라지고 잉크가 빨리 차요. 적 색 위에서는 느려져요",
	"🧱 상자 뒤에서 C로 앉으면 숨을 수 있어요 · 우클릭 조준",
	"👀 V 키로 1인칭 ↔ 3인칭(어깨 시점) 전환",
	"💥 많이 칠하면 스페셜이 차요 — Q로 크로마 봄 투척!",
	"⏱ 노란 미션이 뜨면 팀 보너스 기회! 마지막 30초는 페인트 1.5배",
}
function HUD.ShowTips()
	local card = make("Frame", { Size = UDim2.new(0, 560, 0, 46), Position = UDim2.new(0.5, -280, 1, -150), BackgroundColor3 = Color3.fromRGB(10, 10, 16),
		BackgroundTransparency = 0.2 }, gui)
	corner(card, 12)
	make("UIStroke", { Thickness = 2, Color = player:GetAttribute("TeamColor") or Color3.new(1, 1, 1) }, card)
	local t = text(card, { Size = UDim2.new(1, -24, 1, -12), Position = UDim2.new(0, 12, 0, 6), Font = Enum.Font.GothamBold, TextStrokeTransparency = 1 })
	task.spawn(function()
		task.wait(1.5)
		for _, tip in ipairs(TIPS) do
			if not card.Parent or not player:GetAttribute("InMatch") then
				break
			end
			t.Text = tip
			task.wait(5)
		end
		card:Destroy()
	end)
end

-- 결과창: 팀 vs 상대 (각 팀 안에서 점수 → 처치 → 데스 적은 순). 솔로는 한 표
local RCOLS = { { "#", 34 }, { "플레이어", 160 }, { "처치", 52 }, { "데스", 52 }, { "점수", 70 }, { "코인", 56 }, { "레이팅", 58 } }
local function resultRow(parent, y, values, color, bold, width)
	local x = 0
	local scale = width / 482
	for i, c in ipairs(RCOLS) do
		local w = c[2] * scale
		local t = text(parent, { Size = UDim2.fromOffset(w - 4, 24), Position = UDim2.fromOffset(x + 2, y), Text = values[i], TextScaled = false, TextSize = 16,
			Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextColor3 = color or Color3.new(1, 1, 1), TextStrokeTransparency = 0.7, ZIndex = 12,
			TextXAlignment = (i == 2) and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
		x = x + w
	end
end

local function sortRows(list)
	table.sort(list, function(a, b)
		if (a.Score or 0) ~= (b.Score or 0) then
			return (a.Score or 0) > (b.Score or 0)
		end
		if a.Kills ~= b.Kills then
			return a.Kills > b.Kills
		end
		return a.Deaths < b.Deaths
	end)
	return list
end

local function teamTable(parent, x, width, title, color, scoreText, rows)
	local box = make("Frame", { Size = UDim2.new(0, width, 1, -150), Position = UDim2.fromOffset(x, 112), BackgroundColor3 = Color3.fromRGB(28, 26, 42),
		ZIndex = 11 }, parent)
	corner(box, 12)
	make("UIStroke", { Color = color, Thickness = 2 }, box)
	local head = make("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = color, ZIndex = 11 }, box)
	corner(head, 12)
	text(head, { Size = UDim2.new(0.68, -12, 1, -8), Position = UDim2.fromOffset(12, 4), Text = title, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(16, 14, 24), TextStrokeTransparency = 1, ZIndex = 12 })
	text(head, { Size = UDim2.new(0.32, -12, 1, -8), Position = UDim2.new(0.68, 0, 0, 4), Text = scoreText, TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(16, 14, 24), TextStrokeTransparency = 1, ZIndex = 12 })
	resultRow(box, 48, { "#", "플레이어", "처치", "데스", "점수", "코인", "레이팅" }, Color3.fromRGB(170, 170, 195), false, width)
	make("Frame", { Size = UDim2.new(1, -16, 0, 1), Position = UDim2.fromOffset(8, 75), BackgroundColor3 = Color3.fromRGB(80, 78, 110), BorderSizePixel = 0,
		ZIndex = 12 }, box)
	for i, row in ipairs(rows) do
		if i > 10 then
			break
		end
		local y = 52 + i * 30
		if row.Player == player then
			local hl = make("Frame", { Size = UDim2.new(1, -8, 0, 28), Position = UDim2.fromOffset(4, y - 2), BackgroundColor3 = color, BackgroundTransparency = 0.6,
				ZIndex = 11 }, box)
			corner(hl, 6)
		end
		local rating = row.RatingDelta and string.format("%+d", row.RatingDelta) or "-"
		local name = (i == 1 and "★ " or "") .. row.Name .. (row.IsBot and " (봇)" or "")
		resultRow(box, y, { tostring(i), name, tostring(row.Kills), tostring(row.Deaths), tostring(row.Score or row.Cells), tostring(row.Coins), rating },
			(row.Player == player) and Color3.new(1, 1, 1) or Color3.fromRGB(225, 225, 240), row.Player == player, width)
	end
end

function HUD.ShowResults(r)
	for _, c in ipairs(results:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	results.Visible = true
	gui.Enabled = true
	local head = r.WinnerName and (r.WinnerName .. " 승리!") or "무승부!"
	local mine = player:GetAttribute("OwnerId")
	local won = false
	for _, row in ipairs(r.Rows) do
		if row.Player == player then
			won = row.Won
		end
	end
	text(results, { Size = UDim2.new(1, -40, 0, 50), Position = UDim2.new(0, 20, 0, 14), Text = head,
		TextColor3 = r.WinnerColor or Color3.new(1, 1, 1), ZIndex = 11 })
	text(results, { Size = UDim2.new(1, -40, 0, 26), Position = UDim2.new(0, 20, 0, 66), Text = won and "🏆 VICTORY" or "다음 판엔 이길 수 있어요!",
		Font = Enum.Font.GothamBold, TextColor3 = won and Color3.fromRGB(255, 215, 60) or Color3.fromRGB(200, 200, 220), ZIndex = 11 })
	local unit = (r.Mode == "Flag") and "점" or "%"
	if r.Mode == "Solo" then
		local t = r.Teams[1]
		teamTable(results, 20, 960, "솔로 순위", Color3.fromRGB(255, 200, 60), t and string.format("1위 %.1f%s", t.Score, unit) or "", sortRows(r.Rows))
	else
		-- 왼쪽 = 우리 팀, 오른쪽 = 상대 팀
		local teams = {}
		for _, t in ipairs(r.Teams) do
			table.insert(teams, t)
		end
		table.sort(teams, function(a, b)
			return (a.OwnerId == mine) and b.OwnerId ~= mine
		end)
		for i, t in ipairs(teams) do
			if i > 2 then
				break
			end
			local rows = {}
			for _, row in ipairs(r.Rows) do
				if row.OwnerId == t.OwnerId then
					table.insert(rows, row)
				end
			end
			local title = (i == 1 and mine == t.OwnerId) and ("우리 팀 · " .. t.Name) or ((mine and i == 2) and ("상대 팀 · " .. t.Name) or t.Name)
			local st = (r.Mode == "Flag") and string.format("%.0f점", t.Score)
				or string.format("%.1f점 (칠 %.1f%% · 처치 %d)", t.Score, t.Coverage or 0, t.Kills or 0)
			teamTable(results, 20 + (i - 1) * 490, 470, title, t.Color, st, sortRows(rows))
		end
		text(results, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0.5, -20, 0, 112), Text = "VS", ZIndex = 13, TextColor3 = Color3.fromRGB(255, 255, 255) })
	end
	text(results, { Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 20, 1, -32), Font = Enum.Font.Gotham, ZIndex = 11, TextScaled = false, TextSize = 15,
		TextColor3 = Color3.fromRGB(160, 160, 180), Text = (r.Ranked and "랭크전 · " or "일반전 · 레이팅 변동 없음 · ") .. (r.Mode == "Flag" and "깃발 점수로 승패" or "승패 = 페인트 면적 80% + 처치·미션 20%") .. " · 개인 점수 = 칠한 셀 + 처치×30" })
	task.delay(Config.ResultsTime, function()
		results.Visible = false
	end)
end

-- 스폰 지점 무기 교체 바 갱신 (SpawnZone · Owned · Weapon 속성이 바뀔 때)
function HUD.UpdateSwitch()
	if not switchBar then
		return
	end
	local show = player:GetAttribute("InMatch") and player:GetAttribute("SpawnZone")
	switchBar.Visible = show == true
	if not show then
		return
	end
	for _, c in ipairs(switchBar:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	text(switchBar, { Size = UDim2.fromOffset(150, 40), Text = "🔁 무기 교체", Font = Enum.Font.GothamBlack, LayoutOrder = 0, TextScaled = false, TextSize = 18 })
	local ownedStr = "," .. (player:GetAttribute("Owned") or "") .. ","
	local cur = player:GetAttribute("Weapon")
	for i, w in ipairs(Weapons.List) do
		if string.find(ownedStr, "," .. w.Id .. ",", 1, true) then
			local on = (w.Id == cur)
			local chip = make("Frame", { Size = UDim2.fromOffset(112, 40), BackgroundColor3 = on and (player:GetAttribute("TeamColor") or Color3.new(1, 1, 1))
				or Color3.fromRGB(44, 42, 62), LayoutOrder = i }, switchBar)
			corner(chip, 8)
			text(chip, { Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), Text = string.format("[%d] %s", i, w.Class), TextScaled = false,
				TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = on and Color3.fromRGB(16, 14, 24) or Color3.new(1, 1, 1), TextStrokeTransparency = 1 })
		end
	end
	text(switchBar, { Size = UDim2.fromOffset(70, 40), Text = "T 다음", Font = Enum.Font.GothamBold, LayoutOrder = 99, TextScaled = false, TextSize = 15,
		TextColor3 = Color3.fromRGB(200, 200, 220) })
end

-- 아이템 카드 [F]: 맨 앞 아이템 그림 + 이름 + 남은 개수 (G로 순서 바꾸기)
function HUD.UpdateItems()
	if not itemCard then
		return
	end
	local list = {}
	for x in string.gmatch(player:GetAttribute("Items") or "", "[^,]+") do
		table.insert(list, x)
	end
	for _, c in ipairs(itemCard.Pic:GetChildren()) do
		c:Destroy()
	end
	local id = list[1]
	if id then
		UI.ModelImage(itemCard.Pic, ModelKit.Item(id, player:GetAttribute("TeamColor")), UDim2.fromScale(1, 1), math.rad(35))
		itemCard.Name.Text = ((ITEM_DEF[id] and ITEM_DEF[id].Name) or id) .. ((#list > 1) and ("  +" .. (#list - 1)) or "")
		itemCard.Name.TextColor3 = Color3.fromRGB(255, 225, 100)
	else
		text(itemCard.Pic, { Size = UDim2.fromScale(1, 1), Text = "🎁", TextTransparency = 0.6, TextStrokeTransparency = 1 })
		itemCard.Name.Text = "미션 보상"
		itemCard.Name.TextColor3 = Color3.fromRGB(170, 170, 190)
	end
end

-- 새 아이템 획득 카드 (화면 가운데 아래, 2.5초)
function HUD.ItemToast(id)
	local def = ITEM_DEF[id]
	if not def then
		return
	end
	if toast then
		toast:Destroy()
	end
	local notifyGui = player.PlayerGui:FindFirstChild("SplashNotify")
	toast = make("Frame", { Size = UDim2.fromOffset(380, 110), Position = UDim2.new(0.5, -190, 0.68, 0), BackgroundColor3 = Color3.fromRGB(20, 16, 34),
		BackgroundTransparency = 0.05 }, notifyGui)
	corner(toast, 16)
	make("UIStroke", { Thickness = 3, Color = Color3.fromRGB(255, 210, 70) }, toast)
	local pic = make("Frame", { Size = UDim2.fromOffset(94, 94), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(50, 44, 80) }, toast)
	corner(pic, 12)
	UI.ModelImage(pic, ModelKit.Item(id, player:GetAttribute("TeamColor")), UDim2.fromScale(1, 1), math.rad(35))
	text(toast, { Size = UDim2.new(1, -120, 0, 34), Position = UDim2.fromOffset(112, 12), Text = "획득! " .. def.Name, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 220, 80) })
	text(toast, { Size = UDim2.new(1, -120, 0, 44), Position = UDim2.fromOffset(112, 50), Text = def.Desc, TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold, TextStrokeTransparency = 1 })
	local me = toast
	me.Size = UDim2.fromOffset(40, 110)
	TweenService:Create(me, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(380, 110) }):Play()
	task.delay(2.6, function()
		if me.Parent then
			me:Destroy()
		end
	end)
end

return HUD
