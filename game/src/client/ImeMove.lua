-- 한글 입력기(IME) 상태에서도 WASD로 이동되게 보완
-- 원인: 채팅에서 한/영을 한글로 바꾼 뒤에는 Roblox 기본 이동(PlayerModule)이 W·A·S·D를 '이동 동작'으로 받지 못함.
--       (화살표 키는 글자가 아니라 그대로 됨) 하지만 W·A·S·D 키 자체는 게임에 들어옴(KeyCode 확인함).
-- 해결: W·A·S·D가 눌려 있는데 기본 이동이 0일 때만, 같은 방식(카메라 기준)으로 대신 움직여 줌.
--       기본 이동이 정상일 때(영문 상태)는 아무것도 하지 않으므로 이중 이동이 생기지 않음.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ImeMove = {}

local player = Players.LocalPlayer
local controls = nil

local function getControls()
	if controls then
		return controls
	end
	local ps = player:FindFirstChild("PlayerScripts")
	local pm = ps and ps:FindFirstChild("PlayerModule")
	if pm then
		local ok, mod = pcall(require, pm)
		if ok and mod and mod.GetControls then
			controls = mod:GetControls()
		end
	end
	return controls
end

local K = Enum.KeyCode

function ImeMove.Init()
	RunService:BindToRenderStep("SF_ImeMove", Enum.RenderPriority.Input.Value + 1, function()
		-- 채팅 등 글 입력 중에는 움직이지 않음
		if UserInputService:GetFocusedTextBox() then
			return
		end
		local x = (UserInputService:IsKeyDown(K.D) and 1 or 0) - (UserInputService:IsKeyDown(K.A) and 1 or 0)
		local z = (UserInputService:IsKeyDown(K.W) and 1 or 0) - (UserInputService:IsKeyDown(K.S) and 1 or 0)
		if x == 0 and z == 0 then
			return
		end
		local c = player.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or hum.PlatformStand then
			return
		end
		local ctl = getControls()
		if ctl then
			local ok, mv = pcall(function()
				return ctl:GetMoveVector()
			end)
			if ok and mv and mv.Magnitude > 0.01 then
				return -- 기본 이동이 정상 동작 중 → 손대지 않음
			end
			if ctl.GetActiveController and ctl:GetActiveController() == nil then
				return -- 이동 컨트롤이 꺼진 상태(게임이 일부러 막은 경우)는 존중
			end
		end
		hum:Move(Vector3.new(x, 0, -z).Unit, true) -- 카메라 기준 (기본 이동과 같은 방식)
	end)
end

return ImeMove
