-- 플레이어 저장 데이터 (코인, 보유 무기, 장착 무기, 레이팅, 통계)
-- Studio에서 저장하려면: 게임 설정 > 보안 > "Studio의 API 서비스 액세스 사용" 켜기
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local WeaponSkins = require(ReplicatedStorage.Shared.WeaponSkins)

local DataService = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("SplashFront_Profile_" .. Config.DataVersion)
end)

local profiles = {}

local function defaultProfile()
	return {
		Coins = 300,
		Owned = { [Weapons.Default] = true },
		Equipped = Weapons.Default,
		Rating = Config.Rating.Start,
		Wins = 0,
		MVPs = 0,                -- 경기 MVP(전체 최고 점수) 횟수
		Matches = 0,
		Kills = 0,
		Cells = 0,
		Cosmetics = {},          -- [아이템 Id] = true
		WSkins = {},             -- 무기 스킨 ["라인@무기"] = true
		WSkinEquip = {},         -- [무기 Id] = { Line = 라인 Id, V = 변형 번호 }
		Knives = { Tactical = true }, -- 보유한 칼 외형
		KnifeModel = "Tactical",      -- 장착한 칼 외형
		EquippedSkin = nil,
		EquippedPattern = nil,
		EquippedEffect = nil,
		CratePity = 0,           -- 마지막 레전더리 이후 개봉 수
		CratesOpened = 0,
		Level = 1,
		XP = 0,
		Quests = {},             -- QuestService가 관리 (기간 키 + 진행도)
	}
end

local function ownedString(owned)
	local list = {}
	for id, v in pairs(owned) do
		if v then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return table.concat(list, ",")
end

function DataService.Publish(player)
	local p = profiles[player]
	if not p then
		return
	end
	player:SetAttribute("Coins", p.Coins)
	player:SetAttribute("Rating", p.Rating)
	player:SetAttribute("Tier", Config.GetTier(p.Rating).Name)
	player:SetAttribute("Weapon", p.Equipped)
	player:SetAttribute("Owned", ownedString(p.Owned))
	player:SetAttribute("Wins", p.Wins)
	player:SetAttribute("MVPs", p.MVPs or 0)
	player:SetAttribute("Skin", p.EquippedSkin)
	player:SetAttribute("Pattern", p.EquippedPattern)
	player:SetAttribute("KillEffect", p.EquippedEffect)
	player:SetAttribute("OwnedCosmetics", ownedString(p.Cosmetics or {}))
	player:SetAttribute("OwnedWSkins", ownedString(p.WSkins or {}))
	player:SetAttribute("WSkinEquip", WeaponSkins.EncodeEquip(p.WSkinEquip))
	player:SetAttribute("OwnedKnives", ownedString(p.Knives or { Tactical = true }))
	player:SetAttribute("KnifeModel", p.KnifeModel or "Tactical")
	player:SetAttribute("CratePity", p.CratePity or 0)
	player:SetAttribute("Level", p.Level or 1)
	player:SetAttribute("XP", p.XP or 0)
	player:SetAttribute("XPNeed", Config.XPNeed(p.Level or 1))
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Rating.Value = p.Rating
		ls.Wins.Value = p.Wins
	end
end

function DataService.Load(player)
	local data = nil
	local failed = false
	if store then
		-- 일시적 오류는 몇 번 다시 시도. 끝내 실패하면 이번 접속은 저장하지 않음 (빈 데이터로 덮어써 구매품을 잃지 않게)
		failed = true
		-- 다른 서버(로비↔경기)에서 막 넘어왔으면 그 서버가 저장한 최신본이 보일 때까지 잠깐 기다림
		local minSaved = nil
		pcall(function()
			local td = player:GetJoinData().TeleportData
			if type(td) == "table" and type(td.SF) == "table" and type(td.SF.SavedAt) == "number" then
				minSaved = td.SF.SavedAt - 1
			end
		end)
		local function fetch()
			return pcall(function()
				local o = Instance.new("DataStoreGetOptions")
				o.UseCache = false
				return store:GetAsync("u" .. player.UserId, o)
			end)
		end
		for attempt = 1, 4 do
			local ok, result = fetch()
			local waited = 0
			while ok and minSaved and waited < 6 and type(result) == "table" and (result.SavedAt or 0) < minSaved do
				waited = waited + 1
				task.wait(1.5)
				ok, result = fetch()
			end
			if ok then
				data = result
				failed = false
				break
			end
			warn("[SplashFront] 데이터 불러오기 실패(" .. attempt .. "/4):", result)
			task.wait(attempt * 1.5)
		end
	end
	local p = defaultProfile()
	if type(data) == "table" then
		for k, v in pairs(data) do
			p[k] = v
		end
		if type(p.Owned) ~= "table" then
			p.Owned = { [Weapons.Default] = true }
		end
		p.Owned[Weapons.Default] = true
		if type(p.Cosmetics) ~= "table" then
			p.Cosmetics = {}
		end
		if type(p.WSkins) ~= "table" then
			p.WSkins = {}
		end
		if type(p.WSkinEquip) ~= "table" then
			p.WSkinEquip = {}
		end
		if type(p.Knives) ~= "table" then
			p.Knives = {}
		end
		p.Knives.Tactical = true
		if not Weapons.KnifeModelById[p.KnifeModel or ""] or not p.Knives[p.KnifeModel] then
			p.KnifeModel = "Tactical"
		end
	end
	p.LoadFailed = failed or nil
	profiles[player] = p
	if failed then
		player:SetAttribute("DataWarning", "저장 데이터를 불러오지 못했어요. 이번 접속의 구매·진행은 저장되지 않으니 잠시 후 다시 접속해 주세요")
	end

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local r = Instance.new("IntValue")
	r.Name = "Rating"
	r.Parent = ls
	local w = Instance.new("IntValue")
	w.Name = "Wins"
	w.Parent = ls
	ls.Parent = player

	-- VIP 게임패스
	local vip = false
	if Config.Monetization.VipGamePassId ~= 0 then
		pcall(function()
			vip = MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.Monetization.VipGamePassId)
		end)
	end
	player:SetAttribute("Vip", vip)

	player:SetAttribute("FirstMatch", (p.Matches or 0) == 0)
	DataService.Publish(player)
	return p
