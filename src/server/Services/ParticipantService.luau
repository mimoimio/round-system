--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local CharacterRegistry = require(game.ServerScriptService.Server.Modules.CharacterRegistry)

local ParticipantService = {}

local DUMMY_COUNT = 3
local SWORD_NAME = "ClassicSword"

local function getLobbyCFrame(): CFrame
	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		return spawnLocation.CFrame + Vector3.new(0, 5, 0)
	end

	return CFrame.new(0, 10, 0)
end

local function sendCharacterToLobby(character: Model)
	if character.Parent then
		character:PivotTo(getLobbyCFrame())
	end
end

local function giveLoadout(characterModel: Model)
	local classicSword = ServerStorage:FindFirstChild("ClassicSword")
	if not classicSword or not classicSword:IsA("Tool") then
		warn("[ParticipantService] Missing Tool 'ClassicSword' in ServerStorage")
		return
	end

	for _, child in characterModel:GetChildren() do
		if child:IsA("Tool") and child.Name == classicSword.Name then
			return
		end
	end

	local sword = classicSword:Clone()
	sword.Parent = characterModel
end

local function removeSwordFromContainer(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child.Name == SWORD_NAME then
			child:Destroy()
		end
	end
end

local function cleanupPlayerLoadout(participantId: string, character: Model)
	removeSwordFromContainer(character)

	local numericPart = string.sub(participantId, 8)
	local userId = tonumber(numericPart)
	if not userId then
		return
	end

	local player = Players:GetPlayerByUserId(userId)
	if player then
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			removeSwordFromContainer(backpack)
		end
	end
end

local function registerPlayerParticipants()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local id = "Player_" .. tostring(player.UserId)
			CharacterRegistry.Register(id, character)
			PlayerSessions.addParticipant(id, "Red")
		end
	end
end

local function spawnDummyParticipants()
	local dummyTemplate = ServerStorage:FindFirstChild("DummyRig")
	if not dummyTemplate or not dummyTemplate:IsA("Model") then
		warn("[ParticipantService] Missing Model 'DummyRig' in ServerStorage")
		return
	end

	for _ = 1, DUMMY_COUNT do
		local dummyId = "Dummy_" .. HttpService:GenerateGUID(false)
		local dummy = dummyTemplate:Clone()
		dummy.Name = dummyId
		dummy.Parent = workspace

		CharacterRegistry.Register(dummyId, dummy)
		PlayerSessions.addParticipant(dummyId, "Blue")
	end
end

local function giveLoadoutToParticipants()
	local participants = PlayerSessions:getState().CurrentRound.Participants
	for participantId in participants do
		local character = CharacterRegistry.GetModel(participantId)
		if character then
			giveLoadout(character)
		end
	end
end

function ParticipantService.initialize()
	Players.PlayerRemoving:Connect(function(player)
		local id = "Player_" .. tostring(player.UserId)
		CharacterRegistry.Unregister(id)
	end)
end

function ParticipantService.start()
	PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
		return state.CurrentRound.Phase
	end, function(phase: PlayerSessions.Phase, previousPhase: PlayerSessions.Phase)
		if phase == "Starting" and previousPhase ~= "Starting" then
			registerPlayerParticipants()
			spawnDummyParticipants()
		elseif phase == "InProgress" and previousPhase ~= "InProgress" then
			giveLoadoutToParticipants()
		end
	end)

	PlayerSessions:observe(function(state: PlayerSessions.PlayersState)
		return state.CurrentRound.Participants
	end, function(_: PlayerSessions.ParticipantEntity, participantId: string)
		return participantId
	end, function(_: PlayerSessions.ParticipantEntity, participantId: string)
		return function()
			local character = CharacterRegistry.GetModel(participantId)
			if character then
				if string.sub(participantId, 1, 6) == "Dummy_" then
					character:Destroy()
				elseif string.sub(participantId, 1, 7) == "Player_" then
					cleanupPlayerLoadout(participantId, character)
					sendCharacterToLobby(character)
				end
			end
			CharacterRegistry.Unregister(participantId)
		end
	end)
end

return ParticipantService
