local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local e = React.createElement
local useBinding = React.useBinding
local useEffect = React.useEffect
local useRef = React.useRef
local useState = React.useState

local function RoundPhaseProgressBar()
	local progressBinding, setProgressBinding = useBinding(0)
	local phaseStartClockRef = useRef(os.clock())
	local phaseDurationRef = useRef(1)
	local roundState, setRoundState = useState(function()
		return PlayerSessions:getState().CurrentRound
	end)

	useEffect(function()
		local unsubscribeRound = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound
		end, function(nextRound)
			setRoundState(nextRound)
		end)
		local cr = PlayerSessions:getState().CurrentRound
		setRoundState(cr)
		warn("setRound", cr)
		return function()
			unsubscribeRound()
		end
	end, {})

	useEffect(function()
		local remainingAtSync = math.max(0, roundState.TimeEnd - os.time())
		phaseDurationRef.current = math.max(1, remainingAtSync)
		phaseStartClockRef.current = os.clock()
		setProgressBinding(0)
	end, { roundState.Phase, roundState.TimeEnd })

	useEffect(function()
		local heartbeat = RunService.Heartbeat:Connect(function()
			local elapsed = os.clock() - phaseStartClockRef.current
			local progress = math.clamp(elapsed / phaseDurationRef.current, 0, 1)
			setProgressBinding(progress)
		end)

		return function()
			heartbeat:Disconnect()
		end
	end, {})

	return e("Frame", {
		Size = UDim2.fromScale(1, 0.015),
		BackgroundColor3 = Color3.fromRGB(36, 36, 36),
		AnchorPoint = Vector2.new(0, 1),
		BorderSizePixel = 0,
		ZIndex = 0,
	}, {
		Fill = e("Frame", {
			Size = progressBinding:map(function(progress)
				return UDim2.fromScale(roundState.Phase == "Resolution" and 0 or progress, 1)
			end),
			BackgroundColor3 = Color3.fromRGB(255, 183, 77),
			BorderSizePixel = 0,
			ZIndex = 1,
		}),
	})
end

return RoundPhaseProgressBar
