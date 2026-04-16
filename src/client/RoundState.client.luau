-- --!strict
-- local Players = game:GetService("Players")
-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local RunService = game:GetService("RunService")

-- local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

-- type RoundState = PlayerSessions.RoundState

-- local player = Players.LocalPlayer
-- local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- local gui = Instance.new("ScreenGui")
-- gui.Name = "RoundStateGui"
-- gui.ResetOnSpawn = false
-- gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- gui.Parent = playerGui

-- local label = Instance.new("TextLabel")
-- label.Name = "RoundInfo"
-- label.AnchorPoint = Vector2.new(0, 0)
-- label.Position = UDim2.fromOffset(16, 16)
-- label.Size = UDim2.fromOffset(320, 48)
-- label.BackgroundTransparency = 0.3
-- label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
-- label.TextColor3 = Color3.fromRGB(255, 255, 255)
-- label.TextXAlignment = Enum.TextXAlignment.Left
-- label.Font = Enum.Font.GothamBold
-- label.TextScaled = true
-- label.Parent = gui

-- local currentRound: RoundState = PlayerSessions:getState().CurrentRound

-- PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
-- 	return state.CurrentRound
-- end, function(roundState: RoundState)
-- 	currentRound = roundState
-- end)

-- RunService.RenderStepped:Connect(function()
-- 	local remaining = math.max(0, currentRound.TimeEnd - os.time())
-- 	label.Text = string.format("Phase: %s | Time: %ds", currentRound.Phase, remaining)
-- end)
