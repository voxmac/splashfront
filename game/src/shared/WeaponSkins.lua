-- 무기 스킨 컬렉션: 총 종류마다 따로 사서, 총마다 따로 장착
-- 등급이 오를수록 연출이 늘어남
--   스탠다드: 몸체 색·재질
--   디럭스  : + 투톤(금속 부품 색·재질)
--   프리미엄: + 발광 라인 + 색상 변형 3종
--   얼티밋  : + 총에서 흐르는 입자·빛 + 전용 처치 피니셔 + 색상 변형 3종
-- 스킨 Id = 컬렉션Id .. "@" .. 무기Id  (예: "NeonPulse@K2")
-- 장착 정보(플레이어 속성 WSkinEquip) = "K2=NeonPulse:2;Rifle=SteelWave:1"
local WeaponSkins = {}

WeaponSkins.Tiers = {
	{ Id = "Standard", Name = "스탠다드", Price = 1200, Color = Color3.fromRGB(90, 170, 255) },
	{ Id = "Deluxe", Name = "디럭스", Price = 2500, Color = Color3.fromRGB(60, 220, 160) },
	{ Id = "Premium", Name = "프리미엄", Price = 4500, Color = Color3.fromRGB(210, 90, 255) },
	{ Id = "Ultimate", Name = "얼티밋", Price = 8000, Color = Color3.fromRGB(255, 190, 40) },
}
WeaponSkins.BundleDiscount = 0.25 -- 컬렉션 전체(모든 총) 한 번에 사면 25% 할인

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Body/BodyMat: 몸체, Metal/MetalMat: 금속 부품, Accent: 발광 라인(없으면 팀 색), Particle: 입자 색, Finisher: 처치 연출
WeaponSkins.Lines = {
	{ Id = "SteelWave", Name = "스틸 웨이브", Tier = "Standard", Desc = "빛을 머금은 헤어라인 스틸",
		Variants = { { Name = "기본", Body = c(178, 184, 196), BodyMat = "Metal", Metal = c(70, 74, 86), MetalMat = "Metal" } } },
	{ Id = "DesertRanger", Name = "데저트 레인저", Tier = "Standard", Desc = "모래바람을 견디는 전술 도장",
		Variants = { { Name = "기본", Body = c(196, 168, 120), BodyMat = "Fabric", Metal = c(84, 82, 60), MetalMat = "Metal" } } },
	{ Id = "BlackOnyx", Name = "블랙 오닉스", Tier = "Deluxe", Desc = "무광 블랙에 금빛 부품",
		Variants = { { Name = "기본", Body = c(24, 24, 28), BodyMat = "SmoothPlastic", Metal = c(230, 180, 70), MetalMat = "Foil" } } },
	{ Id = "SakuraBloom", Name = "사쿠라 블룸", Tier = "Deluxe", Desc = "벚꽃 대리석과 진주빛 금속",
		Variants = { { Name = "기본", Body = c(255, 176, 205), BodyMat = "Marble", Metal = c(240, 236, 245), MetalMat = "Metal" } } },
	{ Id = "NeonPulse", Name = "네온 펄스", Tier = "Premium", Desc = "어둠 속에서 맥박처럼 빛나는 네온 라인",
		Variants = {
			{ Name = "마젠타", Body = c(20, 18, 34), BodyMat = "Glass", Metal = c(44, 40, 66), MetalMat = "Metal", Accent = c(255, 40, 200) },
			{ Name = "시안", Body = c(14, 24, 36), BodyMat = "Glass", Metal = c(36, 50, 70), MetalMat = "Metal", Accent = c(40, 230, 255) },
			{ Name = "라임", Body = c(18, 28, 18), BodyMat = "Glass", Metal = c(40, 60, 40), MetalMat = "Metal", Accent = c(170, 255, 50) },
		} },
	{ Id = "FrostCrystal", Name = "프로스트 크리스탈", Tier = "Premium", Desc = "얼음 결정으로 깎아 만든 총",
		Variants = {
			{ Name = "아이스", Body = c(170, 225, 255), BodyMat = "Ice", Metal = c(210, 220, 235), MetalMat = "Metal", Accent = c(140, 220, 255) },
			{ Name = "아메시스트", Body = c(190, 150, 255), BodyMat = "Ice", Metal = c(220, 210, 240), MetalMat = "Metal", Accent = c(200, 130, 255) },
			{ Name = "에메랄드", Body = c(120, 230, 170), BodyMat = "Ice", Metal = c(210, 235, 220), MetalMat = "Metal", Accent = c(90, 255, 170) },
		} },
	{ Id = "InfernoCore", Name = "인페르노 코어", Tier = "Ultimate", Desc = "갈라진 용암 사이로 불씨가 흩날림 · 처치 시 화염 기둥",
		Finisher = "Inferno",
		Variants = {
			{ Name = "화염", Body = c(255, 90, 20), BodyMat = "CrackedLava", Metal = c(40, 30, 30), MetalMat = "Metal", Accent = c(255, 140, 30), Particle = c(255, 150, 40) },
			{ Name = "청염", Body = c(40, 140, 255), BodyMat = "CrackedLava", Metal = c(26, 30, 46), MetalMat = "Metal", Accent = c(80, 190, 255), Particle = c(90, 200, 255) },
			{ Name = "흑염", Body = c(150, 40, 255), BodyMat = "CrackedLava", Metal = c(20, 16, 26), MetalMat = "Metal", Accent = c(190, 90, 255), Particle = c(200, 120, 255) },
		} },
	{ Id = "ChromaGalaxy", Name = "크로마 갤럭시", Tier = "Ultimate", Desc = "별빛이 흐르는 우주 도장 · 처치 시 은하 폭발",
		Finisher = "Galaxy",
		Variants = {
			{ Name = "갤럭시", Body = c(60, 30, 140), BodyMat = "Glass", Metal = c(30, 24, 60), MetalMat = "Metal", Accent = c(150, 110, 255), Particle = c(230, 220, 255) },
			{ Name = "오로라", Body = c(20, 110, 120), BodyMat = "Glass", Metal = c(18, 40, 50), MetalMat = "Metal", Accent = c(60, 255, 200), Particle = c(180, 255, 230) },
			{ Name = "선셋", Body = c(200, 70, 110), BodyMat = "Glass", Metal = c(60, 26, 40), MetalMat = "Metal", Accent = c(255, 170, 60), Particle = c(255, 220, 160) },
		} },
}

