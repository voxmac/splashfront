-- 로비 UI: 프로필, 매치 대기열, 상점(무기 / 크로마 크레이트 / 컬렉션), 크레이트 개봉 연출
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local SoundBank = require(script.Parent:WaitForChild("SoundBank"))

local player = Players.LocalPlayer
local Lobby = {}

local remotes, HUD
local gui, profileLbl, queueFrame, statusLbl, shop, pages, tabButtons, reveal
local queueButtons = {}
local lastState = nil
local randomItemsRestricted = false

local DARK = Color3.fromRGB(20, 20, 30)
local PANEL = Color3.fromRGB(32, 32, 46)

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

local function label(parent, props)
	local t = make("TextLabel", { BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
		TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, parent)
	for k, v in pairs(props) do
		t[k] = v
	end
	return t
end

local function button(parent, text, color, props)
	local b = make("TextButton", { Text = text, BackgroundColor3 = color or Color3.fromRGB(255, 46, 170), TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBlack, TextSize = 16, AutoButtonColor = true }, parent)
	corner(b, 8)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	b.MouseButton1Click:Connect(function()
		SoundBank.Play("ui_click", nil, 0.4)
	end)
	return b
end

local function owned(attr, id)
	local s = player:GetAttribute(attr) or ""
	for x in string.gmatch(s, "[^,]+") do
		if x == id then
			return true
		end
	end
	return false
end

local function shopCall(action, id)
	local ok, res = pcall(function()
		return remotes.Shop:InvokeServer(action, id)
	end)
	if ok and res then
		HUD.Banner(res.msg, res.ok and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(255, 120, 120))
		SoundBank.Play(res.ok and (action == "buy" and "ui_buy" or "ui_click") or "ui_error", nil, 0.6)
	end
	return ok and res
end

------------------------------------------------------------------------
-- 상점 페이지
------------------------------------------------------------------------
local function clear(page)
	for _, c in ipairs(page:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function buildWeapons(page)
	clear(page)
	local coins = player:GetAttribute("Coins") or 0
	local equipped = player:GetAttribute("Weapon")
	for i, w in ipairs(Weapons.List) do
		local row = make("Frame", { Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = PANEL, LayoutOrder = i }, page)
		corner(row, 10)
		label(row, { Text = w.Name .. "  ·  " .. w.Class, Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -170, 0, 22), TextSize = 18 })
		label(row, { Text = string.format("피해 %s · 간격 %.2fs · 사거리 %d · 페인트 %s", w.Pellets > 1 and (w.Damage .. "×" .. w.Pellets) or tostring(w.Damage),
			w.FireInterval, w.Range, tostring(w.PaintRadius)), Position = UDim2.new(0, 14, 0, 34), Size = UDim2.new(1, -170, 0, 20),
			TextSize = 13, TextColor3 = Color3.fromRGB(180, 180, 200), Font = Enum.Font.Gotham })
		local isOwned = owned("Owned", w.Id)
		local text, color
		if equipped == w.Id then
			text, color = "장착 중", Color3.fromRGB(70, 70, 90)
		elseif isOwned then
			text, color = "장착", Color3.fromRGB(0, 170, 160)
		else
			text = string.format("%d 코인", w.Price)
			color = coins >= w.Price and Color3.fromRGB(255, 46, 170) or Color3.fromRGB(90, 60, 80)
		end
		local b = button(row, text, color, { Size = UDim2.new(0, 140, 0, 40), Position = UDim2.new(1, -150, 0.5, -20) })
		b.MouseButton1Click:Connect(function()
			if equipped == w.Id then
				return
			end
			shopCall(isOwned and "equip" or "buy", w.Id)
			task.wait(0.2)
			buildWeapons(page)
		end)
	end
end

local function buildCrate(page)
	clear(page)
	local top = make("Frame", { Size = UDim2.new(1, -8, 0, 120), BackgroundColor3 = PANEL, LayoutOrder = 1 }, page)
	corner(top, 12)
	label(top, { Text = "크로마 크레이트", TextSize = 24, Font = Enum.Font.GothamBlack, Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(0.6, 0, 0, 30) })
	label(top, { Text = "무기 스킨 · 페인트 패턴 · 처치 이펙트 중 1개 (외형 전용, 능력치 변화 없음)", TextSize = 13, Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(190, 190, 210), Position = UDim2.new(0, 16, 0, 42), Size = UDim2.new(0.62, 0, 0, 18) })
	local pity = player:GetAttribute("CratePity") or 0
	label(top, { Text = string.format("천장: %d / %d회 — %d회 안에 레전더리 확정", pity, Cosmetics.PityCount, Cosmetics.PityCount - pity), TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 200, 60), Position = UDim2.new(0, 16, 0, 64), Size = UDim2.new(0.62, 0, 0, 18) })

	if randomItemsRestricted then
		label(top, { Text = "이 계정/지역에서는 유료 랜덤 상자를 이용할 수 없어요.", TextColor3 = Color3.fromRGB(255, 140, 140), TextSize = 14,
			Position = UDim2.new(0, 16, 0, 88), Size = UDim2.new(0.9, 0, 0, 20) })
	else
		local buy = button(top, Cosmetics.CratePrice .. " R$  개봉", Color3.fromRGB(255, 180, 30),
			{ Size = UDim2.new(0, 170, 0, 44), Position = UDim2.new(1, -186, 0, 14), TextColor3 = Color3.fromRGB(40, 20, 0) })
		buy.MouseButton1Click:Connect(function()
			local id = Config.Monetization.CrateProductId
			if id == 0 then
				HUD.Banner("Config.Monetization.CrateProductId에 개발자 상품 ID를 넣어주세요", Color3.fromRGB(255, 200, 80))
				return
			end
			MarketplaceService:PromptProductPurchase(player, id)
		end)
		if RunService:IsStudio() then
			local test = button(top, "Studio 테스트 개봉", Color3.fromRGB(80, 80, 110),
				{ Size = UDim2.new(0, 170, 0, 36), Position = UDim2.new(1, -186, 0, 66), TextSize = 14 })
			test.MouseButton1Click:Connect(function()
				shopCall("crateTest")
			end)
		end
	end

	-- 확률 공개표
	local order = 2
	for _, r in ipairs(Cosmetics.Rarities) do
		local items = Cosmetics.ByRarity[r.Id]
		local head = make("Frame", { Size = UDim2.new(1, -8, 0, 30), BackgroundColor3 = r.Color, BackgroundTransparency = 0.15, LayoutOrder = order }, page)
		corner(head, 8)
		label(head, { Text = string.format("%s  %d%%  (중복 시 %d 코인 환급)", r.Name, r.Chance, r.Refund), Font = Enum.Font.GothamBlack,
			Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -24, 1, 0), TextColor3 = Color3.fromRGB(15, 15, 20) })
		order = order + 1
		for _, item in ipairs(items) do
			local kindName = (item.Kind == "Skin" and "무기 스킨") or (item.Kind == "Pattern" and "페인트 패턴") or "처치 이펙트"
			local have = owned("OwnedCosmetics", item.Id)
			local row = make("Frame", { Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, LayoutOrder = order }, page)
			label(row, { Text = string.format("   %s  ·  %s%s", item.Name, kindName, have and "   ✔ 보유" or ""), Size = UDim2.new(0.75, 0, 1, 0), TextSize = 14,
				Font = Enum.Font.Gotham, TextColor3 = have and Color3.fromRGB(140, 255, 170) or Color3.new(1, 1, 1) })
			label(row, { Text = string.format("%.2f%%", Cosmetics.ItemChance(item)), Size = UDim2.new(0.25, -12, 1, 0), Position = UDim2.new(0.75, 0, 0, 0),
				TextXAlignment = Enum.TextXAlignment.Right, TextSize = 14, Font = Enum.Font.Code })
			order = order + 1
		end
	end
