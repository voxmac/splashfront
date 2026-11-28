-- 총·크루 장비 모델 만들기 (서버·클라이언트 공용)
-- 1순위: ReplicatedStorage.SplashModels 안의 업로드/임포트된 Blender 모델 (Gun_Pistol, Gear_Helmet …)
--        파트 이름 끝: _Body(스킨 색) / _Accent(팀 색, 네온) / _Metal(금속) / _Anchor(잡는 점) / _Muzzle(총구)
-- 2순위: 같은 구조로 파트를 조립한 내장 대체 모델 (업로드 전에도 게임이 바로 돌아가게)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(script.Parent.Weapons)

local ModelKit = {}

local DARK = Color3.fromRGB(32, 32, 40)
local METAL = Color3.fromRGB(184, 188, 198)

local function kindOf(part)
	local n = part.Name
	for _, k in ipairs({ "Body", "Accent", "Metal", "Anchor", "Muzzle" }) do
		if string.sub(n, -#k) == k then
			return k
		end
	end
	return "Body"
end

local function newPart(model, kind, shape, size, cf)
	local p = Instance.new("Part")
	p.Name = model.Name .. "_" .. kind
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Parent = model
	return p
end

-- 내장 대체 총: 몸통 + 총열 + 잉크 탱크 + 손잡이 (+ 저격 조준경 / 유탄 통)
local function fallbackGun(weaponId)
	local w = Weapons.Get(weaponId)
	local m = Instance.new("Model")
	m.Name = "Gun_" .. w.Id
	local L = w.Size.Z
	local Y = Enum.PartType.Cylinder
	newPart(m, "Anchor", nil, Vector3.new(0.05, 0.05, 0.05), CFrame.new())
	newPart(m, "Body", nil, Vector3.new(w.Size.X, w.Size.Y * 0.55, L * 0.62), CFrame.new(0, 0.05, -L * 0.18))
	newPart(m, "Body", nil, Vector3.new(w.Size.X * 0.75, w.Size.Y * 0.75, 0.26), CFrame.new(0, -0.32, 0.05) * CFrame.Angles(math.rad(18), 0, 0))
	local barrelLen = L * 0.45
	local cyl = CFrame.Angles(0, math.rad(90), 0) -- 원기둥 축(X) → 앞(-Z)
	newPart(m, "Metal", Y, Vector3.new(barrelLen, 0.16, 0.16), CFrame.new(0, 0.1, -L * 0.45 - barrelLen / 2 + 0.1) * cyl)
	if w.Id == "Launcher" then
		newPart(m, "Body", Y, Vector3.new(L * 0.7, 0.62, 0.62), CFrame.new(0, 0.12, -L * 0.3) * cyl)
		newPart(m, "Accent", Y, Vector3.new(0.4, 0.46, 0.46), CFrame.new(0, 0.6, -L * 0.2) * CFrame.Angles(0, 0, math.rad(90)))
	elseif w.Id == "Sniper" then
		newPart(m, "Body", Y, Vector3.new(0.9, 0.22, 0.22), CFrame.new(0, 0.42, -0.45) * cyl)
		newPart(m, "Accent", Y, Vector3.new(0.9, 0.18, 0.18), CFrame.new(0, -0.12, -1.4) * cyl)
	else
		newPart(m, "Accent", Enum.PartType.Ball, Vector3.new(0.32, 0.32, 0.32), CFrame.new(0, 0.34, -0.05))
	end
	newPart(m, "Accent", nil, Vector3.new(w.Size.X + 0.03, 0.05, L * 0.5), CFrame.new(0, -0.1, -L * 0.18))
	newPart(m, "Muzzle", nil, Vector3.new(0.05, 0.05, 0.05), CFrame.new(0, 0.1, -L * 0.45 - barrelLen + 0.1))
	return m
end

local function fallbackHelmet()
	local m = Instance.new("Model")
	m.Name = "Gear_Helmet"
	newPart(m, "Anchor", nil, Vector3.new(0.05, 0.05, 0.05), CFrame.new())
	newPart(m, "Body", Enum.PartType.Ball, Vector3.new(1.45, 1.25, 1.5), CFrame.new(0, 0.18, 0.02))
	newPart(m, "Accent", Enum.PartType.Cylinder, Vector3.new(0.12, 1.5, 1.5), CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(90)))
	for _, x in ipairs({ -0.24, 0.24 }) do
		newPart(m, "Metal", Enum.PartType.Cylinder, Vector3.new(0.14, 0.36, 0.36), CFrame.new(x, 0.08, -0.66) * CFrame.Angles(0, math.rad(90), 0))
		newPart(m, "Accent", Enum.PartType.Cylinder, Vector3.new(0.05, 0.28, 0.28), CFrame.new(x, 0.08, -0.74) * CFrame.Angles(0, math.rad(90), 0))
	end
	return m
