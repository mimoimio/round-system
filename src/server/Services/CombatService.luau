--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterRegistry = require(game.ServerScriptService.Server.Modules.CharacterRegistry)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local CombatService = {}
local KILL_REWARD_CASH = 5
local ENABLE_REWARD_LOGS = true

local function rewardLog(message: string)
	if ENABLE_REWARD_LOGS then
		print(string.format("[CombatService][Rewards] %s", message))
	end
end

function CombatService.start()
	PlayerSessions:observe(function(state: PlayerSessions.PlayersState)
		return state.CurrentRound.Participants
	end, function(_: PlayerSessions.ParticipantEntity, participantId: string)
		return participantId
	end, function(_: PlayerSessions.ParticipantEntity, participantId: string)
		local character = CharacterRegistry.GetModel(participantId)
		if not character then
			return function() end
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return function() end
		end

		local connection = humanoid.Died:Connect(function()
			local creatorTag = humanoid:FindFirstChild("creator")
			if creatorTag and creatorTag:IsA("ObjectValue") and creatorTag.Value and creatorTag.Value:IsA("Player") then
				local killer = creatorTag.Value
				local victim = Players:GetPlayerFromCharacter(character)
				if killer ~= victim then
					PlayerSessions.addPlayerCash(tostring(killer.UserId), KILL_REWARD_CASH)
					rewardLog(
						string.format(
							"Kill reward granted. Killer=%s Victim=%s Amount=%d",
							killer.Name,
							if victim then victim.Name else participantId,
							KILL_REWARD_CASH
						)
					)
				else
					rewardLog(string.format("No kill reward (self-kill). Player=%s", killer.Name))
				end
			else
				rewardLog(string.format("No kill reward (missing creator tag). Participant=%s", participantId))
			end

			PlayerSessions.removeParticipant(participantId)
		end)

		return function()
			connection:Disconnect()
		end
	end)
end

-- return CombatService
return {}
