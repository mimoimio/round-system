--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local InputService = {}
local DEBUG_INPUT_LOGS = true

type InputRequest = "Load" | "ToggleReady" | "AddShield" | "RemoveShield" | "AddTarget" | "RemoveTarget" | "Aim"

local function logInput(message: string)
	if DEBUG_INPUT_LOGS then
		print("[Pistol/InputService] " .. message)
	end
end

local function getParticipantId(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

local function totalAllocatedShots(targets: { [string]: number }): number
	local total = 0
	for _, value in targets do
		total += value
	end
	return total
end

local function canAcceptInput(participant: PlayerSessions.ParticipantEntity, phase: PlayerSessions.Phase): boolean
	return phase == "ActionInput" and participant.IsAlive
end

local function setShootMode(participantId: string, participant: PlayerSessions.ParticipantEntity)
	if participant.PendingAction ~= "Shoot" then
		PlayerSessions.setParticipantPendingAction(participantId, "Shoot")
		PlayerSessions.clearParticipantPending(participantId)
	end
end

local function setShieldMode(participantId: string, participant: PlayerSessions.ParticipantEntity)
	if participant.PendingAction ~= "Shield" then
		PlayerSessions.clearParticipantPending(participantId)
		PlayerSessions.setParticipantPendingAction(participantId, "Shield")
	end
end

function InputService.initialize()
	Remotes.PistolInput.OnServerEvent:Connect(
		function(player: Player, request: InputRequest, targetParticipantId: string?)
			if type(request) ~= "string" then
				logInput(string.format("Ignored non-string request from %s", player.Name))
				return
			end

			local state = PlayerSessions:getState()
			local participantId = getParticipantId(player)
			local participant = state.CurrentRound.Participants[participantId]
			logInput(
				string.format(
					"Request=%s from %s participant=%s phase=%s",
					request,
					player.Name,
					participantId,
					state.CurrentRound.Phase
				)
			)
			if not participant then
				logInput(
					string.format("Rejected %s for %s: participant missing in CurrentRound", request, participantId)
				)
				return
			end

			if not participant.IsAlive then
				logInput(string.format("Rejected %s for %s: participant is dead", request, participantId))
				return
			end

			if not canAcceptInput(participant, state.CurrentRound.Phase) then
				logInput(
					string.format(
						"Rejected %s for %s: phase=%s (expected ActionInput)",
						request,
						participantId,
						state.CurrentRound.Phase
					)
				)
				return
			end

			if request == "Load" then
				PlayerSessions.clearParticipantPending(participantId)
				PlayerSessions.setParticipantPendingAction(participantId, "Load")
				PlayerSessions.setParticipantReady(participantId, false)
				logInput(string.format("Accepted Load for %s", participantId))
				return
			end

			if request == "Aim" then
				if participant.PendingAction == "Shoot" then
					return
				end
				PlayerSessions.clearParticipantPending(participantId)
				PlayerSessions.setParticipantPendingAction(participantId, "Shoot")
				PlayerSessions.setParticipantReady(participantId, false)
				logInput(string.format("Accepted Load for %s", participantId))
				return
			end

			if request == "ToggleReady" then
				PlayerSessions.setParticipantReady(participantId, not participant.IsReady)
				logInput(
					string.format("Accepted ToggleReady for %s -> %s", participantId, tostring(not participant.IsReady))
				)
				return
			end

			if request == "AddShield" then
				setShieldMode(participantId, participant)
				local updated = PlayerSessions:getState().CurrentRound.Participants[participantId]
				if updated then
					PlayerSessions.addParticipantShield(participantId, 1)
					PlayerSessions.setParticipantReady(participantId, false)
					logInput(string.format("Accepted AddShield for %s -> pendingShields +1", participantId))
				end
				return
			end

			if request == "RemoveShield" then
				if participant.PendingAction ~= "Shield" or participant.PendingShields <= 0 then
					logInput(
						string.format(
							"Rejected RemoveShield for %s: action=%s shields=%d",
							participantId,
							participant.PendingAction,
							participant.PendingShields
						)
					)
					return
				end
				PlayerSessions.addParticipantShield(participantId, -1)
				local updated = PlayerSessions:getState().CurrentRound.Participants[participantId]
				if updated and updated.PendingShields == 0 then
					PlayerSessions.setParticipantPendingAction(participantId, "None")
				end
				PlayerSessions.setParticipantReady(participantId, false)
				logInput(string.format("Accepted RemoveShield for %s", participantId))
				return
			end

			if request == "AddTarget" then
				if type(targetParticipantId) ~= "string" or targetParticipantId == "" then
					logInput(string.format("Rejected AddTarget for %s: missing targetParticipantId", participantId))
					return
				end
				if targetParticipantId == participantId then
					logInput(string.format("Rejected AddTarget for %s: cannot target self", participantId))
					return
				end

				local target = PlayerSessions:getState().CurrentRound.Participants[targetParticipantId]
				if not target or not target.IsAlive then
					logInput(
						string.format(
							"Rejected AddTarget for %s: target %s missing or dead",
							participantId,
							tostring(targetParticipantId)
						)
					)
					return
				end

				setShootMode(participantId, participant)
				local updated = PlayerSessions:getState().CurrentRound.Participants[participantId]
				if not updated then
					logInput(
						string.format(
							"Rejected AddTarget for %s: participant disappeared after mode set",
							participantId
						)
					)
					return
				end

				local allocated = totalAllocatedShots(updated.PendingTargets)
				if allocated >= updated.Bullets then
					logInput(
						string.format(
							"Rejected AddTarget for %s: allocated=%d bullets=%d",
							participantId,
							allocated,
							updated.Bullets
						)
					)
					return
				end

				local current = updated.PendingTargets[targetParticipantId] or 0
				PlayerSessions.setParticipantTargetAllocation(participantId, targetParticipantId, current + 1)
				PlayerSessions.setParticipantReady(participantId, false)
				logInput(
					string.format(
						"Accepted AddTarget for %s -> %s now %d",
						participantId,
						targetParticipantId,
						current + 1
					)
				)
				return
			end

			if request == "RemoveTarget" then
				if type(targetParticipantId) ~= "string" or targetParticipantId == "" then
					logInput(string.format("Rejected RemoveTarget for %s: missing targetParticipantId", participantId))
					return
				end
				if participant.PendingAction ~= "Shoot" then
					logInput(
						string.format(
							"Rejected RemoveTarget for %s: action is %s (expected Shoot)",
							participantId,
							participant.PendingAction
						)
					)
					return
				end

				local current = participant.PendingTargets[targetParticipantId] or 0
				if current <= 0 then
					logInput(
						string.format(
							"Rejected RemoveTarget for %s: target %s has no allocation",
							participantId,
							targetParticipantId
						)
					)
					return
				end

				PlayerSessions.setParticipantTargetAllocation(participantId, targetParticipantId, current - 1)
				local updated = PlayerSessions:getState().CurrentRound.Participants[participantId]
				if updated and totalAllocatedShots(updated.PendingTargets) == 0 then
					PlayerSessions.setParticipantPendingAction(participantId, "None")
				end
				PlayerSessions.setParticipantReady(participantId, false)
				logInput(
					string.format(
						"Accepted RemoveTarget for %s -> %s now %d",
						participantId,
						targetParticipantId,
						current - 1
					)
				)
				return
			end

			logInput(string.format("Ignored unknown request '%s' from %s", request, participantId))
		end
	)
end

return InputService
