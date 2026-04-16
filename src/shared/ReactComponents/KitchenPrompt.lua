local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local e = React.createElement

local function KitchenPrompt(props)
	return e("ProximityPrompt", {
		ActionText = props.ActionText or "Add",
		ObjectText = props.IngredientId,
		Style = Enum.ProximityPromptStyle.Custom,
		MaxActivationDistance = props.MaxActivationDistance or 10,
		KeyboardKeyCode = Enum.KeyCode.E,
		RequiresLineOfSight = false,
		HoldDuration = 0,
		[React.Event.Triggered] = function()
			Remotes.InteractStation:FireServer(props.IngredientId)
		end,
	})
end

return KitchenPrompt
