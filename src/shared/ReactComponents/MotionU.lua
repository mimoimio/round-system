local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local React = require(ReplicatedStorage.Packages.React)
local ReactFlow = require(ReplicatedStorage.Packages.ReactFlow)
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

local function MotionU()
	local rot, setRot = ReactFlow.useSpring({
		target = 0,
		start = 0,
		damper = 1,
		speed = 90,
	})
	-- local rot, setRot = React.useBinding((tick() % 360) * 90)
	local tra, setTransparency = ReactFlow.useSpring({
		target = 0,
		start = 0,
		damper = 1,
		speed = 90,
	})
	useEffect(function()
		-- local connection = RunService.Heartbeat:Connect(function()
		-- 	setRot((tick() % 360) * 90)
		-- end)

		task.delay(3, function()
			setRot({
				target = 0,
				start = 359,
				damper = 1,
				speed = 1,
			})
			task.delay(2, function()
				setTransparency({
					target = 1,
					start = 0,
					speed = 2,

					damper = 1,
				})
			end)
		end)

		return function()
			-- connection:Disconnect()
		end
	end, {})
	return e("ImageLabel", {
		Size = UDim2.new(0, 300, 0, 300),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Image = "rbxassetid://80904021630425",
		ImageTransparency = tra,
	}, {
		e("ImageLabel", {
			ImageTransparency = tra,
			Size = UDim2.new(0, 300, 0, 300),
			BackgroundTransparency = 1,
			Image = "rbxassetid://126047134021312",
			ZIndex = 1,
			Rotation = rot,
		}),
		e("ImageLabel", {
			ImageTransparency = tra,
			Size = UDim2.new(0, 300, 0, 300),
			BackgroundTransparency = 1,
			Image = "rbxassetid://91455518796669",
			ZIndex = 2,
		}),
		e("ImageLabel", {
			ImageTransparency = tra,
			Size = UDim2.new(0, 200, 0, 200),
			BackgroundTransparency = 1,
			Image = "rbxassetid://80947077979637",
			ZIndex = 3,
			ScaleType = Enum.ScaleType.Fit,
			Position = rot:map(function(r)
				local f = (math.tan(r / 150) + 0.5) * 20
				return UDim2.new(0.5, -f / 1.5 + 20, 0.5, -50 + f)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}),
	})
end

return MotionU