end

local function buildCollection(page)
	clear(page)
	local slots = { Skin = "Skin", Pattern = "Pattern", Effect = "KillEffect" }
	local kinds = { { "Skin", "무기 스킨" }, { "Pattern", "페인트 패턴" }, { "Effect", "처치 이펙트" } }
	local order = 1
	local any = false
	for _, k in ipairs(kinds) do
		label(page, { Text = k[2], TextSize = 18, Font = Enum.Font.GothamBlack, Size = UDim2.new(1, -8, 0, 28), LayoutOrder = order })
		order = order + 1
		for _, item in ipairs(Cosmetics.Items) do
			if item.Kind == k[1] and owned("OwnedCosmetics", item.Id) then
				any = true
				local r = Cosmetics.Rarity(item.Rarity)
				local equipped = player:GetAttribute(slots[item.Kind]) == item.Id
				local row = make("Frame", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = PANEL, LayoutOrder = order }, page)
				corner(row, 8)
				make("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = r.Color, BorderSizePixel = 0 }, row)
				label(row, { Text = item.Name .. "  (" .. r.Name .. ")", Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(1, -150, 1, 0) })
				local b = button(row, equipped and "해제" or "장착", equipped and Color3.fromRGB(70, 70, 90) or Color3.fromRGB(0, 170, 160),
					{ Size = UDim2.new(0, 110, 0, 30), Position = UDim2.new(1, -120, 0.5, -15) })
				b.MouseButton1Click:Connect(function()
					shopCall("equipCosmetic", item.Id)
					task.wait(0.2)
					buildCollection(page)
				end)
				order = order + 1
			end
		end
	end
	if not any then
		label(page, { Text = "아직 보유한 외형이 없어요. 크로마 크레이트에서 얻을 수 있어요!", Size = UDim2.new(1, -8, 0, 30), LayoutOrder = 99,
			TextColor3 = Color3.fromRGB(190, 190, 210) })
	end
end

local builders = { Weapons = buildWeapons, Crate = buildCrate, Collection = buildCollection }
local currentTab = "Weapons"

local function showTab(name)
	currentTab = name
	for n, p in pairs(pages) do
		p.Visible = (n == name)
	end
	for n, b in pairs(tabButtons) do
		b.BackgroundColor3 = (n == name) and Color3.fromRGB(255, 46, 170) or Color3.fromRGB(60, 60, 80)
	end
	builders[name](pages[name])
end

local function toggleShop(force)
	local on = force
	if on == nil then
		on = not shop.Visible
	end
	if player:GetAttribute("InMatch") then
		on = false
	end
	shop.Visible = on
	if on then
		remotes.Telemetry:FireServer("OpenedShop")
		showTab(currentTab)
	end
end

------------------------------------------------------------------------
-- 크레이트 개봉 연출
------------------------------------------------------------------------
function Lobby.ShowCrate(res)
	reveal.Visible = true
	clear(reveal)
	local box = make("Frame", { Size = UDim2.fromOffset(120, 120), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(60, 60, 80), Rotation = 0 }, reveal)
	corner(box, 18)
	make("UIStroke", { Thickness = 4, Color = Color3.new(1, 1, 1) }, box)
	-- 흔들기 → 등급 색으로 터짐
	SoundBank.Play("crate_shake", nil, 0.7)
	for i = 1, 6 do
		box.Rotation = (i % 2 == 0) and 8 or -8
		task.wait(0.08)
	end
	box.Rotation = 0
	box.BackgroundColor3 = res.Color
	SoundBank.Play("crate_" .. string.lower(res.Rarity), nil, 0.8)
	TweenService:Create(box, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(260, 260) }):Play()
	task.wait(0.35)
	make("TextLabel", { Size = UDim2.new(0, 600, 0, 40), Position = UDim2.new(0.5, -300, 0.45, 140), BackgroundTransparency = 1,
		Text = res.RarityName .. "!", TextColor3 = res.Color, Font = Enum.Font.GothamBlack, TextScaled = true, TextStrokeTransparency = 0.3 }, reveal)
	local kindName = (res.Kind == "Skin" and "무기 스킨") or (res.Kind == "Pattern" and "페인트 패턴") or "처치 이펙트"
	local sub = res.Name .. "  ·  " .. kindName
	if res.Duplicate then
		sub = sub .. "  (중복 → " .. res.Refund .. " 코인 환급)"
	end
	if res.Pitied then
		sub = sub .. "  [천장 확정]"
	end
	make("TextLabel", { Size = UDim2.new(0, 700, 0, 28), Position = UDim2.new(0.5, -350, 0.45, 186), BackgroundTransparency = 1,
		Text = sub, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextScaled = true }, reveal)
	local close = button(reveal, "확인", Color3.fromRGB(255, 46, 170), { Size = UDim2.fromOffset(160, 44), Position = UDim2.new(0.5, -80, 0.45, 226) })
	close.MouseButton1Click:Connect(function()
		reveal.Visible = false
		if shop.Visible then
			showTab(currentTab)
		end
	end)
