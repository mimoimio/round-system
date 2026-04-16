--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BILLBOARD_NAME = "BBBBB"
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local CupVisualService = {}

local TOOL_NAME = "Cup"
local HANDLE_NAME = "Handle"
local VISUAL_CONTAINER_NAME = "CupVisual"

local function removeCupTool(player: Player)
	local character = player.Character
	if character then
		local equipped = character:FindFirstChild(TOOL_NAME)
		if equipped and equipped:IsA("Tool") then
			equipped:Destroy()
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local stored = backpack:FindFirstChild(TOOL_NAME)
		if stored and stored:IsA("Tool") then
			stored:Destroy()
		end
	end
end

local function getPlayerFromParticipantId(participantId: string): Player?
	if string.sub(participantId, 1, 7) ~= "Player_" then
		return nil
	end

	local userId = tonumber(string.sub(participantId, 8))
	if not userId then
		return nil
	end

	return Players:GetPlayerByUserId(userId)
end

local function ensureCupTool(player: Player): Tool?
	local character = player.Character
	if character then
		local equipped = character:FindFirstChild(TOOL_NAME)
		if equipped and equipped:IsA("Tool") then
			equipped.CanBeDropped = false
			return equipped
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return nil
	end

	local existing = backpack:FindFirstChild(TOOL_NAME)
	if existing and existing:IsA("Tool") then
		existing.CanBeDropped = false
		return existing
	end

	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Parent = player.Character

	local handle = Instance.new("Part")
	handle.Name = HANDLE_NAME
	handle.Size = Vector3.new(0.6, 0.6, 0.6)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	return tool
end

local function getToolHandle(player: Player): Part?
	local tool = ensureCupTool(player)
	if not tool then
		return nil
	end

	local handle = tool:FindFirstChild(HANDLE_NAME)
	if handle and handle:IsA("Part") then
		return handle
	end

	return nil
end

function CupVisualService.start()
	PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
		return state.CurrentRound.Phase
	end, function(phase: PlayerSessions.Phase, previousPhase: PlayerSessions.Phase)
		if phase == "Starting" and previousPhase ~= "Starting" then
			for _, player in Players:GetPlayers() do
				ensureCupTool(player)
			end
		elseif phase == "Ended" and previousPhase ~= "Ended" then
			for _, player in Players:GetPlayers() do
				removeCupTool(player)
			end
		end
	end)

	-- Cup visuals are now handled by CupView (React). No imperative model/billboard logic here.
end

return CupVisualService
