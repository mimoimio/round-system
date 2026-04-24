--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local InputService = {}

function InputService.initialize()
	Remotes.Ready.OnServerEvent:Connect(function(player: Player)
		PlayerSessions.setPlayerPhase(tostring(player.UserId), "Ready")
	end)
end

return InputService
