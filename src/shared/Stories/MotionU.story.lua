local RunService = game:GetService("RunService")
local React = require(game.ReplicatedStorage.Packages.React)
local ReactFlow = require(game.ReplicatedStorage.Packages.ReactFlow)
local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
local HStack = require(game.ReplicatedStorage.Shared.ReactComponents.ui.HStack)
local CloseButton = require(game.ReplicatedStorage.Shared.ReactComponents.ui.CloseButton)
local SmallText = require(game.ReplicatedStorage.Shared.ReactComponents.ui.SmallText)

local function MotionU()
	local rot, setRot = ReactFlow.useSpring({
		target = 0,
		start = 0,
		damper = 1,
		speed = 90,
	})
	-- local rot, setRot = React.useBinding((tick() % 360) * 90)
	local tra, setTransparency = ReactFlow.useSpring({
		target = 0,
		start = 0,
		damper = 1,
		speed = 90,
	})
	useEffect(function()
		-- local connection = RunService.Heartbeat:Connect(function()
		-- 	setRot((tick() % 360) * 90)
		-- end)
		setRot({
			target = 0,
			start = 359,
			damper = 1,
			speed = 1,
		})
		task.delay(2, function()
			setTransparency({
				target = 1,
				start = 0,
				speed = 2,

				damper = 1,
			})
		end)

		return function()
			-- connection:Disconnect()
		end
	end, {})
	return e("ImageLabel", {
		Size = UDim2.new(0, 300, 0, 300),
		BackgroundTransparency = 1,
		Image = "rbxassetid://80904021630425",
		ImageTransparency = tra,
	}, {
		e("ImageLabel", {
			ImageTransparency = tra,
			Size = UDim2.new(0, 300, 0, 300),
			BackgroundTransparency = 1,
			Image = "rbxassetid://126047134021312",
			ZIndex = 1,
			Rotation = rot,
		}),
		e("ImageLabel", {
			ImageTransparency = tra,
			Size = UDim2.new(0, 300, 0, 300),
			BackgroundTransparency = 1,
			Image = "rbxassetid://91455518796669",
			ZIndex = 2,
		}),
		e("ImageLabel", {
			ImageTransparency = tra,
			Size = UDim2.new(0, 200, 0, 200),
			BackgroundTransparency = 1,
			Image = "rbxassetid://80947077979637",
			ZIndex = 3,
			ScaleType = Enum.ScaleType.Fit,
			Position = rot:map(function(r)
				local f = (math.tan(r / 150) + 0.5) * 20
				return UDim2.new(0.5, -f / 1.5 + 20, 0.5, -50 + f)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}),
	})
end

function story(target: Frame)
	local root = ReactRoblox.createRoot(target)
	root:render(e(MotionU))
	return function()
		root:unmount()
	end
end

return story
