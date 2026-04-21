local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local Primitives = ReplicatedStorage.Shared.ReactComponents.ui
local VStack = require(Primitives.VStack)
local SmallText = require(Primitives.SmallText)

local e = React.createElement
local useEffect = React.useEffect
local useMemo = React.useMemo
local useState = React.useState

type TargetItem = {
	targetId: string,
	amount: number,
}

local localPlayer = Players.LocalPlayer
local localParticipantId = "Player_" .. tostring(localPlayer.UserId)

local function TargetAllocationsPanel()
	local roundState, setRoundState = useState(function()
		return PlayerSessions:getState().CurrentRound
	end)
	local participant, setParticipant = useState(function()
		return PlayerSessions:getState().CurrentRound.Participants[localParticipantId]
	end)

	useEffect(function()
		local unsubscribeRound = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound
		end, function(nextRound)
			setRoundState(nextRound)
		end)

		local unsubscribeParticipant = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound.Participants[localParticipantId]
		end, function(nextParticipant)
			setParticipant(nextParticipant)
		end)

		return function()
			unsubscribeRound()
			unsubscribeParticipant()
		end
	end, {})

	local isActionInput = roundState.Phase == "ActionInput"
	local isParticipantAlive = participant ~= nil and participant.IsAlive == true
	local pendingTargets = if participant then participant.PendingTargets else {}
	local sortedTargets = useMemo(function()
		local items: { TargetItem } = {}
		for targetId, amount in pendingTargets do
			table.insert(items, { targetId = targetId, amount = amount })
		end
		table.sort(items, function(a, b)
			return a.targetId < b.targetId
		end)
		return items
	end, { pendingTargets })

	if not (isActionInput and isParticipantAlive) then
		return nil
	end

	local targetChildren = {}
	if #sortedTargets == 0 then
		targetChildren.Empty = e(SmallText, {
			Text = "No target allocations",
			TextSize = 16,
		})
	else
		for i, item in ipairs(sortedTargets) do
			targetChildren["Target_" .. tostring(i)] = e(SmallText, {
				Text = string.format("%s x%d", item.targetId, item.amount),
				TextSize = 16,
				LayoutOrder = i,
			})
		end
	end

	return e(React.Fragment, nil, {
		TargetsTitle = e(SmallText, {
			Text = "Target Allocations",
			TextSize = 20,
		}),
		Targets = e(VStack, {
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalFlex = Enum.UIFlexAlignment.None,
			Spacing = UDim.new(0, 4),
		}, targetChildren),
	})
end

return TargetAllocationsPanel