end

local function fallbackBackpack()
	local m = Instance.new("Model")
	m.Name = "Gear_Backpack"
	newPart(m, "Anchor", nil, Vector3.new(0.05, 0.05, 0.05), CFrame.new())
	newPart(m, "Body", nil, Vector3.new(0.9, 1.1, 0.18), CFrame.new(0, 0, 0.12))
	newPart(m, "Accent", Enum.PartType.Cylinder, Vector3.new(1.15, 0.72, 0.72), CFrame.new(0, 0.05, 0.5) * CFrame.Angles(0, 0, math.rad(90)))
	for _, y in ipairs({ -0.55, 0.65 }) do
		newPart(m, "Metal", Enum.PartType.Cylinder, Vector3.new(0.1, 0.76, 0.76), CFrame.new(0, y, 0.5) * CFrame.Angles(0, 0, math.rad(90)))
	end
	return m
end

-- 기대 크기(가장 긴 변, 스터드). FBX 단위 차이로 100배 커지거나 작아져도 여기에 맞춰 줄임
local EXPECT = {
	Gun_Pistol = 1.58, Gun_Rifle = 3.35, Gun_SMG = 2.11, Gun_Shotgun = 3.12, Gun_Sniper = 4.31, Gun_Launcher = 1.88,
	Gear_Helmet = 1.58, Gear_Backpack = 1.68,
}

local function source(name)
	local folder = ReplicatedStorage:FindFirstChild("SplashModels")
	local src = folder and folder:FindFirstChild(name)
	if not src then
		return nil, false
	end
	local m = src:Clone()
	-- 손잡이 표식(_Anchor)이 없으면 위치를 맞출 수 없으니 내장 모델 사용
	local hasAnchor = false
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and kindOf(p) == "Anchor" then
			hasAnchor = true
			break
		end
	end
	if not hasAnchor then
		m:Destroy()
		return nil, false
	end
	local ok = pcall(function()
		local size = m:GetExtentsSize()
		local longest = math.max(size.X, size.Y, size.Z)
		local want = EXPECT[name]
		if want and longest > 0 then
			local r = want / longest
			if r < 0.8 or r > 1.25 then
				m:ScaleTo(m:GetScale() * r)
			end
		end
	end)
	-- 총은 앞뒤(Z)가 가장 길어야 정상. 눕거나 돌아가 있으면 내장 모델 사용
	if ok and string.sub(name, 1, 4) == "Gun_" then
		local size = m:GetExtentsSize()
		if size.Z < math.max(size.X, size.Y) * 0.9 then
			ok = false
		end
	end
	if not ok then
		m:Destroy()
		return nil, false
	end
	return m, true
end

