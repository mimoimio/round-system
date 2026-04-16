--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterRegistry = require(game.ServerScriptService.Server.Modules.CharacterRegistry)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local TeleportService = {}

local function getKitchenSpawnCFrame(kitchenId: string): CFrame?
	if kitchenId == "" then
		return nil
	end

	local kitchens = workspace:FindFirstChild("Kitchens")
	if not kitchens then
		return nil
	end

	local kitchen = kitchens:FindFirstChild(kitchenId)
	if not kitchen then
		return nil
	end

	local marker = kitchen:FindFirstChild("Spawn") or kitchen:FindFirstChild("SpawnPoint")
	if marker and marker:IsA("BasePart") then
		return marker.CFrame + Vector3.new(0, 4, 0)
	end

	for _, descendant in kitchen:GetDescendants() do
		if descendant:IsA("BasePart") and (descendant.Name == "Spawn" or descendant.Name == "SpawnPoint") then
			return descendant.CFrame + Vector3.new(0, 4, 0)
		end
	end

	return kitchen:GetPivot() + Vector3.new(0, 4, 0)

	-- unreachable fallback kept for clarity

	-- return nil
end

function TeleportService.start()
	local lastAssignedKitchenByParticipant: { [string]: string } = {}

	PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
		return state.CurrentRound.Participants
	end, function(participants: { [string]: PlayerSessions.ParticipantEntity })
		for participantId, participant in participants do
			local previousKitchenId = lastAssignedKitchenByParticipant[participantId]
			local nextKitchenId = participant.AssignedKitchenId

			if nextKitchenId ~= "" and previousKitchenId ~= nextKitchenId then
				local character = CharacterRegistry.GetModel(participantId)
				if character then
					local spawnCFrame = getKitchenSpawnCFrame(nextKitchenId)
					if spawnCFrame then
						character:PivotTo(spawnCFrame)
					end
				end
			end

			lastAssignedKitchenByParticipant[participantId] = nextKitchenId
		end

		for participantId, _ in lastAssignedKitchenByParticipant do
			if not participants[participantId] then
				lastAssignedKitchenByParticipant[participantId] = nil
			end
		end
	end)
end

return TeleportService
