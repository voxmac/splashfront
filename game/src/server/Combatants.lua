-- 매치 참가자(플레이어 + 봇) 레지스트리
-- entity = { Id, Name, IsBot, Player, Model, OwnerId, TeamId, WeaponId,
--            Ink, Special, Kills, Deaths, Cells, LastFire, LastDamaged,
--            ProtectedUntil, Spread, Alive }
local Signal = require(script.Parent.Signal)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Combatants = {}
Combatants.Painted = Signal.new()   -- (entity, cellsChanged)
Combatants.Killed = Signal.new()    -- (killerEntity|nil, victimEntity, headshot)

local byId = {}
local byModel = {}

function Combatants.New(fields)
	local e = {
		Id = fields.Id,
		Name = fields.Name,
		IsBot = fields.IsBot or false,
		Player = fields.Player,
		Model = nil,
		OwnerId = fields.OwnerId,
		TeamId = fields.TeamId,
		WeaponId = fields.WeaponId or "Pistol",
		Ink = Config.InkMax,
		Special = 0,
		Kills = 0,
		Deaths = 0,
		Cells = 0,
		MissionWins = 0,
		LastFire = 0,
		LastDamaged = 0,
		ProtectedUntil = 0,
		Spread = 0,
		Alive = false,
		Coins = 0,
	}
	byId[e.Id] = e
	return e
end

function Combatants.SetModel(e, model)
	if e.Model then
		byModel[e.Model] = nil
	end
	e.Model = model
	if model then
		byModel[model] = e
	end
end

function Combatants.Remove(e)
	if e.Model then
		byModel[e.Model] = nil
	end
	byId[e.Id] = nil
end

function Combatants.Clear()
	byId = {}
	byModel = {}
end

function Combatants.FromModel(model)
	return byModel[model]
end

function Combatants.FromPart(part)
	local node = part
	while node and node ~= workspace do
		local e = byModel[node]
		if e then
			return e
		end
		node = node.Parent
	end
	return nil
end

function Combatants.FromPlayer(player)
	return byId["P" .. player.UserId]
end

function Combatants.All()
	local list = {}
	for _, e in pairs(byId) do
		table.insert(list, e)
	end
	return list
end

function Combatants.IsEnemy(a, b)
	return a ~= b and a.TeamId ~= b.TeamId
end

-- 플레이어 HUD 동기화용 (속성은 자동 복제됨)
function Combatants.Sync(e)
	if e.Player then
		e.Player:SetAttribute("Ink", math.floor(e.Ink + 0.5))
		e.Player:SetAttribute("Special", math.min(1, e.Special / Config.SpecialCells))
		e.Player:SetAttribute("MatchKills", e.Kills)
		e.Player:SetAttribute("MatchCells", e.Cells)
	end
end

return Combatants
