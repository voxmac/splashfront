-- 외형 아이템 + 크로마 크레이트(랜덤 상자) 확률표
-- 확률은 등급을 먼저 뽑고, 그 등급 안에서 아이템을 균등하게 뽑음
-- 확률·아이템을 바꾸면 상점 UI의 확률 공개 표에도 자동 반영됨
local Cosmetics = {}

Cosmetics.CratePrice = 79 -- R$ (실제 가격은 Creator Hub의 개발자 상품에서 설정)
Cosmetics.PityCount = 30  -- 이 횟수 안에 레전더리가 없으면 확정

Cosmetics.Rarities = {
	{ Id = "Rare", Name = "레어", Chance = 72, Color = Color3.fromRGB(80, 160, 255), Refund = 60 },
	{ Id = "Epic", Name = "에픽", Chance = 23, Color = Color3.fromRGB(190, 90, 255), Refund = 200 },
	{ Id = "Legendary", Name = "레전더리", Chance = 5, Color = Color3.fromRGB(255, 190, 40), Refund = 800 },
}

-- Kind: Skin(총 외형) / Pattern(내가 칠한 셀의 재질) / Effect(처치 이펙트)
Cosmetics.Items = {
	-- 레어
	{ Id = "SkinCamo", Kind = "Skin", Rarity = "Rare", Name = "정글 카모", Color = Color3.fromRGB(70, 110, 60), Material = "Fabric" },
	{ Id = "SkinGraffiti", Kind = "Skin", Rarity = "Rare", Name = "스트리트 그래피티", Color = Color3.fromRGB(255, 130, 40), Material = "SmoothPlastic" },
	{ Id = "SkinMidnight", Kind = "Skin", Rarity = "Rare", Name = "미드나잇", Color = Color3.fromRGB(30, 40, 90), Material = "Metal" },
	{ Id = "SkinSoda", Kind = "Skin", Rarity = "Rare", Name = "크림 소다", Color = Color3.fromRGB(255, 180, 210), Material = "SmoothPlastic" },
	{ Id = "PatMatte", Kind = "Pattern", Rarity = "Rare", Name = "매트 페인트", Material = "SmoothPlastic" },
	{ Id = "PatSand", Kind = "Pattern", Rarity = "Rare", Name = "샌드 텍스처", Material = "Sand" },
	{ Id = "FxConfetti", Kind = "Effect", Rarity = "Rare", Name = "컨페티", Effect = "Confetti" },
	{ Id = "FxSmoke", Kind = "Effect", Rarity = "Rare", Name = "컬러 스모크", Effect = "Smoke" },
	-- 에픽
	{ Id = "SkinChrome", Kind = "Skin", Rarity = "Epic", Name = "홀로 크롬", Color = Color3.fromRGB(210, 215, 230), Material = "Foil" },
	{ Id = "SkinLava", Kind = "Skin", Rarity = "Epic", Name = "용암 균열", Color = Color3.fromRGB(255, 90, 20), Material = "CrackedLava" },
	{ Id = "SkinIce", Kind = "Skin", Rarity = "Epic", Name = "아이스 크리스탈", Color = Color3.fromRGB(170, 230, 255), Material = "Ice" },
	{ Id = "PatGlitter", Kind = "Pattern", Rarity = "Epic", Name = "글리터", Material = "Foil" },
	{ Id = "PatNeon", Kind = "Pattern", Rarity = "Epic", Name = "네온 글로우", Material = "Neon" },
	{ Id = "FxStarburst", Kind = "Effect", Rarity = "Epic", Name = "스타버스트", Effect = "Starburst" },
	-- 레전더리
	{ Id = "SkinGalaxy", Kind = "Skin", Rarity = "Legendary", Name = "갤럭시", Color = Color3.fromRGB(120, 60, 255), Material = "Neon" },
	{ Id = "SkinGold", Kind = "Skin", Rarity = "Legendary", Name = "골든 드립", Color = Color3.fromRGB(255, 200, 50), Material = "Foil" },
	{ Id = "PatAurora", Kind = "Pattern", Rarity = "Legendary", Name = "오로라", Material = "ForceField" },
	{ Id = "FxRainbow", Kind = "Effect", Rarity = "Legendary", Name = "무지개 폭발", Effect = "Rainbow" },

	------------------------------------------------------------------
	-- 무기 스킨 컬렉션 세트: 같은 테마의 바닥 패턴 + 처치 이펙트 (외형 상점에서 바로 구매 + 크레이트에서도 나옴)
	-- 패턴: Material(주 재질) + Material2(섞을 재질) + Mix(Checker 체크 / Stripe 사선 줄무늬 / Scatter 흩뿌림)
	--       Tint(테마 색을 팀 색에 살짝 섞음, TintAmount 0.2 이하라 팀 색은 그대로 읽힘)
	------------------------------------------------------------------
	{ Id = "PatSteelWave", Kind = "Pattern", Rarity = "Rare", Collection = "SteelWave", Name = "스틸 웨이브 플레이트",
		Material = "Metal", Material2 = "DiamondPlate", Mix = "Stripe", Tint = Color3.fromRGB(190, 196, 210), TintAmount = 0.12 },
	{ Id = "FxSteelWave", Kind = "Effect", Rarity = "Rare", Collection = "SteelWave", Name = "스틸 스파크", Effect = "Sparks" },
	{ Id = "PatDesertRanger", Kind = "Pattern", Rarity = "Rare", Collection = "DesertRanger", Name = "데저트 샌드",
		Material = "Sand", Material2 = "Fabric", Mix = "Scatter", Tint = Color3.fromRGB(210, 180, 130), TintAmount = 0.14 },
	{ Id = "FxDesertRanger", Kind = "Effect", Rarity = "Rare", Collection = "DesertRanger", Name = "모래 폭풍", Effect = "Dust" },
	{ Id = "PatBlackOnyx", Kind = "Pattern", Rarity = "Epic", Collection = "BlackOnyx", Name = "오닉스 골드 체커",
		Material = "Slate", Material2 = "Foil", Mix = "Checker", Tint = Color3.fromRGB(230, 180, 70), TintAmount = 0.1 },
	{ Id = "FxBlackOnyx", Kind = "Effect", Rarity = "Epic", Collection = "BlackOnyx", Name = "골드 샤워", Effect = "GoldShower" },
	{ Id = "PatSakuraBloom", Kind = "Pattern", Rarity = "Epic", Collection = "SakuraBloom", Name = "벚꽃 대리석",
		Material = "Marble", Material2 = "SmoothPlastic", Mix = "Scatter", Tint = Color3.fromRGB(255, 180, 210), TintAmount = 0.16 },
	{ Id = "FxSakuraBloom", Kind = "Effect", Rarity = "Epic", Collection = "SakuraBloom", Name = "벚꽃 흩날림", Effect = "Petals" },
	{ Id = "PatNeonPulse", Kind = "Pattern", Rarity = "Epic", Collection = "NeonPulse", Name = "네온 그리드",
		Material = "Glass", Material2 = "Neon", Mix = "Stripe" },
	{ Id = "FxNeonPulse", Kind = "Effect", Rarity = "Epic", Collection = "NeonPulse", Name = "네온 펄스 링", Effect = "NeonRings" },
	{ Id = "PatFrostCrystal", Kind = "Pattern", Rarity = "Epic", Collection = "FrostCrystal", Name = "서리 결정",
		Material = "Ice", Material2 = "Glacier", Mix = "Checker", Tint = Color3.fromRGB(210, 240, 255), TintAmount = 0.18 },
	{ Id = "FxFrostCrystal", Kind = "Effect", Rarity = "Epic", Collection = "FrostCrystal", Name = "얼음 파편", Effect = "IceShatter" },
	{ Id = "PatInfernoCore", Kind = "Pattern", Rarity = "Legendary", Collection = "InfernoCore", Name = "용암 균열",
		Material = "CrackedLava", Material2 = "Basalt", Mix = "Scatter", Tint = Color3.fromRGB(255, 120, 30), TintAmount = 0.12 },
	{ Id = "FxInfernoCore", Kind = "Effect", Rarity = "Legendary", Collection = "InfernoCore", Name = "인페르노 기둥", Effect = "Inferno" },
	{ Id = "PatChromaGalaxy", Kind = "Pattern", Rarity = "Legendary", Collection = "ChromaGalaxy", Name = "은하수",
		Material = "ForceField", Material2 = "Neon", Mix = "Scatter", Tint = Color3.fromRGB(150, 110, 255), TintAmount = 0.12 },
	{ Id = "FxChromaGalaxy", Kind = "Effect", Rarity = "Legendary", Collection = "ChromaGalaxy", Name = "갤럭시 폭발", Effect = "Galaxy" },
}

