local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactFlow = require(ReplicatedStorage.Packages.ReactFlow)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundController = require(ReplicatedStorage.Shared.Controllers.SoundController)

local Primitives = ReplicatedStorage.Shared.ReactComponents.ui
local HStack = require(Primitives.HStack)
local VStack = require(Primitives.VStack)
local SmallButton = require(Primitives.SmallButton)
local SmallText = require(Primitives.SmallText)

local e = React.createElement
local useBinding = React.useBinding
local useEffect = React.useEffect
local useRef = React.useRef
local useState = React.useState
local useSpring = ReactFlow.useSpring

local localPlayer = Players.LocalPlayer
local localParticipantId = "Player_" .. tostring(localPlayer.UserId)
local PLAYER_PREFIX = "Player_"
local AIM_PROMPT_NAME = "AimPrompt"
local getModelFromParticipantId: (participantId: string) -> Model?

type PromptEntry = {
	id: string,
	isClosing: boolean,
	participantId: string,
	prompt: ProximityPrompt,
}

local function getModelAdornee(model: Model?): BasePart?
	if not model then
		return nil
	end

	if model.PrimaryPart then
		return model.PrimaryPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function SightBillboard(props: {
	Visible: boolean,
	ParticipantId: string?,
})
	local rotationBinding, setRotationBinding = useBinding(0)

	useEffect(function()
		local heartbeat = RunService.Heartbeat:Connect(function()
			setRotationBinding((os.clock() * 180) % 360)
		end)

		return function()
			heartbeat:Disconnect()
		end
	end, {})

	local model = if props.ParticipantId then getModelFromParticipantId(props.ParticipantId) else nil
	local adornee = getModelAdornee(model)
	if not props.Visible or not adornee then
		return nil
	end

	return e("BillboardGui", {
		Name = "SightBillboard",
		Adornee = adornee,
		Size = UDim2.fromOffset(72, 72),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Sight = e("ImageLabel", {
			Name = "Sight",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(64, 64),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Image = "rbxassetid://111507972600301",
			Rotation = rotationBinding,
		}),
	})
end

getModelFromParticipantId = function(participantId: string): Model?
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

local function getPromptParent(model: Model): BasePart?
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

