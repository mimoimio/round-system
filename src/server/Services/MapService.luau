--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local MapService = {}

local MAP_CONTAINER_NAME = "MapContainer"
local ARENA_NAME = "Arena"
local MAP_DIAMETER = 50

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
	arena.Size = Vector3.new(MAP_DIAMETER, 1, MAP_DIAMETER)
	arena.CFrame = CFrame.new(0, -5, 80)
	arena.TopSurface = Enum.SurfaceType.Smooth
	arena.BottomSurface = Enum.SurfaceType.Smooth
	arena.Material = Enum.Material.Concrete
	arena.Color = Color3.fromRGB(120, 120, 120)
	arena.Parent = container
	arena.CanCollide = false
	arena.Transparency = 1

	local ActualArena = Instance.new("Part")
	ActualArena.Name = ARENA_NAME
	ActualArena.Anchored = true
	ActualArena.CanCollide = true
	ActualArena.Size = Vector3.new(1, MAP_DIAMETER, MAP_DIAMETER)
	ActualArena.CFrame = CFrame.new(0, -5, 80) * CFrame.Angles(0, 0, math.pi / 2)
	ActualArena.Shape = "Cylinder"
	ActualArena.TopSurface = Enum.SurfaceType.Smooth
	ActualArena.BottomSurface = Enum.SurfaceType.Smooth
	ActualArena.Material = Enum.Material.Concrete
	ActualArena.Color = Color3.fromRGB(120, 120, 120)
	ActualArena.Parent = arena
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
		elseif (phase == "WaitingForPlayers") and previousPhase ~= phase then
			destroyMap()
		end
	end)
end

-- return MapService
return MapService
