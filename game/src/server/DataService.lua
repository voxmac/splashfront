-- 플레이어 저장 데이터 (코인, 보유 무기, 장착 무기, 레이팅, 통계)
-- Studio에서 저장하려면: 게임 설정 > 보안 > "Studio의 API 서비스 액세스 사용" 켜기
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

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
		Matches = 0,
		Kills = 0,
		Cells = 0,
		Cosmetics = {},          -- [아이템 Id] = true
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
	player:SetAttribute("Skin", p.EquippedSkin)
	player:SetAttribute("Pattern", p.EquippedPattern)
	player:SetAttribute("KillEffect", p.EquippedEffect)
	player:SetAttribute("OwnedCosmetics", ownedString(p.Cosmetics or {}))
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
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("u" .. player.UserId)
		end)
		if ok then
			data = result
		else
			warn("[SplashFront] 데이터 불러오기 실패:", result)
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
	end
	profiles[player] = p

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
	profiles[player] = p
	DataService.Publish(player)
	DataService.Save(player)
end

function DataService.Save(player)
	local p = profiles[player]
	if not p or not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("u" .. player.UserId, p)
	end)
	if not ok then
		warn("[SplashFront] 저장 실패:", err)
	end
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
		for _, pl in ipairs(Players:GetPlayers()) do
			DataService.Save(pl)
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
