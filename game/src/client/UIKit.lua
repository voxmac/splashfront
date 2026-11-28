-- 공용 UI 스타일: 패널·버튼·닫기 버튼·아이템 이미지(3D 미리보기)
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ModelKit = require(ReplicatedStorage.Shared.ModelKit)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local WeaponSkins = require(ReplicatedStorage.Shared.WeaponSkins)
local SoundBank = require(script.Parent:WaitForChild("SoundBank"))

local UI = {}

-- SF 톤: 짙은 남색 강철 + 네온 포인트 (로비 격납고와 같은 색)
UI.Colors = {
	Bg = Color3.fromRGB(12, 16, 30),
	Panel = Color3.fromRGB(22, 28, 50),
	Panel2 = Color3.fromRGB(34, 42, 72),
	Pink = Color3.fromRGB(255, 46, 170),
	Cyan = Color3.fromRGB(0, 200, 255),
	Gold = Color3.fromRGB(255, 200, 50),
	Green = Color3.fromRGB(0, 190, 150),
	Text = Color3.fromRGB(245, 245, 255),
	Sub = Color3.fromRGB(180, 178, 205),
	Dim = Color3.fromRGB(62, 74, 108),
	Neon = Color3.fromRGB(240, 255, 40),
}

-- 글꼴: 제목·버튼·숫자는 두꺼운 이탤릭 (하이퍼 FPS 느낌), 본문은 Gotham Bold
UI.Fonts = {
	Heavy = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
	Black = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
}
local ITALIC_FONTS = { [Enum.Font.GothamBlack] = true, [Enum.Font.FredokaOne] = true, [Enum.Font.LuckiestGuy] = true }
local C = UI.Colors

function UI.make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local make = UI.make

function UI.corner(p, r)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 10) }, p)
end

function UI.stroke(p, color, thick, transp)
	return make("UIStroke", { Color = color or Color3.new(1, 1, 1), Thickness = thick or 2, Transparency = transp or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end

function UI.gradient(p, c1, c2, rot)
	return make("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 90 }, p)
end

function UI.label(parent, props)
	local t = make("TextLabel", { BackgroundTransparency = 1, TextColor3 = C.Text, Font = Enum.Font.GothamBold,
		TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, parent)
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	return t
end

-- 둥근 버튼 (마우스를 올리면 살짝 커짐)
function UI.button(parent, text, color, props)
	local b = make("TextButton", { Text = text, BackgroundColor3 = color or C.Pink, TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBlack, TextSize = 18, AutoButtonColor = true }, parent)
	UI.corner(b, 10)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	local scale = make("UIScale", { Scale = 1 }, b)
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 1.04 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 1 }):Play()
	end)
	b.MouseButton1Click:Connect(function()
		SoundBank.Play("ui_click", nil, 0.4)
	end)
	return b
end

-- 닫기 버튼: 둥근 빨강-분홍 그라데이션 + 흰 X, 마우스를 올리면 회전
function UI.CloseButton(parent, onClose, size)
	size = size or 40
	local b = make("TextButton", { Size = UDim2.fromOffset(size, size), Position = UDim2.new(1, -size - 12, 0, 12), AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, ZIndex = 50 }, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	UI.gradient(b, Color3.fromRGB(255, 80, 110), Color3.fromRGB(220, 30, 140), 45)
	UI.stroke(b, Color3.new(1, 1, 1), 2, 0.2)
	for _, rot in ipairs({ 45, -45 }) do
		make("Frame", { Size = UDim2.new(0.5, 0, 0, 4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Rotation = rot, ZIndex = 51 }, b)
	end
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), { Rotation = 90 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), { Rotation = 0 }):Play()
	end)
	b.MouseButton1Click:Connect(function()
		SoundBank.Play("ui_click", nil, 0.4)
		if onClose then
			onClose()
		end
	end)
	return b
end

