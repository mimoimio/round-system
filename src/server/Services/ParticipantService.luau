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
	"Dummy_A5",
	"Dummy_A6",
	"Dummy_A7",
	"Dummy_A8",
	"Dummy_A9",
	"Dummy_notscareme",
	"Dummy_getthroughit",
	"Dummy_getthroughme",
	"Dummy_notthinkingthat",
	"Dummy_notdoit",
	"Dummy_befindinsomeone",
	"Dummy_mnotthatstupid",
	"Dummy_nextticket",
	"Dummy_nexttrain",
	"Dummy_Idoit",
	"Dummy_wannathinkthat",
	"Dummy_Happen",
	"Dummy_A30",
	"Dummy_A40",
	"Dummy_A50",
	"Dummy_A60",
	"Dummy_A70",
	"Dummy_A80",
	"Dummy_A90",
	"Dummy_notscareme0",
	"Dummy_getthroughit0",
	"Dummy_getthroughme0",
	"Dummy_notthinkingthat0",
	"Dummy_notdoit0",
	"Dummy_befindinsomeone0",
	"Dummy_mnotthatstupid0",
	"Dummy_nextticket0",
	"Dummy_nexttrain0",
	"Dummy_Idoit0",
	"Dummy_wannathinkthat0",
	"Dummy_Happen0",
	"Dummy_getthroughme0a",
	"Dummy_notthinkingthat0a",
	"Dummy_notdoit0a",
	"Dummy_befindinsomeone0a",
	"Dummy_mnotthatstupid0a",
	"Dummy_nextticket0a",
	"Dummy_nexttrain0a",
	"Dummy_Idoit0a",
	"Dummy_wannathinkthat0a",
	"Dummy_Happen0a",
}
local DUMMY_PLAYER_ID = "Dummy"
local DUMMY_RIG_NAME = "DummyRig"

local participantModels: { [string]: Model } = {}
local randomGenerator = Random.new()

local function getParticipantId(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

local function getPlayerFromParticipantId(participantId: string): Player?
	local userIdString = string.match(participantId, "^Player_(%d+)$")
	if not userIdString then
		return nil
	end

	local userId = tonumber(userIdString)
	if not userId then
		return nil
	end

	return Players:GetPlayerByUserId(userId)
end

local function shouldTrackPlayerParticipantModel(participantId: string): boolean
	local participant = PlayerSessions:getState().CurrentRound.Participants[participantId]
	return participant ~= nil and participant.IsAlive
end

local function unregisterParticipantModel(participantId: string)
	local model = participantModels[participantId]
	if model then
		local hum: Humanoid = model:FindFirstChild("Humanoid")
		if hum then
			-- warn("humanoid", participantId)
			hum.JumpHeight = 7.2
			hum.WalkSpeed = 16
		end
	end
	participantModels[participantId] = nil
end

local function registerParticipantModel(participantId: string, model: Model?)
	if model then
		participantModels[participantId] = model
		local hum: Humanoid = model:FindFirstChild("Humanoid")
		if hum then
			hum.WalkSpeed = 0
			hum.JumpHeight = 0
		end
	else
		unregisterParticipantModel(participantId)
	end
end

local function refreshPlayerCharacterModel(player: Player, character: Model?)
	local participantId = getParticipantId(player)
	if shouldTrackPlayerParticipantModel(participantId) and character then
		registerParticipantModel(participantId, character)
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
		local hum = clone:FindFirstChild("Humanoid")
		if hum then
			hum.BreakJointsOnDeath = false
		end

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

local function getAliveNonSelfParticipantIds(
	participants: { [string]: PlayerSessions.ParticipantEntity },
	participantId: string
): { string }
	local ids = {}
	for targetParticipantId, targetParticipant in participants do
		if targetParticipantId ~= participantId and targetParticipant.IsAlive then
			table.insert(ids, targetParticipantId)
		end
	end
	return ids
end

local function killPlayerCharacter(participantId: string)
	local model = participantModels[participantId]
	if not (model and model.Parent) then
		return
	end
	task.delay(0.5, function()
		if model and model:FindFirstChild("Humanoid") then
			model.Humanoid.Health = 0
		end
	end)

	-- local humanoid = model:FindFirstChildOfClass("Humanoid")
	-- if humanoid then
	-- 	if humanoid.Health > 0 then
	-- 		humanoid.Health = 0
	-- 	end
	-- 	return
	-- end

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

		refreshPlayerCharacterModel(player, player.Character)
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

function ParticipantService.AssignRandomDummyInputsForTurn()
	local participants = PlayerSessions:getState().CurrentRound.Participants

	for participantId, participant in participants do
		if not participant.IsAlive or not isDummyParticipant(participantId) then
			continue
		end

		if participant.IsReady then
			continue
		end

		PlayerSessions.clearParticipantPending(participantId)

		local possibleTargets = getAliveNonSelfParticipantIds(participants, participantId)
		local canShoot = participant.Bullets > 0 and #possibleTargets > 0
		local roll = randomGenerator:NextNumber()

		if canShoot and roll < 0.45 then
			-- warn("SHOOT")
			PlayerSessions.setParticipantPendingAction(participantId, "Shoot")
			local shotCount = randomGenerator:NextInteger(1, participant.Bullets)
			for _ = 1, shotCount do
				local targetIndex = randomGenerator:NextInteger(1, #possibleTargets)
				local targetParticipantId = possibleTargets[targetIndex]
				local currentParticipant = PlayerSessions:getState().CurrentRound.Participants[participantId]
				if not currentParticipant then
					break
				end
				local currentAmount = currentParticipant.PendingTargets[targetParticipantId] or 0
				PlayerSessions.setParticipantTargetAllocation(participantId, targetParticipantId, currentAmount + 1)
			end
		elseif roll < 0.7 then
			-- warn("Shield")
			PlayerSessions.setParticipantPendingAction(participantId, "Shield")
			PlayerSessions.addParticipantShield(participantId, randomGenerator:NextInteger(1, 2))
		else
			-- warn("Load")
			PlayerSessions.setParticipantPendingAction(participantId, "Load")
		end

		PlayerSessions.setParticipantReady(participantId, true)
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
			refreshPlayerCharacterModel(player, character)
		end)

		if player.Character then
			refreshPlayerCharacterModel(player, player.Character)
		end
	end)

	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			refreshPlayerCharacterModel(player, character)
		end)

		if player.Character then
			refreshPlayerCharacterModel(player, player.Character)
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
					task.delay(0.5, function()
						if model and model:FindFirstChild("Humanoid") then
							model.Humanoid.Health = 0
						end
					end)
					task.delay(2, function()
						if model and model.Parent then
							model:Destroy()
						end
						unregisterParticipantModel(participantId)
					end)
				else
					killPlayerCharacter(participantId)
					task.delay(1, function()
						unregisterParticipantModel(participantId)
					end)
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

		for participantId, nextParticipant in nextParticipants do
			local previousParticipant = previousParticipants[participantId]
			if nextParticipant.IsAlive and (not previousParticipant or not previousParticipant.IsAlive) then
				if isDummyParticipant(participantId) then
					local dummyModel = ensureDummyModel(participantId)
					registerParticipantModel(participantId, dummyModel)
				else
					local player = getPlayerFromParticipantId(participantId)
					if player then
						refreshPlayerCharacterModel(player, player.Character)
					end
				end
			elseif not nextParticipant.IsAlive then
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
