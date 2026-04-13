--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local MapService = {}

local MAP_CENTER = Vector3.new(200, 0, 200)
local mapContainer: Folder? = nil

local function buildMap()
	if mapContainer then
		mapContainer:Destroy()
	end

	mapContainer = Instance.new("Folder")
	mapContainer.Name = "ActiveRoundMap"
	mapContainer.Parent = workspace

	local platform = Instance.new("Part")
	platform.Name = "RoundPlatform"
	platform.Size = Vector3.new(60, 1, 60)
	platform.Position = MAP_CENTER
	platform.Color = Color3.new(math.random(), math.random(), math.random())
	platform.Anchored = true
	platform.Parent = mapContainer
end

local function destroyMap()
	if mapContainer then
		mapContainer:Destroy()
		mapContainer = nil
	end
end

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

return MapService
