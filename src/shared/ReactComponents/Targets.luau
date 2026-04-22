local Bullets = require(script.Parent.Bullets)
local Shields = require(script.Parent.Shields)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local e = React.createElement
local useEffect = React.useEffect
local useState = React.useState

local PLAYER_PREFIX = "Player_"
local localParticipantId = "Player_" .. tostring(Players.LocalPlayer.UserId)

local function getModelFromParticipantId(participantId: string): Model?
	if string.sub(participantId, 1, #PLAYER_PREFIX) == PLAYER_PREFIX then
		local userId = tonumber(string.sub(participantId, #PLAYER_PREFIX + 1))
		if not userId then
			return nil
		end

		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return nil
		end

		return player.Character
	end

	local instance = Workspace:FindFirstChild(participantId, true)
	if instance and instance:IsA("Model") then
		return instance
	end

	return nil
end

local function getAdorneeFromModel(model: Model): BasePart?
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function Targets()
	local participant, setParticipant = useState(function()
		return PlayerSessions:getState().CurrentRound.Participants[localParticipantId]
	end)

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

	local action = if participant then participant.PendingAction else "None"
	local pendingTargets = if participant then participant.PendingTargets else {}
	local pendingShields = if participant then participant.PendingShields else 0

	local children = {}
	if action == "Shoot" then
		for targetParticipantId, amount in pendingTargets do
			if amount > 0 then
				local model = getModelFromParticipantId(targetParticipantId)
				if model then
					local adornee = getAdorneeFromModel(model)
					if adornee then
						children[targetParticipantId] = e("BillboardGui", {
							Adornee = adornee,
							Size = UDim2.fromScale(4, 1),
							StudsOffset = Vector3.new(0, 2.6, 0),
							AlwaysOnTop = true,
						}, {
							bulets = e(Bullets, {
								Amount = amount,
								Position = UDim2.new(0.5, 0, 0.5, 0),
								AnchorPoint = Vector2.new(0.5, 0.5),
							}),
							Highlight = e("Highlight", {
								Adornee = model,
							}),
						})
					end
				end
			end
		end
	elseif action == "Shield" then
		local model = game.Players.LocalPlayer.Character
		if model then
			children.PlayersShields = e("BillboardGui", {
				Adornee = model:FindFirstChild("Head"),
				Size = UDim2.fromOffset(200, 50),
				StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
				-- StudsOffset = Vector3.new(0, 2.6, 0),
				AlwaysOnTop = true,
			}, {
				Shields = e(Shields, { Amount = pendingShields }),
				Highlight = e("Highlight", {
					Adornee = model,
					FillColor = Color3.new(0, 0, 1),
				}),
			})
		end
	elseif action == "Load" then
		local model = game.Players.LocalPlayer.Character
		if model then
			children.PlayersShields = e("BillboardGui", {
				Adornee = model:FindFirstChild("Head"),
				Size = UDim2.fromOffset(200, 50),
				StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
				-- StudsOffset = Vector3.new(0, 2.6, 0),
				AlwaysOnTop = true,
			}, {
				Bullets = e(Bullets, {
					Amount = 1,
					Position = UDim2.new(0.5, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
				}),
				Highlight = e("Highlight", {
					Adornee = model,
					FillColor = Color3.new(1, 0.8, 0),
				}),
			})
		end
	end

	return e(React.Fragment, nil, children)
end

return Targets