-- 제목 띠가 있는 패널 (SF: 남색 강철 판 + 네온 테두리 + 사선 줄무늬 제목 띠)
function UI.Panel(parent, title, size, accent)
	accent = accent or C.Pink
	local f = make("Frame", { Size = size, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Bg }, parent)
	UI.corner(f, 14)
	UI.stroke(f, accent, 2, 0.05)
	UI.gradient(f, Color3.fromRGB(26, 34, 60), Color3.fromRGB(10, 13, 26), 90)
	local head = make("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = accent, BorderSizePixel = 0, ClipsDescendants = true }, f)
	UI.corner(head, 14)
	make("Frame", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), BackgroundColor3 = accent, BorderSizePixel = 0 }, head)
	UI.gradient(head, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 175), 90)
	-- 사선 줄무늬 장식
	for k = 0, 6 do
		make("Frame", { Size = UDim2.fromOffset(14, 140), Position = UDim2.new(1, -60 - k * 26, 0, -30), Rotation = 28, BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.82, BorderSizePixel = 0 }, head)
	end
	-- 제목 아래 얇은 네온 선
	make("Frame", { Size = UDim2.new(1, -28, 0, 2), Position = UDim2.fromOffset(14, 66), BackgroundColor3 = C.Neon, BackgroundTransparency = 0.3,
		BorderSizePixel = 0 }, f)
	UI.label(head, { Text = title, FontFace = UI.Fonts.Black, TextSize = 32, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -90, 1, 0),
		TextStrokeTransparency = 0.5 })
	return f, head
end

-- 화면 전체 글꼴 정리: GothamBlack·FredokaOne(이전 카툰 글꼴)과 SFItalic 표시가 붙은 글자를 두꺼운 이탤릭으로
local function styleText(o)
	if not (o:IsA("TextLabel") or o:IsA("TextButton")) then
		return
	end
	if o:GetAttribute("SFItalic") or ITALIC_FONTS[o.Font] then
		o.FontFace = UI.Fonts.Heavy
	end
end
function UI.AutoStyle(root)
	for _, d in ipairs(root:GetDescendants()) do
		styleText(d)
	end
	root.DescendantAdded:Connect(function(d)
		-- 만든 직후 속성을 채우는 코드가 있으니 한 박자 뒤에 적용
		task.defer(styleText, d)
	end)
end

------------------------------------------------------------------------
-- 커스텀 아이콘 (업로드한 이미지). 아직 없으면 이모지로 보였다가 이미지가 준비되면 바뀜
------------------------------------------------------------------------
local images = ReplicatedStorage:WaitForChild("Images", 10)
function UI.Icon(parent, name, emoji, props)
	local holder = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(32, 32) }, parent)
	for k, v in pairs(props or {}) do
		holder[k] = v
	end
	local img = make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Visible = false,
		ZIndex = holder.ZIndex }, holder)
	local txt = make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = emoji or "", TextScaled = true,
		Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), ZIndex = holder.ZIndex }, holder)
	local function refresh()
		local url = images and images:GetAttribute("icon_" .. name)
		img.Image = url or ""
		img.Visible = url ~= nil
		txt.Visible = url == nil
	end
	refresh()
	if images then
		images:GetAttributeChangedSignal("icon_" .. name):Connect(refresh)
	end
	return holder
end

------------------------------------------------------------------------
-- 아이템 이미지: 총은 3D 미리보기(ViewportFrame), 패턴은 재질 견본, 이펙트는 아이콘
------------------------------------------------------------------------
-- zoom: 카메라 거리 배율 (작을수록 크게 보임)
local function viewportModel(parent, model, size, rotY, zoom)
	local vp = make("ViewportFrame", { Size = size or UDim2.fromScale(1, 1), BackgroundTransparency = 1, LightColor = Color3.new(1, 1, 1),
		Ambient = Color3.fromRGB(210, 210, 225), LightDirection = Vector3.new(-1, -1, -0.5) }, parent)
	local world = make("WorldModel", {}, vp)
	model:PivotTo(CFrame.Angles(0, rotY or math.rad(90), 0))
	model.Parent = world
	local cf, sz = model:GetBoundingBox()
	local cam = make("Camera", { FieldOfView = 30 }, vp)
	local dist = sz.Magnitude * (zoom or 1.9)
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, sz.Magnitude * 0.18, dist), cf.Position)
	vp.CurrentCamera = cam
	return vp
end

function UI.ModelImage(parent, model, size, rotY)
	return viewportModel(parent, model, size, rotY)
end

function UI.GunImage(parent, weaponId, accent, skin, size, look)
	local model = ModelKit.Gun(weaponId, accent or C.Cyan, skin, skin and Cosmetics.MaterialOf(skin.Material) or nil, look)
	-- 총 미리보기: 칸 크기에 꽉 차게(가로·세로 비율에 맞춰 카메라 거리 계산), 밝은 조명
	local vp = viewportModel(parent, model, size, math.rad(90), 1.45)
	vp.LightColor = Color3.fromRGB(255, 252, 245)
	vp.Ambient = Color3.fromRGB(230, 230, 240)
	local cam = vp.CurrentCamera
	local cf, sz = model:GetBoundingBox()
	local function fit()
		local abs = vp.AbsoluteSize
		if abs.X < 4 or abs.Y < 4 then
			return
		end
		local aspect = abs.X / abs.Y
		local vt = math.tan(math.rad(cam.FieldOfView / 2))
		local ht = vt * aspect
		-- 옆에서 보므로 화면 가로 = 총 길이(가장 긴 변), 세로 = 높이
		local long = math.max(sz.X, sz.Z)
		local dist = math.max((long / 2) / ht, (sz.Y / 2) / vt) * 1.12 + math.min(sz.X, sz.Z) / 2
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, sz.Y * 0.08, dist), cf.Position)
	end
	fit()
	vp:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	return vp
