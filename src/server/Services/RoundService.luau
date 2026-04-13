--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

type Phase = PlayerSessions.Phase
type TeamColor = PlayerSessions.TeamColor
type ParticipantEntity = PlayerSessions.ParticipantEntity

local RoundService = {}

local ENABLE_ROUND_LOGS = false
local LOG_PREFIX = "[RoundService]"

local INTERMISSION_DURATION = 3
local STARTING_DURATION = 3
local IN_PROGRESS_DURATION = 12
local ENDED_DURATION = 3
local WAITING_RECHECK_DURATION = 3
local LOOP_TICK_SECONDS = 1
local MIN_PLAYERS = 1
local WIN_REWARD_CASH = 10
local ENABLE_REWARD_LOGS = true

local function log(message: string)
	if ENABLE_ROUND_LOGS then
		print(string.format("%s %s", LOG_PREFIX, message))
	end
end

local function rewardLog(message: string)
	if ENABLE_REWARD_LOGS then
		print(string.format("[RoundService][Rewards] %s", message))
	end
end

local function participantsCount(participants: { [string]: any }): number
	local count = 0
	for _ in participants do
		count += 1
	end
	return count
end

local function getLastParticipantTeam(participants: { [string]: ParticipantEntity }): (number, TeamColor)
	local count = 0
	local lastTeam: TeamColor = "None"

	for _, participant in participants do
		count += 1
		lastTeam = participant.Team
	end

	return count, lastTeam
end

local function getPhase(): Phase
	return PlayerSessions:getState().CurrentRound.Phase
end

local function hasEnoughPlayers(): boolean
	return #Players:GetPlayers() >= MIN_PLAYERS
end

local function awardWinningTeamCash(winner: TeamColor, participants: { [string]: ParticipantEntity })
	if winner ~= "Red" and winner ~= "Blue" then
		rewardLog(string.format("No winner payout. Winner=%s", winner))
		return
	end

	for participantId, participant in participants do
		if participant.Team == winner and string.sub(participantId, 1, 7) == "Player_" then
			local userId = tonumber(string.sub(participantId, 8))
			if userId then
				local player = Players:GetPlayerByUserId(userId)
				if player then
					PlayerSessions.addPlayerCash(player, WIN_REWARD_CASH)
					rewardLog(
						string.format(
							"Winner reward granted. Player=%s Team=%s Amount=%d",
							player.Name,
							winner,
							WIN_REWARD_CASH
						)
					)
				else
					rewardLog(
						string.format("Skipped winner payout (player not in server). ParticipantId=%s", participantId)
					)
				end
			else
				rewardLog(
					string.format("Skipped winner payout (invalid participant id). ParticipantId=%s", participantId)
				)
			end
		end
	end
end

local function transitionFromWaitingForPlayers()
	local activePlayers = #Players:GetPlayers()
	local enoughPlayers = activePlayers >= MIN_PLAYERS
	log(
		string.format(
			"Evaluating WaitingForPlayers transition. ActivePlayers=%d MinPlayers=%d Enough=%s",
			activePlayers,
			MIN_PLAYERS,
			tostring(enoughPlayers)
		)
	)

	if enoughPlayers then
		log(string.format("Phase transition: WaitingForPlayers -> Intermission (duration=%ds)", INTERMISSION_DURATION))
		PlayerSessions.setPhase("Intermission", INTERMISSION_DURATION)
	else
		log(string.format("Phase remains WaitingForPlayers (recheck duration=%ds)", WAITING_RECHECK_DURATION))
		PlayerSessions.setPhase("WaitingForPlayers", WAITING_RECHECK_DURATION)
	end
end

local function transitionFromIntermission()
	log(string.format("Phase transition: Intermission -> Starting (duration=%ds)", STARTING_DURATION))
	PlayerSessions.setPhase("Starting", STARTING_DURATION)
end

local function transitionFromStarting()
	log(string.format("Phase transition: Starting -> InProgress (duration=%ds)", IN_PROGRESS_DURATION))
	PlayerSessions.setRoundWinner("None")
	PlayerSessions.setPhase("InProgress", IN_PROGRESS_DURATION)
