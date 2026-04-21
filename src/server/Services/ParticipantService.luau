--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local ParticipantService = {}

local STARTING_BULLETS = 0
local DUMMY_PARTICIPANT_IDS = {
	"Dummy_A1",
	"Dummy_A2",
	"Dummy_A3",
	"Dummy_A4",
	-- "Dummy_A5",
	-- "Dummy_A6",
	-- "Dummy_A7",
	-- "Dummy_A8",
	-- "Dummy_A9",
	-- "Dummy_notscareme",
	-- "Dummy_getthroughit",
	-- "Dummy_getthroughme",
	-- "Dummy_notthinkingthat",
	-- "Dummy_notdoit",
	-- "Dummy_befindinsomeone",
	-- "Dummy_mnotthatstupid",
	-- "Dummy_nextticket",
	-- "Dummy_nexttrain",
	-- "Dummy_Idoit",
	-- "Dummy_wannathinkthat",
	-- "Dummy_Happen",
}
local DUMMY_PLAYER_ID = "Dummy"
local DUMMY_RIG_NAME = "DummyRig"

local participantModels: { [string]: Model } = {}

local function getParticipantId(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

local function unregisterParticipantModel(participantId: string)
	participantModels[participantId] = nil
end

local function registerParticipantModel(participantId: string, model: Model?)
	if model then
		participantModels[participantId] = model
	else
		unregisterParticipantModel(participantId)
	end
end

local function createFallbackDummyModel(dummyParticipantId: string): Model
	local model = Instance.new("Model")
	model.Name = dummyParticipantId

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 3, 1)
	root.Anchored = true
	root.CanCollide = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	model.Parent = workspace
	return model
end

local function ensureDummyModel(dummyParticipantId: string): Model
	local existing = participantModels[dummyParticipantId]
	if existing and existing.Parent then
		return existing
	end

	local rigTemplate = ServerStorage:FindFirstChild(DUMMY_RIG_NAME)
	if rigTemplate and rigTemplate:IsA("Model") then
		local clone = rigTemplate:Clone()
		clone.Name = dummyParticipantId
		clone.Parent = workspace
		return clone
	end

	return createFallbackDummyModel(dummyParticipantId)
end

local function shouldHaveDummy(roundPhase: PlayerSessions.Phase): boolean
	return roundPhase == "Intermission" or roundPhase == "ActionInput" or roundPhase == "Resolution"
end

local function isDummyParticipant(participantId: string): boolean
	return string.sub(participantId, 1, 6) == "Dummy_"
end

local function killPlayerCharacter(participantId: string)
	local model = participantModels[participantId]
	if not (model and model.Parent) then
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if humanoid.Health > 0 then
			humanoid.Health = 0
		end
		return
	end

	-- model:BreakJoints()
end

function ParticipantService.SyncParticipantsFromPlayers()
	local phase = PlayerSessions:getState().CurrentRound.Phase
	local currentParticipants = PlayerSessions:getState().CurrentRound.Participants

	for _, player in Players:GetPlayers() do
		local participantId = getParticipantId(player)
		if not currentParticipants[participantId] then
			PlayerSessions.addParticipant(tostring(player.UserId), participantId)
		end

		local character = player.Character
		if character then
			registerParticipantModel(participantId, character)
		end
	end

	local onlineByParticipantId: { [string]: boolean } = {}
	for _, player in Players:GetPlayers() do
		onlineByParticipantId[getParticipantId(player)] = true
	end

	if shouldHaveDummy(phase) then
		for _, dummyParticipantId in DUMMY_PARTICIPANT_IDS do
			onlineByParticipantId[dummyParticipantId] = true
			if not currentParticipants[dummyParticipantId] then
				PlayerSessions.addParticipant(DUMMY_PLAYER_ID, dummyParticipantId)
			end

			local dummyModel = ensureDummyModel(dummyParticipantId)
			registerParticipantModel(dummyParticipantId, dummyModel)
		end
	end

	for participantId in currentParticipants do
		if not onlineByParticipantId[participantId] then
			if isDummyParticipant(participantId) then
				local dummyModel = participantModels[participantId]
				if dummyModel and dummyModel.Parent then
					dummyModel:Destroy()
				end
				unregisterParticipantModel(participantId)
			end
			PlayerSessions.removeParticipant(participantId)
		end
	end
end

function ParticipantService.ResetParticipantsForNewRound()
	for participantId in PlayerSessions:getState().CurrentRound.Participants do
		PlayerSessions.resetParticipantForRound(participantId, STARTING_BULLETS)
	end
end

function ParticipantService.ClearTurnInputs()
	for participantId in PlayerSessions:getState().CurrentRound.Participants do
		PlayerSessions.clearParticipantPending(participantId)
	end
end

function ParticipantService.GetAliveParticipantIds(): { string }
	local ids = {}
	for participantId, participant in PlayerSessions:getState().CurrentRound.Participants do
		if participant.IsAlive then
			table.insert(ids, participantId)
		end
	end
	return ids
end

function ParticipantService.GetAliveCount(): number
	local count = 0
	for _, participant in PlayerSessions:getState().CurrentRound.Participants do
		if participant.IsAlive then
			count += 1
		end
	end
	return count
end

function ParticipantService.AreAllAliveReady(): boolean
	local aliveCount = 0
	for _, participant in PlayerSessions:getState().CurrentRound.Participants do
		if participant.IsAlive then
			aliveCount += 1
			if not participant.IsReady then
				return false
			end
		end
	end

	return aliveCount > 0
end

function ParticipantService.GetWinnerParticipantId(): string?
	local winnerId: string? = nil
	for participantId, participant in PlayerSessions:getState().CurrentRound.Participants do
		if participant.IsAlive then
			if winnerId ~= nil then
				return nil
			end
			winnerId = participantId
		end
	end
	return winnerId
end

function ParticipantService.initialize()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			registerParticipantModel(getParticipantId(player), character)
		end)

		if player.Character then
			registerParticipantModel(getParticipantId(player), player.Character)
		end
	end)

	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			registerParticipantModel(getParticipantId(player), character)
		end)

		if player.Character then
			registerParticipantModel(getParticipantId(player), player.Character)
		end
	end

	PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
		return state.CurrentRound.Participants
	end, function(nextParticipants, previousParticipants)
		for participantId, previousParticipant in previousParticipants do
			local nextParticipant = nextParticipants[participantId]
			if previousParticipant.IsAlive and nextParticipant and not nextParticipant.IsAlive then
				if isDummyParticipant(participantId) then
					local model = participantModels[participantId]
					if model and model.Parent then
						model:Destroy()
					end
					unregisterParticipantModel(participantId)
				else
					killPlayerCharacter(participantId)
				end
			end

			if nextParticipant == nil and isDummyParticipant(participantId) then
				local model = participantModels[participantId]
				if model and model.Parent then
					model:Destroy()
				end
				unregisterParticipantModel(participantId)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local participantId = getParticipantId(player)
		unregisterParticipantModel(participantId)
		PlayerSessions.removeParticipant(participantId)
	end)
end

function ParticipantService.GetParticipantModel(participantId: string): Model?
	local model = participantModels[participantId]
	if model and model.Parent then
		return model
	end
	participantModels[participantId] = nil
	return nil
end

return ParticipantService