-- 크리에이터 상점 총 (ReplicatedStorage.StoreGuns.<StoreModel>): Tool이든 Model이든 메시만 쓰고
-- 손잡이(Handle) 위치를 잡는 점(_Anchor)으로, 손잡이에서 가장 먼 앞쪽 끝을 총구(_Muzzle)로 자동 지정. 원래 질감·색은 그대로
local MUZZLE_HINTS = { "muzzle", "firepoint", "flash", "shoot", "silenc", "suppress", "barrel", "tip" }
local function storeSource(w)
	local folder = ReplicatedStorage:FindFirstChild("StoreGuns")
	local src = folder and w.StoreModel and folder:FindFirstChild(w.StoreModel)
	if not src then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "Gun_" .. w.Id
	local copy = src:Clone()
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D")
			or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("BillboardGui") or d:IsA("ClickDetector") then
			d:Destroy()
		end
	end
	local handle, muzzleHint
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			local n = string.lower(d.Name)
			if (n == "handle" or (n == "grip" and (not handle or string.lower(handle.Name) ~= "handle"))) then
				handle = d
			end
			for _, h in ipairs(MUZZLE_HINTS) do
				if string.find(n, h, 1, true) and not muzzleHint then
					muzzleHint = d
				end
			end
		end
	end
	for _, d in ipairs(copy:GetChildren()) do
		d.Parent = m
	end
	copy:Destroy()
	local parts = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		m:Destroy()
		return nil
	end
	m.PrimaryPart = handle or parts[1]
	-- 크기 맞춤 (가장 긴 변 = 무기 기대 길이)
	pcall(function()
		local size = m:GetExtentsSize()
		local longest = math.max(size.X, size.Y, size.Z)
		local want = w.ModelLength or w.Size.Z
		if longest > 0 then
			m:ScaleTo(m:GetScale() * (want / longest))
		end
	end)
	-- 앞뒤 축: 바운딩 박스의 가장 긴 축, 총구 쪽 = 손잡이에서 먼 끝 (이름 힌트가 있으면 그쪽)
	local bcf, bsize = m:GetBoundingBox()
	local axes = { { bcf.RightVector, bsize.X }, { bcf.UpVector, bsize.Y }, { bcf.LookVector, bsize.Z } }
	table.sort(axes, function(a, b)
		return a[2] > b[2]
	end)
	local fwd, len = axes[1][1], axes[1][2]
	local gripPos = (handle or m.PrimaryPart).Position
	local endA = bcf.Position + fwd * len / 2
	local endB = bcf.Position - fwd * len / 2
	local muzzlePos
	if muzzleHint then
		muzzlePos = muzzleHint.Position
		if (muzzlePos - endA).Magnitude > (muzzlePos - endB).Magnitude then
			fwd = -fwd
		end
		muzzlePos = bcf.Position + fwd * len / 2
	else
		if (gripPos - endA).Magnitude < (gripPos - endB).Magnitude then
			fwd = -fwd
		end
		muzzlePos = bcf.Position + fwd * len / 2
	end
	-- 위쪽: 두 번째로 긴 축 중 원래 모델에서 위를 향한 쪽
	local up = axes[2][1]
	local worldUp = (handle and handle.CFrame.UpVector) or Vector3.yAxis
	if up:Dot(worldUp) < 0 then
		up = -up
	end
	if math.abs(up:Dot(fwd)) > 0.9 then
		up = axes[3][1]
	end
	-- 손잡이 위치는 총 아래쪽 뒤편으로 살짝 (Handle이 없으면 총 길이의 뒤 1/3 지점)
	if not handle then
		gripPos = bcf.Position - fwd * len * 0.18
	end
	local anchorCf = CFrame.lookAt(gripPos, gripPos + fwd, up)
	local anchor = Instance.new("Part")
	anchor.Name = m.Name .. "_Anchor"
	anchor.Size = Vector3.new(0.05, 0.05, 0.05)
	anchor.CFrame = anchorCf
	anchor.Parent = m
	local muzzle = Instance.new("Part")
	muzzle.Name = m.Name .. "_Muzzle"
	muzzle.Size = Vector3.new(0.05, 0.05, 0.05)
	muzzle.CFrame = CFrame.new(muzzlePos)
	muzzle.Parent = m
	for _, p in ipairs(parts) do
		p:SetAttribute("KeepLook", true)
	end
	m.PrimaryPart = anchor
	return m
end

-- 모델을 Anchor 기준으로 정리: PrimaryPart = Anchor, 표식 숨김, 색 입히기
local function finish(model, accentColor, bodyColor, bodyMaterial)
	local anchor, muzzle
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local k = kindOf(p)
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Massless = true
			p:SetAttribute("Kind", k)
			if p:GetAttribute("KeepLook") then
				-- 상점 총: 원래 색·재질 유지 (스킨은 Body만 바꾸지 않음)
				if k == "Anchor" or k == "Muzzle" then
					p.Transparency = 1
				end
				p:SetAttribute("Kind", "Store")
			elseif k == "Anchor" or k == "Muzzle" then
				p.Transparency = 1
				if k == "Anchor" then
					anchor = p
				else
					muzzle = p
				end
			elseif k == "Accent" then
				p.Color = accentColor or Color3.new(1, 1, 1)
				p.Material = Enum.Material.Neon
			elseif k == "Metal" then
				p.Color = METAL
				p.Material = Enum.Material.Metal
			else
				p.Color = bodyColor or DARK
				p.Material = bodyMaterial or Enum.Material.SmoothPlastic
			end
		end
	end
	if anchor then
		model.PrimaryPart = anchor
		-- 가져온 모델의 축이 달라도 총구(_Muzzle) 쪽이 모델의 앞(-Z)이 되도록 기준축을 맞춤
		if muzzle then
			local d = anchor.CFrame:PointToObjectSpace(muzzle.Position)
			local flat = Vector3.new(d.X, 0, d.Z)
			if flat.Magnitude > 0.2 then
				anchor.PivotOffset = CFrame.lookAt(Vector3.zero, flat.Unit)
			end
		end
	end
	return model, muzzle
