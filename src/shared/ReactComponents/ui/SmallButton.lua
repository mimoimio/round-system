local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundController = require(game.ReplicatedStorage.Shared.Controllers.SoundController)
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local function SmallButton(props)
	local scale, setScale = React.useBinding(1)

	local buttonClass = props.ButtonClass
	if buttonClass == nil then
		buttonClass = props.Image and "ImageButton" or "TextButton"
	end

	local bgTransparency = props.BackgroundTransparency
	if bgTransparency == nil then
		bgTransparency = 0.3
	end

	local buttonProps = {
		LayoutOrder = props.LayoutOrder,
		Size = props.Size or UDim2.new(0, 48, 0, 48),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = props.BackgroundColor3,
		BackgroundTransparency = bgTransparency,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex or 11,
		AutoButtonColor = props.AutoButtonColor,
		[React.Event.Activated] = props[React.Event.Activated] or nil,
		[React.Event.MouseEnter] = function()
			setScale(1.05)
			SoundController.Sound("Click")
		end,
		[React.Event.MouseLeave] = function()
			setScale(1)
			-- SoundController.Sound("Click")
		end,
	}

	if buttonClass == "ImageButton" then
		buttonProps.Image = props.Image
		buttonProps.ImageRectOffset = props.ImageRectOffset
		buttonProps.ImageRectSize = props.ImageRectSize
		buttonProps.ImageTransparency = props.ImageTransparency or 0
		buttonProps.ImageColor3 = props.ImageColor3 or props.TextColor3
		buttonProps.ScaleType = props.ScaleType or Enum.ScaleType.Fit
	else
		buttonProps.Text = props.Text or ""
		buttonProps.TextSize = props.TextSize or 16
		buttonProps.TextStrokeTransparency = props.TextStrokeTransparency or 1
		buttonProps.Font = props.Font or Enum.Font.FredokaOne
		buttonProps.TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255)
	end

	local overlayColor = props.KeybindColor3 or props.TextColor3 or Color3.fromRGB(255, 255, 255)

	props.children = props.children or {}
	props.children.UICorner = e("UICorner", { CornerRadius = props.CornerRadius or UDim.new(0, 8) })
	props.children.UITextSizeConstraint = e("UITextSizeConstraint", {
		MaxTextSize = 18,
		MinTextSize = 18,
	})
	props.children.UIScale = e("UIScale", {
		Scale = props.Scale,
	})
	props.children.TextOverlay = props.KeybindText
			and e("TextLabel", {
				TextYAlignment = Enum.TextYAlignment.Bottom,
				LayoutOrder = 1,
				Size = UDim2.new(0, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, -4),
				BackgroundTransparency = 1,
				Text = props.KeybindText,
				TextSize = props.KeybindTextSize or 20,
				TextTransparency = props.KeybindTextTransparency or 0.6,
				TextStrokeTransparency = props.KeybindTextStrokeTransparency or 0,
				Font = props.KeybindFont or Enum.Font.FredokaOne,
				TextColor3 = overlayColor,
				BorderSizePixel = 0,
				Active = false,
			}, {
				UITextSizeConstraint = e("UITextSizeConstraint", {
					MaxTextSize = 18,
					MinTextSize = 18,
				}),
				UICorner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			})
		or nil

	return e(buttonClass, buttonProps, props.children)
end

return SmallButton