-- 크레이트 전용 항목: 무기 스킨 컬렉션 (당첨되면 그 컬렉션 중 아직 없는 총 1종을 무작위로 지급)
local WeaponSkins = require(script.Parent.WeaponSkins)
local TIER_RARITY = { Standard = "Rare", Deluxe = "Rare", Premium = "Epic", Ultimate = "Legendary" }
Cosmetics.CrateWeaponSkins = {}
for _, line in ipairs(WeaponSkins.Lines) do
	table.insert(Cosmetics.CrateWeaponSkins, { Id = "WS_" .. line.Id, Kind = "WSkin", Line = line.Id, Rarity = TIER_RARITY[line.Tier] or "Rare",
		Name = line.Name, Tier = line.Tier })
end

Cosmetics.ById = {}
Cosmetics.ByRarity = {}      -- 외형 상점 목록 (패턴·이펙트·크레이트 스킨)
Cosmetics.CrateByRarity = {} -- 크레이트에서 나오는 것 전부 (외형 + 컬렉션 세트 + 무기 스킨 컬렉션)
for _, item in ipairs(Cosmetics.Items) do
	Cosmetics.ById[item.Id] = item
	Cosmetics.ByRarity[item.Rarity] = Cosmetics.ByRarity[item.Rarity] or {}
	table.insert(Cosmetics.ByRarity[item.Rarity], item)
	Cosmetics.CrateByRarity[item.Rarity] = Cosmetics.CrateByRarity[item.Rarity] or {}
	table.insert(Cosmetics.CrateByRarity[item.Rarity], item)
