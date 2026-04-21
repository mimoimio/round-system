local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Primitives = ReplicatedStorage.Shared.ReactComponents.ui
local SmallText = require(Primitives.SmallText)
local VStack = require(Primitives.VStack)

local e = React.createElement

local function RoundHUD(props)
	local phase = props.Phase
	local timeEnd = props.TimeEnd
	local currentTurn = props.TurnIndex or 0
	local assignedKitchenId = props.AssignedKitchenId
	local activeOrders = props.ActiveOrders

	local now, setNow = React.useBinding(os.time())

	React.useEffect(function()
		local connection = RunService.Heartbeat:Connect(function()
			setNow(os.time())
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	local countdownText = now:map(function(currentNow)
		local remaining = math.max(0, timeEnd - currentNow)
		return string.format("%s | %ds", phase, remaining)
	end)

	local _currentNowValue = now:getValue()

	local orderChildren = {}
	for index, orderId in ipairs(activeOrders) do
		orderChildren["Order_" .. tostring(index)] = e(SmallText, {
			Text = string.format("%d. %s", index, orderId),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = index,
		})
	end

	if #activeOrders == 0 then
		orderChildren.Empty = e(SmallText, {
			Text = "No active orders",
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 1,
		})
	end

	return e(VStack, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		VerticalFlex = Enum.UIFlexAlignment.None,
		Padding = {
			Top = UDim.new(0, 24),
		},
		Spacing = UDim.new(0, 8),
	}, {
		Countdown = e(SmallText, {
			-- Countdown = phase ~= "InProgress" and e(SmallText, {
			Text = string.format("Turn %d | %s", currentTurn, countdownText),
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center,
		}) or nil,
		Kitchen = assignedKitchenId ~= "" and e(SmallText, {
			Text = string.format("Kitchen: %s", assignedKitchenId),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
		}) or nil,
		OrdersTitle = e(SmallText, {
			Text = "Orders",
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		Orders = e(VStack, {
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Spacing = UDim.new(0, 4),
		}, orderChildren),
	})
end

return RoundHUD
