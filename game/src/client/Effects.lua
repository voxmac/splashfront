-- 시각/청각 효과: 트레이서, 착탄 스플래시, 크로마 봄, 처치 이펙트, 데미지 숫자
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local SoundBank = require(script.Parent:WaitForChild("SoundBank"))
local CharacterPose = require(script.Parent:WaitForChild("CharacterPose"))

local player = Players.LocalPlayer
local Effects = {}

local function folder()
	local f = workspace:FindFirstChild("ClientFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ClientFX"
		f.Parent = workspace
	end
	return f
end

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder()
	return p
end

function Effects.Sound(id, position, volume, pitch)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	if position then
		local a = fxPart({ Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, Position = position })
		s.Parent = a
		s:Play()
		Debris:AddItem(a, 2)
	else
		s.Parent = workspace.CurrentCamera
		s:Play()
		Debris:AddItem(s, 2)
	end
end

function Effects.Tracer(from, to, color, width)
	local dist = (to - from).Magnitude
	if dist < 0.5 then
		return
	end
	local p = fxPart({
		Size = Vector3.new(width or 0.18, width or 0.18, dist), Color = color,
		CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2), Transparency = 0.1,
	})
	TweenService:Create(p, TweenInfo.new(0.12), { Transparency = 1, Size = Vector3.new(0.02, 0.02, dist) }):Play()
	Debris:AddItem(p, 0.2)
	Effects.Splash(to, color, 1)
end

function Effects.Splash(pos, color, scale)
	scale = scale or 1
	local blob = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6 * scale, Color = color, Position = pos })
	TweenService:Create(blob, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * 2.4 * scale, Transparency = 1 }):Play()
	Debris:AddItem(blob, 0.3)
	for _ = 1, math.floor(3 * scale) do
		local drop = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, Color = color, Position = pos })
		local off = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5) * 4 * scale
		TweenService:Create(drop, TweenInfo.new(0.3), { Position = pos + off, Transparency = 1 }):Play()
		Debris:AddItem(drop, 0.35)
	end
end

function Effects.Muzzle(cf, color)
	local p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = color, CFrame = cf })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Brightness = 4
	light.Parent = p
	TweenService:Create(p, TweenInfo.new(0.06), { Size = Vector3.one * 1.1, Transparency = 1 }):Play()
	Debris:AddItem(p, 0.08)
end

function Effects.Bomb(from, to, color, radius)
	local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Color = color, Position = from })
	local t0 = os.clock()
	local dur = 0.7
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local a = math.min(1, (os.clock() - t0) / dur)
		local p = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * 10, 0)
		ball.Position = p
		if a >= 1 then
			conn:Disconnect()
			ball:Destroy()
			local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2, 2), Color = color,
				CFrame = CFrame.new(to + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
			TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 }):Play()
			Debris:AddItem(ring, 0.4)
			Effects.Splash(to + Vector3.new(0, 1, 0), color, 4)
			local cam = workspace.CurrentCamera
			if cam and (cam.CFrame.Position - to).Magnitude < radius * 2.5 then
				Effects.Shake(0.5)
			end
		end
	end)
end