local function PromptEntryRow(props: {
	Entry: PromptEntry,
	OnShoot: () -> (),
	OnRemove: () -> (),
})
	local scale, setScale = useSpring({
		start = 0.9,
		target = 1,
		speed = 18,
		damper = 0.6,
	})

	useEffect(function()
		if props.Entry.isClosing then
			setScale({
				target = 0,
				speed = 20,
				damper = 1,
			})
		else
			setScale({
				target = 1,
				speed = 18,
				damper = 0.6,
			})
		end
	end, { props.Entry.isClosing })
	-- for pc
	useEffect(function()
		local connections = {
			connection = not props.Entry.isClosing
				and UserInputService.InputBegan:Connect(function(io: InputObject, gp)
					if gp then
						return
					end
					if io.UserInputType == Enum.UserInputType.MouseButton1 then
						props.OnShoot()
					end
				end),
			connection2 = not props.Entry.isClosing
				and UserInputService.InputBegan:Connect(function(io: InputObject, gp)
					if gp then
						return
					end
					if io.UserInputType == Enum.UserInputType.MouseButton2 then
						props.OnRemove()
					end
				end),
			-- touch = UserInputService.TouchEnabled,
		}
		return function()
			for i, connection in connections do
				connection:Disconnect()
			end
		end
	end, { props.Entry.isClosing })

	return e(HStack, {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Spacing = UDim.new(0, 8),
	}, {
		Target = e(SmallText, {
			Text = props.Entry.participantId,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Shoot = e(SmallButton, {
			Text = "Shoot",
			Size = UDim2.fromOffset(78, 34),
			BackgroundTransparency = 0.2,
			[React.Event.Activated] = props.OnShoot,
			Scale = scale,
		}),
		Remove = e(SmallButton, {
			Text = "Remove",
			Size = UDim2.fromOffset(86, 34),
			BackgroundTransparency = 0.2,
			Scale = scale,
			[React.Event.Activated] = props.OnRemove,
		}),
	})
end

local function AimProximityPrompts()
	local roundState, setRoundState = useState(function()
		return PlayerSessions:getState().CurrentRound
	end)
	local participant, setParticipant = useState(function()
		return PlayerSessions:getState().CurrentRound.Participants[localParticipantId]
	end)
	local entries, setEntries = useState({} :: { [string]: PromptEntry })
	local createdPromptsRef = useRef({} :: { [ProximityPrompt]: boolean })
	local promptToEntryRef = useRef({} :: { [ProximityPrompt]: string })
	local highlightByPromptRef = useRef({} :: { [ProximityPrompt]: Highlight })
	local aimedParticipantId, setAimedParticipantId = useState(nil :: string?)
	local canShowPrompts = participant
		and participant.IsAlive
		and roundState.Phase == "ActionInput"
		and participant.PendingAction == "Shoot"

	useEffect(function()
		local unsubscribeRound = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound
		end, function(nextRound)
			setRoundState(nextRound)
		end)

		local unsubscribeParticipant = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			return state.CurrentRound.Participants[localParticipantId]
		end, function(nextParticipant)
			setParticipant(nextParticipant)
		end)

		return function()
			unsubscribeRound()
			unsubscribeParticipant()
		end
	end, {})

	local function sendInput(request: string, targetParticipantId: string?)
		if not participant or not participant.IsAlive then
			return
		end
		if roundState.Phase ~= "ActionInput" then
			return
		end

		if request == "AddTarget" then
			SoundController.Sound("Plap")
		elseif request == "RemoveTarget" then
			SoundController.Sound("Trash")
		end

		Remotes.PistolInput:FireServer(request, targetParticipantId)
	end

	local function destroyHighlightForPrompt(prompt: ProximityPrompt)
		local highlight = highlightByPromptRef.current[prompt]
		if highlight then
			highlight:Destroy()
			highlightByPromptRef.current[prompt] = nil
		end
	end

	local function closePromptEntry(prompt: ProximityPrompt)
		local entryId = promptToEntryRef.current[prompt]
		if not entryId then
			return
		end

		destroyHighlightForPrompt(prompt)
		setEntries(function(previous)
			local entry = previous[entryId]
			if not entry then
				return previous
			end
			local next = table.clone(previous)
			next[entryId] = {
				id = entry.id,
				isClosing = true,
				participantId = entry.participantId,
				prompt = entry.prompt,
			}
			return next
		end)

		task.delay(0.15, function()
			setEntries(function(previous)
				local next = table.clone(previous)
				next[entryId] = nil
				return next
			end)
			promptToEntryRef.current[prompt] = nil
		end)
	end

	useEffect(function()
		local localParticipant = participant
		local canShowPrompts = localParticipant
			and localParticipant.IsAlive
			and roundState.Phase == "ActionInput"
			and localParticipant.PendingAction == "Shoot"
		if not canShowPrompts then
			setAimedParticipantId(nil)
			for prompt in createdPromptsRef.current do
				closePromptEntry(prompt)
				prompt:Destroy()
				createdPromptsRef.current[prompt] = nil
			end
			return
		end

		local activeParticipants = roundState.Participants
		local seenByParticipantId: { [string]: boolean } = {}
		for participantId, participant in activeParticipants do
			if participantId ~= localParticipantId and participant.IsAlive then
				seenByParticipantId[participantId] = true
				local model = getModelFromParticipantId(participantId)
				if model then
					local parent = getPromptParent(model)
					if parent then
						local existingPrompt = parent:FindFirstChild(AIM_PROMPT_NAME)
						if existingPrompt and existingPrompt:IsA("ProximityPrompt") then
							existingPrompt.Style = Enum.ProximityPromptStyle.Custom
							existingPrompt.MaxActivationDistance = 1000
							existingPrompt.RequiresLineOfSight = false
							existingPrompt.ActionText = "Aim"
							existingPrompt.ObjectText = participantId
							existingPrompt.Enabled = true
							existingPrompt:SetAttribute("ParticipantId", participantId)
							createdPromptsRef.current[existingPrompt] = true
						else
							local prompt = Instance.new("ProximityPrompt")
							prompt.Name = AIM_PROMPT_NAME
							prompt.Style = Enum.ProximityPromptStyle.Custom
							prompt.MaxActivationDistance = 1000
							prompt.RequiresLineOfSight = false
							prompt.ActionText = "Aim"
							prompt.ObjectText = participantId
							prompt.Enabled = true
							prompt:SetAttribute("ParticipantId", participantId)
							prompt.Parent = parent
							createdPromptsRef.current[prompt] = true
						end
					end
				end
			end
		end

		for prompt in createdPromptsRef.current do
			local participantId = prompt:GetAttribute("ParticipantId")
			local participant = if type(participantId) == "string" then activeParticipants[participantId] else nil
			if not prompt.Parent or type(participantId) ~= "string" or participantId == localParticipantId then
				closePromptEntry(prompt)
				prompt:Destroy()
				createdPromptsRef.current[prompt] = nil
			elseif not participant or not participant.IsAlive or not seenByParticipantId[participantId] then
				closePromptEntry(prompt)
				prompt:Destroy()
				createdPromptsRef.current[prompt] = nil
			end
		end
	end, { roundState.Participants, roundState.Phase, participant })

	useEffect(function()
		local shownConnection = ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
			local localParticipant = participant
			if
				not (
					localParticipant
					and localParticipant.IsAlive
					and roundState.Phase == "ActionInput"
					and localParticipant.PendingAction == "Shoot"
				)
			then
				return
			end

			if not createdPromptsRef.current[prompt] then
				return
			end
			if promptToEntryRef.current[prompt] then
				return
			end

			local participantId = prompt:GetAttribute("ParticipantId")
			if type(participantId) ~= "string" or participantId == "" then
				return
			end
			if participantId == localParticipantId then
				return
			end

			local participant = roundState.Participants[participantId]
			if not participant or not participant.IsAlive then
				return
			end

			local entryId = tostring(tick())
			promptToEntryRef.current[prompt] = entryId
			setAimedParticipantId(participantId)
			setEntries(function(previous)
				local next = table.clone(previous)
				next[entryId] = {
					id = entryId,
					isClosing = false,
					participantId = participantId,
					prompt = prompt,
				}
				return next
			end)
		end)

		local hiddenConnection = ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
			if not createdPromptsRef.current[prompt] then
				return
			end
			local participantId = prompt:GetAttribute("ParticipantId")
			if type(participantId) == "string" and participantId == aimedParticipantId then
				setAimedParticipantId(nil)
			end
			closePromptEntry(prompt)
		end)

		return function()
			shownConnection:Disconnect()
			hiddenConnection:Disconnect()
		end
	end, { roundState.Participants, roundState.Phase, participant })

	useEffect(function()
		return function()
			for prompt in createdPromptsRef.current do
				destroyHighlightForPrompt(prompt)
				if prompt and prompt.Parent then
					prompt:Destroy()
				end
				createdPromptsRef.current[prompt] = nil
				promptToEntryRef.current[prompt] = nil
			end
			setEntries({})
		end
	end, {})

	local children = {}
	for id, entry in entries do
		children[id] = not entry.isClosing
			and e(PromptEntryRow, {
				Entry = entry,
				OnShoot = function()
					sendInput("AddTarget", entry.participantId)
				end,
				OnRemove = function()
					sendInput("RemoveTarget", entry.participantId)
				end,
			})

		local model = getModelFromParticipantId(entry.participantId)
		children[id .. "highlight"] = not entry.isClosing
			and e("Highlight", {
				Name = "AimPromptHighlight",
				Adornee = model,
				FillColor = Color3.fromRGB(255, 204, 64),
				FillTransparency = 0.75,
				OutlineColor = Color3.fromRGB(255, 255, 255),
				OutlineTransparency = 0,
				Parent = model,
			})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 20,
	}, {
		SightBillboard = e(SightBillboard, {
			Visible = canShowPrompts,
			ParticipantId = aimedParticipantId,
		}),
		PromptList = e(VStack, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			VerticalFlex = Enum.UIFlexAlignment.None,
			Padding = {
				Right = UDim.new(0, 24),
				Bottom = UDim.new(0, 96),
			},
			Spacing = UDim.new(0, 8),
		}, children),
	})
end

return AimProximityPrompts
