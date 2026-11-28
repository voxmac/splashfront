-- 로비 UI: 프로필 · 접속자 목록(왼쪽) · 매치 참가(오른쪽 아래) · 상점 · 랭킹 TOP 50 · 크레이트 개봉 연출
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local ModelKit = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ModelKit"))
local PolicyService = game:GetService("PolicyService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local WeaponSkins = require(ReplicatedStorage.Shared.WeaponSkins)
local SoundBank = require(script.Parent:WaitForChild("SoundBank"))
local UI = require(script.Parent:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local Lobby = {}
local C = UI.Colors
local make, corner, label, button = UI.make, UI.corner, UI.label, UI.button

local remotes, HUD
local gui, profileLbl, matchFrame, matchBody, statusLbl, shop, pages, tabButtons, reveal, board, boardList, peopleList, questPanel, questList
local HttpService = game:GetService("HttpService")
local lastState = nil
local matchSig, peopleSig = "", ""
local randomItemsRestricted = false
local modalHandler = function() end

local TIER_COLOR = {
	["브론즈"] = Color3.fromRGB(205, 127, 50), ["실버"] = Color3.fromRGB(200, 205, 215), ["골드"] = Color3.fromRGB(255, 205, 60),
	["플래티넘"] = Color3.fromRGB(90, 230, 210), ["다이아몬드"] = Color3.fromRGB(110, 170, 255), ["크로마 마스터"] = Color3.fromRGB(255, 80, 200),
}

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

local function clear(page)
	for _, c in ipairs(page:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function updateModal()
	modalHandler((shop and shop.Visible) or (board and board.Visible) or (reveal and reveal.Visible) or (questPanel and questPanel.Visible) or false)
end

------------------------------------------------------------------------
-- 상점 페이지
------------------------------------------------------------------------
local function buildWeapons(page)
	clear(page)
	local coins = player:GetAttribute("Coins") or 0
	local equipped = player:GetAttribute("Weapon")
	for i, w in ipairs(Weapons.List) do
		if ModelKit.HasStoreModel(w.Id) then -- 상점 총 모델이 없으면 표시 안 함
		local row = make("Frame", { Size = UDim2.new(1, -10, 0, 112), BackgroundColor3 = C.Panel, LayoutOrder = i }, page)
		corner(row, 14)
		if equipped == w.Id then
			UI.stroke(row, C.Cyan, 2)
		end
		local img = make("Frame", { Size = UDim2.fromOffset(170, 96), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.Panel2 }, row)
		corner(img, 12)
		UI.gradient(img, Color3.fromRGB(70, 66, 110), Color3.fromRGB(34, 32, 54), 90)
		UI.GunImage(img, w.Id, C.Cyan, Cosmetics.ById[player:GetAttribute("Skin") or ""], nil, WeaponSkins.LookFor(player, w.Id))
		label(row, { Text = w.Name, Font = Enum.Font.GothamBlack, TextSize = 26, Position = UDim2.fromOffset(194, 10), Size = UDim2.new(1, -380, 0, 30) })
		label(row, { Text = w.Class, TextSize = 18, TextColor3 = C.Gold, Position = UDim2.fromOffset(194, 42), Size = UDim2.new(1, -380, 0, 22) })
		label(row, { Text = string.format("피해 %s · 연사 %.2f초 · 사거리 %d · 페인트 %s", w.Pellets > 1 and (w.Damage .. "×" .. w.Pellets) or tostring(w.Damage),
			w.FireInterval, w.Range, tostring(w.PaintRadius)), Position = UDim2.fromOffset(194, 70), Size = UDim2.new(1, -380, 0, 22),
			TextSize = 17, TextColor3 = C.Sub, Font = Enum.Font.GothamMedium })
		local isOwned = owned("Owned", w.Id)
		local text, color
		if equipped == w.Id then
			text, color = "장착 중", C.Dim
		elseif isOwned then
			text, color = "장착", C.Green
		else
			text = string.format("%d", w.Price)
			color = coins >= w.Price and C.Pink or Color3.fromRGB(90, 60, 80)
		end
		local b = button(row, text, color, { Size = UDim2.fromOffset(160, 52), Position = UDim2.new(1, -176, 0.5, -26), TextSize = 22 })
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
end

local function buildCrate(page)
	clear(page)
	local top = make("Frame", { Size = UDim2.new(1, -10, 0, 196), BackgroundColor3 = C.Panel, LayoutOrder = 1 }, page)
	corner(top, 14)
	UI.gradient(top, Color3.fromRGB(90, 50, 140), Color3.fromRGB(30, 28, 48), 0)
	label(top, { Text = "크로마 크레이트", TextSize = 30, Font = Enum.Font.FredokaOne, Position = UDim2.fromOffset(18, 12), Size = UDim2.new(0.62, 0, 0, 36) })
	label(top, { Text = "무기 스킨 컬렉션 · 컬렉션 세트 패턴·이펙트 · 기존 외형 중 1개 (외형 전용, 능력치 변화 없음)", TextSize = 17, Font = Enum.Font.GothamMedium,
		TextColor3 = C.Sub, Position = UDim2.fromOffset(18, 54), Size = UDim2.new(0.64, 0, 0, 22), TextWrapped = true })
	local pity = player:GetAttribute("CratePity") or 0
	label(top, { Text = string.format("천장 %d / %d · %d회 안에 레전더리 확정", pity, Cosmetics.PityCount, Cosmetics.PityCount - pity), TextSize = 17,
		TextColor3 = C.Gold, Position = UDim2.fromOffset(18, 84), Size = UDim2.new(0.64, 0, 0, 22) })
	if randomItemsRestricted then
		label(top, { Text = "이 계정/지역에서는 유료 랜덤 상자를 이용할 수 없어요.", TextColor3 = Color3.fromRGB(255, 140, 140), TextSize = 17,
			Position = UDim2.fromOffset(18, 114), Size = UDim2.new(0.9, 0, 0, 22) })
	else
		local buy = button(top, Cosmetics.CratePrice .. " R$  개봉", Color3.fromRGB(255, 190, 40),
			{ Size = UDim2.fromOffset(210, 56), Position = UDim2.new(1, -226, 0, 16), TextColor3 = Color3.fromRGB(40, 20, 0), TextSize = 24 })
		buy.MouseButton1Click:Connect(function()
			local id = Config.Monetization.CrateProductId
			if id == 0 then
				HUD.Banner("Config.Monetization.CrateProductId에 개발자 상품 ID를 넣어주세요", Color3.fromRGB(255, 200, 80))
				return
			end
			MarketplaceService:PromptProductPurchase(player, id)
		end)
		-- 포인트(코인)로 개봉
		local coinPrice = Config.CrateCoinPrice or 5000
		local coins = player:GetAttribute("Coins") or 0
		local cbuy = button(top, string.format("%d 코인  개봉", coinPrice), coins >= coinPrice and C.Cyan or C.Dim,
			{ Size = UDim2.fromOffset(210, 52), Position = UDim2.new(1, -226, 0, 80), TextColor3 = Color3.fromRGB(10, 20, 40), TextSize = 21 })
		cbuy.MouseButton1Click:Connect(function()
			if (player:GetAttribute("Coins") or 0) < coinPrice then
				HUD.Banner(string.format("코인이 부족해요 (%d 필요)", coinPrice), Color3.fromRGB(255, 180, 120))
				return
			end
			shopCall("crateCoins")
		end)
		if RunService:IsStudio() then
			local test = button(top, "Studio 테스트 개봉", C.Dim, { Size = UDim2.fromOffset(210, 38), Position = UDim2.new(1, -226, 0, 142), TextSize = 16 })
			test.MouseButton1Click:Connect(function()
				shopCall("crateTest")
			end)
		end
	end

	-- 확률 공개표 (아이템 이미지 카드)
	local order = 2
	for _, r in ipairs(Cosmetics.Rarities) do
		local head = make("Frame", { Size = UDim2.new(1, -10, 0, 40), BackgroundColor3 = r.Color, LayoutOrder = order }, page)
		corner(head, 10)
		label(head, { Text = string.format("%s  %d%%   (중복 시 %d 코인 환급)", r.Name, r.Chance, r.Refund), Font = Enum.Font.GothamBlack, TextSize = 20,
			Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), TextColor3 = Color3.fromRGB(15, 15, 20) })
		order = order + 1
		local grid = make("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, page)
		make("UIGridLayout", { CellSize = UDim2.new(0.25, -10, 0, 176), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
		order = order + 1
		for _, item in ipairs(Cosmetics.CrateByRarity[r.Id]) do
			local kindName = Cosmetics.KindName(item.Kind)
			local have = owned("OwnedCosmetics", item.Id)
			local card = make("Frame", { BackgroundColor3 = C.Panel }, grid)
			corner(card, 12)
			UI.stroke(card, r.Color, 2, have and 0 or 0.5)
			local pic = make("Frame", { Size = UDim2.new(1, -16, 0, 96), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.Panel2 }, card)
			corner(pic, 10)
			UI.gradient(pic, r.Color:Lerp(Color3.new(0, 0, 0), 0.55), Color3.fromRGB(26, 24, 40), 90)
			UI.ItemImage(pic, item)
			label(card, { Text = item.Name, TextSize = 18, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(10, 108), Size = UDim2.new(1, -20, 0, 22),
				TextTruncate = Enum.TextTruncate.AtEnd })
			if item.Kind == "WSkin" then
				have = false
				kindName = "무기 스킨 · 총 랜덤 1종"
			end
			label(card, { Text = kindName .. (have and "  · 보유" or ""), TextSize = 15, TextColor3 = have and Color3.fromRGB(140, 255, 170) or C.Sub,
				Position = UDim2.fromOffset(10, 130), Size = UDim2.new(1, -20, 0, 18) })
			label(card, { Text = string.format("%.2f%%", Cosmetics.ItemChance(item)), TextSize = 15, Font = Enum.Font.Code, TextColor3 = r.Color,
				Position = UDim2.fromOffset(10, 150), Size = UDim2.new(1, -20, 0, 18) })
		end
	end
end

local function buildCollection(page)
	clear(page)
	local slots = { Skin = "Skin", Pattern = "Pattern", Effect = "KillEffect" }
	local kinds = { { "Skin", "무기 스킨" }, { "Pattern", "페인트 패턴" }, { "Effect", "처치 이펙트" } }
	local order = 1
	local any = false
	-- 보유 무기 (상점에서 산 총은 계속 남아 있고 여기서 바로 장착)
	label(page, { Text = "보유 무기", TextSize = 24, Font = Enum.Font.GothamBlack, Size = UDim2.new(1, -10, 0, 34), LayoutOrder = order })
	order = order + 1
	local wgrid = make("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, page)
	make("UIGridLayout", { CellSize = UDim2.new(0.25, -10, 0, 150), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, wgrid)
	order = order + 1
	local equippedW = player:GetAttribute("Weapon")
	for i, w in ipairs(Weapons.List) do
		if owned("Owned", w.Id) then
			local cardF = make("Frame", { BackgroundColor3 = C.Panel, LayoutOrder = i }, wgrid)
			corner(cardF, 12)
			UI.stroke(cardF, (equippedW == w.Id) and C.Cyan or C.Dim, 2, (equippedW == w.Id) and 0 or 0.5)
			local pic = make("Frame", { Size = UDim2.new(1, -16, 0, 70), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.Panel2 }, cardF)
			corner(pic, 10)
			UI.GunImage(pic, w.Id, C.Cyan, Cosmetics.ById[player:GetAttribute("Skin") or ""], nil, WeaponSkins.LookFor(player, w.Id))
			label(cardF, { Text = w.Name, TextSize = 16, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(10, 80), Size = UDim2.new(1, -20, 0, 20),
				TextTruncate = Enum.TextTruncate.AtEnd })
			local b = button(cardF, (equippedW == w.Id) and "장착 중" or "장착", (equippedW == w.Id) and C.Dim or C.Green,
				{ Size = UDim2.new(1, -16, 0, 36), Position = UDim2.new(0, 8, 1, -42), TextSize = 17 })
			b.MouseButton1Click:Connect(function()
				if equippedW ~= w.Id then
					shopCall("equip", w.Id)
					task.wait(0.2)
					buildCollection(page)
				end
			end)
		end
	end
	-- 보유 무기 스킨 (총별 장착)
	local wsOwned = {}
	for x in string.gmatch(player:GetAttribute("OwnedWSkins") or "", "[^,]+") do
		table.insert(wsOwned, x)
	end
	if #wsOwned > 0 then
		any = true
		table.sort(wsOwned)
		local eq = WeaponSkins.ParseEquip(player:GetAttribute("WSkinEquip"))
		label(page, { Text = "무기 스킨", TextSize = 24, Font = Enum.Font.GothamBlack, Size = UDim2.new(1, -10, 0, 34), LayoutOrder = order })
		order = order + 1
		local sgrid = make("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, page)
		make("UIGridLayout", { CellSize = UDim2.new(0.25, -10, 0, 176), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, sgrid)
		order = order + 1
		for i, sid in ipairs(wsOwned) do
			local lineId, wid = WeaponSkins.Split(sid)
			local line = WeaponSkins.LineById[lineId or ""]
			if line and Weapons.ById[wid] then
				local on = eq[wid] and eq[wid].Line == lineId
				local tier = WeaponSkins.TierById[line.Tier]
				local cardF = make("Frame", { BackgroundColor3 = C.Panel, LayoutOrder = i }, sgrid)
				corner(cardF, 12)
				UI.stroke(cardF, tier.Color, 2, on and 0 or 0.5)
				local pic = make("Frame", { Size = UDim2.new(1, -16, 0, 90), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1) }, cardF)
				corner(pic, 10)
				UI.gradient(pic, tier.Color:Lerp(Color3.new(1, 1, 1), 0.35), tier.Color:Lerp(Color3.fromRGB(40, 36, 70), 0.45), 90)
				UI.GunImage(pic, wid, C.Cyan, nil, nil, WeaponSkins.Look(lineId, on and eq[wid].V or 1))
				label(cardF, { Text = line.Name .. " · " .. Weapons.Get(wid).Name, TextSize = 14, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(10, 100),
					Size = UDim2.new(1, -20, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
				local b = button(cardF, on and "해제" or "장착", on and C.Dim or C.Green, { Size = UDim2.new(1, -16, 0, 36), Position = UDim2.new(0, 8, 1, -42), TextSize = 17 })
				b.MouseButton1Click:Connect(function()
					shopCall(on and "unequipWSkin" or "equipWSkin", on and wid or sid)
					task.wait(0.2)
					buildCollection(page)
				end)
			end
		end
	end
	for _, k in ipairs(kinds) do
		label(page, { Text = k[2], TextSize = 24, Font = Enum.Font.GothamBlack, Size = UDim2.new(1, -10, 0, 34), LayoutOrder = order })
		order = order + 1
		for _, item in ipairs(Cosmetics.Items) do
			if item.Kind == k[1] and owned("OwnedCosmetics", item.Id) then
				any = true
				local r = Cosmetics.Rarity(item.Rarity)
				local equipped = player:GetAttribute(slots[item.Kind]) == item.Id
				local row = make("Frame", { Size = UDim2.new(1, -10, 0, 76), BackgroundColor3 = C.Panel, LayoutOrder = order }, page)
				corner(row, 12)
				UI.stroke(row, r.Color, 2, equipped and 0 or 0.6)
				local pic = make("Frame", { Size = UDim2.fromOffset(100, 60), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.Panel2 }, row)
				corner(pic, 10)
				UI.ItemImage(pic, item)
				label(row, { Text = item.Name, TextSize = 22, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(122, 10), Size = UDim2.new(1, -280, 0, 28) })
				label(row, { Text = r.Name, TextSize = 17, TextColor3 = r.Color, Position = UDim2.fromOffset(122, 40), Size = UDim2.new(1, -280, 0, 22) })
				local b = button(row, equipped and "해제" or "장착", equipped and C.Dim or C.Green,
					{ Size = UDim2.fromOffset(130, 46), Position = UDim2.new(1, -146, 0.5, -23), TextSize = 20 })
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
		label(page, { Text = "아직 보유한 외형이 없어요. 크로마 크레이트에서 얻을 수 있어요!", Size = UDim2.new(1, -10, 0, 40), LayoutOrder = 99,
			TextSize = 19, TextColor3 = C.Sub })
	end
end

-- 포인트(코인)로 사는 스킨: 크레이트 아이템을 등급별 가격으로 바로 구매
local function buildSkins(page)
	clear(page)
	local coins = player:GetAttribute("Coins") or 0
	label(page, { Text = string.format("보유 코인 %d · 일일·주간 미션으로 모아서 원하는 스킨을 바로 구매하세요", coins), TextSize = 18, TextColor3 = C.Gold,
		Size = UDim2.new(1, -10, 0, 30), LayoutOrder = 0, TextWrapped = true })
	local order = 1
	for _, r in ipairs(Cosmetics.Rarities) do
		local price = Config.SkinPrices[r.Id]
		local head = make("Frame", { Size = UDim2.new(1, -10, 0, 40), BackgroundColor3 = r.Color, LayoutOrder = order }, page)
		corner(head, 10)
		label(head, { Text = string.format("%s  ·  %d", r.Name, price), Font = Enum.Font.GothamBlack, TextSize = 20, Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -28, 1, 0), TextColor3 = Color3.fromRGB(15, 15, 20) })
		order = order + 1
		local grid = make("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, page)
		make("UIGridLayout", { CellSize = UDim2.new(0.25, -10, 0, 220), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
		order = order + 1
		for _, item in ipairs(Cosmetics.ByRarity[r.Id]) do
			if not item.Collection then
			local have = owned("OwnedCosmetics", item.Id)
			local kindName = (item.Kind == "Skin" and "무기 스킨") or (item.Kind == "Pattern" and "페인트 패턴") or "처치 이펙트"
			local cardF = make("Frame", { BackgroundColor3 = C.Panel }, grid)
			corner(cardF, 12)
			UI.stroke(cardF, r.Color, 2, have and 0 or 0.4)
			local pic = make("Frame", { Size = UDim2.new(1, -16, 0, 100), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.Panel2 }, cardF)
			corner(pic, 10)
			UI.gradient(pic, r.Color:Lerp(Color3.new(0, 0, 0), 0.5), Color3.fromRGB(26, 24, 40), 90)
			UI.ItemImage(pic, item)
			label(cardF, { Text = item.Name, TextSize = 18, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(10, 112), Size = UDim2.new(1, -20, 0, 22),
				TextTruncate = Enum.TextTruncate.AtEnd })
			label(cardF, { Text = kindName, TextSize = 15, TextColor3 = C.Sub, Position = UDim2.fromOffset(10, 136), Size = UDim2.new(1, -20, 0, 18) })
			local can = coins >= price
			local b = button(cardF, have and "보유" or (price .. " 코인"), have and C.Dim or (can and C.Green or Color3.fromRGB(90, 60, 80)),
				{ Size = UDim2.new(1, -16, 0, 42), Position = UDim2.new(0, 8, 1, -50), TextSize = 19 })
			b.MouseButton1Click:Connect(function()
				if have then
					return
				end
				shopCall("buyCosmetic", item.Id)
				task.wait(0.25)
				buildSkins(page)
			end)
			end
		end
	end
	-- 무기 스킨 컬렉션 세트: 같은 테마의 바닥 패턴 + 처치 이펙트
	label(page, { Text = "무기 스킨 컬렉션 세트 · 바닥 패턴 + 처치 이펙트", TextSize = 22, Font = Enum.Font.GothamBlack, Size = UDim2.new(1, -10, 0, 34),
		LayoutOrder = order })
	order = order + 1
	for _, line in ipairs(WeaponSkins.Lines) do
		local tier = WeaponSkins.TierById[line.Tier]
		local head = make("Frame", { Size = UDim2.new(1, -10, 0, 38), BackgroundColor3 = tier.Color, LayoutOrder = order }, page)
		corner(head, 10)
		label(head, { Text = string.format("%s  ·  %s", line.Name, tier.Name), Font = Enum.Font.GothamBlack, TextSize = 19, Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -28, 1, 0), TextColor3 = Color3.fromRGB(15, 15, 20) })
		order = order + 1
		local grid = make("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, page)
		make("UIGridLayout", { CellSize = UDim2.new(0.5, -10, 0, 200), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
		order = order + 1
		for _, item in ipairs(Cosmetics.Items) do
			if item.Collection == line.Id then
				local r = Cosmetics.Rarity(item.Rarity)
				local price = Config.SkinPrices[r.Id]
				local have = owned("OwnedCosmetics", item.Id)
				local cardF = make("Frame", { BackgroundColor3 = C.Panel, LayoutOrder = (item.Kind == "Pattern") and 1 or 2 }, grid)
				corner(cardF, 12)
				UI.stroke(cardF, tier.Color, 2, have and 0 or 0.4)
				local pic = make("Frame", { Size = UDim2.new(1, -16, 0, 100), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.Panel2 }, cardF)
				corner(pic, 10)
				UI.gradient(pic, tier.Color:Lerp(Color3.new(0, 0, 0), 0.5), Color3.fromRGB(26, 24, 40), 90)
				UI.ItemImage(pic, item)
				label(cardF, { Text = item.Name, TextSize = 18, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(10, 112), Size = UDim2.new(1, -20, 0, 22),
					TextTruncate = Enum.TextTruncate.AtEnd })
				label(cardF, { Text = (item.Kind == "Pattern") and "바닥 페인트 패턴" or "처치 이펙트", TextSize = 15, TextColor3 = C.Sub,
					Position = UDim2.fromOffset(10, 136), Size = UDim2.new(0.5, -10, 0, 18) })
				local can = coins >= price
				local b = button(cardF, have and "보유" or (price .. " 코인"), have and C.Dim or (can and C.Green or Color3.fromRGB(90, 60, 80)),
					{ Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -158, 1, -48), TextSize = 18 })
				b.MouseButton1Click:Connect(function()
					if have then
						return
					end
					shopCall("buyCosmetic", item.Id)
					task.wait(0.25)
					buildSkins(page)
				end)
			end
		end
	end
end

------------------------------------------------------------------------
-- 무기 스킨 상점: 총을 고르고 → 등급별 컬렉션 스킨을 사서 → 그 총에만 장착 (변형 색상 선택)
------------------------------------------------------------------------
local wsWeapon = nil       -- 지금 보고 있는 총
local wsPreview = {}       -- [라인 Id] = 미리보기 변형 번호

local function shopWeaponIds()
	local list = {}
	for _, w in ipairs(Weapons.List) do
		if ModelKit.HasStoreModel(w.Id) then
			table.insert(list, w.Id)
		end
	end
	return list
end

local function ownedSet()
	local set = {}
	for x in string.gmatch(player:GetAttribute("OwnedWSkins") or "", "[^,]+") do
		set[x] = true
	end
	return set
end

local function buildWeaponSkins(page)
	clear(page)
	local coins = player:GetAttribute("Coins") or 0
	local have = ownedSet()
	local equip = WeaponSkins.ParseEquip(player:GetAttribute("WSkinEquip"))
	local ids = shopWeaponIds()
	if not wsWeapon or not table.find(ids, wsWeapon) then
		wsWeapon = table.find(ids, player:GetAttribute("Weapon")) and player:GetAttribute("Weapon") or ids[1]
	end
	local w = Weapons.Get(wsWeapon)
	local order = 0
	local function nextOrder()
		order = order + 1
		return order
	end
	label(page, { Text = string.format("보유 코인 %d · 총마다 따로 사고 따로 장착해요 (외형 전용, 능력치 변화 없음)", coins), TextSize = 17,
		TextColor3 = C.Gold, Size = UDim2.new(1, -10, 0, 26), LayoutOrder = nextOrder() })

	-- 총 고르기
	local chips = make("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder() }, page)
	make("UIGridLayout", { CellSize = UDim2.new(1 / 6, -6, 0, 36), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, chips)
	for i, wid in ipairs(ids) do
		local ww = Weapons.Get(wid)
		local sel = wid == wsWeapon
		local b = button(chips, ww.Name, sel and C.Pink or C.Panel2, { TextSize = 15, LayoutOrder = i, TextTruncate = Enum.TextTruncate.AtEnd })
		b.MouseButton1Click:Connect(function()
			wsWeapon = wid
			buildWeaponSkins(page)
		end)
	end

	-- 지금 장착한 모습
	local cur = equip[wsWeapon]
	local curLine = cur and WeaponSkins.LineById[cur.Line]
	local top = make("Frame", { Size = UDim2.new(1, -10, 0, 150), BackgroundColor3 = C.Panel, LayoutOrder = nextOrder() }, page)
	corner(top, 14)
	UI.gradient(top, Color3.fromRGB(70, 50, 120), Color3.fromRGB(30, 28, 48), 0)
	local pic = make("Frame", { Size = UDim2.fromOffset(300, 134), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1) }, top)
	corner(pic, 12)
	UI.gradient(pic, Color3.fromRGB(150, 140, 200), Color3.fromRGB(70, 64, 110), 90)
	UI.GunImage(pic, wsWeapon, C.Cyan, nil, nil, cur and WeaponSkins.Look(cur.Line, cur.V) or nil)
	label(top, { Text = w.Name, TextSize = 26, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(324, 14), Size = UDim2.new(1, -510, 0, 30) })
	label(top, { Text = curLine and string.format("장착: %s · %s", curLine.Name, curLine.Variants[cur.V] and curLine.Variants[cur.V].Name or "") or "장착: 기본 외형",
		TextSize = 18, TextColor3 = curLine and WeaponSkins.TierById[curLine.Tier].Color or C.Sub, Position = UDim2.fromOffset(324, 50), Size = UDim2.new(1, -510, 0, 24) })
	label(top, { Text = "스탠다드 → 디럭스(투톤) → 프리미엄(발광·색상 변형) → 얼티밋(입자·전용 피니셔)", TextSize = 14, TextColor3 = C.Sub,
		Position = UDim2.fromOffset(324, 80), Size = UDim2.new(1, -510, 0, 20), TextWrapped = true })
	if curLine then
		local rb = button(top, "기본으로", C.Dim, { Size = UDim2.fromOffset(150, 46), Position = UDim2.new(1, -166, 0.5, -23), TextSize = 18 })
		rb.MouseButton1Click:Connect(function()
			shopCall("unequipWSkin", wsWeapon)
			task.wait(0.2)
			buildWeaponSkins(page)
		end)
	end

	-- 등급별 스킨 카드
	for _, tier in ipairs(WeaponSkins.Tiers) do
		local head = make("Frame", { Size = UDim2.new(1, -10, 0, 38), BackgroundColor3 = tier.Color, LayoutOrder = nextOrder() }, page)
		corner(head, 10)
		label(head, { Text = string.format("%s  ·  %d 코인", tier.Name, tier.Price), Font = Enum.Font.GothamBlack, TextSize = 20,
			Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), TextColor3 = Color3.fromRGB(15, 15, 20) })
		local grid = make("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder() }, page)
		make("UIGridLayout", { CellSize = UDim2.new(0.5, -10, 0, 270), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
		for _, line in ipairs(WeaponSkins.Lines) do
			if line.Tier == tier.Id then
				local skinId = WeaponSkins.SkinId(line.Id, wsWeapon)
				local mine = have[skinId]
				local isOn = cur and cur.Line == line.Id
				local v = wsPreview[line.Id] or (isOn and cur.V) or 1
				local card = make("Frame", { BackgroundColor3 = C.Panel, LayoutOrder = line.Order }, grid)
				corner(card, 12)
				UI.stroke(card, tier.Color, 2, (mine or isOn) and 0 or 0.5)
				local cp = make("Frame", { Size = UDim2.new(1, -16, 0, 144), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1) }, card)
				corner(cp, 10)
				UI.gradient(cp, tier.Color:Lerp(Color3.new(1, 1, 1), 0.35), tier.Color:Lerp(Color3.fromRGB(40, 36, 70), 0.45), 90)
				UI.GunImage(cp, wsWeapon, C.Cyan, nil, nil, WeaponSkins.Look(line.Id, v))
				label(card, { Text = line.Name, TextSize = 19, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(12, 156), Size = UDim2.new(1, -24, 0, 22),
					TextTruncate = Enum.TextTruncate.AtEnd })
				label(card, { Text = line.Desc, TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(12, 179), Size = UDim2.new(1, -24, 0, 18),
					TextTruncate = Enum.TextTruncate.AtEnd })
				-- 색상 변형 점 (보유했으면 누르면 그 색으로 장착, 아니면 미리보기)
				if #line.Variants > 1 then
					for vi, vv in ipairs(line.Variants) do
						local dot = make("TextButton", { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(12 + (vi - 1) * 34, 202), Text = "",
							BackgroundColor3 = vv.Accent or vv.Body, AutoButtonColor = true }, card)
						corner(dot, 13)
						UI.stroke(dot, (vi == v) and Color3.new(1, 1, 1) or Color3.fromRGB(20, 20, 30), 2)
						dot.MouseButton1Click:Connect(function()
							wsPreview[line.Id] = vi
							if mine then
								shopCall("equipWSkin", skinId .. ":" .. vi)
								task.wait(0.2)
							end
							buildWeaponSkins(page)
						end)
					end
					label(card, { Text = line.Variants[v].Name, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(18 + #line.Variants * 34, 204),
						Size = UDim2.fromOffset(110, 22) })
				end
				local text, color
				if isOn then
					text, color = "장착 중", C.Dim
				elseif mine then
					text, color = "장착", C.Green
				else
					text, color = tier.Price .. " 코인", (coins >= tier.Price) and C.Pink or Color3.fromRGB(90, 60, 80)
				end
				local b = button(card, text, color, { Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -158, 1, -48), TextSize = 18 })
				b.MouseButton1Click:Connect(function()
					if isOn then
						return
					end
					if mine then
						shopCall("equipWSkin", skinId .. ":" .. v)
					else
						shopCall("buyWSkin", skinId)
					end
					task.wait(0.25)
					buildWeaponSkins(page)
				end)
			end
		end
	end

	-- 컬렉션 묶음: 그 컬렉션을 모든 총에 한 번에 (할인)
	label(page, { Text = string.format("컬렉션 묶음 · 모든 총 한 번에 %d%% 할인", math.floor(WeaponSkins.BundleDiscount * 100)), TextSize = 22,
		Font = Enum.Font.GothamBlack, Size = UDim2.new(1, -10, 0, 34), LayoutOrder = nextOrder() })
	for _, line in ipairs(WeaponSkins.Lines) do
		local tier = WeaponSkins.TierById[line.Tier]
		local price, n = WeaponSkins.BundlePrice(line.Id, ids, have)
		local row = make("Frame", { Size = UDim2.new(1, -10, 0, 54), BackgroundColor3 = C.Panel, LayoutOrder = nextOrder() }, page)
		corner(row, 10)
		UI.stroke(row, tier.Color, 2, 0.5)
		label(row, { Text = line.Name, TextSize = 19, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.4, 0, 1, 0) })
		label(row, { Text = n > 0 and string.format("%s · 남은 %d종", tier.Name, n) or (tier.Name .. " · 모두 보유"), TextSize = 15, TextColor3 = tier.Color,
			Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.3, 0, 1, 0) })
		local b = button(row, n > 0 and (price .. " 코인") or "보유", n > 0 and ((coins >= price) and C.Pink or Color3.fromRGB(90, 60, 80)) or C.Dim,
			{ Size = UDim2.fromOffset(170, 40), Position = UDim2.new(1, -180, 0.5, -20), TextSize = 17 })
		b.MouseButton1Click:Connect(function()
			if n == 0 then
				return
			end
			shopCall("buyWBundle", line.Id)
			task.wait(0.3)
			buildWeaponSkins(page)
		end)
	end
end

-- 로벅스 충전: VIP 게임패스 + 코인 팩 (가격은 Roblox에서 실시간으로 읽음)
local priceCache = {}
local function robuxPrice(id, infoType)
	local key = tostring(infoType) .. id
	if priceCache[key] then
		return priceCache[key]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType)
	end)
	local p = ok and info and info.PriceInRobux or nil
	priceCache[key] = p
	return p
end

local function buildRobux(page)
	clear(page)
	label(page, { Text = "로벅스로 VIP와 코인을 충전할 수 있어요 · 코인은 스킨 상점·무기 구매에 사용", TextSize = 18, TextColor3 = C.Sub,
		Size = UDim2.new(1, -10, 0, 28), LayoutOrder = 0 })
	local grid = make("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1 }, page)
	make("UIGridLayout", { CellSize = UDim2.new(0.25, -10, 0, 250), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	local M = Config.Monetization
	local items = {
		{ Kind = "Pass", Id = M.VipGamePassId, Title = "VIP", Sub = "코인 획득 1.25배 (영구)", Icon = "crown", Color = Color3.fromRGB(255, 180, 40) },
	}
	local packs = {}
	for id, coins in pairs(M.CoinProducts or {}) do
		table.insert(packs, { Id = id, Coins = coins })
	end
	table.sort(packs, function(a, b)
		return a.Coins < b.Coins
	end)
	for _, pk in ipairs(packs) do
		table.insert(items, { Kind = "Product", Id = pk.Id, Title = string.format("코인 %d", pk.Coins), Sub = (pk.Coins >= 3000 and "50% 보너스")
			or (pk.Coins >= 1200 and "20% 보너스") or "기본 팩", Icon = "coin", Color = C.Cyan })
	end
	for i, it in ipairs(items) do
		if it.Id and it.Id ~= 0 then
			local owned = it.Kind == "Pass" and player:GetAttribute("Vip")
			local cardF = make("Frame", { BackgroundColor3 = C.Panel, LayoutOrder = i }, grid)
			corner(cardF, 14)
			UI.stroke(cardF, it.Color, 2, 0.2)
			local pic = make("Frame", { Size = UDim2.new(1, -16, 0, 110), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.Panel2 }, cardF)
			corner(pic, 12)
			UI.gradient(pic, it.Color:Lerp(Color3.new(0, 0, 0), 0.35), Color3.fromRGB(26, 24, 40), 90)
			UI.Icon(pic, it.Icon, "", { Size = UDim2.fromOffset(88, 88), Position = UDim2.new(0.5, -44, 0.5, -44) })
			label(cardF, { Text = it.Title, TextSize = 22, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(10, 124), Size = UDim2.new(1, -20, 0, 28),
				TextXAlignment = Enum.TextXAlignment.Center })
			label(cardF, { Text = it.Sub, TextSize = 15, TextColor3 = C.Sub, Position = UDim2.fromOffset(10, 154), Size = UDim2.new(1, -20, 0, 20),
				TextXAlignment = Enum.TextXAlignment.Center })
			local b = button(cardF, owned and "보유 중" or "...", owned and C.Dim or Color3.fromRGB(0, 176, 111),
				{ Size = UDim2.new(1, -16, 0, 46), Position = UDim2.new(0, 8, 1, -54), TextSize = 20 })
			if not owned then
				task.spawn(function()
					local price = robuxPrice(it.Id, it.Kind == "Pass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
					if b.Parent then
						b.Text = price and (price .. " R$") or "구매"
					end
				end)
			end
			b.MouseButton1Click:Connect(function()
				if owned then
					return
				end
				if it.Kind == "Pass" then
					MarketplaceService:PromptGamePassPurchase(player, it.Id)
				else
					MarketplaceService:PromptProductPurchase(player, it.Id)
				end
			end)
		end
	end
end

local builders = { Weapons = buildWeapons, WSkins = buildWeaponSkins, Skins = buildSkins, Crate = buildCrate, Collection = buildCollection, Robux = buildRobux }
local currentTab = "Weapons"

local function showTab(name)
	currentTab = name
	for n, p in pairs(pages) do
		p.Visible = (n == name)
	end
	for n, b in pairs(tabButtons) do
		b.BackgroundColor3 = (n == name) and C.Pink or C.Panel2
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
		board.Visible = false
		questPanel.Visible = false
		remotes.Telemetry:FireServer("OpenedShop")
		showTab(currentTab)
	end
	updateModal()
end

------------------------------------------------------------------------
-- 일일·주간 미션 창
------------------------------------------------------------------------
local function fmtLeft(sec)
	sec = math.max(0, math.floor(sec or 0))
	local d = math.floor(sec / 86400)
	local h = math.floor((sec % 86400) / 3600)
	local m = math.floor((sec % 3600) / 60)
	if d > 0 then
		return string.format("%d일 %d시간", d, h)
	end
	return string.format("%d시간 %d분", h, m)
end

function Lobby.UpdateQuests()
	if not questList then
		return
	end
	local ok, list = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Quests") or "[]")
	end)
	if not ok or type(list) ~= "table" then
		return
	end
	clear(questList)
	local order = 0
	for _, period in ipairs({ "Daily", "Weekly" }) do
		local left = nil
		for _, q in ipairs(list) do
			if q.Period == period then
				left = q.Left
			end
		end
		order = order + 1
		label(questList, { Text = string.format("%s  ·  초기화까지 %s", period == "Daily" and "일일 미션" or "주간 미션", fmtLeft(left)), TextSize = 21,
			Font = Enum.Font.GothamBlack, Size = UDim2.new(1, -10, 0, 32), LayoutOrder = order })
		for _, q in ipairs(list) do
			if q.Period == period then
				order = order + 1
				local row = make("Frame", { Size = UDim2.new(1, -10, 0, 70), BackgroundColor3 = q.Done and Color3.fromRGB(34, 60, 50) or C.Panel, LayoutOrder = order }, questList)
				corner(row, 12)
				UI.stroke(row, q.Done and Color3.fromRGB(120, 255, 170) or C.Dim, 2, 0.3)
				UI.Icon(row, q.Done and "check" or "quest", "", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(12, 15) })
				label(row, { Text = q.Name, TextSize = 20, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(62, 10), Size = UDim2.new(1, -230, 0, 24) })
				local bar = make("Frame", { Size = UDim2.new(1, -230, 0, 10), Position = UDim2.fromOffset(62, 44), BackgroundColor3 = C.Dim }, row)
				corner(bar, 5)
				local fill = make("Frame", { Size = UDim2.fromScale(math.clamp(q.P / math.max(1, q.Goal), 0, 1), 1), BorderSizePixel = 0,
					BackgroundColor3 = q.Done and Color3.fromRGB(120, 255, 170) or C.Cyan }, bar)
				corner(fill, 5)
				label(row, { Text = string.format("%d / %d", q.P, q.Goal), TextSize = 16, TextColor3 = C.Sub, Position = UDim2.new(1, -164, 0, 10),
					Size = UDim2.fromOffset(70, 22), TextXAlignment = Enum.TextXAlignment.Right })
				label(row, { Text = (q.Done and "받음 " or "") .. "+" .. q.Reward .. " 코인", TextSize = 19, Font = Enum.Font.GothamBlack, TextColor3 = C.Gold,
					Position = UDim2.new(1, -150, 0, 34), Size = UDim2.fromOffset(136, 26), TextXAlignment = Enum.TextXAlignment.Right })
			end
		end
	end
end

local function openQuests()
	if player:GetAttribute("InMatch") then
		return
	end
	shop.Visible = false
	board.Visible = false
	questPanel.Visible = true
	Lobby.UpdateQuests()
	updateModal()
end

------------------------------------------------------------------------
-- 랭킹 TOP 50
------------------------------------------------------------------------
local COLS = { { "순위", 70 }, { "이름", 200 }, { "등급", 130 }, { "Rating", 110 }, { "승리", 80 }, { "MVP", 80 } }
local function rowCells(parent, values, color, font, size)
	local x = 16
	for i, col in ipairs(COLS) do
		label(parent, { Text = values[i], Position = UDim2.fromOffset(x, 0), Size = UDim2.new(0, col[2] - 8, 1, 0), TextSize = size or 18,
			Font = font or Enum.Font.GothamBold, TextColor3 = (type(color) == "table" and color[i]) or color or C.Text,
			TextXAlignment = (i == 2) and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
		x = x + col[2]
	end
end

local function openBoard()
	if player:GetAttribute("InMatch") then
		return
	end
	shop.Visible = false
	questPanel.Visible = false
	board.Visible = true
	updateModal()
	clear(boardList)
	label(boardList, { Text = "불러오는 중...", Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Sub })
	task.spawn(function()
		local ok, res = pcall(function()
			return remotes.Leaderboard:InvokeServer()
		end)
		clear(boardList)
		if not ok or not res then
			label(boardList, { Text = "랭킹을 불러오지 못했어요", Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center })
			return
		end
		for i, r in ipairs(res.Rows) do
			if i > 50 then
				break
			end
			local mine = r.UserId == player.UserId
			local row = make("Frame", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = mine and Color3.fromRGB(80, 40, 90) or ((i % 2 == 0) and C.Panel or C.Panel2),
				LayoutOrder = i }, boardList)
			corner(row, 8)
			if mine then
				UI.stroke(row, C.Pink, 2)
			end
			local medal = tostring(i)
			local tierColor = TIER_COLOR[r.Tier] or C.Text
			rowCells(row, { medal, r.Name, r.Tier, tostring(r.Rating), tostring(r.Wins or 0), tostring(r.MVPs or 0) }, { C.Gold, C.Text, tierColor, C.Cyan, C.Text, C.Gold })
		end
		if #res.Rows == 0 then
			label(boardList, { Text = "아직 랭크 기록이 없어요 · 랭크전에 참가해 보세요!", Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center })
		end
	end)
end

------------------------------------------------------------------------
-- 크레이트 개봉 연출: 흔들림 → 등급 빛 폭발 → 회전하는 빛줄기 + 아이템 카드
------------------------------------------------------------------------
function Lobby.ShowCrate(res)
	reveal.Visible = true
	updateModal()
	clear(reveal)
	local item = Cosmetics.ById[res.ItemId] or { Kind = res.Kind, Name = res.Name }
	local box = make("Frame", { Size = UDim2.fromOffset(150, 150), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(70, 60, 110) }, reveal)
	corner(box, 22)
	UI.stroke(box, Color3.new(1, 1, 1), 4)
	UI.label(box, { Text = "?", TextScaled = true, Font = Enum.Font.FredokaOne, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	SoundBank.Play("crate_shake", nil, 0.7)
	for i = 1, 8 do
		box.Rotation = (i % 2 == 0) and 9 or -9
		task.wait(0.07)
	end
	box:Destroy()

	-- 빛줄기
	local rays = make("Frame", { Size = UDim2.fromOffset(900, 900), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1 }, reveal)
	for k = 0, 11 do
		local ray = make("Frame", { Size = UDim2.new(0, 70, 0.5, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = res.Color, BorderSizePixel = 0, Rotation = k * 30 }, rays)
		make("UIGradient", { Transparency = NumberSequence.new(1, 0.55), Rotation = 90 }, ray)
	end
	local spin
	spin = RunService.RenderStepped:Connect(function(dt)
		if not rays.Parent then
			spin:Disconnect()
			return
		end
		rays.Rotation = rays.Rotation + dt * 25
	end)
	SoundBank.Play("crate_" .. string.lower(res.Rarity), nil, 0.8)

	local card = make("Frame", { Size = UDim2.fromOffset(40, 50), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Bg }, reveal)
	corner(card, 20)
	UI.stroke(card, res.Color, 5)
	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(340, 420) }):Play()
	local band = make("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = res.Color }, card)
	corner(band, 20)
	make("Frame", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), BackgroundColor3 = res.Color, BorderSizePixel = 0 }, band)
	label(band, { Text = res.RarityName .. "!", Font = Enum.Font.FredokaOne, TextScaled = true, Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5),
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(20, 16, 30) })
	local pic = make("Frame", { Size = UDim2.new(1, -32, 0, 200), Position = UDim2.fromOffset(16, 66), BackgroundColor3 = C.Panel2 }, card)
	corner(pic, 14)
	UI.gradient(pic, res.Color:Lerp(Color3.new(0, 0, 0), 0.4), Color3.fromRGB(20, 18, 32), 90)
	if res.Kind == "WSkin" then
		UI.GunImage(pic, res.WeaponId or "Rifle", C.Cyan, nil, nil, WeaponSkins.Look(res.Line, 1))
	else
		UI.ItemImage(pic, item)
	end
	local kindName = Cosmetics.KindName(res.Kind)
	label(card, { Text = res.Name, Font = Enum.Font.GothamBlack, TextSize = 28, Position = UDim2.fromOffset(16, 276), Size = UDim2.new(1, -32, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Center })
	local sub = kindName
	if res.Duplicate then
		sub = sub .. "  ·  중복 -> " .. res.Refund .. " 코인 환급"
	end
	if res.Pitied then
		sub = sub .. "  ·  천장 확정"
	end
	label(card, { Text = sub, TextSize = 17, TextColor3 = C.Sub, Position = UDim2.fromOffset(16, 312), Size = UDim2.new(1, -32, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true })
	local ok = button(card, "확인", C.Pink, { Size = UDim2.fromOffset(200, 52), Position = UDim2.new(0.5, -100, 1, -68), TextSize = 24 })
	ok.MouseButton1Click:Connect(function()
		reveal.Visible = false
		clear(reveal)
		updateModal()
		if shop.Visible then
			showTab(currentTab)
		end
	end)
end

------------------------------------------------------------------------
-- 매치 참가 (오른쪽 아래): 대기 중인 배틀만 목록 + 새 배틀 시작 + 방장 맵 선택
------------------------------------------------------------------------
local function queueTitle(q)
	local mode = Config.Modes[q.Mode]
	return (q.Mode == "Solo") and "솔로 페인트 로얄 8인" or string.format("%s %dvs%d", mode.Name, q.TeamSize, q.TeamSize)
end

local function rebuildMatch()
	local s = lastState
	local mine = player:GetAttribute("Queue")
	local counts = (s and s.QueueCounts) or {}
	local info = (s and s.QueueInfo) or {}
	local mySide = player:GetAttribute("QueueSide")
	local sig = tostring(mine) .. tostring(mySide) .. "|" .. (s and s.Phase or "") .. tostring(s and s.OpenSlots) .. tostring(s and s.EndsAt and math.floor((s.EndsAt - workspace:GetServerTimeNow()) / 10))
	for _, q in ipairs(Config.Queues) do
		local qi = info[q.Id] or {}
		local sd = qi.Sides or {}
		sig = sig .. q.Id .. (counts[q.Id] or 0) .. tostring(qi.Host) .. tostring(qi.Map) .. tostring(sd[1]) .. tostring(sd[2])
	end
	if sig == matchSig then
		return
	end
	matchSig = sig
	clear(matchBody)
	local order = 0
	local function nextOrder()
		order = order + 1
		return order
	end

	-- 진행 중인 배틀: 봇 자리(빈자리)가 있으면 바로 합류
	if s and s.Phase == "Playing" and (s.OpenSlots or 0) > 0 then
		local jb = button(matchBody, "", Color3.fromRGB(20, 120, 80), { Size = UDim2.new(1, 0, 0, 62), LayoutOrder = nextOrder(), Text = "" })
		UI.gradient(jb, Color3.fromRGB(40, 220, 130), Color3.fromRGB(10, 120, 80), 90)
		label(jb, { Text = "진행 중인 배틀 · " .. tostring(s.MapName or ""), Font = Enum.Font.GothamBlack, TextSize = 20, Position = UDim2.fromOffset(14, 6),
			Size = UDim2.new(1, -150, 0, 26) })
		local left = math.max(0, math.floor((s.EndsAt or 0) - workspace:GetServerTimeNow()))
		label(jb, { Text = string.format("%s · 남은 시간 %d:%02d · 빈자리 %d", tostring(s.ModeName or ""), left // 60, left % 60, s.OpenSlots), TextSize = 15,
			Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -150, 0, 20) })
		label(jb, { Text = "바로 합류 >", TextSize = 18, Font = Enum.Font.GothamBlack, Position = UDim2.new(1, -140, 0, 20), Size = UDim2.fromOffset(126, 24),
			TextXAlignment = Enum.TextXAlignment.Right })
		jb.MouseButton1Click:Connect(function()
			remotes.Queue:FireServer("quick")
		end)
	end
	label(matchBody, { Text = "대기 중인 배틀", TextSize = 17, TextColor3 = C.Sub, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = nextOrder() })
	local any = false
	for _, q in ipairs(Config.Queues) do
		local n = counts[q.Id] or 0
		if n > 0 or mine == q.Id then
			any = true
			local qi = info[q.Id] or {}
			local joined = mine == q.Id
			local b = button(matchBody, "", joined and C.Pink or C.Panel2, { Size = UDim2.new(1, 0, 0, 62), LayoutOrder = nextOrder(), Text = "" })
			label(b, { Text = queueTitle(q) .. (q.Ranked and "  [랭크]" or ""), Font = Enum.Font.GothamBlack, TextSize = 20, Position = UDim2.fromOffset(14, 6),
				Size = UDim2.new(1, -160, 0, 26) })
			label(b, { Text = string.format("%s  ·  %s", qi.Host or "-", qi.Map or "-"), TextSize = 15, TextColor3 = joined and Color3.new(1, 1, 1) or C.Sub,
				Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -160, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
			local sd = qi.Sides
			local countText = sd and string.format('<font color="#3CB4FF">●</font> %d/%d  <font color="#FF8A30">●</font> %d/%d', sd[1] or 0, q.TeamSize, sd[2] or 0, q.TeamSize)
				or string.format("%d명 대기", n)
			label(b, { Text = countText, TextSize = 17, TextColor3 = C.Gold, Position = UDim2.new(1, -150, 0, 6), Size = UDim2.fromOffset(136, 24),
				TextXAlignment = Enum.TextXAlignment.Right, RichText = true })
			-- 대기 취소는 발판에서 내려오면 됨 (나가기 버튼 없음)
			local status = joined and ((mySide == 1 and "블루 ZONE 대기") or (mySide == 2 and "오렌지 ZONE 대기") or "대기 중") or "참가 >"
			label(b, { Text = status, TextSize = 16, Font = Enum.Font.GothamBlack, Position = UDim2.new(1, -150, 0, 34),
				Size = UDim2.fromOffset(136, 20), TextXAlignment = Enum.TextXAlignment.Right })
			if not joined then
				b.MouseButton1Click:Connect(function()
					remotes.Queue:FireServer(q.Id)
				end)
			end
		end
	end
	if not any then
		label(matchBody, { Text = "지금 대기 중인 배틀이 없어요 · 아래에서 새로 시작하세요", TextSize = 16, TextColor3 = C.Sub, TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 40), LayoutOrder = nextOrder() })
	end

	-- 방장 맵 선택
	if mine then
		local qi = info[mine] or {}
		if qi.HostId == player.UserId and s and s.Maps then
			label(matchBody, { Text = "방장 · 맵을 고르세요", TextSize = 17, TextColor3 = C.Gold, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = nextOrder() })
			local row = make("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = nextOrder() }, matchBody)
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, row)
			local opts = { { nil, "순환" }, { "random", "랜덤" } }
			for _, m in ipairs(s.Maps) do
				table.insert(opts, { m.Id, m.Name })
			end
			local w = 1 / #opts
			for _, o in ipairs(opts) do
				local sel = (qi.MapId == o[1])
				local mb = button(row, o[2], sel and C.Cyan or C.Panel2, { Size = UDim2.new(w, -6, 1, 0), TextSize = 15, TextWrapped = true })
				mb.MouseButton1Click:Connect(function()
					remotes.Queue:FireServer("map", o[1])
				end)
			end
			-- 정원이 다 모이면 카운트다운 없이 바로 시작
			local n = counts[mine] or 0
			if qi.Full then
				local go = button(matchBody, "> 바로 시작 (정원 " .. n .. "/" .. tostring(qi.Capacity) .. ")", C.Pink,
					{ Size = UDim2.new(1, 0, 0, 46), LayoutOrder = nextOrder(), TextSize = 19 })
				go.MouseButton1Click:Connect(function()
					remotes.Queue:FireServer("startNow")
				end)
			else
				label(matchBody, { Text = string.format("정원 %d / %d · 모두 모이면 '바로 시작' 버튼이 생겨요 (빈자리는 봇)", n, qi.Capacity or 0), TextSize = 15,
					TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = nextOrder() })
			end
		end
	end

	label(matchBody, { Text = "새 배틀 시작", TextSize = 17, TextColor3 = C.Sub, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = nextOrder() })
	local grid = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder() }, matchBody)
	make("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 44), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	for i, q in ipairs(Config.Queues) do
		local qb = button(grid, queueTitle(q), (mine == q.Id) and C.Pink or C.Panel, { TextSize = 15, LayoutOrder = i, TextWrapped = true })
		UI.stroke(qb, C.Dim, 1, 0.3)
		qb.MouseButton1Click:Connect(function()
			remotes.Queue:FireServer(q.Id)
		end)
	end
end

local function refreshStatus()
	local s = lastState
	local mine = player:GetAttribute("Queue")
	if not s then
		statusLbl.Text = ""
	elseif s.Phase == "Countdown" then
		local qi = s.QueueInfo and s.QueueInfo[s.QueueId] or {}
		statusLbl.Text = string.format("%s 시작까지 %d초 · 맵 %s", s.QueueId or "", math.max(0, math.ceil(s.EndsAt - workspace:GetServerTimeNow())), qi.Map or "")
	elseif s.Phase == "Playing" or s.Phase == "Results" then
		statusLbl.Text = "다른 경기 진행 중 · 대기하면 다음 판에 참가해요"
	else
		statusLbl.Text = mine and "참가자를 기다리는 중... 발판에서 내려오면 취소" or "발판을 밟거나 아래에서 배틀을 고르세요"
	end
end

------------------------------------------------------------------------
-- 접속자 목록 (왼쪽)
------------------------------------------------------------------------
local function rebuildPeople()
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		return (a:GetAttribute("Rating") or 0) > (b:GetAttribute("Rating") or 0)
	end)
	local sig = ""
	for _, pl in ipairs(list) do
		sig = sig .. pl.UserId .. tostring(pl:GetAttribute("Rating")) .. tostring(pl:GetAttribute("Queue")) .. tostring(pl:GetAttribute("InMatch"))
	end
	if sig == peopleSig then
		return
	end
	peopleSig = sig
	clear(peopleList)
	peopleList.Parent:FindFirstChild("Title").Text = string.format("접속자 %d명", #list)
	for i, pl in ipairs(list) do
		local tier = pl:GetAttribute("Tier") or "브론즈"
		local status, sc
		if pl:GetAttribute("InMatch") then
			status, sc = "경기 중", Color3.fromRGB(255, 120, 120)
		elseif pl:GetAttribute("Queue") then
			status, sc = "대기 " .. tostring(pl:GetAttribute("Queue")), C.Gold
		else
			status, sc = "로비", Color3.fromRGB(140, 230, 170)
		end
		local row = make("Frame", { Size = UDim2.new(1, -6, 0, 46), BackgroundColor3 = (pl == player) and Color3.fromRGB(70, 40, 84) or C.Panel, LayoutOrder = i },
			peopleList)
		corner(row, 8)
		make("Frame", { Size = UDim2.new(0, 5, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = TIER_COLOR[tier] or C.Text, BorderSizePixel = 0 }, row)
		label(row, { Text = pl.DisplayName, TextSize = 17, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(18, 3), Size = UDim2.new(1, -110, 0, 22),
			TextTruncate = Enum.TextTruncate.AtEnd })
		label(row, { Text = string.format("%s · %d", tier, pl:GetAttribute("Rating") or Config.Rating.Start), TextSize = 14, TextColor3 = TIER_COLOR[tier] or C.Sub,
			Position = UDim2.fromOffset(18, 24), Size = UDim2.new(1, -110, 0, 18) })
		label(row, { Text = status, TextSize = 14, TextColor3 = sc, Position = UDim2.new(1, -100, 0, 0), Size = UDim2.new(0, 92, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right })
	end
end

local function refreshProfile()
	local vip = player:GetAttribute("Vip") and "  ·  VIP" or ""
	local tier = player:GetAttribute("Tier") or "브론즈"
	profileLbl.Text = string.format('<font size="22"><b>%s</b></font>%s  <font color="#FFC850">Lv.%d</font>\n %d 코인\n <font color="#%s">%s</font>  %d  ·  %d승',
		player.DisplayName, vip, player:GetAttribute("Level") or 1, player:GetAttribute("Coins") or 0, (TIER_COLOR[tier] or C.Text):ToHex(), tier,
		player:GetAttribute("Rating") or Config.Rating.Start, player:GetAttribute("Wins") or 0)
end

function Lobby.OnState(s)
	lastState = s
	local inMatch = player:GetAttribute("InMatch") == true
	gui.Enabled = not inMatch
	if inMatch and (shop.Visible or board.Visible or questPanel.Visible) then
		shop.Visible = false
		board.Visible = false
		questPanel.Visible = false
		updateModal()
	end
	rebuildMatch()
	refreshStatus()
end

function Lobby.SetModalHandler(fn)
	modalHandler = fn
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

	-- 프로필 (왼쪽 위)
	local card = make("Frame", { Size = UDim2.fromOffset(300, 104), Position = UDim2.fromOffset(16, 16), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.1 }, gui)
	corner(card, 14)
	UI.stroke(card, C.Pink, 2, 0.3)
	profileLbl = label(card, { Size = UDim2.new(1, -28, 1, -14), Position = UDim2.fromOffset(14, 7), TextYAlignment = Enum.TextYAlignment.Top, TextSize = 18,
		RichText = true })

	-- 아래 가운데 액션 독: [배틀 시작] [매치 선택] + 아이콘 타일 (무기·미션·상점·랭킹)
	local dock = make("Frame", { Name = "Dock", Size = UDim2.fromOffset(470, 178), Position = UDim2.new(0.5, 0, 1, -14), AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1 }, gui)
	local function bigButton(textStr, c1, c2, x)
		local b = button(dock, textStr, c1, { Size = UDim2.fromOffset(226, 58), Position = UDim2.fromOffset(x, 0), TextSize = 26 })
		UI.gradient(b, c1, c2, 90)
		UI.stroke(b, Color3.new(1, 1, 1), 2, 0.35)
		make("UIStroke", { Color = Color3.fromRGB(10, 10, 20), Thickness = 2, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, b)
		b:SetAttribute("SFItalic", true)
		return b
	end
	-- 좁은 화면: 독을 매치 패널 왼쪽 남은 공간의 가운데로, 그래도 좁으면 작게
	local dockScale = make("UIScale", { Scale = 1 }, dock)
	local function placeDock()
		local cam = workspace.CurrentCamera
		local w = cam and cam.ViewportSize.X or 1920
		local free = w - 420 - 48 -- 매치 패널 폭 + 여백
		if w / 2 + 235 > w - 420 - 32 then
			dock.Position = UDim2.new(0, math.max(330, free / 2 + 10), 1, -14)
			dockScale.Scale = math.clamp((free - 330) / 480, 0.7, 1)
		else
			dock.Position = UDim2.new(0.5, 0, 1, -14)
			dockScale.Scale = 1
		end
	end
	placeDock()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeDock)
	end
	local battleBtn = bigButton("배틀 시작", Color3.fromRGB(235, 70, 255), Color3.fromRGB(150, 40, 220), 4)
	local playBtn = bigButton("매치 선택", Color3.fromRGB(40, 235, 120), Color3.fromRGB(10, 170, 90), 240)
	-- [배틀 시작] = 진행 중인 배틀 빈자리에 바로 합류, 없으면 대기열로. 대기 중에는 [배틀 취소]로 바뀜
	local function refreshBattleBtn()
		local waiting = player:GetAttribute("Queue") ~= nil and not player:GetAttribute("InMatch")
		battleBtn.Text = waiting and "배틀 취소" or "배틀 시작"
		local g = battleBtn:FindFirstChildOfClass("UIGradient")
		if g then
			g.Color = waiting and ColorSequence.new(Color3.fromRGB(255, 90, 90), Color3.fromRGB(190, 30, 60))
				or ColorSequence.new(Color3.fromRGB(235, 70, 255), Color3.fromRGB(150, 40, 220))
		end
	end
	player:GetAttributeChangedSignal("Queue"):Connect(refreshBattleBtn)
	player:GetAttributeChangedSignal("InMatch"):Connect(refreshBattleBtn)
	refreshBattleBtn()
	battleBtn.MouseButton1Click:Connect(function()
		if player:GetAttribute("Queue") ~= nil and not player:GetAttribute("InMatch") then
			remotes.Queue:FireServer(nil) -- 대기 취소
		else
			remotes.Queue:FireServer("quick")
		end
	end)
	playBtn.MouseButton1Click:Connect(function()
		if matchFrame then
			matchFrame.Visible = not matchFrame.Visible
		end
	end)
	local tiles = {
		{ "무기", "target", function()
			currentTab = "Weapons"
			toggleShop(true)
		end, Color3.fromRGB(0, 200, 255) },
		{ "미션", "quest", function()
			openQuests()
		end, Color3.fromRGB(40, 235, 120) },
		{ "상점", "chest", function()
			currentTab = "Crate"
			toggleShop(true)
		end, Color3.fromRGB(255, 60, 200) },
		{ "랭킹", "trophy", function()
			openBoard()
		end, Color3.fromRGB(255, 200, 40) },
	}
	for i, t in ipairs(tiles) do
		local tile = make("TextButton", { Size = UDim2.fromOffset(104, 104), Position = UDim2.fromOffset(4 + (i - 1) * 118, 70), BackgroundColor3 = C.Bg,
			BackgroundTransparency = 0.15, Text = "", AutoButtonColor = false }, dock)
		corner(tile, 14)
		UI.stroke(tile, t[4], 2, 0.25)
		UI.gradient(tile, Color3.fromRGB(40, 50, 84), Color3.fromRGB(14, 18, 34), 90)
		UI.Icon(tile, t[2], "", { Size = UDim2.fromOffset(62, 62), Position = UDim2.new(0.5, -31, 0, 8) })
		local tl = label(tile, { Text = t[1], TextSize = 20, Font = Enum.Font.GothamBlack, Position = UDim2.new(0, 0, 1, -32), Size = UDim2.new(1, 0, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4 })
		tl:SetAttribute("SFItalic", true)
		local sc = make("UIScale", { Scale = 1 }, tile)
		tile.MouseEnter:Connect(function()
			TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1.07 }):Play()
		end)
		tile.MouseLeave:Connect(function()
			TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1 }):Play()
		end)
		tile.MouseButton1Click:Connect(function()
			SoundBank.Play("ui_click", nil, 0.4)
			t[3]()
		end)
	end

	-- 접속자 목록 (왼쪽, 채팅창 위)
	local people = make("Frame", { Size = UDim2.new(0, 300, 1, -414), Position = UDim2.fromOffset(16, 128), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.15 }, gui)
	corner(people, 14)
	make("UISizeConstraint", { MinSize = Vector2.new(300, 120) }, people)
	label(people, { Name = "Title", Text = "접속자", TextSize = 19, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 28) })
	peopleList = make("ScrollingFrame", { Size = UDim2.new(1, -16, 1, -44), Position = UDim2.fromOffset(8, 38), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, people)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }, peopleList)

	-- 매치 참가 (오른쪽 아래)
	-- 매치 패널: 오른쪽 가운데 (아래 가운데는 액션 독)
	matchFrame = make("Frame", { Size = UDim2.fromOffset(420, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1, -16, 0.5, 20),
		AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.08 }, gui)
	corner(matchFrame, 16)
	UI.stroke(matchFrame, C.Cyan, 2, 0.3)
	make("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, matchFrame)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, matchFrame)
	label(matchFrame, { Text = "매치 참가", TextSize = 26, Font = Enum.Font.FredokaOne, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 1 })
	statusLbl = label(matchFrame, { Size = UDim2.new(1, 0, 0, 22), TextSize = 16, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 220, 100), LayoutOrder = 2 })
	matchBody = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3 }, matchFrame)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, matchBody)

	-- 상점 창
	shop = UI.Panel(gui, "SPLASH SHOP", UDim2.fromOffset(860, 660), C.Pink)
	shop.Visible = false
	shop.ZIndex = 5
	UI.CloseButton(shop, function()
		toggleShop(false)
	end, 44)
	tabButtons = {}
	pages = {}
	local tabs = { { "Weapons", "무기" }, { "WSkins", "무기 스킨" }, { "Skins", "외형 상점" }, { "Crate", "크레이트" }, { "Collection", "컬렉션" }, { "Robux", "충전 · VIP" } }
	for i, t in ipairs(tabs) do
		local b = button(shop, t[2], C.Panel2, { Size = UDim2.fromOffset(130, 48), Position = UDim2.fromOffset(20 + (i - 1) * 137, 76), TextSize = 18 })
		b.MouseButton1Click:Connect(function()
			showTab(t[1])
		end)
		tabButtons[t[1]] = b
		local page = make("ScrollingFrame", { Size = UDim2.new(1, -32, 1, -150), Position = UDim2.fromOffset(16, 138), BackgroundTransparency = 1,
			ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, BorderSizePixel = 0 }, shop)
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }, page)
		-- 카드 테두리(UIStroke)가 스크롤 영역 가장자리에서 잘리지 않게 안쪽 여백 (오른쪽은 스크롤바 자리까지)
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10) }, page)
		pages[t[1]] = page
	end

	-- 랭킹 창
	board = UI.Panel(gui, "시즌 " .. Config.Season .. " 랭킹 TOP 50", UDim2.fromOffset(720, 660), Color3.fromRGB(230, 160, 20))
	board.Visible = false
	UI.CloseButton(board, function()
		board.Visible = false
		updateModal()
	end, 44)
	local header = make("Frame", { Size = UDim2.new(1, -32, 0, 36), Position = UDim2.fromOffset(16, 76), BackgroundColor3 = C.Panel2 }, board)
	corner(header, 8)
	rowCells(header, { "순위", "이름", "등급", "Rating", "승리", "MVP" }, C.Sub, Enum.Font.GothamBlack, 17)
	boardList = make("ScrollingFrame", { Size = UDim2.new(1, -32, 1, -136), Position = UDim2.fromOffset(16, 120), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, board)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, boardList)

	-- 미션 창
	questPanel = UI.Panel(gui, "일일 · 주간 미션", UDim2.fromOffset(720, 640), C.Green)
	questPanel.Visible = false
	UI.CloseButton(questPanel, function()
		questPanel.Visible = false
		updateModal()
	end, 44)
	label(questPanel, { Text = "미션을 달성하면 코인이 자동으로 들어와요 · 코인으로 스킨 상점에서 원하는 스킨을 구매", TextSize = 16, TextColor3 = C.Sub,
		Position = UDim2.fromOffset(20, 72), Size = UDim2.new(1, -40, 0, 22) })
	questList = make("ScrollingFrame", { Size = UDim2.new(1, -32, 1, -120), Position = UDim2.fromOffset(16, 104), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, questPanel)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, questList)

	reveal = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 4, 14), BackgroundTransparency = 0.25, Visible = false, ZIndex = 20 }, gui)

	-- 로비 상점 부스(E) · 랭킹 보드 클릭
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "SF_ShopPrompt" then
			toggleShop(true)
		end
	end)
	task.spawn(function()
		local lobbyFolder = workspace:WaitForChild("Lobby", 30)
		local lb = lobbyFolder and lobbyFolder:WaitForChild("Leaderboard", 30)
		local cd = lb and lb:WaitForChild("OpenBoard", 30)
		if cd then
			cd.MouseClick:Connect(function(who)
				if who == player then
					openBoard()
				end
			end)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			toggleShop()
		elseif input.KeyCode == Enum.KeyCode.Escape and (shop.Visible or board.Visible or questPanel.Visible) then
			shop.Visible = false
			board.Visible = false
			questPanel.Visible = false
			updateModal()
		end
	end)
	player:GetAttributeChangedSignal("Quests"):Connect(function()
		if questPanel.Visible then
			Lobby.UpdateQuests()
		end
	end)
	player:GetAttributeChangedSignal("QueueSide"):Connect(function()
		matchSig = nil
		rebuildMatch()
	end)
	player:GetAttributeChangedSignal("Vip"):Connect(function()
		if shop.Visible and currentTab == "Robux" then
			showTab("Robux")
		end
	end)
	for _, attr in ipairs({ "Coins", "Rating", "Tier", "Wins", "Vip", "Level" }) do
		player:GetAttributeChangedSignal(attr):Connect(refreshProfile)
	end
	player:GetAttributeChangedSignal("Queue"):Connect(function()
		rebuildMatch()
		refreshStatus()
	end)
	refreshProfile()
	rebuildMatch()
	task.spawn(function()
		while true do
			if gui.Enabled then
				refreshStatus()
				rebuildPeople()
			end
			task.wait(0.5)
		end
	end)
end

return Lobby
