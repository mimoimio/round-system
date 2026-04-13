local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local VStack = require(script.Parent.VStack) -- Assuming VStack is in the same folder

local function Panel(props)
	return e(VStack, {
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Padding = { Top = UDim.new(0, 10), Bottom = UDim.new(0, 10), Left = UDim.new(0, 16), Right = UDim.new(0, 16) },
		VerticalFlex = Enum.UIFlexAlignment.Fill,
	}, {
		-- Header
		TitleContainer = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 0.2,
			Text = props.Title or "",
			TextSize = 18,
			Font = Enum.Font.FredokaOne,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
		}, {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			}),
			CloseButton = props.OnClose and e("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = "X",
				[React.Event.Activated] = props.OnClose,
			}, {
				Padding = e("UIPadding", {
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
				}),
			}),
		}),

		-- Body
		BodyContainer = e(VStack, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 0.2,
			Padding = { Top = UDim.new(0, 10), Bottom = UDim.new(0, 10) },
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			VerticalAlignment = props.VerticalAlignment,
			LayoutOrder = 2,
		}, props.children),
	})
end

return Panel
