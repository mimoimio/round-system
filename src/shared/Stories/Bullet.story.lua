local React = require(game.ReplicatedStorage.Packages.React)
local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
local HStack = require(game.ReplicatedStorage.Shared.ReactComponents.ui.HStack)
local CloseButton = require(game.ReplicatedStorage.Shared.ReactComponents.ui.CloseButton)
local SmallText = require(game.ReplicatedStorage.Shared.ReactComponents.ui.SmallText)

local function Bullets()
	return e(HStack, {
		-- BackgroundTransparency = 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromScale(0, 0),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -40, 1, -40),
		Padding = {
			All = UDim.new(0, 8),
		},
		Spacing = UDim.new(0, 8),
	}, {
		Bullets = e(SmallText, {
			TextSize = 64,
			Text = "⚙️",
		}),
		e(SmallText, {
			TextSize = 64,
			Text = "⚙️",
		}),
		e(SmallText, {
			TextSize = 64,
			Text = "⚙️",
		}),
	})
end

function story(target: Frame)
	local root = ReactRoblox.createRoot(target)
	root:render(e(Bullets))
	return function()
		root:unmount()
	end
end

return story
