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
	if action == "crateTest" then
		return CrateService.TestOpen(player)
	elseif action == "equipCosmetic" then
		return CrateService.Equip(player, weaponId)
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
		if not player or not DataService.Get(player) then
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