end

function UI.ItemImage(parent, item, size)
	if item.Kind == "Skin" then
		return UI.GunImage(parent, "Rifle", Color3.fromRGB(255, 255, 255), item, size)
	elseif item.Kind == "WSkin" then
		return UI.GunImage(parent, item.PreviewWeapon or "Rifle", C.Cyan, nil, size, WeaponSkins.Look(item.Line, 1))
	end
	local holder = make("Frame", { Size = size or UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, parent)
	if item.Kind == "Pattern" then
		-- 재질 견본: 작은 바닥 셀 3×3을 3D로
		local m = Instance.new("Model")
		local cols = { C.Pink, C.Cyan, C.Gold }
		local m2 = item.Material2 and Cosmetics.MaterialOf(item.Material2)
		for x = -1, 1 do
			for z = -1, 1 do
				local p = Instance.new("Part")
				p.Anchored = true
				p.Size = Vector3.new(0.95, 0.2, 0.95)
				p.Position = Vector3.new(x, 0, z)
				local col = cols[((x + z) % 3) + 1]
				if item.Tint then
					col = col:Lerp(item.Tint, (item.TintAmount or 0.1) * 1.5)
				end
				p.Color = col
				local alt = m2 and ((item.Mix == "Checker" and (x + z) % 2 == 0) or (item.Mix == "Stripe" and x == z) or (item.Mix ~= "Checker" and item.Mix ~= "Stripe" and (x * z) ~= 0 and x == -z))
				p.Material = alt and m2 or (Cosmetics.MaterialOf(item.Material) or Enum.Material.SmoothPlastic)
				p.Parent = m
			end
		end
		local vp = viewportModel(holder, m, UDim2.fromScale(1, 1), 0)
		vp.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 3.2, 2.4), Vector3.zero)
	else
		-- 처치 이펙트: 가운데 빛나는 구 + 사방으로 튀는 색 구슬
		local m = Instance.new("Model")
		local palette = (item.Effect == "Rainbow") and { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 230, 60),
			Color3.fromRGB(80, 220, 90), Color3.fromRGB(60, 140, 255), Color3.fromRGB(170, 80, 255) }
			or (item.Effect == "Smoke") and { Color3.fromRGB(220, 222, 230), Color3.fromRGB(180, 184, 196) }
			or { C.Pink, C.Cyan, C.Gold }
		-- 무기 스킨 세트 이펙트: 그 컬렉션의 색으로
		local line = item.Collection and WeaponSkins.LineById[item.Collection]
		if line then
			palette = {}
			for _, v in ipairs(line.Variants) do
				table.insert(palette, v.Accent or v.Body)
				table.insert(palette, v.Particle or v.Metal)
			end
		end
		local core = Instance.new("Part")
		core.Shape = Enum.PartType.Ball
		core.Anchored = true
		core.Size = Vector3.one * ((item.Effect == "Smoke") and 1.6 or 0.9)
		core.Material = (item.Effect == "Smoke") and Enum.Material.SmoothPlastic or Enum.Material.Neon
		core.Color = palette[1]
		core.Parent = m
		for k = 1, 10 do
			local a = k / 10 * math.pi * 2
			local b = Instance.new("Part")
			b.Shape = Enum.PartType.Ball
			b.Anchored = true
			local r = (k % 2 == 0) and 1.5 or 1.05
			b.Size = Vector3.one * ((k % 2 == 0) and 0.35 or 0.5)
			b.Position = Vector3.new(math.cos(a) * r, math.sin(a) * r, 0)
			b.Color = palette[(k % #palette) + 1]
			b.Material = (item.Effect == "Smoke") and Enum.Material.SmoothPlastic or Enum.Material.Neon
			b.Parent = m
		end
		local vp = viewportModel(holder, m, UDim2.fromScale(1, 1), 0)
		vp.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 6), Vector3.zero)
	end
	return holder
end

return UI
