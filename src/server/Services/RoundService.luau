--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParticipantService = require(script.Parent.ParticipantService)
local ResolutionService = require(script.Parent.ResolutionService)
local TeleportService = require(script.Parent.TeleportService)
local MapService = require(script.Parent.MapService)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local RoundService = {}

local INTERMISSION_DURATION = 4
local ACTION_INPUT_DURATION = 8
local MIN_ACTION_INPUT_DURATION = 4
local RESOLUTION_DURATION = 2
local ENDED_DURATION = 5
local WAITING_RECHECK_DURATION = 10
local LOOP_TICK_SECONDS = 1
local MIN_HUMAN_PLAYERS_TO_START = 1
local WIN_REWARD_CASH = 10

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
	PlayerSessions.setPhase("WaitingForPlayers", WAITING_RECHECK_DURATION)
end

local function transitionToIntermission()
	MapService.BuildMap()
	PlayerSessions.setRoundWinnerParticipant(nil)
	PlayerSessions.setRoundTurnIndex(0)
	PlayerSessions.setPhase("Intermission", INTERMISSION_DURATION)
	ParticipantService.SyncParticipantsFromPlayers()
	ParticipantService.ResetParticipantsForNewRound()
	TeleportService.TeleportParticipantsToArena()
end

local function transitionToActionInput()
	local nextTurnIndex = PlayerSessions:getState().CurrentRound.TurnIndex + 1
	PlayerSessions.setRoundTurnIndex(nextTurnIndex)
	ParticipantService.ClearTurnInputs()
	PlayerSessions.setPhase("ActionInput", getActionInputDuration(nextTurnIndex))
end

local function transitionToResolution()
	ResolutionService.ResolveCurrentTurn()
	PlayerSessions.setPhase("Resolution", RESOLUTION_DURATION)
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

	PlayerSessions.setPhase("Ended", ENDED_DURATION)
end

local function clearRoundParticipants()
	for participantId in PlayerSessions:getState().CurrentRound.Participants do
		PlayerSessions.removeParticipant(participantId)
	end
end

local function runLoop()
	while true do
		local currentRound = PlayerSessions:getState().CurrentRound

		-- warn("currentRound",currentRound)

		if currentRound.Phase == "ActionInput" and ParticipantService.AreAllAliveReady() then
			transitionToResolution()
			task.wait(LOOP_TICK_SECONDS)
			continue
		end

		if os.time() < currentRound.TimeEnd then
			task.wait(LOOP_TICK_SECONDS)
			continue
		end

		local phase = PlayerSessions:getState().CurrentRound.Phase
		if phase == "WaitingForPlayers" then
			if getActivePlayerCount() >= MIN_HUMAN_PLAYERS_TO_START then
				transitionToIntermission()
			else
				PlayerSessions.setPhase("WaitingForPlayers", WAITING_RECHECK_DURATION)
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
	PlayerSessions.setPhase("WaitingForPlayers", WAITING_RECHECK_DURATION)
end

function RoundService.start()
	task.spawn(runLoop)
end

return RoundService
