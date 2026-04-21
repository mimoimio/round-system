local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactFlow = require(ReplicatedStorage.Packages.ReactFlow)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local SoundController = require(ReplicatedStorage.Shared.Controllers.SoundController)

local Primitives = ReplicatedStorage.Shared.ReactComponents.ui
local VStack = require(Primitives.VStack)
local SmallText = require(Primitives.SmallText)

local e = React.createElement
local useEffect = React.useEffect
local useRef = React.useRef
local useState = React.useState
local useSpring = ReactFlow.useSpring
local useTween = ReactFlow.useTween

local function RoundStartFlash()
	local roundPhase, setRoundPhase = useState(function()
		return PlayerSessions:getState().CurrentRound.Phase
	end)
	local previousPhaseRef = useRef(roundPhase)
	local sequenceTokenRef = useRef(0)
	local visible, setVisible = useState(false)

	useEffect(function()
		local unsubscribePhase = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound.Phase
		end, function(nextPhase)
			setRoundPhase(nextPhase)
		end)

		return function()
			unsubscribePhase()
		end
	end, {})

	local flashTransparency, setFlashTransparency = useTween({
		start = 1,
		target = 1,
		info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	})
	local textTransparency, setTextTransparency = useTween({
		start = 1,
		target = 1,
		info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	})
	local barScale, setBarScale = useSpring({
		start = 0.2,
		target = 0.2,
		speed = 18,
		damper = 0.7,
	})
	local titleScale, setTitleScale = useSpring({
		start = 1.6,
		target = 1.6,
		speed = 22,
		damper = 0.65,
	})

	useEffect(function()
		local previousPhase = previousPhaseRef.current
		local nextPhase = roundPhase
		local shouldTrigger = previousPhase == "Intermission" and nextPhase == "ActionInput"
		previousPhaseRef.current = nextPhase

		if not shouldTrigger then
			return
		end

		sequenceTokenRef.current += 1
		local token = sequenceTokenRef.current
		SoundController.Sound("Start")
		setVisible(true)

		setFlashTransparency({
			start = 0.15,
			target = 0.7,
			info = TweenInfo.new(0.18, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		})
		setTextTransparency({
			start = 1,
			target = 0,
			info = TweenInfo.new(0.08, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		})
		setBarScale({
			start = 0.2,
			target = 1,
			speed = 28,
			damper = 0.55,
		})
		setTitleScale({
			start = 1.7,
			target = 1,
			speed = 26,
			damper = 0.58,
		})

		task.delay(0.22, function()
			if sequenceTokenRef.current ~= token then
				return
			end

			setFlashTransparency({
				target = 1,
				info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			})
			setTextTransparency({
				target = 1,
				info = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			})
			setBarScale({
				target = 1.25,
				speed = 16,
				damper = 0.75,
			})
			setTitleScale({
				target = 0.9,
				speed = 18,
				damper = 0.8,
			})
		end)

		task.delay(0.62, function()
			if sequenceTokenRef.current ~= token then
				return
			end
			setVisible(false)
		end)
	end, { roundPhase })

	if not visible then
		return nil
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 234, 157),
		BackgroundTransparency = flashTransparency,
		BorderSizePixel = 0,
		ZIndex = 200,
	}, {
		Backdrop = e(VStack, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			VerticalFlex = Enum.UIFlexAlignment.None,
			Spacing = UDim.new(0, 10),
		}, {
			TopBar = e("Frame", {
				Size = barScale:map(function(scale)
					return UDim2.fromScale(math.clamp(scale, 0, 1.25), 0.035)
				end),
				BackgroundColor3 = Color3.fromRGB(255, 120, 80),
				BackgroundTransparency = textTransparency,
				BorderSizePixel = 0,
				ZIndex = 201,
			}),
			Title = e(SmallText, {
				Text = "START!",
				TextSize = 54,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTransparency = textTransparency,
				Size = UDim2.fromScale(1, 0),
				children = {
					Scale = e("UIScale", {
						Scale = titleScale,
					}),
				},
			}),
			BottomBar = e("Frame", {
				Size = barScale:map(function(scale)
					return UDim2.fromScale(math.clamp(scale, 0, 1.25), 0.035)
				end),
				BackgroundColor3 = Color3.fromRGB(255, 120, 80),
				BackgroundTransparency = textTransparency,
				BorderSizePixel = 0,
				ZIndex = 201,
			}),
		}),
	})
end

return RoundStartFlash