end

-- 경험치: 레벨업하면 코인 보너스. 반환: 이번에 오른 레벨 수
function DataService.AddXP(player, amount)
	local p = profiles[player]
	if not p or amount <= 0 then
		return 0
	end
	p.Level = p.Level or 1
	p.XP = (p.XP or 0) + math.floor(amount)
	local ups = 0
	while p.XP >= Config.XPNeed(p.Level) do
		p.XP = p.XP - Config.XPNeed(p.Level)
		p.Level = p.Level + 1
		ups = ups + 1
		p.Coins = p.Coins + Config.LevelReward(p.Level)
		player:SetAttribute("LevelUp", p.Level .. ":" .. Config.LevelReward(p.Level) .. ":" .. os.clock())
	end
	DataService.Publish(player)
	return ups
end

function DataService.Reset(player)
	local p = defaultProfile()
	p.ForceReset = true -- 관리자 초기화: 이번 저장은 합치지 않고 덮어씀
	profiles[player] = p
	DataService.Publish(player)
	DataService.Save(player)
end

-- 보유 목록은 합집합으로 저장: 다른 서버가 먼저 저장한 구매품이 있어도 절대 지워지지 않음
local function union(a, b)
	local out = {}
	for k, v in pairs(type(a) == "table" and a or {}) do
		if v then
			out[k] = true
		end
	end
	for k, v in pairs(type(b) == "table" and b or {}) do
		if v then
			out[k] = true
		end
	end
	return out
end

function DataService.Save(player)
	local p = profiles[player]
	if not p or not store or p.LoadFailed then
		return false
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync("u" .. player.UserId, function(old)
				if type(old) == "table" and not p.ForceReset then
					p.Owned = union(old.Owned, p.Owned)
					p.Cosmetics = union(old.Cosmetics, p.Cosmetics)
				end
				p.SavedAt = os.time()
				local copy = table.clone(p)
				copy.LoadFailed = nil
				copy.ForceReset = nil
				return copy
			end)
		end)
		if ok then
			p.ForceReset = nil
			return true
		end
		warn("[SplashFront] 저장 실패(" .. attempt .. "/3):", err)
		task.wait(attempt)
	end
	return false
end

function DataService.IsSafe(player)
	local p = profiles[player]
	return p ~= nil and not p.LoadFailed
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.AddCoins(player, amount)
	local p = profiles[player]
	if not p then
		return 0
	end
	if player:GetAttribute("Vip") then
		amount = math.floor(amount * Config.VipCoinMul + 0.5)
	end
	p.Coins = p.Coins + amount
	DataService.Publish(player)
	return amount
end

function DataService.Unload(player)
	DataService.Save(player)
	profiles[player] = nil
end

function DataService.Start()
	Players.PlayerRemoving:Connect(DataService.Unload)
	game:BindToClose(function()
		-- 서버 종료: 모두 동시에 저장하고 끝날 때까지 기다림
		local pending = 0
		for _, pl in ipairs(Players:GetPlayers()) do
			pending = pending + 1
			task.spawn(function()
				DataService.Save(pl)
				pending = pending - 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, pl in ipairs(Players:GetPlayers()) do
				DataService.Save(pl)
			end
		end
	end)
end

return DataService
