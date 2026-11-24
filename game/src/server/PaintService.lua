-- 페인트 셀 관리: 칠하기, 면적 집계, 발밑 색 조회
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Combatants = require(script.Parent.Combatants)

local PaintService = {}

local cellsFolder = nil
local palette = {}      -- ownerId -> Color3
local counts = {}       -- ownerId -> 셀 수
local totalCells = 0
local radiusMul = 1
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
local downRay = RaycastParams.new()
downRay.FilterType = Enum.RaycastFilterType.Include

function PaintService.Init(folder)
	cellsFolder = folder
	overlap.FilterDescendantsInstances = { folder }
	downRay.FilterDescendantsInstances = { folder }
	totalCells = #folder:GetChildren()
	PaintService.Reset()
end

function PaintService.SetPalette(map)
	palette = map
end

function PaintService.SetRadiusMultiplier(m)
	radiusMul = m
end

function PaintService.Reset()
	counts = {}
	if not cellsFolder then
		return
	end
	for _, c in ipairs(cellsFolder:GetChildren()) do
		c:SetAttribute("Owner", 0)
		c.Color = Config.NeutralColor
		c.Material = Enum.Material.SmoothPlastic
	end
end

-- 페인트 패턴: 셀 위치(격자 좌표)로 주 재질/보조 재질을 나눠 체크·줄무늬·흩뿌림 무늬를 만들고 테마 색을 살짝 섞음
local function patternLook(cell, pat)
	local mat = pat.Mat
	if pat.Mat2 then
		local gx = math.floor(cell.Position.X / Config.CellSize + 0.5)
		local gz = math.floor(cell.Position.Z / Config.CellSize + 0.5)
		local alt
		if pat.Mix == "Checker" then
			alt = (gx + gz) % 2 == 0
		elseif pat.Mix == "Stripe" then
			alt = (gx + gz) % 4 == 0
		else
			alt = (gx * 7 + gz * 13 + gx * gz) % 5 == 0
		end
		if alt then
			mat = pat.Mat2
		end
	end
	return mat
end

local function setOwner(cell, ownerId, material)
	local prev = cell:GetAttribute("Owner") or 0
	if prev == ownerId then
		return false
	end
	if prev ~= 0 then
		counts[prev] = (counts[prev] or 1) - 1
	end
	counts[ownerId] = (counts[ownerId] or 0) + 1
	cell:SetAttribute("Owner", ownerId)
	local color = palette[ownerId] or Config.NeutralColor
	if type(material) == "table" then
		-- 패턴 장착: 재질 무늬 + 테마 색 살짝
		if material.Tint then
			color = color:Lerp(material.Tint, material.TintAmount or 0.1)
		end
		cell.Color = color
		cell.Material = patternLook(cell, material)
	else
		cell.Color = color
		cell.Material = material or Enum.Material.Glass -- 기본: 젖은 페인트 느낌 / 페인트 패턴 장착 시 해당 재질
	end
	return true
end

-- position 주변 radius 안의 셀을 ownerId로 칠함. 새로 칠한 셀 수를 돌려줌
function PaintService.PaintAt(position, radius, ownerId, painterEntity)
	if not cellsFolder or ownerId == nil or ownerId == 0 then
		return 0
	end
	local r = radius * radiusMul
	local parts = workspace:GetPartBoundsInRadius(position, r, overlap)
	local changed = 0
	local material = painterEntity and painterEntity.PatternMaterial or nil
	for _, cell in ipairs(parts) do
		-- 높이 차이가 큰 셀(다른 층)은 제외
		if math.abs(cell.Position.Y - position.Y) <= math.max(3, r * 0.6) then
			if setOwner(cell, ownerId, material) then
				changed = changed + 1
			end
		end
	end
	if changed > 0 and painterEntity then
		painterEntity.Cells = painterEntity.Cells + changed
		painterEntity.Special = painterEntity.Special + changed
		Combatants.Painted:Fire(painterEntity, changed)
	end
	return changed
end

-- 지점 아래로 레이를 쏴 가장 가까운 바닥 셀을 찾아 칠함 (탄도 경로 칠하기용)
function PaintService.PaintBelow(position, radius, ownerId, painterEntity)
	local hit = workspace:Raycast(position, Vector3.new(0, -12, 0), downRay)
	if hit then
		return PaintService.PaintAt(hit.Position, radius, ownerId, painterEntity)
	end
	return 0
end

-- 발밑 셀의 주인 (없으면 0)
function PaintService.OwnerBelow(position)
	if not cellsFolder then
		return 0
	end
	local hit = workspace:Raycast(position, Vector3.new(0, -6, 0), downRay)
	if hit then
		return hit.Instance:GetAttribute("Owner") or 0
	end
	return 0
end

function PaintService.CountInRadius(position, radius)
	local result = {}
	local parts = workspace:GetPartBoundsInRadius(position, radius, overlap)
	for _, cell in ipairs(parts) do
		local o = cell:GetAttribute("Owner") or 0
		if o ~= 0 then
			result[o] = (result[o] or 0) + 1
		end
	end
	return result
end

function PaintService.GetCounts()
	return counts
end

function PaintService.GetTotal()
	return totalCells
end

-- ownerId -> 0~100 (%)
function PaintService.GetCoverage()
	local out = {}
	for owner, n in pairs(counts) do
		out[owner] = (totalCells > 0) and (n / totalCells * 100) or 0
	end
	return out
end

return PaintService
