-- 크로마 크레이트(랜덤 상자) 개봉 + 외형 장착
-- 실제 판매: Creator Hub에서 79 R$ 개발자 상품을 만들고 Config.Monetization.CrateProductId에 ID 입력
-- Studio에서는 상품 ID 없이 "테스트 개봉" 버튼으로 확률·연출 확인 가능
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local DataService = require(script.Parent.DataService)
local Telemetry = require(script.Parent.TelemetryService)

local CrateService = {}

local rng = Random.new()
local remotes = nil

-- 상자 하나 개봉. 결과 테이블 반환 (구매 처리 성공 후에만 호출)
function CrateService.Open(player)
	local p = DataService.Get(player)
	if not p then
		return nil
	end
	p.CratePity = (p.CratePity or 0) + 1
	p.CratesOpened = (p.CratesOpened or 0) + 1
	local pityHit = p.CratePity >= Cosmetics.PityCount
	local item, rarity = Cosmetics.Roll(rng, pityHit)
	if rarity.Id == "Legendary" then
		p.CratePity = 0
	end
	local duplicate = p.Cosmetics[item.Id] == true
	local refund = 0
	if duplicate then
		refund = rarity.Refund
		p.Coins = p.Coins + refund
	else
		p.Cosmetics[item.Id] = true
	end
	DataService.Publish(player)
	DataService.Save(player)
	Telemetry.Custom(player, "CrateOpen", 1, rarity.Id, item.Id, duplicate and "dup" or "new")
	if refund > 0 then
		Telemetry.Economy(player, true, refund, p.Coins, "Gameplay", "CrateRefund")
	end
	local result = {
		ItemId = item.Id, Name = item.Name, Kind = item.Kind, Rarity = rarity.Id, RarityName = rarity.Name,
		Color = rarity.Color, Duplicate = duplicate, Refund = refund, Pity = p.CratePity, Pitied = pityHit,
	}
	remotes.CrateResult:FireClient(player, result)
	return result
end

function CrateService.Equip(player, itemId)
	local p = DataService.Get(player)
	local item = Cosmetics.ById[itemId]
	if not p then
		return { ok = false, msg = "데이터 없음" }
	end
	if itemId == nil then
		return { ok = false, msg = "잘못된 요청" }
	end
	if not item or not p.Cosmetics[itemId] then
		return { ok = false, msg = "보유하지 않은 아이템" }
	end
	local slot = (item.Kind == "Skin" and "EquippedSkin") or (item.Kind == "Pattern" and "EquippedPattern") or "EquippedEffect"
	if p[slot] == itemId then
		p[slot] = nil -- 다시 누르면 해제
		DataService.Publish(player)
		return { ok = true, msg = item.Name .. " 해제" }
	end
	p[slot] = itemId
	DataService.Publish(player)
	return { ok = true, msg = item.Name .. " 장착" }
end

-- Studio 전용 무료 테스트 개봉
function CrateService.TestOpen(player)
	if not RunService:IsStudio() then
		return { ok = false, msg = "테스트 개봉은 Studio에서만 가능해요" }
	end
	CrateService.Open(player)
	return { ok = true, msg = "테스트 개봉" }
end

function CrateService.Init(remoteFolder)
	remotes = remoteFolder
end

return CrateService