end

local function mat(name, default)
	local ok, m = pcall(function()
		return Enum.Material[name]
	end)
	return (ok and m) or default
end

-- 무기 스킨(WeaponSkins.Look) 입히기. 상점 실총은 원래 텍스처를 걷어내고 큰 부품=몸체, 작은 부품=금속 색으로
function ModelKit.ApplyLook(model, look)
	if not look then
		return
	end
	local parts = {}
	local biggest, bigVol = nil, 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			table.insert(parts, p)
			local v = p.Size.X * p.Size.Y * p.Size.Z
			if v > bigVol then
				biggest, bigVol = p, v
			end
		end
	end
	local bodyMat = mat(look.BodyMat, Enum.Material.SmoothPlastic)
	local metalMat = mat(look.MetalMat, Enum.Material.Metal)
	for _, p in ipairs(parts) do
		local k = p:GetAttribute("Kind")
		if k == "Store" then
			for _, d in ipairs(p:GetChildren()) do
				if d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then
					d:Destroy()
				end
			end
			if p:IsA("MeshPart") then
				pcall(function()
					p.TextureID = ""
				end)
			end
			local v = p.Size.X * p.Size.Y * p.Size.Z
			local small = v < bigVol * 0.08
			p.Color = small and look.Metal or look.Body
			p.Material = small and metalMat or bodyMat
		elseif k == "Accent" then
			if look.Accent then
				p.Color = look.Accent
			end
		elseif k == "Metal" then
			p.Color = look.Metal
			p.Material = metalMat
		elseif k ~= "Anchor" and k ~= "Muzzle" then
			p.Color = look.Body
			p.Material = bodyMat
		end
	end
	-- 프리미엄 이상: 몸체를 따라 빛나는 라인
	if look.Glow and look.Accent and biggest then
		-- 1인칭 총의 외곽선을 이 색으로 (WeaponController가 읽음)
		model:SetAttribute("SkinOutline", look.Accent)
		local light = Instance.new("PointLight")
		light.Name = "SkinLight"
		light.Color = look.Accent
		light.Range = 4
		light.Brightness = 1.2
		light.Parent = biggest
	end
	-- 얼티밋: 총에서 흩날리는 입자
	if look.Particle and biggest then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "SkinParticles"
		pe.Color = ColorSequence.new(look.Particle, look.Accent or look.Particle)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(0.5, 1)
		pe.Rate = 14
		pe.Speed = NumberRange.new(0.3, 1)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Acceleration = Vector3.new(0, (look.Finisher == "Inferno") and 2 or 0.3, 0)
		pe.Shape = Enum.ParticleEmitterShape.Box
		pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		pe.Parent = biggest
	end
end

