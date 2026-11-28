-- 시각/청각 효과: 트레이서, 착탄 스플래쉬, 크로마 봄, 처치 이펙트, 데미지 숫자
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local SoundBank = require(script.Parent:WaitForChild("SoundBank"))
local CharacterPose = require(script.Parent:WaitForChild("CharacterPose"))
local PaintVisual = require(script.Parent:WaitForChild("PaintVisual"))


local player = Players.LocalPlayer
local Effects = {}
function Effects.WallSplat(inst, pos, normal, color)
	PaintVisual.WallSplat(inst, pos, normal, color)
end

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

-- 파티클 한 번 터뜨리기 (잉크 방울은 포물선으로 떨어지고, 연기는 퍼지며 사라짐)
local function burst(pos, color, count, speed, size, life, gravity, lightEmission, transparency)
	local holder = fxPart({ Size = Vector3.one * 0.1, Position = pos, Transparency = 1 })
	local att = Instance.new("Attachment")
	att.Parent = holder
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = lightEmission or 0.15
	pe.LightInfluence = 0.6
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.3) })
	pe.Transparency = transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(life * 0.6, life)
	pe.Speed = NumberRange.new(speed * 0.5, speed)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, -(gravity or 0), 0)
	pe.Drag = 2
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(count)
	Debris:AddItem(holder, life + 0.1)
end
Effects.Burst = burst

