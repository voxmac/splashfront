-- 업로드한 이미지(데칼)를 게임에 적용
-- 1) 데칼 ID → 실제 이미지 주소 (InsertService로 데칼을 불러와 Texture 속성을 읽음)
-- 2) ReplicatedStorage.Images 폴더 속성으로 공유 (클라이언트 HUD 아이콘: "icon_coin" 등)
-- 3) 맵 표면에 Texture(타일 반복) 입히기 — 판정용 모양은 그대로
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetIds = require(ReplicatedStorage.Shared.AssetIds)

local ImageService = {}

local folder = Instance.new("Folder")
folder.Name = "Images"
folder.Parent = ReplicatedStorage
local urls = {}  -- "tex_floor_tile" -> "http://www.roblox.com/asset/?id=..."

local function resolve(decalId)
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(decalId)
	end)
	if not ok or not asset then
		warn("[SplashFront] 이미지 불러오기 실패:", decalId, asset)
		return nil
	end
	local d = asset:FindFirstChildWhichIsA("Decal", true) or asset:FindFirstChildWhichIsA("Texture", true)
	local url = d and d.Texture
	asset:Destroy()
	if url and url ~= "" then
		return url
	end
	return nil
end

function ImageService.Load()
	local n = 0
	for group, list in pairs({ tex = AssetIds.Textures or {}, icon = AssetIds.Icons or {} }) do
		for name, id in pairs(list) do
			if id ~= 0 then
				local url = resolve(id)
				if url then
					urls[group .. "_" .. name] = url
					folder:SetAttribute(group .. "_" .. name, url)
					n = n + 1
				end
			end
		end
	end
	print("[SplashFront] 이미지", n, "개 준비 (없는 이미지는 단색·이모지로 대체)")
end

function ImageService.Url(key)
	return urls[key]
end

------------------------------------------------------------------------
-- 맵 표면 텍스처
------------------------------------------------------------------------
local F = Enum.NormalId
local SIDES = { F.Front, F.Back, F.Left, F.Right }
local ALL = { F.Top, F.Bottom, F.Front, F.Back, F.Left, F.Right }

-- 이름 → { 텍스처, 면 목록, 타일 크기(U, V), 색 입히기 여부 }
local RULES = {
	Floor = { "floor_tile", { F.Top }, 8, 8 },
	Platform = { { "floor_tile", { F.Top }, 8, 8 }, { "wall_panel", SIDES, 8, 8 } },
	MidTower = { { "floor_tile", { F.Top }, 8, 8 }, { "wall_panel", SIDES, 24, 24 } },
	SpawnTower = { { "floor_tile", { F.Top }, 8, 8 }, { "wall_panel", SIDES, 24, 24 } },
	WarehouseRoof = { "floor_tile", { F.Top }, 8, 8 },
	Wall = { "wall_panel", { F.Top, F.Front, F.Back, F.Left, F.Right }, 8, 8 },
	WarehouseWall = { "wall_panel", { F.Top, F.Front, F.Back, F.Left, F.Right }, 8, 8 },
	Boundary = { "wall_panel", SIDES, 8, 8 },
	SpawnWall = { "wall_panel", SIDES, 8, 8 },
	Parapet = { "wall_panel", { F.Top, F.Front, F.Back, F.Left, F.Right }, 6, 6 },
	Lintel = { "wall_panel", SIDES, 8, 8 },
	WallSill = { "hazard", { F.Top, F.Front, F.Back }, 3, 3 },
	Crate = { "crate_wood", ALL, 8, 3 },
	Container = { "container_rib", SIDES, 12.8, 7, true },
	Ramp = { "ramp_plate", { F.Top }, 6, 6 },
	Stage = { "ramp_plate", { F.Top }, 8, 8, true },
}

local function apply(part, texName, faces, u, v, tint)
	local url = urls["tex_" .. texName]
	if not url then
		return
	end
	for _, face in ipairs(faces) do
		local t = Instance.new("Texture")
		t.Name = "SF_Tex"
		t.Texture = url
		t.Face = face
		t.StudsPerTileU = u
		t.StudsPerTileV = v
		if tint then
			t.Color3 = part.Color
		end
		t.Parent = part
	end
end

function ImageService.ApplyTextures(root, overrides)
	if not next(urls) then
		return
	end
	for _, p in ipairs(root:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Cell" and p.Transparency < 0.5 then
			local rule = (overrides and overrides[p.Name]) or RULES[p.Name]
			if rule then
				if type(rule[1]) == "table" then
					for _, r in ipairs(rule) do
						apply(p, r[1], r[2], r[3], r[4], r[5])
					end
				else
					apply(p, rule[1], rule[2], rule[3], rule[4], rule[5])
				end
			end
		end
	end
end

-- 로비: 어두운 바닥에 타일 무늬를 보라빛으로 물들여 깔기
ImageService.LobbyRules = {
	Floor = { "floor_tile", { F.Top }, 10, 10, true },
	Stage = { "ramp_plate", { F.Top }, 6, 6, true },
}

return ImageService
