-- 바닥 페인트 연출 (클라이언트 전용)
-- 서버의 바닥 셀(4스터드 격자)은 점수·이동속도 판정용으로 그대로 두고 화면에서는 숨김.
-- 대신 셀마다 셀보다 큰 둥근 페인트 방울을 무작위로 겹쳐 깔아 스플래툰처럼 번진 모양을 만들고,
-- 칠해질 때 '촥' 하고 퍼지는 애니메이션 + 주변 물방울을 뿌림
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)

local PV = {}

local CELL = Config.CellSize
local NEUTRAL = Config.NeutralColor
local layer = nil
local conns = {}
local visuals = {}      -- cell -> { Blob, Drops = {} }
local pending = {}      -- cell -> true (같은 프레임의 색·주인 변경을 한 번에 처리)
local rng = Random.new()
local GROW = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local DROP = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function disc(pos, d, color, material)
	local p = Instance.new("Part")
	p.Name = "Paint"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.05, d, d)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	p.Material = material
	p.Reflectance = (material == Enum.Material.SmoothPlastic) and 0.12 or 0
	p.Parent = layer
	return p
end

local function paintMaterial(cell)
	-- 기본 '젖은 페인트'(Glass)는 바닥 위에서 투명해 보이므로 반짝이는 플라스틱으로, 패턴 재질은 그대로
	local m = cell.Material
	if m == Enum.Material.Glass then
		return Enum.Material.SmoothPlastic
	end
	return m
end

local function clearCell(cell)
	local v = visuals[cell]
	if v then
		v.Blob:Destroy()
		for _, d in ipairs(v.Drops) do
			d:Destroy()
		end
		visuals[cell] = nil
	end
end

local function paintCell(cell, animate)
	pending[cell] = nil
	if not cell.Parent then
		clearCell(cell)
		return
	end
	local owner = cell:GetAttribute("Owner") or 0
	if owner == 0 or cell.Color == NEUTRAL then
		clearCell(cell)
		return
	end
	local color, mat = cell.Color, paintMaterial(cell)
	local top = cell.Position + Vector3.new(0, cell.Size.Y / 2 + 0.02, 0)
	local v = visuals[cell]
	if not v then
		-- 셀보다 큰 원(1.4~1.9배)을 조금씩 어긋나게 → 이웃 방울과 겹쳐 둥글게 번진 경계
		local d = CELL * rng:NextNumber(1.4, 1.9)
		local jitter = Vector3.new(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, 0.03), rng:NextNumber(-0.7, 0.7))
		local blob = disc(top + jitter, animate and 0.4 or d, color, mat)
		v = { Blob = blob, Size = d, Drops = {} }
		visuals[cell] = v
		if animate then
			TweenService:Create(blob, GROW, { Size = Vector3.new(0.05, d, d) }):Play()
		end
		-- 가장자리에 흩뿌린 물방울
		if rng:NextNumber() < 0.35 then
			for _ = 1, rng:NextInteger(1, 2) do
				local a = rng:NextNumber() * math.pi * 2
				local r = CELL * rng:NextNumber(0.9, 1.5)
				local dd = rng:NextNumber(0.5, 1.3)
				local pos = top + Vector3.new(math.cos(a) * r, rng:NextNumber(0, 0.03), math.sin(a) * r)
				local drop = disc(animate and top or pos, dd, color, mat)
				if animate then
					drop.Size = Vector3.new(0.05, 0.2, 0.2)
					TweenService:Create(drop, DROP, { CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Size = Vector3.new(0.05, dd, dd) }):Play()
				end
				table.insert(v.Drops, drop)
			end
		end
	else
		-- 다른 색이 덮어 칠함: 색을 바꾸고 살짝 '퐁' 튀게
		v.Blob.Color = color
		v.Blob.Material = mat
		for _, d in ipairs(v.Drops) do
			d.Color = color
			d.Material = mat
		end
		if animate then
			local s = v.Size
			v.Blob.Size = Vector3.new(0.05, s * 0.6, s * 0.6)
			TweenService:Create(v.Blob, GROW, { Size = Vector3.new(0.05, s, s) }):Play()
		end
	end
end

local function queue(cell)
	if pending[cell] then
		return
	end
	pending[cell] = true
	task.defer(paintCell, cell, true)
end

local function bind(folder)
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	conns = {}
	for cell in pairs(visuals) do
		clearCell(cell)
	end
	if not folder then
		return
	end
	for _, cell in ipairs(folder:GetChildren()) do
		if cell:IsA("BasePart") then
			table.insert(conns, cell:GetAttributeChangedSignal("Owner"):Connect(function()
				queue(cell)
			end))
			table.insert(conns, cell:GetPropertyChangedSignal("Color"):Connect(function()
				queue(cell)
			end))
			if (cell:GetAttribute("Owner") or 0) ~= 0 then
				paintCell(cell, false)
			end
		end
	end
end

function PV.Init()
	layer = Instance.new("Folder")
	layer.Name = "PaintLayer"
	layer.Parent = workspace
	local active = ReplicatedStorage:WaitForChild("ActiveCells")
	active.Changed:Connect(function()
		bind(active.Value)
	end)
	bind(active.Value)
end

return PV