function Effects.Splash(pos, color, scale)
	scale = scale or 1
	-- 잉크 방울 + 옅은 물보라
	burst(pos, color, math.floor(10 * scale), 16 * scale, 0.32 * scale, 0.55, 45)
	burst(pos, color:Lerp(Color3.new(1, 1, 1), 0.35), math.floor(4 * scale), 4, 1.4 * scale, 0.35, 0, 0.1,
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }))
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
	-- 십자 섬광 + 옅은 총구 연기
	for _, rot in ipairs({ 0, 90 }) do
		local f = fxPart({ Size = Vector3.new(0.08, 1.2, 0.08), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon,
			CFrame = cf * CFrame.Angles(0, 0, math.rad(rot + math.random(-20, 20))) })
		TweenService:Create(f, TweenInfo.new(0.05), { Transparency = 1, Size = Vector3.new(0.02, 1.8, 0.02) }):Play()
		Debris:AddItem(f, 0.07)
	end
	if math.random() < 0.5 then
		burst(cf.Position, Color3.fromRGB(190, 190, 195), 2, 2, 0.6, 0.6, -2, 0,
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }))
	end
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
	elseif kind == "Sparks" then
		-- 스틸 스파크: 금속 불꽃이 사방으로 튀고 떨어짐
		for _ = 1, 22 do
			local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
			local p = fxPart({ Size = Vector3.new(0.08, 0.08, 0.9), Color = Color3.fromRGB(255, 230, 170), CFrame = CFrame.lookAt(pos, pos + dir) })
			TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(pos + dir * 6 - Vector3.new(0, 1.5, 0), pos + dir * 7),
				Transparency = 1 }):Play()
			Debris:AddItem(p, 0.5)
		end
		local flash = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.5, Color = Color3.fromRGB(220, 230, 255), Position = pos })
		TweenService:Create(flash, TweenInfo.new(0.2), { Size = Vector3.one * 4, Transparency = 1 }):Play()
		Debris:AddItem(flash, 0.25)
	elseif kind == "Dust" then
		-- 모래 폭풍: 바닥에서 소용돌이치며 퍼지는 모래 먼지
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			local p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, Color = Color3.fromRGB(214, 186, 140), Material = Enum.Material.Sand,
				Transparency = 0.25, Position = pos + Vector3.new(0, 0.3, 0) })
			TweenService:Create(p, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { Position = pos + Vector3.new(math.cos(a) * 5, 1.5 + (i % 3), math.sin(a) * 5),
				Size = Vector3.one * 4, Transparency = 1 }):Play()
			Debris:AddItem(p, 1.2)
		end
	elseif kind == "GoldShower" then
		-- 골드 샤워: 금빛 조각이 솟았다가 쏟아짐
		for _ = 1, 20 do
			local p = fxPart({ Size = Vector3.new(0.35, 0.06, 0.35), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Foil, Position = pos })
			local up = pos + Vector3.new((math.random() - 0.5) * 4, 3 + math.random() * 2, (math.random() - 0.5) * 4)
			local t1 = TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = up,
				Orientation = Vector3.new(math.random(0, 360), math.random(0, 360), 0) })
			t1:Play()
			t1.Completed:Connect(function()
				TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = up + Vector3.new(0, -4, 0),
					Transparency = 1 }):Play()
			end)
			Debris:AddItem(p, 1.1)
		end
	elseif kind == "Petals" then
		-- 벚꽃 흩날림: 분홍 꽃잎이 회전하며 천천히 떨어짐
		for _ = 1, 26 do
			local c = (math.random() < 0.5) and Color3.fromRGB(255, 180, 210) or Color3.fromRGB(255, 225, 238)
			local p = fxPart({ Size = Vector3.new(0.35, 0.04, 0.22), Color = c, Material = Enum.Material.SmoothPlastic,
				Position = pos + Vector3.new((math.random() - 0.5) * 2, 2 + math.random() * 2, (math.random() - 0.5) * 2) })
			TweenService:Create(p, TweenInfo.new(1.4 + math.random() * 0.5, Enum.EasingStyle.Sine), {
				Position = p.Position + Vector3.new((math.random() - 0.5) * 7, -2.5, (math.random() - 0.5) * 7),
				Orientation = Vector3.new(math.random(0, 720), math.random(0, 720), math.random(0, 360)), Transparency = 1 }):Play()
			Debris:AddItem(p, 2)
		end
	elseif kind == "NeonRings" then
		-- 네온 펄스 링: 바닥을 따라 퍼지는 네온 고리 3겹
		for i = 1, 3 do
			local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1, 1), Color = (i == 2) and Color3.fromRGB(40, 230, 255)
				or Color3.fromRGB(255, 40, 200), Transparency = 0.1, CFrame = CFrame.new(pos + Vector3.new(0, 0.2 + i * 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
			task.delay((i - 1) * 0.1, function()
				TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { Size = Vector3.new(0.15, 12, 12), Transparency = 1 }):Play()
			end)
			Debris:AddItem(ring, 0.9)
		end
	elseif kind == "IceShatter" then
		-- 얼음 파편: 얼음 결정이 솟았다 깨지며 흩어짐
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			local shard = fxPart({ Size = Vector3.new(0.5, 2.2, 0.5), Color = Color3.fromRGB(180, 230, 255), Material = Enum.Material.Ice, Transparency = 0.1,
				CFrame = CFrame.new(pos) * CFrame.Angles(math.cos(a) * 0.5, 0, math.sin(a) * 0.5) })
			TweenService:Create(shard, TweenInfo.new(0.6, Enum.EasingStyle.Back), { CFrame = shard.CFrame * CFrame.new(math.cos(a) * 3, 1.5, math.sin(a) * 3)
				* CFrame.Angles(math.random(), math.random(), 0), Transparency = 1 }):Play()
			Debris:AddItem(shard, 0.65)
		end
		local frost = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = Color3.fromRGB(230, 248, 255), Material = Enum.Material.Ice,
			Transparency = 0.3, Position = pos })
		TweenService:Create(frost, TweenInfo.new(0.5), { Size = Vector3.one * 6, Transparency = 1 }):Play()
		Debris:AddItem(frost, 0.55)
	elseif kind == "Inferno" then
		-- 얼티밋 스킨 피니셔: 솟구치는 화염 기둥 + 불씨
		for i = 1, 10 do
			local h = 1 + i * 0.9
			local p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * (2.6 - i * 0.15), Color = Color3.fromRGB(255, 120 + i * 10, 30),
				Material = Enum.Material.Neon, Transparency = 0.15, Position = pos + Vector3.new(0, 0.3, 0) })
			TweenService:Create(p, TweenInfo.new(0.35 + i * 0.04, Enum.EasingStyle.Quad), { Position = pos + Vector3.new((math.random() - 0.5) * 1.2, h, (math.random() - 0.5) * 1.2),
				Size = Vector3.one * 0.3, Transparency = 1 }):Play()
			Debris:AddItem(p, 0.9)
		end
		for _ = 1, 14 do
			local p = fxPart({ Size = Vector3.new(0.15, 0.15, 0.15), Color = Color3.fromRGB(255, 200, 80), Material = Enum.Material.Neon, Position = pos })
			TweenService:Create(p, TweenInfo.new(0.9), { Position = pos + Vector3.new((math.random() - 0.5) * 8, math.random() * 7, (math.random() - 0.5) * 8),
				Transparency = 1 }):Play()
			Debris:AddItem(p, 1)
		end
	elseif kind == "Galaxy" then
		-- 얼티밋 스킨 피니셔: 회전하며 퍼지는 별빛 고리 + 중심 섬광
		local core = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Color = Color3.fromRGB(230, 220, 255), Material = Enum.Material.Neon, Position = pos })
		TweenService:Create(core, TweenInfo.new(0.45), { Size = Vector3.one * 6, Transparency = 1 }):Play()
		Debris:AddItem(core, 0.5)
		for i = 1, 18 do
			local a = i / 18 * math.pi * 2
			local cc = Color3.fromHSV(0.7 + (i % 6) * 0.04, 0.6, 1)
			local p = fxPart({ Size = Vector3.new(0.25, 0.25, 0.25), Color = cc, Material = Enum.Material.Neon, Position = pos })
			local r = 5 + (i % 3)
			TweenService:Create(p, TweenInfo.new(0.8, Enum.EasingStyle.Quart), { Position = pos + Vector3.new(math.cos(a + 1) * r, 1 + (i % 4) * 0.6, math.sin(a + 1) * r),
				Transparency = 1 }):Play()
			Debris:AddItem(p, 0.85)
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

