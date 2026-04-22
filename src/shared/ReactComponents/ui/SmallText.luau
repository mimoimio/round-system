local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local SmallText = function(props)
	local children = props.children or {}
	children.UITextSizeConstraint = e("UITextSizeConstraint", {
		MaxTextSize = props.TextSize or 18,
		MinTextSize = props.TextSize or 18,
	})
	return e("TextLabel", {
		AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0,
		Text = props.Text,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		TextScaled = props.TextScaled,
		Font = props.Font or "FredokaOne",
		LayoutOrder = props.LayoutOrder,
	}, children)
end
return SmallText
