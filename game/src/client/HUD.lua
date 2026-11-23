-- 경기 HUD: 타이머·점수바·미션·조준선·히트마커·잉크·스페셜·체력·킬피드·결과
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local player = Players.LocalPlayer
local HUD = {}

local gui, top, timerLbl, modeLbl, barHolder, missionFrame, missionLbl, missionTimer
local cross = {}
local hitmarker, inkBar, inkFill, specialFill, specialLbl, healthFill, healthLbl
local feed, banner, vignette, splashed, results, scope, weaponLbl, flagLbl, inkLbl, switchBar
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

	-- 상단: 타이머 + 점수바
	top = make("Frame", { Size = UDim2.new(0, 520, 0, 86), Position = UDim2.new(0.5, -260, 0, 10), BackgroundTransparency = 1 }, gui)
	timerLbl = text(top, { Size = UDim2.new(0, 140, 0, 46), Position = UDim2.new(0.5, -70, 0, 0), Text = "3:00" })
	modeLbl = text(top, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, 46), Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(220, 220, 230) })
	barHolder = make("Frame", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 64),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40), BackgroundTransparency = 0.2 }, top)
	corner(barHolder, 10)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, barHolder)
	flagLbl = text(gui, { Size = UDim2.new(0, 420, 0, 22), Position = UDim2.new(0.5, -210, 0, 100), Font = Enum.Font.GothamBold })

	-- 미션
	missionFrame = make("Frame", { Size = UDim2.new(0, 340, 0, 64), Position = UDim2.new(0, 16, 0, 120),
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

	-- 하단: 체력 / 잉크(총탄) / 무기 / 스페셜
	local bottom = make("Frame", { Size = UDim2.new(0, 780, 0, 70), Position = UDim2.new(0.5, -390, 1, -86), BackgroundTransparency = 1 }, gui)
	-- 잉크 탱크 (하단 가운데 가로 막대)
	inkBar = make("Frame", { Size = UDim2.new(0, 260, 0, 18), Position = UDim2.new(0.5, -130, 0, 40), BackgroundColor3 = Color3.fromRGB(20, 20, 26),
		BackgroundTransparency = 0.2 }, bottom)
	corner(inkBar, 9)
	inkFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, inkBar)
	corner(inkFill, 9)
	inkLbl = text(bottom, { Size = UDim2.new(0, 260, 0, 26), Position = UDim2.new(0.5, -130, 0, 10), Text = "🎨 잉크 100%", Font = Enum.Font.GothamBold })
	local hb = make("Frame", { Size = UDim2.new(0, 220, 0, 18), Position = UDim2.new(0, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(20, 20, 26),
		BackgroundTransparency = 0.2 }, bottom)
	corner(hb, 9)
	healthFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(90, 255, 140), BorderSizePixel = 0 }, hb)
	corner(healthFill, 9)
	healthLbl = text(bottom, { Size = UDim2.new(0, 220, 0, 30), Position = UDim2.new(0, 0, 0, 6), Text = "100",
		TextXAlignment = Enum.TextXAlignment.Left })
	weaponLbl = text(bottom, { Size = UDim2.new(0, 220, 0, 26), Position = UDim2.new(1, -220, 0, 10), TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold })
	local sb = make("Frame", { Size = UDim2.new(0, 220, 0, 18), Position = UDim2.new(1, -220, 0, 40), BackgroundColor3 = Color3.fromRGB(20, 20, 26),
		BackgroundTransparency = 0.2 }, bottom)
	corner(sb, 9)
	specialFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 220, 60), BorderSizePixel = 0 }, sb)
	corner(specialFill, 9)
	specialLbl = text(sb, { Size = UDim2.fromScale(1, 1), Text = "스페셜", Font = Enum.Font.GothamBold, ZIndex = 2 })

	-- 킬피드
	feed = make("Frame", { Size = UDim2.new(0, 360, 0, 200), Position = UDim2.new(1, -376, 0, 16), BackgroundTransparency = 1 }, gui)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 4) }, feed)

	-- 배너 / 처치 / 피격
	local notifyGui = make("ScreenGui", { Name = "SplashNotify", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10 }, player.PlayerGui)
	banner = text(notifyGui, { Size = UDim2.new(0, 700, 0, 40), Position = UDim2.new(0.5, -350, 0.28, 0), TextTransparency = 1, TextStrokeTransparency = 1 })
	splashed = text(gui, { Size = UDim2.new(0, 500, 0, 60), Position = UDim2.new(0.5, -250, 0.62, 0), Text = "SPLASHED!",
		TextTransparency = 1, TextStrokeTransparency = 1 })
	vignette = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0 }, gui)
	local grad = make("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 0.2) }) }, vignette)
	grad.Name = "Grad"

	-- 저격 조준경
	scope = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 5 }, gui)
	local ring = make("Frame", { Size = UDim2.new(0, 0, 0.8, 0), SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, scope)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, ring)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
	make("UIStroke", { Thickness = 3, Color = Color3.new(0, 0, 0) }, ring)
	make("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, scope)
	make("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, scope)

	-- 스폰 지점 무기 교체 바 (1~6 / T)
	switchBar = make("Frame", { Size = UDim2.new(0, 0, 0, 54), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0.5, 0, 1, -150),
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
			local unit = (s.Mode == "Flag") and "" or "%"
			text(f, { Size = UDim2.fromScale(1, 1), Text = string.format("%s %.0f%s", t.Name, t.Score, unit), Font = Enum.Font.GothamBold })
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
function HUD.Update(spreadPx, weaponId, scoped)
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
		cross[i].Visible = not scoped
	end
	scope.Visible = scoped

	local color = player:GetAttribute("TeamColor") or Color3.new(1, 1, 1)
	local ink = (player:GetAttribute("Ink") or 100) / Config.InkMax
	inkFill.Size = UDim2.fromScale(math.clamp(ink, 0, 1), 1)
	inkFill.BackgroundColor3 = ink < 0.15 and Color3.fromRGB(255, 70, 70) or color
	inkLbl.Text = string.format("🎨 잉크 %d%%", math.floor(math.clamp(ink, 0, 1) * 100))
	inkLbl.TextColor3 = ink < 0.15 and Color3.fromRGB(255, 120, 120) or Color3.new(1, 1, 1)
	local sp = player:GetAttribute("Special") or 0
	specialFill.Size = UDim2.fromScale(math.clamp(sp, 0, 1), 1)
	specialLbl.Text = sp >= 1 and "스페셜 준비! [Q]" or string.format("스페셜 %d%%", math.floor(sp * 100))
	local w = Weapons.Get(weaponId)
	weaponLbl.Text = w.Name .. " · " .. w.Class

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

function HUD.KillFeed(d)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Color3.fromRGB(10, 10, 16), BackgroundTransparency = 0.35 }, feed)
	corner(row, 6)
	local txt = (d.Killer and (d.Killer .. (d.Head and "  ◎  " or "  ▶  ")) or "") .. d.Victim
	local t = text(row, { Size = UDim2.new(1, -12, 1, -4), Position = UDim2.new(0, 6, 0, 2), Text = txt, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 1 })
	t.RichText = true
	local function hex(c)
		return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
	end
	if d.Killer and d.KillerColor then
		local gun = d.Weapon and string.format('  <font color="#D8D8E8">[%s]</font>', d.WeaponClass or d.Weapon) or ""
		t.Text = string.format('<font color="%s">%s</font>%s%s<font color="%s">%s</font>', hex(d.KillerColor), d.Killer, gun,
			d.Head and "  ◎  " or "  ▶  ", hex(d.VictimColor), d.Victim)
	else
		t.Text = string.format('<font color="%s">%s</font> 탈락', hex(d.VictimColor), d.Victim)
	end
	if d.KillerPlayer == player or d.VictimPlayer == player then
		make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5 }, row)
	end
	local kids = {}
	for _, c in ipairs(feed:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(kids, c)
		end
	end
	if #kids > 6 then
		kids[1]:Destroy()
	end
	task.delay(6, function()
		if row.Parent then
			row:Destroy()
		end
	end)
	if d.VictimPlayer == player then
		local gun = d.Weapon and string.format("의 %s(%s)", d.Weapon, d.WeaponClass or "") or "에게"
		local head = d.Head and " · 헤드샷" or ""
		HUD.Banner(string.format("%s%s 스플래시!%s  %d초 후 부활", d.Killer or "?", gun, head, Config.RespawnTime), d.KillerColor)
	elseif d.KillerPlayer == player and d.Victim then
		HUD.Banner(string.format("%s 처치! (%s)", d.Victim, d.Weapon or ""), player:GetAttribute("TeamColor"))
	end
end

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
			teamTable(results, 20 + (i - 1) * 490, 470, title, t.Color, string.format("%.1f%s", t.Score, unit), sortRows(rows))
		end
		text(results, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0.5, -20, 0, 112), Text = "VS", ZIndex = 13, TextColor3 = Color3.fromRGB(255, 255, 255) })
	end
	text(results, { Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 20, 1, -32), Font = Enum.Font.Gotham, ZIndex = 11, TextScaled = false, TextSize = 15,
		TextColor3 = Color3.fromRGB(160, 160, 180), Text = (r.Ranked and "랭크전 · " or "일반전 · 레이팅 변동 없음 · ") .. "점수 = 칠한 셀 + 처치×30" })
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

return HUD
