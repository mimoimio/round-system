--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ResolutionService = {}
local DEBUG_RESOLUTION_LOGS = false

local function logResolution(message: string)
	if DEBUG_RESOLUTION_LOGS then
		print("[Pistol/ResolutionService] " .. message)
	end
end

local function getShot(shots: { [string]: { [string]: number } }, fromId: string, toId: string): number
	local fromMap = shots[fromId]
	if not fromMap then
		return 0
	end
	return fromMap[toId] or 0
end

local function setShot(shots: { [string]: { [string]: number } }, fromId: string, toId: string, value: number)
	if value <= 0 then
		return
	end
	if not shots[fromId] then
		shots[fromId] = {}
	end
	shots[fromId][toId] = value
end

local function sumTargets(targets: { [string]: number }): number
	local total = 0
	for _, amount in targets do
		total += amount
	end
	return total
end

local function fireCombatFeedback(
	participants: { [string]: PlayerSessions.ParticipantEntity },
	participantId: string,
	eventType: string,
	payload: { [string]: any }
)
	local participant = participants[participantId]
	if not participant then
		return
	end

	local userId = tonumber(participant.PlayerId)
	if not userId then
		return
	end

	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end

	Remotes.CombatFeedback:FireClient(player, eventType, payload)
end

function ResolutionService.ResolveCurrentTurn()
	local currentRound = PlayerSessions:getState().CurrentRound
	local participants = currentRound.Participants

	local participantCount = 0
	for _ in participants do
		participantCount += 1
	end
	logResolution(string.format("Resolve start | phase=%s participants=%d", currentRound.Phase, participantCount))

	local aliveIds = {}
	for participantId, participant in participants do
		if participant.IsAlive then
			table.insert(aliveIds, participantId)
		end
	end
	table.sort(aliveIds)
	logResolution("Alive participants: " .. table.concat(aliveIds, ", "))

	local rawShots: { [string]: { [string]: number } } = {}

	for _, shooterId in aliveIds do
		local shooter = participants[shooterId]
		if shooter and shooter.PendingAction == "Load" then
			logResolution(string.format("%s action=Load bullets(before)=%d", shooterId, shooter.Bullets))
			PlayerSessions.addParticipantBullets(shooterId, 1)
		elseif shooter and shooter.PendingAction == "Shoot" then
			local allocated = math.min(sumTargets(shooter.PendingTargets), shooter.Bullets)
			logResolution(
				string.format(
					"%s action=Shoot bullets=%d requested=%d accepted=%d",
					shooterId,
					shooter.Bullets,
					sumTargets(shooter.PendingTargets),
					allocated
				)
			)
			if allocated > 0 then
				PlayerSessions.addParticipantBullets(shooterId, -allocated)
			end

			local remaining = allocated
			for targetId, requested in shooter.PendingTargets do
				if remaining <= 0 then
					break
				end
				local target = participants[targetId]
				if target and target.IsAlive then
					local accepted = math.min(requested, remaining)
					if accepted > 0 then
						logResolution(string.format("Shot accepted: %s -> %s amount=%d", shooterId, targetId, accepted))
						setShot(rawShots, shooterId, targetId, accepted)
						remaining -= accepted
					end
				end
			end
		elseif shooter then
			logResolution(string.format("%s action=%s (no direct ammo change)", shooterId, shooter.PendingAction))
		end
	end

	local effectiveShots: { [string]: { [string]: number } } = {}
	for i = 1, #aliveIds do
		for j = i + 1, #aliveIds do
			local aId = aliveIds[i]
			local bId = aliveIds[j]
			local aToB = getShot(rawShots, aId, bId)
			local bToA = getShot(rawShots, bId, aId)
			setShot(effectiveShots, aId, bId, math.max(0, aToB - bToA))
			setShot(effectiveShots, bId, aId, math.max(0, bToA - aToB))
		end
	end

	local incomingByTarget: { [string]: number } = {}
	local contributorsByTarget: { [string]: { [string]: number } } = {}
	for shooterId, targetMap in effectiveShots do
		for targetId, amount in targetMap do
			if amount > 0 then
				incomingByTarget[targetId] = (incomingByTarget[targetId] or 0) + amount
				if not contributorsByTarget[targetId] then
					contributorsByTarget[targetId] = {}
				end
				contributorsByTarget[targetId][shooterId] = amount
			end
		end
	end

	for _, targetId in aliveIds do
		local participant = participants[targetId]
		if participant then
			local incoming = incomingByTarget[targetId] or 0
			local shields = if participant.PendingAction == "Shield" then participant.PendingShields else 0
			local survives = incoming == 0 or incoming == shields
			local killers = {}
			local shooters = contributorsByTarget[targetId]
			if shooters then
				for shooterId, amount in shooters do
					if amount > 0 then
						table.insert(killers, shooterId)
					end
				end
				table.sort(killers)
			end
			logResolution(
				string.format(
					"Resolve target=%s incoming=%d shields=%d action=%s survives=%s",
					targetId,
					incoming,
					shields,
					participant.PendingAction,
					tostring(survives)
				)
			)
			if not survives then
				PlayerSessions.setParticipantAlive(targetId, false)
				PlayerSessions.clearParticipantPending(targetId)
				fireCombatFeedback(participants, targetId, "death", {
					participantId = targetId,
					incoming = incoming,
					shields = shields,
					killerIds = killers,
				})
				logResolution(string.format("Participant died: %s", targetId))
			elseif incoming > 0 and shields > 0 and incoming == shields then
				fireCombatFeedback(participants, targetId, "block", {
					participantId = targetId,
					incoming = incoming,
					shields = shields,
				})
			end
		end
	end

	local state: PlayerSessions.PlayersState = PlayerSessions:getState()
	for targetId, shooters in contributorsByTarget do
		local target = participants[targetId]
		if target and not PlayerSessions:getState().CurrentRound.Participants[targetId].IsAlive then
			local shooterIds = {}
			for shooterId, amount in shooters do
				if amount > 0 then
					table.insert(shooterIds, shooterId)
				end
			end

			if #shooterIds == 1 then
				PlayerSessions.addPlayerKill(shooterIds[1], 1)
				local participant = state.CurrentRound.Participants[shooterIds[1]]
				PlayerSessions.addPlayerCash(participant.PlayerId, 3)

				fireCombatFeedback(participants, shooterIds[1], "kill", {
					targetId = targetId,
				})
				logResolution(string.format("Kill credit: killer=%s target=%s", shooterIds[1], targetId))
			elseif #shooterIds > 1 then
				for _, shooterId in shooterIds do
					PlayerSessions.addPlayerAssist(shooterId, 1)
					local participant = state.CurrentRound.Participants[shooterId]
					PlayerSessions.addPlayerCash(participant.PlayerId, 1)
					fireCombatFeedback(participants, shooterId, "assist", {
						targetId = targetId,
					})
					logResolution(string.format("Assist credit: assister=%s target=%s", shooterId, targetId))
				end
			end
		end
	end

	for participantId in participants do
		PlayerSessions.clearParticipantPending(participantId)
	end

	logResolution("Resolve end; pending inputs cleared")
end

return ResolutionService
