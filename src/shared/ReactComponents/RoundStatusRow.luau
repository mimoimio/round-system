local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local Primitives = ReplicatedStorage.Shared.ReactComponents.ui
local HStack = require(Primitives.HStack)
local SmallText = require(Primitives.SmallText)

local e = React.createElement
local useEffect = React.useEffect
local useState = React.useState

local localPlayer = Players.LocalPlayer
local localParticipantId = "Player_" .. tostring(localPlayer.UserId)

local function sumTargets(targets: { [string]: number }): number
	local total = 0
	for _, value in targets do
		total += value
	end
	return total
end

local function RoundStatusRow()
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

	local bullets = if participant then participant.Bullets else 0
	local shields = if participant then participant.PendingShields else 0
	local allocatedShots = if participant then sumTargets(participant.PendingTargets) else 0
	local actionText = if participant then participant.PendingAction else "None"
	local readyText = if participant and participant.IsReady then "Ready" else "Not Ready"
	local aliveText = if participant and participant.IsAlive then "Alive" else "Dead"

	return e(HStack, {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Spacing = UDim.new(0, 14),
		Position = UDim2.new(0, 0, 0, 80),
	}, {
		Bullets = e(SmallText, { Text = "Bullets: " .. tostring(bullets), TextSize = 18 }),
		Shields = e(SmallText, { Text = "Shields: " .. tostring(shields), TextSize = 18 }),
		Shots = e(SmallText, { Text = "Shot Alloc: " .. tostring(allocatedShots), TextSize = 18 }),
		Action = e(SmallText, { Text = "Action: " .. actionText, TextSize = 18 }),
		Ready = e(SmallText, { Text = readyText, TextSize = 18 }),
		Alive = e(SmallText, { Text = aliveText, TextSize = 18 }),
	})
end

return RoundStatusRow