-- 투척물 (스페셜 크로마 봄 · 연막탄): 서버와 같은 초기값으로 포물선을 그리다 ProjEnd에서 터짐
local projs = {}
local ModelKit = require(ReplicatedStorage.Shared.ModelKit)
local function startProj(d)
	local visual
	if d.Kind == "Smoke" then
		visual = ModelKit.Item("Smoke")
		for _, p in ipairs(visual:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		visual.Parent = folder()
	else
		visual = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.7, Color = d.Color, Position = d.From })
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.5, 0)
		a0.Parent = visual
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.5, 0)
		a1.Parent = visual
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(d.Color)
		trail.LightEmission = 0.8
		trail.Lifetime = 0.25
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = visual
		local l = Instance.new("PointLight")
		l.Color = d.Color
		l.Range = 10
		l.Brightness = 3
		l.Parent = visual
	end
	local t0 = os.clock()
	local rec = { Visual = visual }
	projs[d.Id] = rec
	rec.Conn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > (Config.Throw.MaxTime + 0.5) then
			rec.Conn:Disconnect()
			visual:Destroy()
			projs[d.Id] = nil
			return
		end
		local pos = d.From + d.Vel * t + d.G * (0.5 * t * t)
		local cf = CFrame.new(pos) * CFrame.Angles(t * 9, t * 5, 0)
		if visual:IsA("Model") then
			visual:PivotTo(cf)
		else
			visual.CFrame = cf
		end
	end)
	SoundBank.Play("special_throw", d.From, 0.7)
end

local function endProj(d)
	local rec = projs[d.Id]
	if rec then
		rec.Conn:Disconnect()
		rec.Visual:Destroy()
		projs[d.Id] = nil
	end
	local pos = d.Pos
	if d.Kind == "Smoke" then
		SoundBank.Play("land", pos, 0.8)
		Effects.Splash(pos, Color3.fromRGB(230, 232, 240), 3)
		return
	end
	local radius = d.Radius or Config.SpecialRadius
	local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2, 2), Color = d.Color,
		CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.4)
	local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = d.Color, Position = pos })
	TweenService:Create(ball, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = Vector3.one * radius * 1.4, Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.35)
	Effects.Splash(pos + Vector3.new(0, 1, 0), d.Color, 4)
	SoundBank.Play("special_boom", pos, 1)
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - pos).Magnitude < radius * 2.5 then
		Effects.Shake(0.4)
	end
end

-- 서버 FX 이벤트 처리
function Effects.OnFX(kind, d)
	if kind == "Slash" then
		-- 다른 사람의 칼 휘두르기: 팔 동작 + 바람 소리
		if d.Shooter ~= player and d.Model then
			CharacterPose.Slash(d.Model, d.Heavy)
			local root = d.Model:FindFirstChild("HumanoidRootPart")
			if root then
				SoundBank.Play("knife_swing", root.Position, 0.6)
			end
		end
		return
	end
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
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { d.Model, folder(), workspace:FindFirstChild("PaintLayer") }
		for _, to in ipairs(d.To) do
			Effects.Tracer(from, to, d.Color, (d.Golden and 0.6) or (d.Weapon == "Sniper" and 0.35) or 0.18)
			-- 다른 사람 총알도 벽에 맞은 자리에 페인트 자국
			local dir = to - d.From
			if dir.Magnitude > 0.5 then
				local hit = workspace:Raycast(d.From, dir + dir.Unit * 0.6, params)
				if hit then
					PaintVisual.WallSplat(hit.Instance, hit.Position, hit.Normal, d.Color)
				end
			end
		end
		SoundBank.Play("fire_" .. string.lower(d.Weapon or "pistol"), d.From, 0.55)
	elseif kind == "Proj" then
		startProj(d)
	elseif kind == "ProjEnd" then
		endProj(d)
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
