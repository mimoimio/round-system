--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParticipantService = require(script.Parent.ParticipantService)
local ResolutionService = require(script.Parent.ResolutionService)
local TeleportService = require(script.Parent.TeleportService)
local MapService = require(script.Parent.MapService)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RoundService = {}

local INTERMISSION_DURATION = 4
local ACTION_INPUT_DURATION = 5
local MIN_ACTION_INPUT_DURATION = 5
local RESOLUTION_DURATION = 1
local ENDED_DURATION = 5
local WAITING_RECHECK_DURATION = 5
local LOOP_TICK_SECONDS = 1
local MIN_HUMAN_PLAYERS_TO_START = 1
local WIN_REWARD_CASH = 10

type ResolutionTargetAllocation = {
	targetParticipantId: string,
	amount: number,
}

type ResolutionActionEntry = {
	participantId: string,
	action: PlayerSessions.PendingAction,
	isAlive: boolean,
	bullets: number,
	pendingShields: number,
	targets: { ResolutionTargetAllocation },
}

type ResolutionSnapshotPayload = {
	turnIndex: number,
	phase: PlayerSessions.Phase,
	dispatchedAt: number,
	actions: { ResolutionActionEntry },
}

local function getActionInputDuration(turnIndex: number): number
	local turnPenalty = math.max(0, turnIndex - 1)
	return math.max(MIN_ACTION_INPUT_DURATION, ACTION_INPUT_DURATION - turnPenalty)
end

local function getActivePlayerCount(): number
	return #Players:GetPlayers()
end

local function transitionToWaitingForPlayers()
	PlayerSessions.setRoundWinnerParticipant(nil)
	PlayerSessions.setRoundTurnIndex(0)
	PlayerSessions.setPhase("WaitingForPlayers", WAITING_RECHECK_DURATION + workspace:GetServerTimeNow())
end

local function transitionToIntermission()
	MapService.BuildMap()
	PlayerSessions.setRoundWinnerParticipant(nil)
	PlayerSessions.setRoundTurnIndex(0)
	PlayerSessions.setPhase("Intermission", INTERMISSION_DURATION + workspace:GetServerTimeNow())
	ParticipantService.SyncParticipantsFromPlayers()
	ParticipantService.ResetParticipantsForNewRound()
	TeleportService.TeleportParticipantsToArena()
end

local function transitionToActionInput()
	local nextTurnIndex = PlayerSessions:getState().CurrentRound.TurnIndex + 1
	PlayerSessions.setRoundTurnIndex(nextTurnIndex)
	ParticipantService.ClearTurnInputs()
	PlayerSessions.setPhase("ActionInput", getActionInputDuration(nextTurnIndex) + workspace:GetServerTimeNow())
end

local function buildResolutionSnapshot(): ResolutionSnapshotPayload
	local currentRound = PlayerSessions:getState().CurrentRound
	local sortedParticipantIds = {}
	for participantId in currentRound.Participants do
		table.insert(sortedParticipantIds, participantId)
	end
	table.sort(sortedParticipantIds)

	local actions = {}
	for _, participantId in sortedParticipantIds do
		local participant = currentRound.Participants[participantId]
		if participant then
			local targetParticipantIds = {}
			for targetParticipantId, amount in participant.PendingTargets do
				if amount > 0 then
					table.insert(targetParticipantIds, targetParticipantId)
				end
			end
			table.sort(targetParticipantIds)

			local targets = {}
			for _, targetParticipantId in targetParticipantIds do
				table.insert(targets, {
					targetParticipantId = targetParticipantId,
					amount = participant.PendingTargets[targetParticipantId],
				})
			end

			table.insert(actions, {
				participantId = participantId,
				action = participant.PendingAction,
				isAlive = participant.IsAlive,
				bullets = participant.Bullets,
				pendingShields = participant.PendingShields,
				targets = targets,
			})
		end
	end

	return {
		turnIndex = currentRound.TurnIndex,
		phase = currentRound.Phase,
		dispatchedAt = os.clock(),
		actions = actions,
	}
end

local function transitionToResolution()
	Remotes.ResolutionSnapshot:FireAllClients(buildResolutionSnapshot())
	ResolutionService.ResolveCurrentTurn()
	local state = PlayerSessions:getState()

	PlayerSessions.setPhase("Resolution", RESOLUTION_DURATION + workspace:GetServerTimeNow())
end

local function awardWinnerAndFinalize()
	local winnerParticipantId = ParticipantService.GetWinnerParticipantId()
	PlayerSessions.setRoundWinnerParticipant(winnerParticipantId)

	if winnerParticipantId then
		local winner = PlayerSessions:getState().CurrentRound.Participants[winnerParticipantId]
		if winner then
			PlayerSessions.addPlayerWin(winnerParticipantId, 1)
			PlayerSessions.addPlayerCash(winner.PlayerId, WIN_REWARD_CASH)
		end
	end

	PlayerSessions.setPhase("Ended", ENDED_DURATION + workspace:GetServerTimeNow())
end

local function clearRoundParticipants()
	for participantId in PlayerSessions:getState().CurrentRound.Participants do
		PlayerSessions.removeParticipant(participantId)
	end
end

local function runLoop()
	while true do
		local currentRound = PlayerSessions:getState().CurrentRound
		local phase = currentRound.Phase

		if phase == "Intermission" or phase == "ActionInput" or phase == "Resolution" then
			TeleportService.EnsureParticipantsInArenaBounds()
		end

		-- warn("currentRound",currentRound)

		if currentRound.Phase == "ActionInput" and ParticipantService.AreAllAliveReady() then
			transitionToResolution()
			task.wait(LOOP_TICK_SECONDS)
			continue
		end

		if workspace:GetServerTimeNow() < currentRound.TimeEnd then
			task.wait(LOOP_TICK_SECONDS)
			continue
		end

		phase = PlayerSessions:getState().CurrentRound.Phase
		if phase == "WaitingForPlayers" then
			if getActivePlayerCount() >= MIN_HUMAN_PLAYERS_TO_START then
				transitionToIntermission()
			else
				PlayerSessions.setPhase("WaitingForPlayers", WAITING_RECHECK_DURATION + workspace:GetServerTimeNow())
			end
		elseif phase == "Intermission" then
			transitionToActionInput()
		elseif phase == "ActionInput" then
			transitionToResolution()
		elseif phase == "Resolution" then
			if ParticipantService.GetAliveCount() <= 1 then
				awardWinnerAndFinalize()
			else
				transitionToActionInput()
			end
		elseif phase == "Ended" then
			TeleportService.TeleportParticipantsToLobby()
			MapService.DestroyMap()
			clearRoundParticipants()
			transitionToWaitingForPlayers()
		end

		task.wait(LOOP_TICK_SECONDS)
	end
end

function RoundService.initialize()
	PlayerSessions.setRoundTurnIndex(0)
	PlayerSessions.setPhase("WaitingForPlayers", WAITING_RECHECK_DURATION + workspace:GetServerTimeNow())
end

function RoundService.start()
	task.spawn(runLoop)
end

return RoundService
