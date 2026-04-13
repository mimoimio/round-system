--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterRegistry = require(game.ServerScriptService.Server.Modules.CharacterRegistry)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local TeleportService = {}

local MAP_CENTER = Vector3.new(200, 0, 200)

function TeleportService.start()
	PlayerSessions:observe(function(state: PlayerSessions.PlayersState)
		return state.CurrentRound.Participants
	end, function(_: PlayerSessions.ParticipantEntity, participantId: string)
		return participantId
	end, function(_: PlayerSessions.ParticipantEntity, participantId: string)
		local character = CharacterRegistry.GetModel(participantId)
		if character then
			local offsetX = math.random(-29, 29)
			local offsetZ = math.random(-29, 29)
			local spawnPosition = MAP_CENTER + Vector3.new(offsetX, 5, offsetZ)
			character:PivotTo(CFrame.new(spawnPosition))
		end

		return function() end
	end)
end

return TeleportService
