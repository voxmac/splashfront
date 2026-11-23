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
}

Cosmetics.ById = {}
Cosmetics.ByRarity = {}
for _, item in ipairs(Cosmetics.Items) do
	Cosmetics.ById[item.Id] = item
	Cosmetics.ByRarity[item.Rarity] = Cosmetics.ByRarity[item.Rarity] or {}
	table.insert(Cosmetics.ByRarity[item.Rarity], item)
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
	return r.Chance / #Cosmetics.ByRarity[item.Rarity]
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
	local pool = Cosmetics.ByRarity[rarity.Id]
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

return Cosmetics