end

------------------------------------------------------------------------
-- 대기열
------------------------------------------------------------------------
local function refreshQueues()
	local s = lastState
	local mine = player:GetAttribute("Queue")
	for _, q in ipairs(Config.Queues) do
		local b = queueButtons[q.Id]
		local n = (s and s.QueueCounts and s.QueueCounts[q.Id]) or 0
		local mode = Config.Modes[q.Mode]
		local title = (q.Mode == "Solo") and "솔로 페인트 로얄 (8인)" or string.format("%s  %dvs%d", mode.Name, q.TeamSize, q.TeamSize)
		b.Text = string.format("%s%s   ·   대기 %d명%s", title, q.Ranked and "  [랭크]" or "", n, (mine == q.Id) and "   ✔ 참가 중" or "")
		b.BackgroundColor3 = (mine == q.Id) and Color3.fromRGB(255, 46, 170) or PANEL
	end
	if not s then
		statusLbl.Text = ""
	elseif s.Phase == "Countdown" then
		statusLbl.Text = string.format("%s 매치 시작까지 %d초 · 맵: %s", s.QueueId or "", math.max(0, math.ceil(s.EndsAt - workspace:GetServerTimeNow())),
			s.NextMapName or "")
	elseif s.Phase == "Playing" or s.Phase == "Results" then
		statusLbl.Text = "다른 경기가 진행 중 — 대기열에 들어가 있으면 다음 판에 참가해요"
	else
		local nextMap = (s.NextMapName and s.NextMapName ~= "") and (" · 다음 맵: " .. s.NextMapName) or ""
		statusLbl.Text = (mine and "참가자를 기다리는 중... (빈자리는 봇)" or "대기열을 골라 매치에 참가하세요") .. nextMap
	end
