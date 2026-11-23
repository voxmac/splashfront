-- SPLASH FRONT : 무기 정의 (사이드그레이드 원칙 — 강해지는 업그레이드 없음)
-- Damage: 1발 피해 / FireInterval: 발사 간격(초) / Range: 사거리
-- InkCost: 1발 잉크 소모 / PaintRadius: 착탄 페인트 반경
-- Spread: 기본 탄퍼짐(도) / SpreadGrow: 연사 시 증가량 / SpreadMax: 최대
-- Pellets: 산탄 수 / Splash: 착탄 범위 피해 반경(0이면 직격만)
-- Recoil: 화면 반동(도) / PathPaint: 탄도 경로도 칠함
-- ZoomFov: 우클릭 조준 시 시야각(작을수록 확대) / Sight: 조준점 모양 (Dot 레드닷, Holo 홀로, Scope 스코프)
local Weapons = {}

Weapons.List = {
	{
		Id = "Pistol", Name = "스플랫 피스톨", Class = "권총", Price = 0,
		Damage = 28, HeadMul = 1.5, FireInterval = 0.2, Range = 70,
		InkCost = 2, PaintRadius = 4, Spread = 0.15, SpreadGrow = 0.25, SpreadMax = 1.5, -- 0.5: 명중률 상향
		Pellets = 1, Splash = 0, Recoil = 1.2, Auto = false, PathPaint = false, ZoomFov = 48, Sight = "Dot",
		Color = Color3.fromRGB(60, 60, 70), Size = Vector3.new(0.4, 0.7, 1.4),
	},
	{
		Id = "Rifle", Name = "스트리트 라이플", Class = "돌격소총", Price = 1500,
		Damage = 18, HeadMul = 1.5, FireInterval = 0.12, Range = 90, -- CBT 1차: 20→18 (TTK 0.48→0.60s)
		InkCost = 1.6, PaintRadius = 3.5, Spread = 0.2, SpreadGrow = 0.12, SpreadMax = 1.8,
		Pellets = 1, Splash = 0, Recoil = 0.9, Auto = true, PathPaint = false, ZoomFov = 36, Sight = "Holo",
		Color = Color3.fromRGB(40, 44, 52), Size = Vector3.new(0.4, 0.6, 2.6),
	},
	{
		Id = "SMG", Name = "레인메이커 SMG", Class = "따발총", Price = 2000,
		Damage = 13, HeadMul = 1.5, FireInterval = 0.065, Range = 45, -- CBT 1차: 11→13 (근거리 최강, TTK 0.46s)
		InkCost = 0.9, PaintRadius = 3, Spread = 1.0, SpreadGrow = 0.15, SpreadMax = 2.8,
		Pellets = 1, Splash = 0, Recoil = 0.6, Auto = true, PathPaint = false, ZoomFov = 46, Sight = "Dot",
		Color = Color3.fromRGB(70, 50, 90), Size = Vector3.new(0.45, 0.8, 1.8),
	},
	{
		Id = "Shotgun", Name = "버스트 블래스터", Class = "산탄총", Price = 2500,
		Damage = 12, HeadMul = 1.25, FireInterval = 0.7, Range = 30, -- CBT 1차: 11→12, 0.8→0.7s
		InkCost = 7, PaintRadius = 3, Spread = 4.2, SpreadGrow = 0, SpreadMax = 4.2,
		Pellets = 8, Splash = 0, Recoil = 4, Auto = false, PathPaint = false, ZoomFov = 54, Sight = "Holo",
		Color = Color3.fromRGB(90, 60, 40), Size = Vector3.new(0.5, 0.7, 2.4),
	},
	{
		Id = "Sniper", Name = "롱샷 차저", Class = "저격총", Price = 3000,
		Damage = 85, HeadMul = 1.8, FireInterval = 1.2, Range = 240,
		InkCost = 14, PaintRadius = 5, Spread = 0, SpreadGrow = 0, SpreadMax = 0,
		HipSpread = 1.2, Pellets = 1, Splash = 0, Recoil = 5, Auto = false, PathPaint = true,
		PathStep = 10, PathRadius = 2, PathMax = 120, -- CBT 1차: 탄도 칠하기 축소(간격 7→10, 반경 2.5→2, 최대 120)
		Scope = true, ScopeFov = 16, ZoomFov = 16, Sight = "Scope", -- 0.5: 확대 강화
		Color = Color3.fromRGB(30, 30, 36), Size = Vector3.new(0.35, 0.6, 3.6),
	},
	{
		Id = "Launcher", Name = "버킷 런처", Class = "유탄발사기", Price = 3500,
		Damage = 45, HeadMul = 1, FireInterval = 1.0, Range = 65,
		InkCost = 12, PaintRadius = 10, Spread = 0.4, SpreadGrow = 0, SpreadMax = 0.4,
		Pellets = 1, Splash = 9, Recoil = 3.5, Auto = false, PathPaint = false, ZoomFov = 42, Sight = "Holo",
		Color = Color3.fromRGB(110, 110, 30), Size = Vector3.new(0.8, 0.8, 2.2),
	},
	------------------------------------------------------------------
	-- 실총 라인업: ReplicatedStorage.StoreGuns 안의 크리에이터 상점 모델(StoreModel 이름)을 씀.
	-- 모델이 없으면 상점에 나오지 않음. 성능은 기존 총과 같은 사이드그레이드 원칙
	------------------------------------------------------------------
	{
		Id = "K2", Name = "K2 소총", Class = "돌격소총", Price = 4000, StoreModel = "K2", ModelLength = 3.3,
		Damage = 19, HeadMul = 1.6, FireInterval = 0.11, Range = 95,
		InkCost = 1.6, PaintRadius = 3.4, Spread = 0.15, SpreadGrow = 0.11, SpreadMax = 1.6,
		Pellets = 1, Splash = 0, Recoil = 0.9, Auto = true, PathPaint = false, ZoomFov = 34, Sight = "Holo",
		Color = Color3.fromRGB(46, 46, 50), Size = Vector3.new(0.4, 0.6, 3.3),
	},
	{
		Id = "K2C1", Name = "K2C1 카빈", Class = "카빈", Price = 4500, StoreModel = "K2C1", ModelLength = 3.0,
		Damage = 16, HeadMul = 1.6, FireInterval = 0.09, Range = 80,
		InkCost = 1.4, PaintRadius = 3.2, Spread = 0.25, SpreadGrow = 0.1, SpreadMax = 1.8,
		Pellets = 1, Splash = 0, Recoil = 0.75, Auto = true, PathPaint = false, ZoomFov = 38, Sight = "Dot",
		Color = Color3.fromRGB(40, 40, 44), Size = Vector3.new(0.4, 0.6, 3.0),
	},
	{
		Id = "K3", Name = "K3 기관총", Class = "경기관총", Price = 5000, StoreModel = "K3", ModelLength = 3.8,
		Damage = 15, HeadMul = 1.4, FireInterval = 0.085, Range = 85,
		InkCost = 1.1, PaintRadius = 3.6, Spread = 0.5, SpreadGrow = 0.08, SpreadMax = 2.6,
		Pellets = 1, Splash = 0, Recoil = 1.1, Auto = true, PathPaint = false, ZoomFov = 40, Sight = "Holo",
		Color = Color3.fromRGB(48, 48, 44), Size = Vector3.new(0.5, 0.8, 3.8),
	},
	{
		Id = "K14", Name = "K14 저격소총", Class = "저격총", Price = 5000, StoreModel = "K14", ModelLength = 4.3,
		Damage = 100, HeadMul = 1.6, FireInterval = 1.5, Range = 260,
		InkCost = 16, PaintRadius = 5, Spread = 0, SpreadGrow = 0, SpreadMax = 0,
		HipSpread = 1.4, Pellets = 1, Splash = 0, Recoil = 5.5, Auto = false, PathPaint = true,
		PathStep = 10, PathRadius = 2, PathMax = 120,
		Scope = true, ScopeFov = 12, ZoomFov = 12, Sight = "Scope",
		Color = Color3.fromRGB(60, 64, 52), Size = Vector3.new(0.35, 0.6, 4.3),
	},
	{
		Id = "K5", Name = "K5 권총", Class = "권총", Price = 2500, StoreModel = "K5", ModelLength = 1.5,
		Damage = 34, HeadMul = 1.6, FireInterval = 0.26, Range = 75,
		InkCost = 3, PaintRadius = 4, Spread = 0.15, SpreadGrow = 0.35, SpreadMax = 1.8,
		Pellets = 1, Splash = 0, Recoil = 1.8, Auto = false, PathPaint = false, ZoomFov = 46, Sight = "Dot",
		Color = Color3.fromRGB(36, 36, 40), Size = Vector3.new(0.35, 0.7, 1.5),
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
