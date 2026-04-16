local Players = game:GetService("Players")
local React = require(game.ReplicatedStorage.Packages.React)
local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local e = React.createElement
local useEffect = React.useEffect
local useRef = React.useRef
local useState = React.useState

local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local CoffeeConfig = require(ReplicatedStorage.Shared.CoffeeModule).Config

local CupView = {}

function CupView.initialize()
	if CupView.initialized then
		return
	end
	CupView.initialized = true
end

local function Cup(props: { ParticipantId: string, Participant: PlayerSessions.ParticipantEntity, Character: Model? })
	local participant = props.Participant
	local cupId = participant.CupId
	local cupModel, setCupModel = useState(nil)
	local toolRef = useRef(nil)

	-- Create tool once for the participant's current cup.
	useEffect(function()
		if cupId == "Empty" then
			return function() end
		end

		local tool = Instance.new("Tool")
		tool.Name = "Cup_" .. props.ParticipantId
		local initialConfig = CoffeeConfig[cupId]
		tool.TextureId = (initialConfig and initialConfig.Image) or "rbxassetid://115293232657520"
		tool.CanBeDropped = false
		tool.RequiresHandle = true
		tool:SetAttribute("CupId", cupId)
		tool.Grip = CFrame.new(1.5, 1.5, 0)
		tool.Enabled = false

		local Handle = Instance.new("Part")
		Handle.Name = "Handle"
		Handle.Transparency = 1
		Handle.Parent = tool
		Handle.CanCollide = false
		Handle.CanTouch = false
		Handle.Massless = true
		toolRef.current = tool

		local character = props.Character
		if character then
			local equippedTool = character:FindFirstChildWhichIsA("Tool")
			if equippedTool then
				equippedTool.Parent = Players:GetPlayerFromCharacter(character).Backpack
			end
			tool.Parent = character
		end

		return function()
			if tool then
				tool:Destroy()
			end
			toolRef.current = nil
		end
	end, { cupId, props.Character })

	-- Update the attached model when the cup type changes.
	useEffect(function()
		local tool = toolRef.current
		if not tool then
			return
		end

		local Handle = tool:FindFirstChild("Handle")
		if not Handle then
			return
		end

		if cupId ~= "Empty" then
			local config = CoffeeConfig[cupId]
			tool.TextureId = (config and config.Image) or ""
		end

		local modelname = if cupId ~= "" and cupId ~= "Empty" then cupId else "cup"

		local model = ReplicatedStorage.Shared.Models:FindFirstChild(modelname)
		if not model then
			model = ReplicatedStorage.Shared.Models:FindFirstChild("error")
		end

		if not model then
			warn("[CupView] No model found for ItemId:", modelname)
			return
		end

		model = model:Clone()
		model:PivotTo(Handle:GetPivot())
		setCupModel(model)
		model.Parent = Handle

		local childPart = model:FindFirstChildWhichIsA("BasePart", true)
		for i, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.Massless = true
			end
		end
		if childPart and childPart:IsA("BasePart") then
			childPart.Anchored = false
			local weld = Instance.new("WeldConstraint", Handle)
			weld.Part0 = Handle
			weld.Part1 = childPart
		end

		return function()
			if model and toolRef.current then
				model:Destroy()
			end
			setCupModel(nil)
		end
	end, { cupId, props.Character })

	return e("Attachment")
end

local function CupRenderer(props: {
	ParticipantId: string,
	Participant: PlayerSessions.ParticipantEntity,
	Character: Model?,
})
	local children = {}
	local participant = props.Participant
	if participant.CupId ~= "Empty" then
		children.cup = e(Cup, {
			key = "cup",
			ParticipantId = props.ParticipantId,
			Participant = participant,
			Character = props.Character,
		})
	end
	return e("Folder", nil, children)
end

local function CupViewApp(props)
	local roundState, setRoundState = useState(function()
		return PlayerSessions:getState().CurrentRound
	end)
	local children = {}
	useEffect(function()
		local unsubscribe = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			setRoundState(state.CurrentRound)
		end)

		return function()
			unsubscribe()
		end
	end, {})

	for participantId, participant in roundState.Participants do
		local playerEntity = PlayerSessions:getState().players[participant.PlayerId]
		children[participantId] = e(CupRenderer, {
			key = participantId,
			ParticipantId = participantId,
			Participant = participant,
			Character = playerEntity and playerEntity.Character or nil,
		})
	end

	return e("Folder", nil, children)
end

function CupView.start()
	local rootFolder = Instance.new("Folder", workspace)
	rootFolder.Name = "TycoonServiceRoot"
	CupView.Root = ReactRoblox.createRoot(rootFolder)
	CupView.Root:render(e(CupViewApp))
end

return CupView
