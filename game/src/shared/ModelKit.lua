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
			if k == "Anchor" or k == "Muzzle" then
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
	end
	return model, muzzle
end

-- weaponId: "Pistol" …, accent: 팀 색, skin: Cosmetics 아이템(선택)
function ModelKit.Gun(weaponId, accent, skin, skinMaterial)
	local model, imported = source("Gun_" .. weaponId)
	if not model then
		model = fallbackGun(weaponId)
	end
	model:SetAttribute("Imported", imported)
	return finish(model, accent, skin and skin.Color or nil, skinMaterial)
end

function ModelKit.Helmet(accent)
	local model = source("Gear_Helmet") or fallbackHelmet()
	return finish(model, accent)
end

function ModelKit.Backpack(accent)
	local model = source("Gear_Backpack") or fallbackBackpack()
	return finish(model, accent)
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

return ModelKit
