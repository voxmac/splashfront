-- SPLASH FRONT : 전역 설정값 (밸런스 조정은 이 파일과 Weapons.lua에서)
local Config = {}

Config.GameName = "SPLASH FRONT"
Config.Build = "1.0"

-- 저장 데이터 버전: 클로즈 테스트 데이터와 정식 출시 데이터를 분리 (출시 때 "v1"로 변경)
Config.DataVersion = "v1" -- 정식 출시: 클로즈 테스트(CBT1) 데이터와 분리해 모두 새로 시작

-- 클로즈 테스트(CBT) 설정
Config.CBT = {
	Enabled = false,          -- 정식 출시: 누구나 입장 (true로 바꾸면 테스터 명단만 입장)
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

-- 개발자 치트(코인 지급·무기 해금·무료 크레이트·레이팅 변경·데이터 초기화 등)
-- 정식 서버에서는 false: 관리자라도 운영용 명령(경기 종료·맵 변경·봇·리포트)만 가능.
-- Studio 테스트에서는 이 값과 관계없이 모두 사용 가능.
Config.DevTools = true -- 관리자(Admins 명단)만 쓸 수 있음. 치트를 막으려면 false

-- 운영용(치트가 아닌) 관리자 명령
Config.OpsCommands = { endMatch = true, nextMap = true, bots = true, balance = true, feedback = true, settings = true, setSetting = true }

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
Config.RespawnTime = 10 -- 사망 후 부활까지(초) · 관리자 패널 설정에서 변경 가능
Config.TeamSpawnRadius = 22 -- 팀전 리스폰: 우리 팀 스폰 지점 반경(스터드) 안에서 랜덤
Config.SpawnProtection = 2

Config.InkMax = 100
Config.InkRefill = 20           -- 초당
Config.InkRefillOwnColor = 45   -- 우리 색 위에서 초당
Config.InkRefillDelay = 0.4     -- 사격 멈춘 뒤 충전 시작까지

Config.WalkSpeed = 16
Config.WalkSpeedOwn = 21
Config.WalkSpeedEnemy = 11
Config.CrouchSpeedMul = 0.6
Config.RunSpeedMul = 1.4    -- 달리기(Shift 누르는 동안) · 조준·앉기·사격 직후엔 안 됨
Config.WalkSpeedMul = 0.55  -- 걷기(Z 전환) · 탄 퍼짐이 줄어 정밀 사격

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
Config.RankedAllowBots = true  -- 봇이 빈자리를 채운 경기도 레이팅 반영 (사람 플레이어만 점수 변동)

-- 승리 판정 (터프·솔로): 최종 점수 = 페인트 면적 몫 80% + (처치 + 미션 점수) 몫 20%  (각각 전체 중 우리 비율)
-- 플래그 러시는 깃발 점수로 판정
Config.WinWeights = { Paint = 0.8, Combat = 0.2 }
Config.MissionKillValue = 1 -- 미션 보너스 1점 = 처치 몇 번어치인지 (미션 보너스는 보통 4점)

Config.Modes = {
	Turf = { Id = "Turf", Name = "터프 배틀", Desc = "더 넓게 칠한 팀이 승리" },
	Flag = { Id = "Flag", Name = "플래그 러시", Desc = "깃발을 꽂아 100점 먼저" },
	Solo = { Id = "Solo", Name = "솔로 페인트 로얄", Desc = "8인 개인전, 면적 1위" },
}
Config.Queues = {
	{ Id = "2v2", Mode = "Turf", TeamSize = 2, Ranked = true },
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

-- 미션 보상 아이템 (미션 성공 팀원 전원에게 1개씩 무작위 지급, 최대 3개 보관 · F 사용 · G 순서 바꾸기)
Config.Items = {
	{ Id = "Jetpack", Name = "제트팩", Desc = "10초 동안 Space를 누르고 있으면 날아올라요", Duration = 10, Weight = 18 },
	{ Id = "Shield", Name = "일시 무적", Desc = "6초 동안 어떤 공격도 받지 않아요", Duration = 6, Weight = 16 },
	{ Id = "Smoke", Name = "연막탄", Desc = "조준한 곳에 12초 동안 연막을 펼쳐 시야를 가려요", Duration = 12, Weight = 20 },
	{ Id = "Golden", Name = "황금총", Desc = "단 1발 · 맞으면 무조건 처치 · 쏘면 사라져요", Weight = 10 },
	{ Id = "Zoom3", Name = "3배 스코프", Desc = "60초 동안 모든 총 조준이 3배 확대", Duration = 60, Zoom = 3, Weight = 20 },
	{ Id = "Zoom6", Name = "6배 스코프", Desc = "60초 동안 모든 총 조준이 6배 확대", Duration = 60, Zoom = 6, Weight = 16 },
}
Config.ItemSlots = 3
Config.JetpackThrust = 85   -- 초당 위로 가속 (중력 196을 상쇄하는 양만큼 추가로 줌)
Config.JetpackMaxRise = 26  -- 최대 상승 속도
Config.SmokeRadius = 14
Config.GoldenRange = 320

-- 투척물(스페셜 크로마 봄·연막탄): 바닥·벽·캐릭터에 닿는 순간 터짐
Config.Throw = { Speed = 55, Gravity = 70, MaxTime = 3 }

-- 미션
Config.MissionInterval = 35
Config.MissionFirstDelay = 20

-- 보상
Config.Rewards = {
	Win = 120, Lose = 60, Kill = 10, Headshot = 5, Per100Cells = 10, Mission = 30,
}

-- 경험치·레벨 (레벨업마다 코인 보너스)
Config.XP = { Kill = 25, Headshot = 10, Win = 100, Lose = 50, PerCells = 40, Mission = 40, Quest = 60 }
function Config.XPNeed(level)
	return 100 + (level - 1) * 35
end
function Config.LevelReward(level)
	return 100 + level * 10
end
Config.MultiKillWindow = 4 -- 초: 이 안에 연달아 처치하면 더블·트리플·쿼드 킬

-- 일일·주간 퀘스트 (한국 시간 자정 / 월요일 0시 초기화, 모든 플레이어가 같은 퀘스트)
-- Stat: Kills · Headshots · Cells · Wins · Matches · Missions · Specials · Items
Config.Quests = {
	Daily = {
		{ Id = "d_kill20", Name = "20 처치 달성", Stat = "Kills", Goal = 20, Reward = 60 },
		{ Id = "d_head5", Name = "헤드샷 5회", Stat = "Headshots", Goal = 5, Reward = 60 },
		{ Id = "d_paint1500", Name = "바닥 1,500칸 칠하기", Stat = "Cells", Goal = 1500, Reward = 60 },
		{ Id = "d_win2", Name = "2승 하기", Stat = "Wins", Goal = 2, Reward = 80 },
		{ Id = "d_play3", Name = "경기 3판 하기", Stat = "Matches", Goal = 3, Reward = 50 },
		{ Id = "d_mission2", Name = "랜덤 미션 2번 성공", Stat = "Missions", Goal = 2, Reward = 70 },
		{ Id = "d_special3", Name = "크로마 봄 3번 터뜨리기", Stat = "Specials", Goal = 3, Reward = 50 },
	},
	Weekly = {
		{ Id = "w_kill300", Name = "300 처치 달성", Stat = "Kills", Goal = 300, Reward = 500 },
		{ Id = "w_win15", Name = "15승 하기", Stat = "Wins", Goal = 15, Reward = 600 },
		{ Id = "w_paint20k", Name = "바닥 20,000칸 칠하기", Stat = "Cells", Goal = 20000, Reward = 500 },
		{ Id = "w_head60", Name = "헤드샷 60회", Stat = "Headshots", Goal = 60, Reward = 450 },
		{ Id = "w_item15", Name = "아이템 15번 사용", Stat = "Items", Goal = 15, Reward = 400 },
		{ Id = "w_play30", Name = "경기 30판 하기", Stat = "Matches", Goal = 30, Reward = 450 },
	},
	PerPeriod = 3,
}

-- 포인트(코인)로 바로 사는 스킨 가격 (크레이트 아이템도 코인으로 직접 구매 가능)
Config.SkinPrices = { Rare = 1500, Epic = 4000, Legendary = 9000 }
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
-- 관리자 패널에서 바꿀 수 있는 운영 설정 (저장되어 모든 서버·재시작 후에도 유지)
-- Key = 설정 이름, Path = Config 안 위치("RespawnTime" 또는 "Item:Jetpack"), Min/Max/Step = 허용 범위
Config.Tunables = {
	{ Key = "RespawnTime", Name = "부활 대기(초)", Min = 2, Max = 30, Step = 1 },
	{ Key = "MatchLength", Name = "경기 시간(초)", Min = 60, Max = 900, Step = 30 },
	{ Key = "LobbyCountdown", Name = "시작 대기(초)", Min = 5, Max = 60, Step = 5 },
	{ Key = "MissionInterval", Name = "미션 간격(초)", Min = 15, Max = 120, Step = 5 },
	{ Key = "Item:Jetpack", Name = "제트팩 유지(초)", Min = 3, Max = 60, Step = 1 },
	{ Key = "Item:Shield", Name = "무적 유지(초)", Min = 2, Max = 30, Step = 1 },
	{ Key = "Item:Smoke", Name = "연막 유지(초)", Min = 3, Max = 60, Step = 1 },
	{ Key = "Item:Zoom3", Name = "3배줌 유지(초)", Min = 10, Max = 300, Step = 10 },
	{ Key = "Item:Zoom6", Name = "6배줌 유지(초)", Min = 10, Max = 300, Step = 10 },
	{ Key = "CrateCoinPrice", Name = "크레이트 코인가", Min = 500, Max = 50000, Step = 500 },
	{ Key = "FillWithBots", Name = "빈자리 봇 (1켬/0끔)", Min = 0, Max = 1, Step = 1 },
}

function Config.GetTunable(key)
	local id = string.match(key, "^Item:(.+)$")
	if id then
		for _, it in ipairs(Config.Items) do
			if it.Id == id then
				return it.Duration
			end
		end
		return nil
	end
	local v = Config[key]
	if type(v) == "boolean" then
		return v and 1 or 0
	end
	return v
end

-- 설정 적용 (서버·클라이언트 공통). values = { [Key] = 숫자 }
function Config.ApplySettings(values)
	for _, t in ipairs(Config.Tunables) do
		local v = tonumber(values and values[t.Key])
		if v then
			v = math.clamp(v, t.Min, t.Max)
			local id = string.match(t.Key, "^Item:(.+)$")
			if id then
				for _, it in ipairs(Config.Items) do
					if it.Id == id and it.Duration then
						it.Desc = string.gsub(it.Desc, tostring(it.Duration) .. "초", tostring(v) .. "초", 1)
						it.Duration = v
					end
				end
			elseif type(Config[t.Key]) == "boolean" then
				Config[t.Key] = v >= 1
			else
				Config[t.Key] = v
			end
		end
	end
end

-- 크로마 크레이트를 포인트(코인)로도 개봉
Config.CrateCoinPrice = 5000

Config.Monetization = {
	VipGamePassId = 2099866275, -- VIP (코인 1.25배)
	CrateProductId = 3735438301, -- 크로마 크레이트 79 R$
	CoinProducts = {
		-- [개발자 상품 ID] = 지급 코인
		[3735438412] = 500,
		[3735438631] = 1200,
		[3735438815] = 3000,
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
