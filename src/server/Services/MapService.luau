--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local MapService = {}

-- Kitchen maps are authored in Workspace.Kitchens; this observer remains as a phase hook.
local function buildMap() end
local function destroyMap() end

function MapService.start()
	PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
		return state.CurrentRound.Phase
	end, function(phase: PlayerSessions.Phase, previousPhase: PlayerSessions.Phase)
		if phase == "Starting" then
			buildMap()
		elseif phase == "WaitingForPlayers" and previousPhase ~= "WaitingForPlayers" then
			destroyMap()
		end
	end)
end

-- return MapService
return MapService
