local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local Primitives = ReplicatedStorage.Shared.ReactComponents.ui
local HStack = require(Primitives.HStack)
local SmallButton = require(Primitives.SmallButton)
local SmallText = require(Primitives.SmallText)
local usePistolControls = require(script.Parent.hooks.usePistolControls)

local e = React.createElement
local useEffect = React.useEffect
local useState = React.useState

export type InputMode = "Shield" | "Aim" | "Load" | "None"

local localPlayer = Players.LocalPlayer
local localParticipantId = "Player_" .. tostring(localPlayer.UserId)

local function RoundControlsRow()
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
	local isReady = participant ~= nil and participant.IsReady == true
	local controls = usePistolControls(roundState.Phase, isParticipantAlive)
	local mode = controls.mode
	local setMode = controls.setMode
	local sendInput = controls.sendInput

	useEffect(function()
		if isParticipantAlive then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end, { isParticipantAlive })

	if not (isActionInput and isParticipantAlive) then
		return nil
	end
	local modeButtons = {
		Shield = e(SmallButton, {
			Text = "Shield",
			KeybindText = "Q",
			BackgroundTransparency = if mode == "Shield" then 0.1 else 0.8,
			BackgroundColor3 = Color3.new(0, 0, 1),
			[React.Event.Activated] = function()
				setMode("Shield")
				sendInput("AddShield")
			end,
			Scale = if mode == "Shield" then 1.2 else 1,
		}),
		Aim = e(SmallButton, {
			Text = "Aim",
			KeybindText = "E",
			BackgroundColor3 = Color3.new(1, 0, 0),
			BackgroundTransparency = if mode == "Aim" then 0.1 else 0.8,
			[React.Event.Activated] = function()
				setMode("Aim")
				sendInput("Aim")
			end,
			Scale = if mode == "Aim" then 1.2 else 1,
		}),
		Load = e(SmallButton, {
			Text = "Load",
			KeybindText = "R",
			BackgroundTransparency = if mode == "Load" then 0.1 else 0.8,
			BackgroundColor3 = Color3.new(1, 1, 0),
			[React.Event.Activated] = function()
				setMode("Load")
				sendInput("Load")
			end,
			Scale = if mode == "Load" then 1.2 else 1,
		}),
	}

	return e(React.Fragment, nil, {
		Controls = e(HStack, {
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Spacing = UDim.new(0, 10),
			Position = UDim2.new(0, 0, 1, 0),
			AnchorPoint = Vector2.new(0, 1),
		}, {
			Shield = modeButtons.Shield,
			Aim = modeButtons.Aim,
			Load = modeButtons.Load,
			Ready = e(SmallButton, {
				Text = "Ready",
				KeybindText = "SPACE",
				BackgroundTransparency = if isReady then 0.1 else 0.8,
				[React.Event.Activated] = function()
					sendInput("ToggleReady")
				end,
			}),
		}),
		Help = e(SmallText, {
			Text = "Shield mode: LMB/tap add, RMB/double-tap remove. Aim mode: use prompt Shoot/Remove buttons when targets are shown.",
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 0),
			Position = UDim2.new(0, 0, 1, 0),
			AnchorPoint = Vector2.new(0, 1),
		}),
	})
end

return RoundControlsRow
