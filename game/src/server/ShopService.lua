-- 무기 상점(게임 코인) + 로벅스 결제 처리
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local DataService = require(script.Parent.DataService)
local CrateService = require(script.Parent.CrateService)
local Telemetry = require(script.Parent.TelemetryService)

local ShopService = {}

local function handle(player, action, weaponId)
	if (action == "buy" or action == "buyCosmetic") and not DataService.IsSafe(player) then
		return { ok = false, msg = "저장 데이터를 불러오지 못해 지금은 구매할 수 없어요. 다시 접속해 주세요" }
	end
	if action == "crateCoins" then
		-- 포인트(코인)로 크레이트 개봉
		if not DataService.IsSafe(player) then
			return { ok = false, msg = "저장 데이터를 불러오지 못해 지금은 구매할 수 없어요. 다시 접속해 주세요" }
		end
		local p = DataService.Get(player)
		local price = Config.CrateCoinPrice or 5000
		if not p then
			return { ok = false, msg = "데이터 없음" }
		end
		if p.Coins < price then
			return { ok = false, msg = "코인이 부족해요 (" .. (price - p.Coins) .. " 부족)" }
		end
		p.Coins = p.Coins - price
		Telemetry.Economy(player, false, price, p.Coins, "Shop", "CrateCoins")
		local res = CrateService.Open(player) -- 저장·결과 연출까지 처리
		if not res then
			p.Coins = p.Coins + price
			DataService.Publish(player)
			return { ok = false, msg = "개봉에 실패해 코인을 돌려드렸어요" }
		end
		return { ok = true, msg = "크레이트 개봉!" }
	elseif action == "crateTest" then
		return CrateService.TestOpen(player)
	elseif action == "equipCosmetic" then
		return CrateService.Equip(player, weaponId)
	elseif action == "buyCosmetic" then
		-- 포인트(코인)로 외형 직접 구매
		local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
		local item = Cosmetics.ById[weaponId]
		local p = DataService.Get(player)
		local price = item and Config.SkinPrices[item.Rarity]
		if not item or not p or not price then
			return { ok = false, msg = "알 수 없는 아이템" }
		end
		p.Cosmetics = p.Cosmetics or {}
		if p.Cosmetics[item.Id] then
			return { ok = false, msg = "이미 보유 중" }
		end
		if p.Coins < price then
			return { ok = false, msg = "코인이 부족해요 (" .. (price - p.Coins) .. " 부족)" }
		end
		p.Coins = p.Coins - price
		p.Cosmetics[item.Id] = true
		DataService.Publish(player)
		DataService.Save(player)
		Telemetry.Economy(player, false, price, p.Coins, "Shop", "Cosmetic_" .. item.Id)
		return { ok = true, msg = item.Name .. " 구매 완료! 컬렉션에서 장착하세요" }
	end
	local p = DataService.Get(player)
	local w = Weapons.ById[weaponId]
	if not p or not w then
		return { ok = false, msg = "알 수 없는 무기" }
	end
	if player:GetAttribute("InMatch") then
		return { ok = false, msg = "경기 중에는 변경할 수 없어요" }
	end
	if action == "buy" then
		if p.Owned[w.Id] then
			return { ok = false, msg = "이미 보유 중" }
		end
		if p.Coins < w.Price then
			return { ok = false, msg = "코인이 부족해요 (" .. (w.Price - p.Coins) .. " 부족)" }
		end
		p.Coins = p.Coins - w.Price
		p.Owned[w.Id] = true
		p.Equipped = w.Id
		DataService.Publish(player)
		DataService.Save(player)
		Telemetry.Economy(player, false, w.Price, p.Coins, "Shop", "Weapon_" .. w.Id)
		return { ok = true, msg = w.Name .. " 구매 완료!" }
	elseif action == "equip" then
		if not p.Owned[w.Id] then
			return { ok = false, msg = "먼저 구매하세요" }
		end
		p.Equipped = w.Id
		DataService.Publish(player)
		return { ok = true, msg = w.Name .. " 장착" }
	end
	return { ok = false, msg = "잘못된 요청" }
end

function ShopService.Init(remotes)
	remotes.Shop.OnServerInvoke = handle
	CrateService.Init(remotes)

	-- 코인 팩 / 크로마 크레이트 (개발자 상품)
	-- PurchaseId를 DataStore에 기록해 서버 재시도·재접속 시 중복 지급을 막음
	local purchaseStore = nil
	pcall(function()
		purchaseStore = DataStoreService:GetDataStore("SplashFront_Purchases_" .. Config.DataVersion)
	end)

	local function grant(player, productId)
		if productId == Config.Monetization.CrateProductId and productId ~= 0 then
			return CrateService.Open(player) ~= nil
		end
		local coins = Config.Monetization.CoinProducts[productId]
		local p = DataService.Get(player)
		if not coins or not p then
			return false
		end
		p.Coins = p.Coins + coins
		DataService.Publish(player)
		DataService.Save(player)
		Telemetry.Economy(player, true, coins, p.Coins, "IAP", "CoinPack_" .. tostring(productId))
		return true
	end

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		-- 데이터를 못 불러온 상태면 지급을 미룸 (로벅스 구매품이 저장 안 되는 일이 없게, 다음 접속 때 다시 처리됨)
		if not player or not DataService.Get(player) or not DataService.IsSafe(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local key = "p_" .. tostring(receipt.PurchaseId)
		if purchaseStore then
			local ok, done = pcall(function()
				return purchaseStore:GetAsync(key)
			end)
			if not ok then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			if done then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
		if not grant(player, receipt.ProductId) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if purchaseStore then
			pcall(function()
				purchaseStore:SetAsync(key, { u = receipt.PlayerId, p = receipt.ProductId, t = os.time() })
			end)
		end
		Telemetry.Custom(player, "Purchase", receipt.CurrencySpent or 0, tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.Monetization.VipGamePassId then
			player:SetAttribute("Vip", true)
		end
	end)
end

return ShopService