end

local function refreshProfile()
	local vip = player:GetAttribute("Vip") and "  ·  VIP" or ""
	profileLbl.Text = string.format("%s%s\n💰 %d 코인\n🏆 %s  %d  ·  %d승", player.DisplayName, vip, player:GetAttribute("Coins") or 0,
		player:GetAttribute("Tier") or "브론즈", player:GetAttribute("Rating") or Config.Rating.Start, player:GetAttribute("Wins") or 0)
end

function Lobby.OnState(s)
	lastState = s
	local inMatch = player:GetAttribute("InMatch") == true
	gui.Enabled = not inMatch
	if inMatch then
		shop.Visible = false
	end
	refreshQueues()
end

function Lobby.Init(remoteFolder, hud)
	remotes = remoteFolder
	HUD = hud
	task.spawn(function()
		pcall(function()
			local info = PolicyService:GetPolicyInfoForPlayerAsync(player)
			randomItemsRestricted = info.ArePaidRandomItemsRestricted
		end)
	end)

	gui = make("ScreenGui", { Name = "SplashLobby", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling },
		player:WaitForChild("PlayerGui"))

	-- 프로필
	local card = make("Frame", { Size = UDim2.fromOffset(270, 96), Position = UDim2.fromOffset(16, 16), BackgroundColor3 = DARK, BackgroundTransparency = 0.15 }, gui)
	corner(card, 12)
	profileLbl = label(card, { Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromOffset(12, 6), TextYAlignment = Enum.TextYAlignment.Top, TextSize = 17 })

	-- 대기열
	queueFrame = make("Frame", { Size = UDim2.new(0, 420, 0, 300), Position = UDim2.new(1, -436, 0, 16), BackgroundColor3 = DARK, BackgroundTransparency = 0.15 }, gui)
	corner(queueFrame, 12)
	label(queueFrame, { Text = "매치 참가", TextSize = 22, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 28) })
	for i, q in ipairs(Config.Queues) do
		local b = button(queueFrame, "", PANEL, { Size = UDim2.new(1, -28, 0, 38), Position = UDim2.fromOffset(14, 40 + (i - 1) * 44), TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left })
		make("UIPadding", { PaddingLeft = UDim.new(0, 12) }, b)
		b.MouseButton1Click:Connect(function()
			if player:GetAttribute("Queue") == q.Id then
				remotes.Queue:FireServer(nil)
			else
				remotes.Queue:FireServer(q.Id)
			end
		end)
		queueButtons[q.Id] = b
	end
	statusLbl = label(queueFrame, { Position = UDim2.new(0, 14, 1, -34), Size = UDim2.new(1, -28, 0, 26), TextSize = 14, TextWrapped = true,
		TextColor3 = Color3.fromRGB(255, 220, 100) })

	-- 상점 버튼
	local shopBtn = button(gui, "상점 · 크레이트  [B]", Color3.fromRGB(255, 46, 170), { Size = UDim2.fromOffset(220, 50), Position = UDim2.new(0, 16, 0, 124), TextSize = 18 })
	shopBtn.MouseButton1Click:Connect(function()
		toggleShop()
	end)

	-- 상점 창
	shop = make("Frame", { Size = UDim2.new(0, 640, 0, 520), Position = UDim2.new(0.5, -320, 0.5, -260), BackgroundColor3 = DARK, Visible = false }, gui)
	corner(shop, 16)
	make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 46, 170) }, shop)
	local closeBtn = button(shop, "✕", Color3.fromRGB(60, 60, 80), { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -46, 0, 10) })
	closeBtn.MouseButton1Click:Connect(function()
		toggleShop(false)
	end)
	tabButtons = {}
	pages = {}
	local tabs = { { "Weapons", "무기" }, { "Crate", "크로마 크레이트" }, { "Collection", "컬렉션" } }
	for i, t in ipairs(tabs) do
		local b = button(shop, t[2], Color3.fromRGB(60, 60, 80), { Size = UDim2.fromOffset(170, 36), Position = UDim2.fromOffset(16 + (i - 1) * 180, 12) })
		b.MouseButton1Click:Connect(function()
			showTab(t[1])
		end)
		tabButtons[t[1]] = b
		local page = make("ScrollingFrame", { Size = UDim2.new(1, -24, 1, -70), Position = UDim2.fromOffset(12, 60), BackgroundTransparency = 1,
			ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, BorderSizePixel = 0 }, shop)
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, page)
		pages[t[1]] = page
	end

	reveal = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Visible = false, ZIndex = 20 }, gui)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.B then
			toggleShop()
		end
	end)
	for _, attr in ipairs({ "Coins", "Rating", "Tier", "Wins", "Vip" }) do
		player:GetAttributeChangedSignal(attr):Connect(refreshProfile)
	end
	player:GetAttributeChangedSignal("Queue"):Connect(refreshQueues)
	refreshProfile()
	refreshQueues()
	task.spawn(function()
		while true do
			task.wait(0.5)
			if gui.Enabled then
				refreshQueues()
			end
		end
	end)
end

return Lobby
