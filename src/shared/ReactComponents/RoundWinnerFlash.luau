local Players = game:GetService("Players")
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

local localPlayer = Players.LocalPlayer
local localParticipantId = "Player_" .. tostring(localPlayer.UserId)

local function formatWinnerLabel(
	winnerParticipantId: string,
	playersState: { [string]: PlayerSessions.PlayerEntity },
	participantsState: { [string]: PlayerSessions.ParticipantEntity }
): string
	if winnerParticipantId == localParticipantId then
		return "YOU WIN!"
	end

	local participant = participantsState[winnerParticipantId]
	if not participant then
		return "WINNER!"
	end

	local playerEntity = playersState[participant.PlayerId]
	if playerEntity then
		local player = Players:GetPlayerByUserId(tonumber(participant.PlayerId) or 0)
		if player then
			return string.upper(player.DisplayName .. " WINS")
		end
	end

	return string.upper(winnerParticipantId .. " WINS")
end

local function RoundWinnerFlash()
	local winnerParticipantId, setWinnerParticipantId = useState(function()
		return PlayerSessions:getState().CurrentRound.WinnerParticipantId
	end)
	local roundParticipants, setRoundParticipants = useState(function()
		return PlayerSessions:getState().CurrentRound.Participants
	end)
	local playersState, setPlayersState = useState(function()
		return PlayerSessions:getState().players
	end)
	local previousWinnerRef = useRef(winnerParticipantId)
	local sequenceTokenRef = useRef(0)
	local visible, setVisible = useState(false)

	useEffect(function()
		local unsubscribeWinner = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound.WinnerParticipantId
		end, function(nextWinnerParticipantId)
			setWinnerParticipantId(nextWinnerParticipantId)
		end)

		local unsubscribeRoundParticipants = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound.Participants
		end, function(nextRoundParticipants)
			setRoundParticipants(nextRoundParticipants)
		end)

		local unsubscribePlayers = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.players
		end, function(nextPlayersState)
			setPlayersState(nextPlayersState)
		end)

		return function()
			unsubscribeWinner()
			unsubscribeRoundParticipants()
			unsubscribePlayers()
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
		info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	})
	local ribbonScale, setRibbonScale = useSpring({
		start = 0.1,
		target = 0.1,
		speed = 22,
		damper = 0.6,
	})
	local titleScale, setTitleScale = useSpring({
		start = 1.8,
		target = 1.8,
		speed = 24,
		damper = 0.58,
	})

	useEffect(function()
		local previousWinner = previousWinnerRef.current
		local nextWinner = winnerParticipantId
		local shouldTrigger = previousWinner == nil and nextWinner ~= nil
		previousWinnerRef.current = nextWinner

		if not shouldTrigger then
			return
		end

		sequenceTokenRef.current += 1
		local token = sequenceTokenRef.current
		SoundController.Sound("TaDa")
		setVisible(true)

		setFlashTransparency({
			start = 0.05,
			target = 0.72,
			info = TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		})
		setTextTransparency({
			start = 1,
			target = 0,
			info = TweenInfo.new(0.1, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		})
		setRibbonScale({
			start = 0.1,
			target = 1,
			speed = 32,
			damper = 0.5,
		})
		setTitleScale({
			start = 1.85,
			target = 1,
			speed = 28,
			damper = 0.56,
		})

		task.delay(0.35, function()
			if sequenceTokenRef.current ~= token then
				return
			end

			setFlashTransparency({
				target = 1,
				info = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			})
			setTextTransparency({
				target = 1,
				info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			})
			setRibbonScale({
				target = 1.2,
				speed = 14,
				damper = 0.78,
			})
			setTitleScale({
				target = 0.9,
				speed = 18,
				damper = 0.8,
			})
		end)

		task.delay(1.1, function()
			if sequenceTokenRef.current ~= token then
				return
			end
			setVisible(false)
		end)
	end, { winnerParticipantId })

	if not visible or winnerParticipantId == nil then
		return nil
	end

	local winnerLabel = formatWinnerLabel(winnerParticipantId, playersState, roundParticipants)

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 224, 130),
		BackgroundTransparency = flashTransparency,
		BorderSizePixel = 0,
		ZIndex = 220,
	}, {
		Backdrop = e(VStack, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			VerticalFlex = Enum.UIFlexAlignment.None,
			Spacing = UDim.new(0, 6),
		}, {
			WinnerText = e(SmallText, {
				Text = winnerLabel,
				TextSize = 50,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTransparency = textTransparency,
				Size = UDim2.fromScale(1, 0),
				children = {
					Scale = e("UIScale", {
						Scale = titleScale,
					}),
				},
			}),
			Ribbon = e("Frame", {
				Size = ribbonScale:map(function(scale)
					return UDim2.fromScale(math.clamp(scale, 0, 1.2), 0.028)
				end),
				BackgroundColor3 = Color3.fromRGB(255, 156, 64),
				BackgroundTransparency = textTransparency,
				BorderSizePixel = 0,
				ZIndex = 221,
			}),
		}),
	})
end

return RoundWinnerFlash
