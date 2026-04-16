--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoffeeModule = require(ReplicatedStorage.Shared.CoffeeModule)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CraftingService = {}

type CoffeeConfigType = CoffeeModule.CoffeeConfigType

local function getParticipantId(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

local function getCurrentIngredients(cupId: string): { string }
	if cupId == "Empty" then
		return {}
	end

	local config = CoffeeModule.Config[cupId] :: CoffeeConfigType?
	if config and config.Ingredients then
		return table.clone(config.Ingredients)
	end

	return {}
end

local function craftCombined(ingredients: { string }): CoffeeConfigType?
	local craftFn = (CoffeeModule :: any).craft or CoffeeModule.Craft
	if type(craftFn) ~= "function" then
		return nil
	end

	return craftFn(ingredients)
end

local function handleServe(participantId: string, participant: PlayerSessions.ParticipantEntity)
	if participant.CupId == "Empty" then
		return
	end

	local matchIndex: number? = nil
	for index, orderId in ipairs(participant.ActiveOrders) do
		if orderId == participant.CupId then
			matchIndex = index
			break
		end
	end

	if not matchIndex then
		return
	end

	local updatedOrders = table.clone(participant.ActiveOrders)
	table.remove(updatedOrders, matchIndex)

	PlayerSessions.setParticipantActiveOrders(participantId, updatedOrders)
	PlayerSessions.addPlayerCash(participant.PlayerId, 1)
	PlayerSessions.addParticipantPoint(participantId, 1)
	PlayerSessions.setParticipantCupId(participantId, "Empty")
	return true
end

function CraftingService.initialize()
	Remotes.InteractStation.OnServerEvent:Connect(function(player: Player, ingredientId: string)
		if type(ingredientId) ~= "string" or ingredientId == "" then
			return
		end

		local normalizedIngredientId = ingredientId
		if string.lower(ingredientId) == "trash" then
			normalizedIngredientId = "Trash"
		elseif string.lower(ingredientId) == "serve" then
			normalizedIngredientId = "Serve"
		else
			normalizedIngredientId = string.lower(ingredientId)
		end

		local participantId = getParticipantId(player)
		local participant = PlayerSessions:getState().CurrentRound.Participants[participantId]
		if not participant then
			return
		end

		if normalizedIngredientId == "Trash" then
			PlayerSessions.setParticipantCupId(participantId, "Empty")
			return
		end

		if normalizedIngredientId == "Serve" then
			handleServe(participantId, participant)
			PlayerSessions.setParticipantCupId(participantId, "Empty")
			return
		end

		local combined = getCurrentIngredients(participant.CupId)
		table.insert(combined, normalizedIngredientId)

		local result = craftCombined(combined)
		if result and result.Id then
			PlayerSessions.setParticipantCupId(participantId, result.Id)
			return
		end
	end)
end

return CraftingService
