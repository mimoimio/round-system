local React = require(game.ReplicatedStorage.Packages.React)
local ReactFlow = require(game.ReplicatedStorage.Packages.ReactFlow)
local e = React.createElement
local useSpring = ReactFlow.useSpring
local useState = React.useState
local useEffect = React.useEffect
local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
local HStack = require(game.ReplicatedStorage.Shared.ReactComponents.ui.HStack)
local CloseButton = require(game.ReplicatedStorage.Shared.ReactComponents.ui.CloseButton)
local SmallText = require(game.ReplicatedStorage.Shared.ReactComponents.ui.SmallText)
local SmallIcon = require(game.ReplicatedStorage.Shared.ReactComponents.ui.SmallIcon)

local function Bullet(props)
	local scale, setScale = useSpring({
		target = .9,
		start = .9,
		damper = .5,
		speed = 10,
	})
	useEffect(function()
		setScale({
			start = .5,
			target = 1,
			damper = .5,
			speed = 20
		})
	end, {})
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 32, 0, 100),
	}, {
		e(SmallIcon, {
			Image = "rbxassetid://11702759774",
			Size = UDim2.new(0, 100, 0, 100),
			ScaleType = Enum.ScaleType.Crop,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
		}, {
			UIScale = e("UIScale", {Scale = scale})
		}),
		UIScale = e("UIScale", {Scale = scale})
	})
end
return Bullet
