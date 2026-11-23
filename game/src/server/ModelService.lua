-- 업로드된 Blender 모델(AssetIds.Models)을 서버 시작 때 불러와 ReplicatedStorage.SplashModels에 둠
-- Studio 3D 가져오기로 직접 넣은 모델이 이미 SplashModels에 있으면 그대로 씀
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetIds = require(ReplicatedStorage.Shared.AssetIds)

local ModelService = {}

local function hasPart(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			return true
		end
	end
	return false
end

function ModelService.Load()
	local folder = ReplicatedStorage:FindFirstChild("SplashModels")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SplashModels"
		folder.Parent = ReplicatedStorage
	end
	local loaded = 0
	for name, id in pairs(AssetIds.Models) do
		if id ~= 0 and not folder:FindFirstChild(name) then
			local ok, asset = pcall(function()
				return InsertService:LoadAsset(id)
			end)
			if ok and asset then
				-- LoadAsset은 Model 안에 업로드된 모델을 한 겹 더 감싸서 줌
				local model = asset:FindFirstChildWhichIsA("Model") or asset
				if hasPart(model) then
					model.Name = name
					model.Parent = folder
					loaded = loaded + 1
				end
				if model ~= asset then
					asset:Destroy()
				end
			else
				warn("[SplashFront] 모델 불러오기 실패:", name, id, asset)
			end
		end
	end
	print("[SplashFront] 모델", loaded, "개 로드 (없는 모델은 내장 대체 모델 사용)")
end

return ModelService
