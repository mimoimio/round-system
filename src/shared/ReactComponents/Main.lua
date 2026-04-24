local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local React = require(ReplicatedStorage.Packages.React)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local Bullets = require(script.Parent.Bullets)
local StatsPanel = require(script.Parent.StatsPanel)
local Targets = require(script.Parent.Targets)
local AimProximityPrompts = require(script.Parent.AimProximityPrompts)
local RoundStartFlash = require(script.Parent.RoundStartFlash)
local RoundWinnerFlash = require(script.Parent.RoundWinnerFlash)
local RoundHeader = require(script.Parent.RoundHeader)
local RoundStatusRow = require(script.Parent.RoundStatusRow)
local RoundControlsRow = require(script.Parent.RoundControlsRow)
local TargetAllocationsPanel = require(script.Parent.TargetAllocationsPanel)
local RoundPhaseProgressBar = require(script.Parent.RoundPhaseProgressBar)
local ResolutionActionAnimations = require(script.Parent.ResolutionActionAnimations)
local useToast = require(script.Parent.Toasts).useToast
local useCombatToasts = require(script.Parent.hooks.useCombatToasts)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local localPlayer = Players.LocalPlayer
local localPlayerId = tostring(localPlayer.UserId)
local localParticipantId = "Player_" .. localPlayerId

local function Main(_props)
	local participant, setParticipant = useState(nil)
	local character, setCharacter = useState(nil)
	local isParticipant = participant ~= nil
	local toast = useToast()

	local playerReady, setPlayerReady = useState(nil)

	useCombatToasts({
		LocalPlayerId = localPlayerId,
		IsParticipant = isParticipant,
		Participant = participant,
		Toast = toast,
	})

	useEffect(function()
		local unsubscribeParticipant = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound.Participants[localParticipantId]
		end, function(nextParticipant)
			setParticipant(nextParticipant)
		end)
		local unsubReady = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			local players = state.players
			local playerEntity = players[localPlayerId]
			return playerEntity and playerEntity.PlayerPhase or nil
		end, function(phase)
			setPlayerReady(phase == "Ready")
		end)

		local gui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen")
		if gui then
			gui.Enabled = false
		end

		local connection = game.Players.LocalPlayer.CharacterAdded:Connect(function(c)
			setCharacter(c)
		end)

		setCharacter(game.Players.LocalPlayer.Character)

		return function()
			unsubscribeParticipant()
			unsubReady()
			connection:Disconnect()
		end
	end, {})
	if not playerReady then
		return e("Frame", {
			Size = UDim2.fromScale(2, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Color3.new(0.5, 0.4, 0.9),
			BackgroundTransparency = 0.5,
			ZIndex = 60,
			Active = true,
		}, {
			mu = character and e(require(script.Parent.MotionU)),
			e(require(script.Parent.ui.SmallButton), {
				Text = "PLAY",
				[React.Event.Activated] = function()
					Remotes.Ready:FireServer()
				end,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				TextSize = 42,
			}),
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		e("UIPadding", {
			PaddingRight = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
		}),
		ResolutionAnimations = e(ResolutionActionAnimations),
		RoundStartFlash = e(RoundStartFlash),
		RoundWinnerFlash = e(RoundWinnerFlash),
		Progress = e(RoundPhaseProgressBar),
		Bullets = e(Bullets),
		TargetMarkers = e(Targets),
		AimPrompts = e(AimProximityPrompts),
		Header = e(RoundHeader),
		Stats = e(StatsPanel, {}),
		Status = e(RoundStatusRow),
		-- TargetAllocations = e(TargetAllocationsPanel), -- dont turn on until further notice
		Controls = e(RoundControlsRow),
	})
end

return Main
