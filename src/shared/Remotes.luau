-- ReplicatedStorage/Shared/Remotes.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local isserver = RunService:IsServer()
local function Start()
	local remote = isserver and Instance.new("RemoteEvent") or ReplicatedStorage.Shared.Events:WaitForChild("start")
	remote.Name = "start"
	remote.Parent = ReplicatedStorage.Shared.Events
	return remote
end
local function Dispatch()
	local remote = isserver and Instance.new("RemoteEvent") or ReplicatedStorage.Shared.Events:WaitForChild("dispatch")
	remote.Name = "dispatch"
	remote.Parent = ReplicatedStorage.Shared.Events
	return remote
end

local function SaveSettings()
	local remote = isserver and Instance.new("RemoteEvent")
		or ReplicatedStorage.Shared.Events:WaitForChild("saveSettings")
	remote.Name = "saveSettings"
	remote.Parent = ReplicatedStorage.Shared.Events
	return remote
end

local function HeadSync()
	local remote = isserver and Instance.new("UnreliableRemoteEvent")
		or ReplicatedStorage.Shared.Events:WaitForChild("HeadSync")
	remote.Name = "HeadSync"
	remote.Parent = ReplicatedStorage.Shared.Events
	return remote
end

local function AddIngredient()
	local remote = isserver and Instance.new("RemoteFunction")
		or ReplicatedStorage.Shared.Events:WaitForChild("AddIngredient")
	remote.Name = "AddIngredient"
	remote.Parent = ReplicatedStorage.Shared.Events
	return remote
end

local function ScoreNotification()
	local remote = isserver and Instance.new("RemoteEvent")
		or ReplicatedStorage.Shared.Events:WaitForChild("ScoreNotification")
	remote.Name = "ScoreNotification"
	remote.Parent = ReplicatedStorage.Shared.Events
	return remote
end

local function Maxed()
	local remote = isserver and Instance.new("RemoteEvent") or ReplicatedStorage.Shared.Events:WaitForChild("Maxed")
	remote.Name = "Maxed"
	remote.Parent = ReplicatedStorage.Shared.Events
	return remote
end

local function ClaimRoulette()
	local remote = isserver and Instance.new("RemoteFunction")
		or ReplicatedStorage.Shared.Events:WaitForChild("ClaimRoulette")
	remote.Name = "ClaimRoulette"
	remote.Parent = ReplicatedStorage.Shared.Events
	return remote
end

local function InteractStation()
	local remote = isserver and Instance.new("RemoteEvent")
		or ReplicatedStorage.Shared.Events:WaitForChild("InteractStation")
	remote.Name = "InteractStation"
	remote.Parent = ReplicatedStorage.Shared.Events
	return remote
end

local function PistolInput()
	local remote = isserver and Instance.new("RemoteEvent")
		or ReplicatedStorage.Shared.Events:WaitForChild("PistolInput")
	remote.Name = "PistolInput"
	remote.Parent = ReplicatedStorage.Shared.Events
	return remote
end

local function CombatFeedback()
	local remote = isserver and Instance.new("RemoteEvent")
		or ReplicatedStorage.Shared.Events:WaitForChild("CombatFeedback")
	remote.Name = "CombatFeedback"
	remote.Parent = ReplicatedStorage.Shared.Events
	return remote
end

return {
	start = Start() :: RemoteEvent,
	dispatch = Dispatch() :: RemoteEvent,
	saveSettings = SaveSettings() :: RemoteEvent,
	HeadSync = HeadSync() :: UnreliableRemoteEvent,
	AddIngredient = AddIngredient() :: RemoteFunction,
	ScoreNotification = ScoreNotification() :: RemoteEvent,
	Maxed = Maxed() :: RemoteEvent,
	ClaimRoulette = ClaimRoulette() :: RemoteFunction,
	InteractStation = InteractStation() :: RemoteEvent,
	PistolInput = PistolInput() :: RemoteEvent,
	CombatFeedback = CombatFeedback() :: RemoteEvent,
}
