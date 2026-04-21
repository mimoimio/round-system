--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local MapService = {}

local MAP_CONTAINER_NAME = "MapContainer"
local ARENA_NAME = "Arena"

local function getOrCreateMapContainer(): Folder
	local existing = workspace:FindFirstChild(MAP_CONTAINER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local container = Instance.new("Folder")
	container.Name = MAP_CONTAINER_NAME
	container.Parent = workspace
	return container
end

local function hasArena(): boolean
	local container = workspace:FindFirstChild(MAP_CONTAINER_NAME)
	if not container then
		return false
	end

	local arena = container:FindFirstChild(ARENA_NAME)
	return arena ~= nil and arena:IsA("BasePart")
end

local function buildMap()
	if hasArena() then
		return
	end

	local container = getOrCreateMapContainer()

	local arena = Instance.new("Part")
	arena.Name = ARENA_NAME
	arena.Anchored = true
	arena.CanCollide = true
	arena.Size = Vector3.new(40, 1, 40)
	arena.CFrame = CFrame.new(0, 10, 0)
	arena.TopSurface = Enum.SurfaceType.Smooth
	arena.BottomSurface = Enum.SurfaceType.Smooth
	arena.Material = Enum.Material.Concrete
	arena.Color = Color3.fromRGB(120, 120, 120)
	arena.Parent = container
end

local function destroyMap()
	local container = workspace:FindFirstChild(MAP_CONTAINER_NAME)
	if container and container:IsA("Folder") then
		container:Destroy()
	end
end

function MapService.BuildMap()
	buildMap()
end

function MapService.DestroyMap()
	destroyMap()
end

function MapService.start()
	PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
		return state.CurrentRound.Phase
	end, function(phase: PlayerSessions.Phase, previousPhase: PlayerSessions.Phase)
		if phase == "Intermission" then
			buildMap()
		elseif (phase == "WaitingForPlayers" or phase == "Ended") and previousPhase ~= phase then
			destroyMap()
		end
	end)
end

-- return MapService
return MapService
