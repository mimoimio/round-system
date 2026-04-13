local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local e = React.createElement

local function Main(props)
	local roundState, setRoundState = React.useState(function()
		return PlayerSessions:getState().CurrentRound
	end)
	local now, setNow = React.useState(os.time())

	React.useEffect(function()
		local unsubscribe = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound
		end, function(nextRound)
			setRoundState(nextRound)
		end)

		return unsubscribe
	end, {})

	React.useEffect(function()
		local connection = RunService.Heartbeat:Connect(function()
			setNow(os.time())
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	local remaining = math.max(0, roundState.TimeEnd - now)
	local showCountdown = roundState.Phase ~= "InProgress"

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Countdown = showCountdown and e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.05),
			Size = UDim2.fromOffset(420, 52),
			BackgroundTransparency = 0.35,
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			Text = string.format("%s | %ds", roundState.Phase, remaining),
		}) or nil,
	})
end
return Main