-- 택티컬 나이프: 손잡이(고무 그립) + 금속 가드 + 블레이드(끝이 뾰족) + 팀 색 네온 날 라인
-- 손잡이 가운데가 원점(Anchor), 날은 모델의 앞(-Z)
function ModelKit.Knife(accent)
	local m = Instance.new("Model")
	m.Name = "Knife"
	local function kp(name, kind, size, cf, color, mat, cls)
		local p = Instance.new(cls or "Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("Kind", kind)
		p.Parent = m
		return p
	end
	local anchor = kp("Anchor", "Anchor", Vector3.new(0.1, 0.1, 0.1), CFrame.new(), Color3.new(), Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	-- 손잡이 (홈 파인 그립 3마디)
	kp("Grip", "Body", Vector3.new(0.2, 0.26, 0.62), CFrame.new(0, 0, 0.05), Color3.fromRGB(30, 30, 36), Enum.Material.Fabric)
	for i = -1, 1 do
		kp("GripRing", "Accent", Vector3.new(0.21, 0.27, 0.04), CFrame.new(0, 0, 0.05 + i * 0.18), accent, Enum.Material.Neon)
	end
	kp("Pommel", "Metal", Vector3.new(0.24, 0.3, 0.1), CFrame.new(0, 0, 0.4), Color3.fromRGB(150, 155, 168), Enum.Material.Metal)
	-- 가드
	kp("Guard", "Metal", Vector3.new(0.14, 0.5, 0.08), CFrame.new(0, 0.04, -0.3), Color3.fromRGB(150, 155, 168), Enum.Material.Metal)
	-- 블레이드: 몸통 + 뾰족한 끝(쐐기) + 등날
	local steel = Color3.fromRGB(205, 212, 225)
	kp("Blade", "Metal", Vector3.new(0.05, 0.28, 0.78), CFrame.new(0, 0.04, -0.73), steel, Enum.Material.Metal)
	kp("Tip", "Metal", Vector3.new(0.05, 0.28, 0.3), CFrame.new(0, 0.04, -1.27), steel, Enum.Material.Metal, "WedgePart")
	kp("Spine", "Body", Vector3.new(0.07, 0.05, 0.8), CFrame.new(0, 0.18, -0.72), Color3.fromRGB(40, 42, 50), Enum.Material.Metal)
	-- 날 끝선 (팀 색으로 빛남)
	kp("Edge", "Accent", Vector3.new(0.06, 0.035, 0.98), CFrame.new(0, -0.1, -0.82), accent, Enum.Material.Neon)
	m.PrimaryPart = anchor
	return m
end

-- weaponId: "Pistol" …, accent: 팀 색, skin: Cosmetics 아이템(선택), look: 무기별 스킨(WeaponSkins.Look, 있으면 우선)
function ModelKit.Gun(weaponId, accent, skin, skinMaterial, look)
	local w = Weapons.Get(weaponId)
	if w.StoreModel then
		local sm = storeSource(w)
		if sm then
			sm:SetAttribute("Imported", true)
			sm:SetAttribute("StoreGun", true)
			local m, muzzle = finish(sm, accent, nil, nil)
			ModelKit.ApplyLook(m, look)
			return m, muzzle
		end
	end
	local model, imported = source("Gun_" .. weaponId)
	if not model then
		model = fallbackGun(weaponId)
	end
	model:SetAttribute("Imported", imported)
	if look then
		local m, muzzle = finish(model, accent, nil, nil)
		ModelKit.ApplyLook(m, look)
		return m, muzzle
	end
	return finish(model, accent, skin and skin.Color or nil, skinMaterial)
end

-- 상점 총 모델이 실제로 들어 있는지 (없으면 상점에 표시 안 함)
function ModelKit.HasStoreModel(weaponId)
	local w = Weapons.ById[weaponId]
	if not w or not w.StoreModel then
		return true
	end
	local folder = ReplicatedStorage:FindFirstChild("StoreGuns")
	return folder ~= nil and folder:FindFirstChild(w.StoreModel) ~= nil
end

function ModelKit.Helmet(accent)
	local model = source("Gear_Helmet") or fallbackHelmet()
	return finish(model, accent)
end

function ModelKit.Backpack(accent)
	local model = source("Gear_Backpack") or fallbackBackpack()
	return finish(model, accent)
end

-- 팀 보호구 세트: 가슴·등 플레이트(팀 색 띠), 어깨 패드, 무릎 패드, 탄약 벨트
-- 히트박스를 가리지 않게 CanQuery=false (총알은 몸에 맞음)
local ARMOR = Color3.fromRGB(36, 38, 52)
function ModelKit.Armor(character, color)
	local set = Instance.new("Model")
	set.Name = "SF_Armor"
	local function piece(target, size, offset, c, mat)
		if not target then
			return nil
		end
		local p = Instance.new("Part")
		p.Name = "Armor"
		p.Size = size
		p.Color = c
		p.Material = mat or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = target.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = target
		w.Part1 = p
		w.Parent = p
		p.Parent = set
		return p
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso then
		local t = torso.Size
		for _, side in ipairs({ -1, 1 }) do
			local z = side * (t.Z / 2 + 0.09)
			piece(torso, Vector3.new(t.X * 0.82, t.Y * 0.72, 0.2), CFrame.new(0, 0.05, z), ARMOR, Enum.Material.Metal)
			piece(torso, Vector3.new(t.X * 0.84, 0.14, 0.22), CFrame.new(0, 0.18, z + side * 0.02), color, Enum.Material.Neon)
			piece(torso, Vector3.new(t.X * 0.84, 0.08, 0.22), CFrame.new(0, -0.12, z + side * 0.02), color, Enum.Material.Neon)
		end
		-- 목 보호대
		piece(torso, Vector3.new(t.X * 0.55, 0.22, t.Z * 1.05), CFrame.new(0, t.Y / 2 - 0.05, 0), ARMOR, Enum.Material.Metal)
	end
	for _, n in ipairs({ "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" }) do
		local a = character:FindFirstChild(n)
		if a then
			local s = a.Size
			piece(a, Vector3.new(s.X * 1.2, 0.36, s.Z * 1.2), CFrame.new(0, s.Y / 2 - 0.12, 0), color, Enum.Material.SmoothPlastic)
			piece(a, Vector3.new(s.X * 1.24, 0.1, s.Z * 1.24), CFrame.new(0, s.Y / 2 - 0.3, 0), ARMOR, Enum.Material.Metal)
		end
	end
	for _, n in ipairs({ "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local l = character:FindFirstChild(n)
		if l then
			local s = l.Size
			local y = (string.find(n, "Lower") and (s.Y / 2 - 0.25)) or 0
			piece(l, Vector3.new(s.X * 0.8, 0.5, 0.22), CFrame.new(0, y, -(s.Z / 2 + 0.06)), ARMOR, Enum.Material.Metal)
			piece(l, Vector3.new(s.X * 0.5, 0.1, 0.24), CFrame.new(0, y, -(s.Z / 2 + 0.08)), color, Enum.Material.Neon)
		end
	end
	-- 장갑 · 부츠 · 팔꿈치 패드
	for _, n in ipairs({ "LeftHand", "RightHand" }) do
		local h = character:FindFirstChild(n)
		if h then
			local sz = h.Size
			piece(h, sz * 1.12, CFrame.new(), Color3.fromRGB(30, 30, 38), Enum.Material.Fabric)
			piece(h, Vector3.new(sz.X * 1.16, 0.08, sz.Z * 1.16), CFrame.new(0, sz.Y / 2 - 0.02, 0), color, Enum.Material.Neon)
		end
	end
	for _, n in ipairs({ "LeftFoot", "RightFoot" }) do
		local f = character:FindFirstChild(n)
		if f then
			local sz = f.Size
			piece(f, Vector3.new(sz.X * 1.15, sz.Y * 1.25, sz.Z * 1.18), CFrame.new(0, 0.02, -0.03), Color3.fromRGB(40, 38, 50), Enum.Material.Leather)
			piece(f, Vector3.new(sz.X * 1.18, 0.1, sz.Z * 1.2), CFrame.new(0, sz.Y * 0.62, -0.03), color, Enum.Material.Neon)
			piece(f, Vector3.new(sz.X * 1.17, 0.12, sz.Z * 1.21), CFrame.new(0, -sz.Y * 0.55, -0.03), Color3.fromRGB(235, 235, 240), Enum.Material.SmoothPlastic)
		end
	end
	for _, n in ipairs({ "LeftLowerArm", "RightLowerArm" }) do
		local a = character:FindFirstChild(n)
		if a then
			local sz = a.Size
			piece(a, Vector3.new(sz.X * 1.15, 0.32, sz.Z * 1.15), CFrame.new(0, sz.Y / 2 - 0.12, 0), ARMOR, Enum.Material.Metal)
		end
	end
	local hip = character:FindFirstChild("LowerTorso") or torso
	if hip then
		local s = hip.Size
		local y = (hip.Name == "LowerTorso") and 0.1 or -s.Y / 2 + 0.15
		piece(hip, Vector3.new(s.X * 1.04, 0.24, s.Z * 1.1), CFrame.new(0, y, 0), Color3.fromRGB(70, 56, 40), Enum.Material.Leather)
		for _, sx in ipairs({ -1, 1 }) do
			local c = piece(hip, Vector3.new(0.5, 0.34, 0.34), CFrame.new(sx * (s.X / 2 + 0.05), y, -0.15) * CFrame.Angles(0, 0, math.rad(90)), color,
				Enum.Material.Neon)
			if c then
				c.Shape = Enum.PartType.Cylinder
			end
		end
	end
	set.Parent = character
	return set
end

-- 모델을 대상 파트에 용접 (Anchor가 target.CFrame * offset 에 오도록)
function ModelKit.WeldTo(model, target, offset)
	model:PivotTo(target.CFrame * offset)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = target
			w.Part1 = p
			w.Parent = p
		end
	end
	model.Parent = target.Parent
	return model
end

-- 팀 색/스킨 다시 칠하기
function ModelKit.Recolor(model, accent, bodyColor, bodyMaterial)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local k = p:GetAttribute("Kind")
			if k == "Accent" then
				p.Color = accent
			elseif k == "Body" and bodyColor then
				p.Color = bodyColor
				p.Material = bodyMaterial or p.Material
			end
		end
	end
end

------------------------------------------------------------------------
-- 미션 보상 아이템 3D 모델 (카툰풍: 둥근 모서리·굵은 색 띠·네온 포인트)
-- 앞(-Z) 기준, 손잡이/중심이 원점. HUD 아이콘(ViewportFrame)과 몸에 차는 제트팩에 씀
------------------------------------------------------------------------
local function ip(m, shape, size, cf, color, mat, name)
	local p = Instance.new("Part")
	p.Name = name or "Item"
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end
local CYL, BALL, BLOCK = Enum.PartType.Cylinder, Enum.PartType.Ball, Enum.PartType.Block
local UPR = CFrame.Angles(0, 0, math.rad(90)) -- 원기둥 세우기
local FWD = CFrame.Angles(0, math.rad(90), 0) -- 원기둥 앞뒤로 눕히기

local ITEM_BUILDERS = {}

ITEM_BUILDERS.Jetpack = function(m, accent)
	local white = Color3.fromRGB(236, 238, 246)
	ip(m, BLOCK, Vector3.new(1.9, 1.7, 0.35), CFrame.new(0, 0, 0), Color3.fromRGB(50, 52, 66), Enum.Material.Metal, "Plate")
	for _, x in ipairs({ -0.55, 0.55 }) do
		ip(m, CYL, Vector3.new(1.7, 0.9, 0.9), CFrame.new(x, 0, 0.55) * UPR, white, Enum.Material.SmoothPlastic, "Tank")
		ip(m, BALL, Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, 0.85, 0.55), white, Enum.Material.SmoothPlastic, "Cap")
		ip(m, CYL, Vector3.new(0.18, 0.95, 0.95), CFrame.new(x, 0.35, 0.55) * UPR, accent, Enum.Material.Neon, "Stripe")
		ip(m, CYL, Vector3.new(0.18, 0.95, 0.95), CFrame.new(x, -0.3, 0.55) * UPR, accent, Enum.Material.Neon, "Stripe")
		local n = ip(m, CYL, Vector3.new(0.45, 0.6, 0.6), CFrame.new(x, -1.05, 0.55) * UPR, Color3.fromRGB(60, 60, 70), Enum.Material.Metal, "Nozzle")
		local a = Instance.new("Attachment")
		a.Name = "Flame"
		a.Position = Vector3.new(-0.3, 0, 0) -- 원기둥 로컬 -X = 아래
		a.Parent = n
	end
	ip(m, BLOCK, Vector3.new(1.4, 0.25, 0.5), CFrame.new(0, 0.6, 0.3), accent, Enum.Material.SmoothPlastic, "Strap")
end

ITEM_BUILDERS.Shield = function(m, accent)
	local blue = Color3.fromRGB(70, 170, 255)
	ip(m, CYL, Vector3.new(0.35, 2.2, 2.2), CFrame.new(0, 0, 0) * FWD, Color3.fromRGB(230, 236, 250), Enum.Material.SmoothPlastic, "Rim")
	ip(m, CYL, Vector3.new(0.45, 1.8, 1.8), CFrame.new(0, 0, -0.02) * FWD, blue, Enum.Material.SmoothPlastic, "Face")
	ip(m, BALL, Vector3.new(1.3, 1.3, 0.6), CFrame.new(0, 0, -0.2), Color3.fromRGB(140, 220, 255), Enum.Material.Glass, "Dome")
	ip(m, BLOCK, Vector3.new(0.25, 0.9, 0.2), CFrame.new(0, 0.05, -0.5), Color3.new(1, 1, 1), Enum.Material.Neon, "Cross")
	ip(m, BLOCK, Vector3.new(0.9, 0.25, 0.2), CFrame.new(0, 0.05, -0.5), Color3.new(1, 1, 1), Enum.Material.Neon, "Cross")
end

ITEM_BUILDERS.Smoke = function(m, accent)
	local grey = Color3.fromRGB(110, 120, 128)
	ip(m, CYL, Vector3.new(1.3, 0.9, 0.9), CFrame.new(0, 0, 0) * UPR, grey, Enum.Material.SmoothPlastic, "Body")
	ip(m, CYL, Vector3.new(0.3, 0.95, 0.95), CFrame.new(0, 0.1, 0) * UPR, Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, "Band")
	ip(m, CYL, Vector3.new(0.2, 0.96, 0.96), CFrame.new(0, -0.35, 0) * UPR, Color3.fromRGB(255, 200, 40), Enum.Material.Neon, "Band")
	ip(m, CYL, Vector3.new(0.3, 0.55, 0.55), CFrame.new(0, 0.8, 0) * UPR, Color3.fromRGB(60, 62, 70), Enum.Material.Metal, "Top")
	ip(m, BLOCK, Vector3.new(0.18, 0.9, 0.3), CFrame.new(0.4, 0.45, 0) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(70, 72, 80), Enum.Material.Metal, "Lever")
	ip(m, CYL, Vector3.new(0.08, 0.45, 0.45), CFrame.new(-0.35, 0.95, 0) * FWD, Color3.fromRGB(220, 220, 230), Enum.Material.Metal, "Pin")
end

local function scope(m, accent, label)
	local black = Color3.fromRGB(34, 34, 42)
	ip(m, CYL, Vector3.new(2.6, 0.55, 0.55), CFrame.new(0, 0, 0) * FWD, black, Enum.Material.SmoothPlastic, "Tube")
	ip(m, CYL, Vector3.new(0.5, 0.8, 0.8), CFrame.new(0, 0, -1.2) * FWD, black, Enum.Material.SmoothPlastic, "Bell")
	ip(m, CYL, Vector3.new(0.45, 0.68, 0.68), CFrame.new(0, 0, 1.15) * FWD, black, Enum.Material.SmoothPlastic, "Eye")
	ip(m, CYL, Vector3.new(0.06, 0.7, 0.7), CFrame.new(0, 0, -1.46) * FWD, Color3.fromRGB(120, 200, 255), Enum.Material.Neon, "Lens")
	for _, z in ipairs({ -0.5, 0.5 }) do
		ip(m, CYL, Vector3.new(0.14, 0.62, 0.62), CFrame.new(0, 0, z) * FWD, accent, Enum.Material.Neon, "Ring")
		ip(m, BLOCK, Vector3.new(0.3, 0.45, 0.3), CFrame.new(0, -0.4, z), Color3.fromRGB(70, 70, 80), Enum.Material.Metal, "Mount")
	end
	ip(m, CYL, Vector3.new(0.3, 0.32, 0.32), CFrame.new(0, 0.38, 0) * UPR, accent, Enum.Material.SmoothPlastic, "Turret")
end
ITEM_BUILDERS.Zoom3 = function(m)
	scope(m, Color3.fromRGB(80, 230, 120))
end
ITEM_BUILDERS.Zoom6 = function(m)
	scope(m, Color3.fromRGB(255, 80, 90))
end

local GOLD = Color3.fromRGB(255, 196, 40)
function ModelKit.Item(id, accent)
	accent = accent or Color3.fromRGB(0, 200, 255)
	if id == "Golden" then
		local gun = ModelKit.Gun("Pistol", GOLD, { Color = GOLD }, Enum.Material.Foil)
		for _, p in ipairs(gun:GetDescendants()) do
			if p:IsA("BasePart") and p:GetAttribute("Kind") == "Metal" then
				p.Color = Color3.fromRGB(255, 225, 120)
				p.Material = Enum.Material.Foil
			end
		end
		return gun
	end
	local m = Instance.new("Model")
	m.Name = "Item_" .. tostring(id)
	local b = ITEM_BUILDERS[id]
	if b then
		b(m, accent)
	else
		ip(m, BALL, Vector3.new(1, 1, 1), CFrame.new(), accent, Enum.Material.Neon)
	end
	return m
end

-- 황금총 상태로 손에 든 총을 금색으로 (해제하면 팀 색으로 되돌림)
function ModelKit.SetGolden(gun, on, accent)
	for _, p in ipairs(gun:GetDescendants()) do
		if p:IsA("BasePart") then
			local k = p:GetAttribute("Kind")
			if k == "Body" or k == "Metal" or k == "Accent" then
				if on then
					if p:GetAttribute("OrigColor") == nil then
						p:SetAttribute("OrigColor", p.Color)
						p:SetAttribute("OrigMat", p.Material.Name)
					end
					p.Color = (k == "Accent") and Color3.fromRGB(255, 240, 160) or GOLD
					p.Material = (k == "Accent") and Enum.Material.Neon or Enum.Material.Foil
				elseif p:GetAttribute("OrigColor") ~= nil then
					p.Color = p:GetAttribute("OrigColor")
					p.Material = Enum.Material[p:GetAttribute("OrigMat")] or p.Material
					if k == "Accent" and accent then
						p.Color = accent
					end
				end
			end
		end
	end
end

return ModelKit