WeaponSkins.LineById = {}
WeaponSkins.TierById = {}
for _, t in ipairs(WeaponSkins.Tiers) do
	WeaponSkins.TierById[t.Id] = t
end
for i, l in ipairs(WeaponSkins.Lines) do
	l.Order = i
	WeaponSkins.LineById[l.Id] = l
end

function WeaponSkins.SkinId(lineId, weaponId)
	return lineId .. "@" .. weaponId
end

function WeaponSkins.Split(skinId)
	return string.match(skinId or "", "^([%w_]+)@([%w_]+)$")
end

function WeaponSkins.Price(lineId)
	local l = WeaponSkins.LineById[lineId]
	return l and WeaponSkins.TierById[l.Tier].Price or nil
end

-- weaponIds: 상점에 나오는 총 목록
function WeaponSkins.BundlePrice(lineId, weaponIds, ownedSet)
	local each = WeaponSkins.Price(lineId) or 0
	local n = 0
	for _, wid in ipairs(weaponIds) do
		if not (ownedSet and ownedSet[WeaponSkins.SkinId(lineId, wid)]) then
			n = n + 1
		end
	end
	return math.floor(each * n * (1 - WeaponSkins.BundleDiscount) / 10 + 0.5) * 10, n
end

-- "K2=NeonPulse:2;Rifle=SteelWave:1" -> { K2 = { Line = "NeonPulse", V = 2 }, ... }
function WeaponSkins.ParseEquip(s)
	local out = {}
	for wid, line, v in string.gmatch(s or "", "([%w_]+)=([%w_]+):(%d+)") do
		out[wid] = { Line = line, V = tonumber(v) }
	end
	return out
end

function WeaponSkins.EncodeEquip(t)
	local parts = {}
	for wid, e in pairs(t or {}) do
		table.insert(parts, string.format("%s=%s:%d", wid, e.Line, e.V or 1))
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

-- 화면에 쓸 외형(Look) 하나: 라인 + 변형 번호
function WeaponSkins.Look(lineId, variant)
	local l = WeaponSkins.LineById[lineId or ""]
	if not l then
		return nil
	end
	local v = l.Variants[math.clamp(variant or 1, 1, #l.Variants)]
	local look = table.clone(v)
	look.Line = l.Id
	look.Tier = l.Tier
	look.Glow = (l.Tier == "Premium" or l.Tier == "Ultimate")
	look.Finisher = l.Finisher
	return look
end

-- 플레이어(또는 속성 문자열)가 그 총에 장착한 스킨의 Look
function WeaponSkins.LookFor(playerOrEquip, weaponId)
	local s = playerOrEquip
	if typeof(playerOrEquip) == "Instance" then
		s = playerOrEquip:GetAttribute("WSkinEquip")
	end
	local e = WeaponSkins.ParseEquip(s)[weaponId or ""]
	return e and WeaponSkins.Look(e.Line, e.V) or nil
end

return WeaponSkins