-- 처치 이펙트 (크로마 크레이트 아이템)
function Effects.KillEffect(kind, pos, color)
	if not pos then
		return
	end
	if kind == "Confetti" then
		for _ = 1, 24 do
			local c = Color3.fromHSV(math.random(), 0.8, 1)
			local p = fxPart({ Size = Vector3.new(0.4, 0.05, 0.25), Color = c, Position = pos })
			local off = Vector3.new(math.random() - 0.5, math.random() * 1.2, math.random() - 0.5) * 10
			TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = pos + off,
				Orientation = Vector3.new(math.random(0, 360), math.random(0, 360), 0), Transparency = 1 }):Play()
			Debris:AddItem(p, 1)
		end
	elseif kind == "Smoke" then
		for i = 1, 6 do
			local p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = color, Material = Enum.Material.SmoothPlastic,
				Transparency = 0.3, Position = pos + Vector3.new(math.random() - 0.5, i * 0.4, math.random() - 0.5) * 2 })
			TweenService:Create(p, TweenInfo.new(1.4), { Size = Vector3.one * 7, Transparency = 1, Position = p.Position + Vector3.new(0, 4, 0) }):Play()
			Debris:AddItem(p, 1.5)
		end
	elseif kind == "Starburst" then
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2
			local p = fxPart({ Size = Vector3.new(0.3, 0.3, 3), Color = color, CFrame = CFrame.lookAt(pos, pos + Vector3.new(math.cos(a), 0.4, math.sin(a))) })
			TweenService:Create(p, TweenInfo.new(0.5), { CFrame = p.CFrame * CFrame.new(0, 0, -6), Transparency = 1 }):Play()
			Debris:AddItem(p, 0.55)
		end
		Effects.Splash(pos, Color3.new(1, 1, 1), 2)
	elseif kind == "Rainbow" then
		for i = 1, 7 do
			local c = Color3.fromHSV(i / 7, 0.9, 1)
			local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1, 1), Color = c,
				CFrame = CFrame.new(pos + Vector3.new(0, i * 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
			TweenService:Create(ring, TweenInfo.new(0.6 + i * 0.05, Enum.EasingStyle.Quad),
				{ Size = Vector3.new(0.3, 10 + i * 2, 10 + i * 2), Transparency = 1 }):Play()
			Debris:AddItem(ring, 1)
		end
	else
		Effects.Splash(pos, color, 3)
	end
end

function Effects.DamageNumber(pos, amount, head, killed)
	local a = fxPart({ Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, Position = pos })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(80, 40)
	bb.AlwaysOnTop = true
	bb.Adornee = a
	bb.Parent = a
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = tostring(amount)
	t.TextColor3 = killed and Color3.fromRGB(255, 70, 70) or (head and Color3.fromRGB(255, 215, 40) or Color3.new(1, 1, 1))
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
	TweenService:Create(a, TweenInfo.new(0.6), { Position = pos + Vector3.new(math.random() - 0.5, 2.5, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(a, 0.7)
end

-- 카메라 흔들림 (WeaponController가 매 프레임 Effects.ShakeOffset()을 적용)
local shake = 0
function Effects.Shake(amount)
	shake = math.max(shake, amount)
end
function Effects.ShakeOffset(dt)
	if shake <= 0.001 then
		shake = 0
		return CFrame.new()
	end
	local s = shake
	shake = shake * math.exp(-12 * dt)
	return CFrame.Angles(math.rad((math.random() - 0.5) * s * 1.6), math.rad((math.random() - 0.5) * s * 1.6), 0)
end

-- 서버 FX 이벤트 처리
function Effects.OnFX(kind, d)
	if kind == "Tracer" then
		if d.Shooter == player then
			return -- 내 사격은 즉시 로컬로 그렸음
		end
		local from = d.From
		if d.Model then
			-- 손에 든 총의 총구에서 나가도록 + 발사 반동 자세
			CharacterPose.Kick(d.Model, 1.5)
			local gun = d.Model:FindFirstChild("SF_Gun")
			local muzzle = nil
			if gun then
				for _, p in ipairs(gun:GetDescendants()) do
					if p:IsA("BasePart") and p:GetAttribute("Kind") == "Muzzle" then
						muzzle = p
					end
				end
			end
			local hand = muzzle or d.Model:FindFirstChild("RightHand")
			if hand then
				from = hand.Position
			end
		end
		for _, to in ipairs(d.To) do
			Effects.Tracer(from, to, d.Color, d.Weapon == "Sniper" and 0.35 or 0.18)
		end
		SoundBank.Play("fire_" .. string.lower(d.Weapon or "pistol"), d.From, 0.55)
	elseif kind == "Bomb" then
		Effects.Bomb(d.From, d.To, d.Color, d.Radius)
		SoundBank.Play("special_throw", d.From, 0.7)
		task.delay(0.7, function()
			SoundBank.Play("special_boom", d.To, 1)
		end)
	elseif kind == "Kill" then
		if d.Pos then
			Effects.KillEffect(d.Effect, d.Pos, d.KillerColor or d.VictimColor)
		end
	end
end

return Effects
