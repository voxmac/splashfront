-- SPLASH FRONT : 전역 설정값 (밸런스 조정은 이 파일과 Weapons.lua에서)
local Config = {}

Config.GameName = "SPLASH FRONT"
Config.Build = "0.5.1-CBT"

-- 저장 데이터 버전: 클로즈 테스트 데이터와 정식 출시 데이터를 분리 (출시 때 "v1"로 변경)
Config.DataVersion = "CBT1"

-- 클로즈 테스트(CBT) 설정
Config.CBT = {
	Enabled = true,           -- false로 바꾸면 누구나 입장 (정식 출시)
	Testers = {               -- 입장 허용 UserId 목록
		-- 12345678,
	},
	GroupId = 0,              -- 이 그룹 멤버도 입장 허용 (0이면 사용 안 함)
	GroupMinRank = 1,         -- 그룹 내 최소 등급
	Admins = {                -- 관리자 패널(F2) 사용 가능 UserId. Studio에서는 모두 관리자
		12046530242,          -- VOXCHOI (소유자)
	},
	KickMessage = "SPLASH FRONT는 현재 클로즈 테스트 중입니다. 테스터 신청 후 입장해 주세요!",
	FeedbackCooldown = 60,    -- 피드백 제출 간격(초)
}

-- 페인트 셀
Config.CellSize = 4              -- 셀 한 칸 크기(스터드)
Config.NeutralColor = Color3.fromRGB(205, 208, 214)

-- 팀 (크루) — 기본값. 실제 경기는 아래 TeamPalette에서 매 판 겹치지 않는 두 색을 자동으로 고름
Config.Teams = {
	{ Id = 1, Name = "네온 메이커즈", Color = Color3.fromRGB(255, 46, 170) },
	{ Id = 2, Name = "터코이즈 타이드", Color = Color3.fromRGB(0, 214, 200) },
}
-- 팀 자동 편성 색 (무지개 + 분홍·하늘). 색상환에서 충분히 떨어진 두 색을 매 판 무작위로 뽑음
Config.TeamPalette = {
	{ Name = "레드 레이더스", Color = Color3.fromRGB(255, 60, 60) },
	{ Name = "오렌지 오버드라이브", Color = Color3.fromRGB(255, 140, 30) },
	{ Name = "옐로 볼트", Color = Color3.fromRGB(255, 214, 0) },
	{ Name = "그린 그렘린", Color = Color3.fromRGB(70, 220, 80) },
	{ Name = "블루 블래스터", Color = Color3.fromRGB(40, 110, 255) },
	{ Name = "인디고 나이츠", Color = Color3.fromRGB(95, 70, 235) },
	{ Name = "바이올렛 바이퍼", Color = Color3.fromRGB(175, 80, 255) },
	{ Name = "핑크 펑크", Color = Color3.fromRGB(255, 46, 170) },
	{ Name = "스카이 스플래셔", Color = Color3.fromRGB(0, 200, 255) },
}
Config.TeamMinHueGap = 0.22 -- 두 팀 색의 최소 색상 차이 (0~0.5)

-- 솔로 모드용 개인 색 (최대 8인)
Config.SoloColors = {
	Color3.fromRGB(255, 46, 170), Color3.fromRGB(0, 214, 200), Color3.fromRGB(255, 196, 0),
	Color3.fromRGB(120, 230, 40), Color3.fromRGB(140, 90, 255), Color3.fromRGB(255, 110, 40),
	Color3.fromRGB(40, 140, 255), Color3.fromRGB(240, 240, 255),
}

-- 플레이어
Config.MaxHealth = 100
Config.RegenDelay = 3
Config.RegenPerSecond = 25
Config.RespawnTime = 4
Config.SpawnProtection = 2

Config.InkMax = 100
Config.InkRefill = 20           -- 초당
Config.InkRefillOwnColor = 45   -- 우리 색 위에서 초당
Config.InkRefillDelay = 0.4     -- 사격 멈춘 뒤 충전 시작까지

Config.WalkSpeed = 16
Config.WalkSpeedOwn = 21
Config.WalkSpeedEnemy = 11
Config.CrouchSpeedMul = 0.6

Config.SpecialCells = 150       -- 이만큼 칠하면 스페셜 충전
Config.SpecialRadius = 14
Config.SpecialDamage = 70

