local React = require(game.ReplicatedStorage.Packages.React)
local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
local HStack = require(game.ReplicatedStorage.Shared.ReactComponents.ui.HStack)
local CloseButton = require(game.ReplicatedStorage.Shared.ReactComponents.ui.CloseButton)
local SmallText = require(game.ReplicatedStorage.Shared.ReactComponents.ui.SmallText)
local Bullet = require(game.ReplicatedStorage.Shared.ReactComponents.Bullet)
local SmallIcon = require(game.ReplicatedStorage.Shared.ReactComponents.ui.SmallIcon)

local function Shields(props)
	local children = {}
	for i = 1, props.Amount do
		children[i] = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 32, 0, 100),
		}, {
			e(SmallIcon, {
				Image = "rbxassetid://71309430456016",
				Size = UDim2.new(0, 100, 0, 100),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				ScaleType = Enum.ScaleType.Crop,
			}),
		})
	end
	return e(HStack, {
		AutomaticSize = Enum.AutomaticSize.XY,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Size = UDim2.fromScale(0, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Padding = {
			All = UDim.new(0, 8),
		},
		Spacing = UDim.new(0, 8),
	}, children)
end
return Shields
