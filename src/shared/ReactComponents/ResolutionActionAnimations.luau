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

local fxFolder = Workspace:FindFirstChild("ResolutionFx")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ResolutionFx"
	fxFolder.Parent = Workspace
end

local BEAM_EFFECT_LIFETIME = 0.2
local ACTION_HIGHLIGHT_LIFETIME = 0.32
local CLASH_MARKER_LIFETIME = 0.24

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

type ShotMap = {
	[string]: { [string]: number },
}

local function getShot(shots: ShotMap, fromId: string, toId: string): number
	local fromMap = shots[fromId]
	if not fromMap then
		return 0
	end
	return fromMap[toId] or 0
end

local function setShot(shots: ShotMap, fromId: string, toId: string, value: number)
	if value <= 0 then
		return
	end
	local fromMap = shots[fromId]
	if not fromMap then
		fromMap = {}
		shots[fromId] = fromMap
	end
	fromMap[toId] = value
end

local function sumTargets(targets: { ResolutionTargetAllocation }): number
	local total = 0
	for _, target in targets do
		total += math.max(0, target.amount)
	end
	return total
end

local function buildShotMaps(actions: { ResolutionActionEntry }): (ShotMap, ShotMap)
	local actionById: { [string]: ResolutionActionEntry } = {}
	local aliveIds = {}

	for _, entry in actions do
		actionById[entry.participantId] = entry
		if entry.isAlive then
			table.insert(aliveIds, entry.participantId)
		end
	end
	table.sort(aliveIds)

	local rawShots: ShotMap = {}
	for _, shooterId in aliveIds do
		local shooter = actionById[shooterId]
		if shooter and shooter.action == "Shoot" then
			local allocated = math.min(sumTargets(shooter.targets), shooter.bullets)
			local remaining = allocated

			for _, target in shooter.targets do
				if remaining <= 0 then
					break
				end

				local targetId = target.targetParticipantId
				local targetEntry = actionById[targetId]
				if targetEntry and targetEntry.isAlive then
					local accepted = math.min(math.max(0, target.amount), remaining)
					if accepted > 0 then
						setShot(rawShots, shooterId, targetId, accepted)
						remaining -= accepted
					end
				end
			end
		end
	end

	local effectiveShots: ShotMap = {}
	for i = 1, #aliveIds do
		for j = i + 1, #aliveIds do
			local aId = aliveIds[i]
			local bId = aliveIds[j]
			local aToB = getShot(rawShots, aId, bId)
			local bToA = getShot(rawShots, bId, aId)
			setShot(effectiveShots, aId, bId, math.max(0, aToB - bToA))
			setShot(effectiveShots, bId, aId, math.max(0, bToA - aToB))
		end
	end

	return rawShots, effectiveShots
end

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

-- TODO somethings not right here
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

local function getPistolBeamTemplate(): Part?
	local inWorkspace = Workspace:FindFirstChild("PistolBeam", true)
	if inWorkspace and inWorkspace:IsA("Part") then
		return inWorkspace
	end

	local inReplicatedStorage = ReplicatedStorage:FindFirstChild("PistolBeam", true)
	if inReplicatedStorage and inReplicatedStorage:IsA("Part") then
		return inReplicatedStorage
	end

	return nil
end