end

local function transitionFromInProgress()
	log("Evaluating InProgress completion and winner state")
	if PlayerSessions:getState().CurrentRound.Winner == "None" then
		log("Winner is None at end of InProgress, setting Winner=Draw")
		PlayerSessions.setRoundWinner("Draw")
	end
	log(string.format("Phase transition: InProgress -> Ended (duration=%ds)", ENDED_DURATION))
	PlayerSessions.setPhase("Ended", ENDED_DURATION)
end

local function transitionFromEnded()
	local currentRound = PlayerSessions:getState().CurrentRound
	local participants = currentRound.Participants
	awardWinningTeamCash(currentRound.Winner, participants)
	local beforeCount = participantsCount(participants)
	log(string.format("Phase transition: Ended -> WaitingForPlayers. Clearing participants (count=%d)", beforeCount))
	for userId in participants do
		log(string.format("Removing participant at round end. UserId=%s", userId))
		PlayerSessions.removeParticipant(userId)
	end
	PlayerSessions.setRoundWinner("None")
	PlayerSessions.setPhase("WaitingForPlayers", WAITING_RECHECK_DURATION)
	log(
		string.format(
			"Round reset complete. Winner=None NextPhase=WaitingForPlayers duration=%ds",
			WAITING_RECHECK_DURATION
		)
	)
end

local function runLoop()
	log("Round loop started")
	while true do
		local currentRound = PlayerSessions:getState().CurrentRound

		if currentRound.Phase == "InProgress" then
			local participantTotal, lastTeam = getLastParticipantTeam(currentRound.Participants)
			if participantTotal <= 1 then
				local winner: TeamColor = if participantTotal == 1 then lastTeam else "Draw"
				log(
					string.format(
						"InProgress early completion. Participants=%d Winner=%s -> transitioning to Ended",
						participantTotal,
						winner
					)
				)
				PlayerSessions.setRoundWinner(winner)
				PlayerSessions.setPhase("Ended", ENDED_DURATION)
				task.wait(LOOP_TICK_SECONDS)
				continue
			end
		end

		local now = os.time()
		local remaining = currentRound.TimeEnd - now

		if now < currentRound.TimeEnd then
			if remaining <= 5 then
				log(
					string.format(
						"Tick waiting for phase timeout. Phase=%s TimeEnd=%d Remaining=%ds",
						currentRound.Phase,
						currentRound.TimeEnd,
						remaining
					)
				)
			end
			task.wait(LOOP_TICK_SECONDS)
			continue
		end

		local phase = getPhase()
		log(string.format("Phase timeout reached. Processing phase=%s", phase))
		if phase == "WaitingForPlayers" then
			transitionFromWaitingForPlayers()
		elseif phase == "Intermission" then
			transitionFromIntermission()
		elseif phase == "Starting" then
			transitionFromStarting()
		elseif phase == "InProgress" then
			transitionFromInProgress()
		elseif phase == "Ended" then
			transitionFromEnded()
		else
			log(string.format("Unknown phase encountered, no transition performed. Phase=%s", tostring(phase)))
		end

		local updatedRound = PlayerSessions:getState().CurrentRound
		log(
			string.format(
				"Post-transition state. Phase=%s TimeEnd=%d Winner=%s Participants=%d",
				updatedRound.Phase,
				updatedRound.TimeEnd,
				updatedRound.Winner,
				participantsCount(updatedRound.Participants)
			)
		)

		task.wait(LOOP_TICK_SECONDS)
	end
end

function RoundService.initialize()
	log("Initializing RoundService and binding PlayerRemoving cleanup")
	Players.PlayerRemoving:Connect(function(player)
		local participantId = "Player_" .. tostring(player.UserId)
		log(string.format("PlayerRemoving received. Removing participant Id=%s Name=%s", participantId, player.Name))
		PlayerSessions.removeParticipant(participantId)
	end)
end

function RoundService.start()
	log("Starting RoundService loop task")
	task.spawn(runLoop)
end

return RoundService
