local CollectionService = game:GetService("CollectionService")

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local e = React.createElement

local function IngredientPromptController(props)
	local assignedKitchenId = props.AssignedKitchenId
	local activePromptsRef = React.useRef({})

	local function forEachIngredientPrompt(callback: (prompt: ProximityPrompt) -> ())
		for _, prompt in CollectionService:GetTagged("ingredients") do
			if prompt:IsA("ProximityPrompt") then
				callback(prompt)
			end
		end

		for _, prompt in CollectionService:GetTagged("Ingredients") do
			if prompt:IsA("ProximityPrompt") then
				callback(prompt)
			end
		end
	end

	React.useEffect(function()
		forEachIngredientPrompt(function(prompt)
			prompt.Enabled = false
		end)
		table.clear(activePromptsRef.current)

		if assignedKitchenId == "" then
			return function() end
		end

		local kitchens = workspace:FindFirstChild("Kitchens")
		if not kitchens then
			return function() end
		end

		local assignedKitchen = kitchens:FindFirstChild(assignedKitchenId)
		if not assignedKitchen then
			return function() end
		end

		for _, descendant in assignedKitchen:GetDescendants() do
			if descendant:IsA("ProximityPrompt") then
				if
					not CollectionService:HasTag(descendant, "ingredients")
					and not CollectionService:HasTag(descendant, "Ingredients")
				then
					continue
				end

				local ingredientId = descendant:GetAttribute("IngredientId")
				if type(ingredientId) == "string" and ingredientId ~= "" then
					descendant.ObjectText = ingredientId
					descendant.Style = Enum.ProximityPromptStyle.Custom
					descendant.Enabled = true
					table.insert(activePromptsRef.current, descendant)
				end
			end
		end

		return function()
			for _, prompt in activePromptsRef.current do
				prompt.Enabled = false
			end
			table.clear(activePromptsRef.current)
		end
	end, { assignedKitchenId })

	return e("Frame", {
		Visible = false,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
	})
end

return IngredientPromptController