-- 매치
Config.MatchLength = 300        -- 5분
Config.FinalSplashTime = 30     -- 남은 시간이 이 값 이하이면 페인트 반경 1.5배
Config.FinalSplashMul = 1.5
Config.LobbyCountdown = 20     -- 매치 시작 전 대기 시간(초)
Config.PadLeaveGrace = 1.5      -- 발판 참가 직후 이 시간 동안은 발판 이탈 검사 안 함
Config.MapScale = 2             -- 맵 가로·세로 배율 (높이는 그대로)
Config.WeaponSwitchRadius = 18  -- 스폰 지점에서 이 거리 안이면 무기 교체 가능
Config.WeaponSwitchGrace = 6    -- 부활 후 이 시간(초) 동안도 무기 교체 가능
Config.HitAssist = { Body = 1.8, Head = 0.9, PerStud = 0.015 } -- 서버 명중 보정(스터드): 지연 보상
Config.HitClaim = { MaxMove = 9, MaxPerp = 1.5 } -- 클라이언트 명중 판정 인정 범위: 대상이 그 사이 움직인 거리 / 탄도에서 벗어난 거리
Config.ResultsTime = 10
Config.FillWithBots = true      -- 인원 부족 시 봇으로 채움 (스튜디오 테스트용으로도 필요)
Config.RankedAllowBots = false  -- 봇이 섞인 랭크전은 레이팅 미반영 (테스트 때는 true로)

Config.Modes = {
	Turf = { Id = "Turf", Name = "터프 배틀", Desc = "더 넓게 칠한 팀이 승리" },
	Flag = { Id = "Flag", Name = "플래그 러시", Desc = "깃발을 꽂아 100점 먼저" },
	Solo = { Id = "Solo", Name = "솔로 페인트 로얄", Desc = "8인 개인전, 면적 1위" },
}
Config.Queues = {
	{ Id = "2v2", Mode = "Turf", TeamSize = 2, Ranked = false },
	{ Id = "3v3", Mode = "Turf", TeamSize = 3, Ranked = true },
	{ Id = "5v5", Mode = "Turf", TeamSize = 5, Ranked = true },
	{ Id = "Flag3v3", Mode = "Flag", TeamSize = 3, Ranked = true },
	{ Id = "Solo", Mode = "Solo", TeamSize = 8, Ranked = true },
}

Config.Flag = {
	PlantTime = 4,
	PlantTimeEnemyGround = 8,
	PointsPerSecond = 1,
	WinScore = 100,
	Radius = 7,
}

-- 미션
Config.MissionInterval = 35
Config.MissionFirstDelay = 20

-- 보상
Config.Rewards = {
	Win = 120, Lose = 60, Kill = 10, Per100Cells = 10, Mission = 30,
}
Config.VipCoinMul = 1.25

-- 랭크
Config.Rating = { Start = 1000, Win = 25, Lose = -18, PerformanceMax = 8 }
Config.Tiers = {
	{ Name = "브론즈", Min = 0 },
	{ Name = "실버", Min = 1100 },
	{ Name = "골드", Min = 1300 },
	{ Name = "플래티넘", Min = 1500 },
	{ Name = "다이아몬드", Min = 1750 },
	{ Name = "크로마 마스터", Min = 2000 },
}
Config.Season = "S1"

-- 수익화 (Creator Hub에서 만든 실제 ID로 교체. 0이면 비활성)
Config.Monetization = {
	VipGamePassId = 0,
	CrateProductId = 0, -- 크로마 크레이트 79 R$ 개발자 상품 ID
	CoinProducts = {
		-- [개발자 상품 ID] = 지급 코인
		-- [123456789] = 500,
	},
}

-- 배경음악 (기획서 3장: 맵별 루프, 마지막 30초 템포 상승)
-- 음원은 Kaggle(ACE-Step 1.5)로 만들어 Open Cloud로 업로드 → AssetIds.Music 에 자동 기록 (MusicPlayer가 재생)
Config.Music = {
	Volume = 0.35,
	FinalSplashSpeed = 1.12, -- 파이널 스플래시 구간 재생 속도
}

-- 효과음 (원하는 에셋 ID로 교체 가능)
Config.Sounds = {
	Fire = "rbxasset://sounds/electronicpingshort.wav",
	Hit = "rbxasset://sounds/impact_water.mp3",
	Splashed = "rbxasset://sounds/swoosh.wav",
}

function Config.GetTier(rating)
	local tier = Config.Tiers[1]
	for _, t in ipairs(Config.Tiers) do
		if rating >= t.Min then
			tier = t
		end
	end
	return tier
end

return Config
