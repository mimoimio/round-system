--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local ParticipantService = require(script.Parent.ParticipantService)

local TeleportService = {}

local function getLobbyCFrame(): CFrame?
	local lobbySpawn = workspace:FindFirstChild("LobbySpawn")
	if lobbySpawn and lobbySpawn:IsA("BasePart") then
		return lobbySpawn.CFrame + Vector3.new(0, 3, 0)
	end

	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		return spawnLocation.CFrame + Vector3.new(0, 3, 0)
	end

	return nil
end

local function getArenaPart(): BasePart?
	local mapContainer = workspace:FindFirstChild("MapContainer")
	if mapContainer then
		local arena = mapContainer:FindFirstChild("Arena")
		if arena and arena:IsA("BasePart") then
			return arena
		end
	end

	local arena = workspace:FindFirstChild("Arena")
	if arena and arena:IsA("BasePart") then
		return arena
	end

	return nil
end

local function getArenaSpawnParts(): { BasePart }
	local spawns = {}
	local arenaSpawns = workspace:FindFirstChild("ArenaSpawns")
	if arenaSpawns then
		for _, child in arenaSpawns:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(spawns, child)
			end
		end
	end

	local arenaPart = getArenaPart()
	if #spawns == 0 and arenaPart then
		table.insert(spawns, arenaPart)
	end

	return spawns
end

local function circlePointOnArena(arena: BasePart, index: number, total: number): CFrame
	local radius = math.max(4, math.min(arena.Size.X, arena.Size.Z) * 0.5 - 4)
	local angle = ((index - 1) / total) * math.pi * 2
	local offset = Vector3.new(math.cos(angle) * radius, arena.Size.Y * 0.5 + 3, math.sin(angle) * radius)
	return arena.CFrame + offset
end

function TeleportService.TeleportParticipantsToArena()
	local arenaPart = getArenaPart()
	if not arenaPart then
		return
	end

	local participants = {}
	for participantId in PlayerSessions:getState().CurrentRound.Participants do
		table.insert(participants, participantId)
	end

	if #participants == 0 then
		return
	end

	local index = 0
	for _, participantId in participants do
		local model = ParticipantService.GetParticipantModel(participantId)
		if model then
			index += 1
			local spawnCFrame = circlePointOnArena(arenaPart, index, #participants)
			local spawnPosition = spawnCFrame.Position
			local lookTarget = Vector3.new(arenaPart.Position.X, spawnPosition.Y, arenaPart.Position.Z)
			model:PivotTo(CFrame.lookAt(spawnPosition, lookTarget))
		end
	end
end

function TeleportService.TeleportParticipantsToLobby()
	local lobbyCFrame = getLobbyCFrame()
	if not lobbyCFrame then
		return
	end

	for participantId in PlayerSessions:getState().CurrentRound.Participants do
		local model = ParticipantService.GetParticipantModel(participantId)
		if model then
			model:PivotTo(lobbyCFrame)
		end
	end
end

return TeleportService
