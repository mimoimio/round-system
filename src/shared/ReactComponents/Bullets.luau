local Players = game:GetService("Players")

local React = require(game.ReplicatedStorage.Packages.React)
local PlayerSessions = require(game.ReplicatedStorage.Shared.producers.PlayerSessions)
local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local HStack = require(game.ReplicatedStorage.Shared.ReactComponents.ui.HStack)
local Bullet = require(game.ReplicatedStorage.Shared.ReactComponents.Bullet)

local localParticipantId = "Player_" .. tostring(Players.LocalPlayer.UserId)

local function Bullets(props)
	local participant, setParticipant = useState(function()
		return PlayerSessions:getState().CurrentRound.Participants[localParticipantId]
	end)

	useEffect(function()
		local unsubscribeParticipant = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound.Participants[localParticipantId]
		end, function(nextParticipant)
			setParticipant(nextParticipant)
		end)

		return function()
			unsubscribeParticipant()
		end
	end, {})

	local amount = if props and type(props.Amount) == "number"
		then props.Amount
		else if participant then participant.Bullets else 0
	local children = {}
	for i = 1, amount do
		children[i] = e(Bullet)
	end
	return e(HStack, {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromScale(0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 1),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Position = props.Position or UDim2.new(0, 0, 1, 0),
		Padding = {
			All = UDim.new(0, 8),
		},
		Spacing = UDim.new(0, 8),
	}, children)
end
return Bullets
