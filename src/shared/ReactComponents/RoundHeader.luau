local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local Primitives = ReplicatedStorage.Shared.ReactComponents.ui
local SmallText = require(Primitives.SmallText)

local e = React.createElement
local useEffect = React.useEffect
local useState = React.useState

local localPlayer = Players.LocalPlayer
local localParticipantId = "Player_" .. tostring(localPlayer.UserId)

local function RoundHeader()
	local roundState, setRoundState = useState(function()
		return PlayerSessions:getState().CurrentRound
	end)
	local participant, setParticipant = useState(function()
		return PlayerSessions:getState().CurrentRound.Participants[localParticipantId]
	end)
	local now, setNow = useState(os.time())

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

		local heartbeat = RunService.Heartbeat:Connect(function()
			setNow(os.time())
		end)

		return function()
			unsubscribeRound()
			unsubscribeParticipant()
			heartbeat:Disconnect()
		end
	end, {})

	local isParticipant = participant ~= nil
	local winner = roundState.WinnerParticipantId
	local remaining = math.max(0, roundState.TimeEnd - now)

	return e(React.Fragment, nil, {
		-- Header = e(SmallText, {
		-- 	Text = string.format("%s | Turn %d | %ds", roundState.Phase, roundState.TurnIndex, remaining),
		-- 	TextSize = 26,
		-- }),
		SpectatorBanner = if not isParticipant
			then e(SmallText, {
				Text = "Spectating - waiting to join next round",
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 0),
				Position = UDim2.new(0, 0, 0, 40),
			})
			else nil,
		-- Winner = winner and e(SmallText, {
		-- 	Text = "Winner: " .. winner,
		-- 	TextSize = 20,
		-- }) or nil,
	})
end

return RoundHeader