local function getBeamAttachments(beamPart: Part): (Attachment?, Attachment?)
	local attachment0 = beamPart:FindFirstChild("Attachment0")
	local attachment1 = beamPart:FindFirstChild("Attachment1")
	if attachment0 and attachment0:IsA("Attachment") and attachment1 and attachment1:IsA("Attachment") then
		return attachment0, attachment1
	end

	local attachments = {}
	for _, child in beamPart:GetChildren() do
		if child:IsA("Attachment") then
			table.insert(attachments, child)
		end
	end

	if #attachments >= 2 then
		return attachments[1], attachments[2]
	end

	return nil, nil
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

	local function createActionHighlight(model: Model, color: Color3)
		local highlight = Instance.new("Highlight")
		highlight.Adornee = model
		highlight.FillColor = color
		highlight.FillTransparency = 0.7
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.OutlineTransparency = 0.15
		highlight.Parent = fxFolder
		trackInstance(highlight)

		task.delay(ACTION_HIGHLIGHT_LIFETIME, function()
			if highlight and highlight.Parent then
				highlight:Destroy()
			end
		end)
	end

	local function createCountBillboard(adornee: BasePart, labelText: string, textColor: Color3)
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ResolutionActionBillboard"
		billboard.Adornee = adornee
		billboard.Size = UDim2.fromOffset(160, 48)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = fxFolder
		trackInstance(billboard)

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.fromScale(1, 1)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = labelText
		textLabel.TextScaled = true
		textLabel.Font = Enum.Font.FredokaOne
		textLabel.TextColor3 = textColor
		textLabel.TextStrokeTransparency = 0.35
		textLabel.Parent = billboard

		task.delay(ACTION_HIGHLIGHT_LIFETIME, function()
			if billboard and billboard.Parent then
				billboard:Destroy()
			end
		end)
	end

	local function playLoadAction(anchor: BasePart)
		if anchor.Parent and anchor.Parent:IsA("Model") then
			createActionHighlight(anchor.Parent, Color3.fromRGB(255, 210, 64))
		end
		createCountBillboard(anchor, "+1", Color3.fromRGB(255, 210, 64))

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

	local function playShieldAction(anchor: BasePart, pendingShields: number)
		if anchor.Parent and anchor.Parent:IsA("Model") then
			createActionHighlight(anchor.Parent, Color3.fromRGB(70, 150, 255))
		end
		createCountBillboard(anchor, "SHIELDS x" .. tostring(math.max(0, pendingShields)), Color3.fromRGB(95, 175, 255))

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

	local function playClashMarker(firstAnchor: BasePart, secondAnchor: BasePart, amount: number)
		local midpoint = (firstAnchor.Position + secondAnchor.Position) / 2
		local clash = createPart(Color3.fromRGB(255, 170, 80), Enum.PartType.Ball)
		trackInstance(clash)
		clash.Size = Vector3.new(0.55, 0.55, 0.55)
		clash.CFrame = CFrame.new(midpoint)
		tweenAndDestroy(clash, TweenInfo.new(CLASH_MARKER_LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(1.5, 1.5, 1.5),
			Transparency = 1,
		})

		local markerPart = Instance.new("Part")
		markerPart.Name = "ClashMarker"
		markerPart.Anchored = true
		markerPart.CanCollide = false
		markerPart.CanQuery = false
		markerPart.CanTouch = false
		markerPart.Transparency = 1
		markerPart.Size = Vector3.new(0.1, 0.1, 0.1)
		markerPart.Position = midpoint
		markerPart.Parent = fxFolder
		trackInstance(markerPart)

		createCountBillboard(markerPart, "CLASH x" .. tostring(amount), Color3.fromRGB(255, 210, 140))

		task.delay(CLASH_MARKER_LIFETIME, function()
			if markerPart and markerPart.Parent then
				markerPart:Destroy()
			end
		end)
	end

	local function playShootAction(shooterAnchor: BasePart, targetAnchor: BasePart, amount: number)
		local origin = shooterAnchor.Position + Vector3.new(0, 1.2, 0)
		local target = targetAnchor.Position + Vector3.new(0, 1, 0)
		local distance = (target - origin).Magnitude
		if distance <= 0.01 then
			return
		end

		local template = getPistolBeamTemplate()
		if template then
			local beamPart = template:Clone()
			beamPart.Anchored = true
			beamPart.CanCollide = false
			beamPart.CanQuery = false
			beamPart.CanTouch = false
			beamPart.CFrame = CFrame.lookAt((origin + target) / 2, target)
			beamPart.Size = Vector3.new(0.2, 0.2, math.max(distance, 0.25))
			beamPart.Parent = fxFolder
			trackInstance(beamPart)

			local attachment0, attachment1 = getBeamAttachments(beamPart)
			if attachment0 and attachment1 then
				attachment0.Position = Vector3.new(0, 0, -beamPart.Size.Z / 2)
				attachment1.Position = Vector3.new(0, 0, beamPart.Size.Z / 2)
			end

			local beam = beamPart:FindFirstChildWhichIsA("Beam", true)
			if beam then
				local beamWidth = 0.08 + math.clamp(amount, 1, 6) * 0.02
				beam.Width0 = beamWidth
				beam.Width1 = beamWidth
				local fadeTween = TweenService:Create(
					beam,
					TweenInfo.new(BEAM_EFFECT_LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Width0 = 0,
						Width1 = 0,
					}
				)
				fadeTween:Play()
			end

			task.delay(BEAM_EFFECT_LIFETIME, function()
				if beamPart and beamPart.Parent then
					beamPart:Destroy()
				end
			end)
		else
			-- warn("failed")
			local tracer = createPart(Color3.fromRGB(255, 92, 92), Enum.PartType.Block)
			trackInstance(tracer)
			tracer.Transparency = 0.08
			tracer.Size = Vector3.new(0.12 + math.clamp(amount, 1, 6) * 0.03, 0.12, math.max(distance, 0.5))
			tracer.CFrame = CFrame.lookAt((origin + target) / 2, target)
			tweenAndDestroy(tracer, TweenInfo.new(0.16, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
				Transparency = 1,
			})
		end

		playShotImpact(targetAnchor)
	end

	local function scheduleAction(
		entry: ResolutionActionEntry,
		index: number,
		sequenceToken: number,
		rawShots: ShotMap,
		effectiveShots: ShotMap
	)
		local startDelay = (index - 1) * ACTION_STAGGER_SECONDS
		task.delay(startDelay, function()
			if sequenceTokenRef.current ~= sequenceToken then
				-- warn("failed")
				return
			end
			-- if not entry.isAlive then
			-- warn("failed")
			-- 	return
			-- end

			local model = getModelFromParticipantId(entry.participantId)
			local anchor = getAnchorPart(model)
			if not anchor then
				-- warn("Failed to animate action: could not find anchor for participant", entry.participantId)
				return
			end

			if entry.action == "Load" then
				playLoadAction(anchor)
			elseif entry.action == "Shield" then
				playShieldAction(anchor, entry.pendingShields)
			elseif entry.action == "Shoot" then
				if model then
					createActionHighlight(model, Color3.fromRGB(255, 92, 92))
				end
				for targetIndex, target in entry.targets do
					task.delay((targetIndex - 1) * MULTI_TARGET_STAGGER_SECONDS, function()
						if sequenceTokenRef.current ~= sequenceToken then
							-- warn("failed")
							return
						end
						local targetModel = getModelFromParticipantId(target.targetParticipantId)
						local targetAnchor = getAnchorPart(targetModel)
						if not targetAnchor then
							-- warn("Failed to animate shoot: could not find target anchor for",target.targetParticipantId)
							return
						end

						local rawAmount = getShot(rawShots, entry.participantId, target.targetParticipantId)
						if rawAmount <= 0 then
							-- warn("failed")
							return
						end

						local effectiveAmount = getShot(effectiveShots, entry.participantId, target.targetParticipantId)
						local clashAmount = rawAmount - effectiveAmount

						if clashAmount > 0 and entry.participantId < target.targetParticipantId then
							playClashMarker(anchor, targetAnchor, clashAmount)
						end

						if effectiveAmount > 0 then
							playShootAction(anchor, targetAnchor, effectiveAmount)
						end
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
			if phase == "Intermission" then
				latestTurnRef.current = 0
			end
		end)

		local snapshotConnection = Remotes.ResolutionSnapshot.OnClientEvent:Connect(
			function(snapshot: ResolutionSnapshotPayload)
				if type(snapshot.turnIndex) ~= "number" then
					-- warn("failed")
					return
				end
				if snapshot.turnIndex < latestTurnRef.current then
					-- warn("failed")
					return
				end
				if snapshot.turnIndex == latestTurnRef.current and snapshot.dispatchedAt <= 0 then
					-- warn("failed")
					return
				end

				latestTurnRef.current = snapshot.turnIndex
				sequenceTokenRef.current += 1
				local sequenceToken = sequenceTokenRef.current
				clearInstances()
				local rawShots, effectiveShots = buildShotMaps(snapshot.actions)

				for index, entry in snapshot.actions do
					scheduleAction(entry, index, sequenceToken, rawShots, effectiveShots)
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
