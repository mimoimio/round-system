local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local useEffect = React.useEffect
local useRef = React.useRef

local PLAYER_PREFIX = "Player_"
local ACTION_STAGGER_SECONDS = 0.1
local MULTI_TARGET_STAGGER_SECONDS = 0.05

local localPlayer = Players.LocalPlayer
local fxFolder = Workspace:FindFirstChild("ResolutionFx")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ResolutionFx"
	fxFolder.Parent = Workspace
end

type ResolutionTargetAllocation = {
	targetParticipantId: string,
	amount: number,
}

type ResolutionActionEntry = {
	participantId: string,
	action: PlayerSessions.PendingAction,
	isAlive: boolean,
	bullets: number,
	pendingShields: number,
	targets: { ResolutionTargetAllocation },
}

type ResolutionSnapshotPayload = {
	turnIndex: number,
	phase: PlayerSessions.Phase,
	dispatchedAt: number,
	actions: { ResolutionActionEntry },
}

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

local function getAnchorPart(model: Model?): BasePart?
	if not model then
		return nil
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function createPart(color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.15
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Shape = shape or Enum.PartType.Block
	part.Parent = fxFolder
	return part
end

local function ResolutionActionAnimations()
	local sequenceTokenRef = useRef(0)
	local latestTurnRef = useRef(0)
	local instancesRef = useRef({} :: { Instance })

	local function clearInstances()
		for _, instance in instancesRef.current do
			if instance and instance.Parent then
				instance:Destroy()
			end
		end
		instancesRef.current = {}
	end

	local function trackInstance(instance: Instance)
		table.insert(instancesRef.current, instance)
	end

	local function tweenAndDestroy(instance: Instance, tweenInfo: TweenInfo, goal: { [string]: any })
		local tween = TweenService:Create(instance, tweenInfo, goal)
		tween:Play()
		tween.Completed:Connect(function()
			if instance and instance.Parent then
				instance:Destroy()
			end
		end)
	end

	local function playLoadAction(anchor: BasePart)
		local part = createPart(Color3.fromRGB(255, 191, 77), Enum.PartType.Block)
		trackInstance(part)
		part.Size = Vector3.new(0.4, 0.4, 0.4)
		part.CFrame = anchor.CFrame + Vector3.new(0, 1.2, 0)
		tweenAndDestroy(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = part.CFrame + Vector3.new(0, 2.2, 0),
			Size = Vector3.new(0.9, 0.9, 0.9),
			Transparency = 1,
		})
	end

	local function playShieldAction(anchor: BasePart)
		local part = createPart(Color3.fromRGB(74, 198, 255), Enum.PartType.Ball)
		trackInstance(part)
		part.Size = Vector3.new(2, 2, 2)
		part.CFrame = anchor.CFrame
		tweenAndDestroy(part, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(7.5, 7.5, 7.5),
			Transparency = 1,
		})
	end

	local function playShotImpact(targetAnchor: BasePart)
		local impact = createPart(Color3.fromRGB(255, 226, 120), Enum.PartType.Ball)
		trackInstance(impact)
		impact.Size = Vector3.new(0.6, 0.6, 0.6)
		impact.CFrame = targetAnchor.CFrame + Vector3.new(0, 1, 0)
		tweenAndDestroy(impact, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(1.8, 1.8, 1.8),
			Transparency = 1,
		})
	end

	local function playShootAction(shooterAnchor: BasePart, targetAnchor: BasePart, amount: number)
		local origin = shooterAnchor.Position + Vector3.new(0, 1.2, 0)
		local target = targetAnchor.Position + Vector3.new(0, 1, 0)
		local distance = (target - origin).Magnitude
		if distance <= 0.01 then
			return
		end

		local tracer = createPart(Color3.fromRGB(255, 92, 92), Enum.PartType.Block)
		trackInstance(tracer)
		tracer.Transparency = 0.08
		tracer.Size = Vector3.new(0.12 + math.clamp(amount, 1, 6) * 0.03, 0.12, math.max(distance, 0.5))
		tracer.CFrame = CFrame.lookAt((origin + target) / 2, target)
		tweenAndDestroy(tracer, TweenInfo.new(0.16, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
			Transparency = 1,
		})

		playShotImpact(targetAnchor)
	end

	local function scheduleAction(entry: ResolutionActionEntry, index: number, sequenceToken: number)
		local startDelay = (index - 1) * ACTION_STAGGER_SECONDS
		task.delay(startDelay, function()
			if sequenceTokenRef.current ~= sequenceToken then
				return
			end
			if not entry.isAlive then
				return
			end

			local model = getModelFromParticipantId(entry.participantId)
			local anchor = getAnchorPart(model)
			if not anchor then
				return
			end

			if entry.action == "Load" then
				playLoadAction(anchor)
			elseif entry.action == "Shield" then
				playShieldAction(anchor)
			elseif entry.action == "Shoot" then
				for targetIndex, target in entry.targets do
					task.delay((targetIndex - 1) * MULTI_TARGET_STAGGER_SECONDS, function()
						if sequenceTokenRef.current ~= sequenceToken then
							return
						end
						local targetModel = getModelFromParticipantId(target.targetParticipantId)
						local targetAnchor = getAnchorPart(targetModel)
						if not targetAnchor then
							return
						end
						playShootAction(anchor, targetAnchor, target.amount)
					end)
				end
			end
		end)
	end

	useEffect(function()
		local phaseUnsubscribe = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound.Phase
		end, function(phase)
			if phase ~= "Resolution" then
				sequenceTokenRef.current += 1
				clearInstances()
			end
		end)

		local snapshotConnection = Remotes.ResolutionSnapshot.OnClientEvent:Connect(
			function(snapshot: ResolutionSnapshotPayload)
				if type(snapshot.turnIndex) ~= "number" then
					return
				end
				if snapshot.turnIndex < latestTurnRef.current then
					return
				end
				if snapshot.turnIndex == latestTurnRef.current and snapshot.dispatchedAt <= 0 then
					return
				end

				latestTurnRef.current = snapshot.turnIndex
				sequenceTokenRef.current += 1
				local sequenceToken = sequenceTokenRef.current
				clearInstances()

				for index, entry in snapshot.actions do
					scheduleAction(entry, index, sequenceToken)
				end
			end
		)

		return function()
			phaseUnsubscribe()
			snapshotConnection:Disconnect()
			sequenceTokenRef.current += 1
			clearInstances()
		end
	end, {})

	return nil
end

return ResolutionActionAnimations
