--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoffeeModule = require(ReplicatedStorage.Shared.CoffeeModule)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local CharacterRegistry = require(game.ServerScriptService.Server.Modules.CharacterRegistry)

local ParticipantService = {}

local ROUND_ORDER_COUNT = 3

local function getLobbyCFrame(): CFrame
	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		return spawnLocation.CFrame + Vector3.new(0, 5, 0)
	end

	return CFrame.new(0, 10, 0)
end

local function sendCharacterToLobby(character: Model)
	if character.Parent then
		character:PivotTo(getLobbyCFrame())
	end
end

local function getKitchenIds(): { string }
	local ids = {}
	local kitchensFolder = workspace:FindFirstChild("Kitchens")
	if not kitchensFolder then
		return ids
	end

	for _, kitchen in kitchensFolder:GetChildren() do
		table.insert(ids, kitchen.Name)
	end

	table.sort(ids)
	return ids
end

local function registerPlayerParticipants()
	local kitchenIds = getKitchenIds()
	local kitchenCount = #kitchenIds
	local playerIndex = 0

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			playerIndex += 1
			local playerId = tostring(player.UserId)
			local id = "Player_" .. playerId
			local assignedKitchenId = if kitchenCount > 0
				then kitchenIds[((playerIndex - 1) % kitchenCount) + 1]
				else ""

			CharacterRegistry.Register(id, character)
			PlayerSessions.addParticipant(playerId, id, "Red") -- changed addParticipant to store a UserId:number, so can easily get player entity.
			PlayerSessions.setParticipantAssignedKitchenId(id, assignedKitchenId)
			PlayerSessions.setParticipantCupId(id, "Empty")
			PlayerSessions.setParticipantActiveOrders(id, {})
		end
	end
end

local function getRoundOrderPool(): { string }
	local pool = {}
	for _, config in ipairs(CoffeeModule.Array) do
		if
			config.Id ~= "Empty"
			and config.Ingredients
			and #config.Ingredients > 1
			and not CoffeeModule.Unorderables[config.Id]
		then
			table.insert(pool, config.Id)
		end
	end

	return pool
end

local function buildSharedRoundOrders(): { string }
	local pool = getRoundOrderPool()
	if #pool == 0 then
		return {}
	end

	local orders = {}
	for _ = 1, ROUND_ORDER_COUNT do
		table.insert(orders, pool[math.random(1, #pool)])
	end

	return orders
end

local function assignOrdersForCurrentRound()
	local sharedOrders = buildSharedRoundOrders()
	for participantId, _ in PlayerSessions:getState().CurrentRound.Participants do
		PlayerSessions.setParticipantActiveOrders(participantId, table.clone(sharedOrders))
	end
end

function ParticipantService.initialize()
	Players.PlayerRemoving:Connect(function(player)
		local id = "Player_" .. tostring(player.UserId)
		CharacterRegistry.Unregister(id)
	end)
end

function ParticipantService.start()
	PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
		return state.CurrentRound.Phase
	end, function(phase: PlayerSessions.Phase, previousPhase: PlayerSessions.Phase)
		if phase == "Starting" and previousPhase ~= "Starting" then
			registerPlayerParticipants()
			assignOrdersForCurrentRound()
		end
	end)

	PlayerSessions:observe(function(state: PlayerSessions.PlayersState)
		return state.CurrentRound.Participants
	end, function(_: PlayerSessions.ParticipantEntity, participantId: string)
		return participantId
	end, function(_: PlayerSessions.ParticipantEntity, participantId: string)
		return function()
			local character = CharacterRegistry.GetModel(participantId)
			if character then
				if string.sub(participantId, 1, 7) == "Player_" then
					sendCharacterToLobby(character)
				end
			end
			CharacterRegistry.Unregister(participantId)
		end
	end)
end

return ParticipantService
