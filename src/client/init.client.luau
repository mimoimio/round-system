local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DispatchEvent = require(ReplicatedStorage.Shared.Controllers.DispatchEvent)
local Reflex = require(ReplicatedStorage.Packages.Reflex)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local React = require(game.ReplicatedStorage.Packages.React)
-- StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
local e = React.createElement
local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
local App = require(game.ReplicatedStorage.Shared.ReactComponents.App)

type DispatchedAction = {
	arguments: {},
	name: string,
}

local receiver = Reflex.createBroadcastReceiver({
	start = function()
		game.ReplicatedStorage.Shared.Events:WaitForChild("start"):FireServer()
	end,
})

game.ReplicatedStorage.Shared.Events.dispatch.OnClientEvent:Connect(function(actions: { DispatchedAction })
	receiver:dispatch(actions)
	DispatchEvent.OnActionsDispatched(actions)
end)

PlayerSessions:applyMiddleware(receiver.middleware)
local controllerModules = game.ReplicatedStorage.Shared.Controllers:GetChildren()

print([[controllers initialization]])
for i, d in controllerModules do
	if d:IsA("ModuleScript") then
		shared[d.Name] = require(d)
	end
end

local initializecontrollers = {}
for i, s in shared do
	if s.initialize and type(s.initialize) == "function" then
		table.insert(initializecontrollers, { name = i, fn = s.initialize })
	end
end
for i, s in initializecontrollers do
	s.fn()
end

local startcontrollers = {}
for i, s in shared do
	if s.start and type(s.start) == "function" then
		table.insert(startcontrollers, { name = i, fn = s.start })
	end
end
for i, s in startcontrollers do
	s.fn()
end

for i, d: Instance in game.ReplicatedStorage.Shared.ReactComponents:GetDescendants() do
	pcall(function()
		require(d)
	end)
end

local ScreenGui, root
local isLoadedOnce

local function loadApp(character: Model)
	if ScreenGui then
		ScreenGui:Destroy()
	end
	if root then
		root:unmount()
	end

	ScreenGui = Instance.new("ScreenGui", game.Players.LocalPlayer.PlayerGui)
	ScreenGui.ResetOnSpawn = true
	ScreenGui.Name = "ReactRoot"
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	root = ReactRoblox.createRoot(ScreenGui)
	root:render(e(App))
	-- local uiReadyEvent = ReplicatedStorage.Shared.Events:WaitForChild("UIReady") :: BindableEvent
	-- uiReadyEvent:Fire()
	isLoadedOnce = true
end

PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
	local players = state.players
	local player = players and players[game.Players.LocalPlayer]
	local character = player and player.Character
	return character
end, function(character, prevcharacter)
	loadApp()
	PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
		local players = state.players
		local player = players and players[game.Players.LocalPlayer]
		local character = player and player.Character
		return character
	end, function()
		loadApp()
	end)
end)

local secs = 0

task.spawn(function()
	while not isLoadedOnce do
		secs += 1
		task.wait(1)
		if secs >= 3 then
			warn("FORCE LOAD. LOAD ONCE DOESNT WORK")
			loadApp()
		end
	end
end)
