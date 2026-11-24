-- 운영 설정 (관리자 패널): 부활 시간·경기 시간·아이템 유지 시간 등
-- 바꾸면 DataStore에 저장(재시작해도 유지) + MessagingService로 다른 서버에도 즉시 반영 + 클라이언트에 공유
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local SettingsService = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("SplashFront_Settings_" .. Config.DataVersion)
end)
local TOPIC = "SF_Settings"
local current = {}

local function publishToClients()
	local snapshot = {}
	for _, t in ipairs(Config.Tunables) do
		snapshot[t.Key] = Config.GetTunable(t.Key)
	end
	ReplicatedStorage:SetAttribute("SF_Settings", HttpService:JSONEncode(snapshot))
end

local function apply(values)
	for k, v in pairs(values or {}) do
		current[k] = v
	end
	Config.ApplySettings(values)
	publishToClients()
end

function SettingsService.Init()
	if store then
		local ok, data = pcall(function()
			return store:GetAsync("global")
		end)
		if ok and type(data) == "table" then
			apply(data)
		end
	end
	publishToClients()
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(msg)
			local ok, data = pcall(function()
				return HttpService:JSONDecode(msg.Data)
			end)
			if ok and type(data) == "table" then
				apply(data)
			end
		end)
	end)
end

-- 관리자: 설정 하나 바꾸기. 반환: 결과 문구
function SettingsService.Set(key, value)
	local def = nil
	for _, t in ipairs(Config.Tunables) do
		if t.Key == key then
			def = t
		end
	end
	value = tonumber(value)
	if not def or not value then
		return false, "알 수 없는 설정"
	end
	value = math.clamp(math.floor(value / def.Step + 0.5) * def.Step, def.Min, def.Max)
	apply({ [key] = value })
	task.spawn(function()
		if store then
			pcall(function()
				store:UpdateAsync("global", function(old)
					old = type(old) == "table" and old or {}
					old[key] = value
					return old
				end)
			end)
		end
		pcall(function()
			MessagingService:PublishAsync(TOPIC, HttpService:JSONEncode({ [key] = value }))
		end)
	end)
	return true, string.format("%s = %s (모든 서버에 저장·적용)", def.Name, tostring(value))
end

-- 관리자 패널 표시용 목록
function SettingsService.List()
	local rows = {}
	for _, t in ipairs(Config.Tunables) do
		table.insert(rows, { Key = t.Key, Name = t.Name, Value = Config.GetTunable(t.Key), Min = t.Min, Max = t.Max, Step = t.Step })
	end
	return rows
end

return SettingsService
