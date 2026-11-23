-- SPLASH FRONT : 무기 정의 (사이드그레이드 원칙 — 강해지는 업그레이드 없음)
-- Damage: 1발 피해 / FireInterval: 발사 간격(초) / Range: 사거리
-- InkCost: 1발 잉크 소모 / PaintRadius: 착탄 페인트 반경
-- Spread: 기본 탄퍼짐(도) / SpreadGrow: 연사 시 증가량 / SpreadMax: 최대
-- Pellets: 산탄 수 / Splash: 착탄 범위 피해 반경(0이면 직격만)
-- Recoil: 화면 반동(도) / PathPaint: 탄도 경로도 칠함
local Weapons = {}

Weapons.List = {
	{
		Id = "Pistol", Name = "스플랫 피스톨", Class = "권총", Price = 0,
		Damage = 28, HeadMul = 1.5, FireInterval = 0.2, Range = 70,
		InkCost = 2, PaintRadius = 4, Spread = 0.6, SpreadGrow = 0.4, SpreadMax = 3,
		Pellets = 1, Splash = 0, Recoil = 1.2, Auto = false, PathPaint = false,
		Color = Color3.fromRGB(60, 60, 70), Size = Vector3.new(0.4, 0.7, 1.4),
	},
	{
		Id = "Rifle", Name = "스트리트 라이플", Class = "돌격소총", Price = 1500,
		Damage = 18, HeadMul = 1.5, FireInterval = 0.12, Range = 90, -- CBT 1차: 20→18 (TTK 0.48→0.60s)
		InkCost = 1.6, PaintRadius = 3.5, Spread = 0.5, SpreadGrow = 0.35, SpreadMax = 4,
		Pellets = 1, Splash = 0, Recoil = 0.9, Auto = true, PathPaint = false,
		Color = Color3.fromRGB(40, 44, 52), Size = Vector3.new(0.4, 0.6, 2.6),
	},
	{
		Id = "SMG", Name = "레인메이커 SMG", Class = "따발총", Price = 2000,
		Damage = 13, HeadMul = 1.5, FireInterval = 0.065, Range = 45, -- CBT 1차: 11→13 (근거리 최강, TTK 0.46s)
		InkCost = 0.9, PaintRadius = 3, Spread = 2.2, SpreadGrow = 0.3, SpreadMax = 6,
		Pellets = 1, Splash = 0, Recoil = 0.6, Auto = true, PathPaint = false,
		Color = Color3.fromRGB(70, 50, 90), Size = Vector3.new(0.45, 0.8, 1.8),
	},
	{
		Id = "Shotgun", Name = "버스트 블래스터", Class = "산탄총", Price = 2500,
		Damage = 12, HeadMul = 1.25, FireInterval = 0.7, Range = 30, -- CBT 1차: 11→12, 0.8→0.7s
		InkCost = 7, PaintRadius = 3, Spread = 6, SpreadGrow = 0, SpreadMax = 6,
		Pellets = 8, Splash = 0, Recoil = 4, Auto = false, PathPaint = false,
		Color = Color3.fromRGB(90, 60, 40), Size = Vector3.new(0.5, 0.7, 2.4),
	},
	{
		Id = "Sniper", Name = "롱샷 차저", Class = "저격총", Price = 3000,
		Damage = 85, HeadMul = 1.8, FireInterval = 1.2, Range = 240,
		InkCost = 14, PaintRadius = 5, Spread = 0, SpreadGrow = 0, SpreadMax = 0,
		HipSpread = 3, Pellets = 1, Splash = 0, Recoil = 5, Auto = false, PathPaint = true,
		PathStep = 10, PathRadius = 2, PathMax = 120, -- CBT 1차: 탄도 칠하기 축소(간격 7→10, 반경 2.5→2, 최대 120)
		Scope = true, ScopeFov = 25,
		Color = Color3.fromRGB(30, 30, 36), Size = Vector3.new(0.35, 0.6, 3.6),
	},
	{
		Id = "Launcher", Name = "버킷 런처", Class = "유탄발사기", Price = 3500,
		Damage = 45, HeadMul = 1, FireInterval = 1.0, Range = 65,
		InkCost = 12, PaintRadius = 10, Spread = 1, SpreadGrow = 0, SpreadMax = 1,
		Pellets = 1, Splash = 9, Recoil = 3.5, Auto = false, PathPaint = false,
		Color = Color3.fromRGB(110, 110, 30), Size = Vector3.new(0.8, 0.8, 2.2),
	},
}

Weapons.ById = {}
for _, w in ipairs(Weapons.List) do
	Weapons.ById[w.Id] = w
end

Weapons.Default = "Pistol"

function Weapons.Get(id)
	return Weapons.ById[id] or Weapons.ById[Weapons.Default]
end

return Weapons
