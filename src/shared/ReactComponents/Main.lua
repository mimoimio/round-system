local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local IngredientProximityPrompts = require(script.Parent.IngredientProximityPrompts)
local IngredientPromptController = require(script.Parent.IngredientPromptController)
local RoundHUD = require(script.Parent.HUD.RoundHUD)
local useToast = require(script.Parent.Toasts).useToast

local e = React.createElement
local useState = React.useState

local localPlayer = Players.LocalPlayer
local localParticipantId = "Player_" .. tostring(localPlayer.UserId)
local EMPTY_ORDERS: { string } = table.freeze({})

local function Main(props)
	local roundState, setRoundState = useState(function()
		return PlayerSessions:getState().CurrentRound
	end)
	local toast = useToast()
	local assignedKitchenId, setAssignedKitchenId = useState("")
	local activeOrders, setActiveOrders = useState({} :: { string })
	local cash, setCash = useState(nil)

	React.useEffect(function()
		local unsubscribeRound = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound
		end, function(nextRound)
			setRoundState(nextRound)
		end)

		local unsubscribeKitchen = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			local participant = state.CurrentRound.Participants[localParticipantId]
			return if participant then participant.AssignedKitchenId else ""
		end, function(nextKitchenId: string)
			setAssignedKitchenId(nextKitchenId)
		end)

		local unsubscribeOrders = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			local participant = state.CurrentRound.Participants[localParticipantId]
			return if participant then participant.ActiveOrders else EMPTY_ORDERS
		end, function(nextOrders: { string })
			setActiveOrders(nextOrders)
		end)
		local unsubCash = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			local playerEntity = state.players[tostring(localPlayer.UserId)]
			return if playerEntity and playerEntity.Data then playerEntity.Data.Cash else nil
		end, function(nextCash: number?)
			setCash(function(prev)
				if prev then
					toast.open("+$" .. (nextCash - prev))
				end
				return nextCash
			end)
		end)
		local state = PlayerSessions:getState()
		local playerEntity = state.players[tostring(localPlayer.UserId)]
		local xcash = if playerEntity and playerEntity.Data then playerEntity.Data.Cash else nil

		setCash(xcash)

		return function()
			unsubscribeRound()
			unsubscribeKitchen()
			unsubscribeOrders()
			unsubCash()
		end
	end, {})

	return e(React.Fragment, nil, {
		PromptController = e(IngredientPromptController, {
			AssignedKitchenId = assignedKitchenId,
		}),
		HUD = e(RoundHUD, {
			Phase = roundState.Phase,
			TimeEnd = roundState.TimeEnd,
			AssignedKitchenId = assignedKitchenId,
			ActiveOrders = activeOrders,
		}),
		IngredientPrompts = e(IngredientProximityPrompts),
	})
end

return Main
