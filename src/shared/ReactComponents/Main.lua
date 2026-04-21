local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local Bullets = require(script.Parent.Bullets)
local StatsPanel = require(script.Parent.StatsPanel)
local Targets = require(script.Parent.Targets)
local AimProximityPrompts = require(script.Parent.AimProximityPrompts)
local RoundStartFlash = require(script.Parent.RoundStartFlash)
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
	local isParticipant = participant ~= nil
	local toast = useToast()

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

		return function()
			unsubscribeParticipant()
		end
	end, {})

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		e("UIPadding",{
			PaddingRight = UDim.new(0,12),
			PaddingLeft = UDim.new(0,12),
			PaddingTop = UDim.new(0,12),
			PaddingBottom = UDim.new(0,12),
		}),
		ResolutionAnimations = e(ResolutionActionAnimations),
		RoundStartFlash = e(RoundStartFlash),
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