end
for _, item in ipairs(Cosmetics.CrateWeaponSkins) do
	Cosmetics.ById[item.Id] = item
	Cosmetics.CrateByRarity[item.Rarity] = Cosmetics.CrateByRarity[item.Rarity] or {}
	table.insert(Cosmetics.CrateByRarity[item.Rarity], item)
end

function Cosmetics.KindName(kind)
	return (kind == "Skin" and "무기 스킨") or (kind == "WSkin" and "무기 스킨 컬렉션") or (kind == "Pattern" and "페인트 패턴") or "처치 이펙트"
end

function Cosmetics.Rarity(id)
	for _, r in ipairs(Cosmetics.Rarities) do
		if r.Id == id then
			return r
		end
	end
	return Cosmetics.Rarities[1]
end

-- 아이템 하나의 실제 확률(%) = 등급 확률 / 등급 내 아이템 수
function Cosmetics.ItemChance(item)
	local r = Cosmetics.Rarity(item.Rarity)
	return r.Chance / #Cosmetics.CrateByRarity[item.Rarity]
end

-- rng: Random 객체, pityHit: true면 레전더리 확정
function Cosmetics.Roll(rng, pityHit)
	local rarity
	if pityHit then
		rarity = Cosmetics.Rarity("Legendary")
	else
		local total = 0
		for _, r in ipairs(Cosmetics.Rarities) do
			total = total + r.Chance
		end
		local x = rng:NextNumber() * total
		local acc = 0
		rarity = Cosmetics.Rarities[#Cosmetics.Rarities]
		for _, r in ipairs(Cosmetics.Rarities) do
			acc = acc + r.Chance
			if x < acc then
				rarity = r
				break
			end
		end
	end
	local pool = Cosmetics.CrateByRarity[rarity.Id]
	return pool[rng:NextInteger(1, #pool)], rarity
end

function Cosmetics.MaterialOf(name)
	local ok, m = pcall(function()
		return Enum.Material[name]
	end)
	if ok and m then
		return m
	end
	return Enum.Material.Glass
end

-- 장착한 패턴 → 칠할 때 쓸 값: 단일 재질(Enum.Material) 또는 무늬 정보 테이블. 없으면 nil
function Cosmetics.PaintStyle(id)
	local item = Cosmetics.ById[id or ""]
	if not item or item.Kind ~= "Pattern" then
		return nil
	end
	if not item.Material2 and not item.Tint then
		return Cosmetics.MaterialOf(item.Material)
	end
	return {
		Mat = Cosmetics.MaterialOf(item.Material),
		Mat2 = item.Material2 and Cosmetics.MaterialOf(item.Material2) or nil,
		Mix = item.Mix,
		Tint = item.Tint,
		TintAmount = item.TintAmount,
	}
end

return Cosmetics
