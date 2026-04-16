local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReactFlow = require(ReplicatedStorage.Packages.ReactFlow)
local React = require(ReplicatedStorage.Packages.React)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef
local useSpring = ReactFlow.useSpring
local useTween = ReactFlow.useTween
local useToast = require(script.Parent.Toasts).useToast

local RING_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.499, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 0),
})

local function getInputIndicator(inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Keyboard then
		return "[E]"
	-- elseif inputType == Enum.ProximityPromptInputType.Gamepad then
	-- 	return "(Y)"
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "👆"
	-- elseif inputType == Enum.ProximityPromptInputType.MouseButton1 then
	-- 	return "🖱️"
	else
		return "[?]"
	end
end

local PromptIndicator -- forward declaration
local TimingBar -- forward declaration

local function PromptButton(props: { prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType })
	local prompt = props.prompt
	local triggered, setTriggered = useState(false)
	local timestart = useRef(nil)
	local position, setPosition = useSpring({
		start = 0,
		target = 5,
		speed = 22,
		damper = 0.5,
	})
	local scale, setScale = useSpring({
		start = 0,
		target = 0,
		speed = 22,
		damper = 0.5,
	})
	local progress, setProgress = useTween({
		start = 0, -- Initial value (required)
		target = 0, -- Target value (optional)
		info = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
	})

	local holdActive, setHoldActive = useState(false)
	local inputIndicator = getInputIndicator(props.inputType)

	useEffect(function()
		setScale({
			start = 0.5,
			target = 1,
			speed = 22,
			damper = 0.5,
		})
		-- return function() end
	end, {})

	useEffect(function()
		if not props.isClosing then
			return
		end

		setScale({
			start = 1,
			target = 0,
			speed = 22,
			damper = 0.5,
		})
	end, { props.isClosing })

	-- Listen to hold events
	useEffect(function()
		local trigger = prompt.Triggered:Connect(function()
			Remotes.InteractStation:FireServer(props.IngredientId)
			warn("Yeah")
			setPosition({
				start = -5,
				target = 0,
				speed = 20,
				damper = 0.4,
			})
			task.spawn(function()
				setTriggered(true)
				task.wait(0.3)
				setTriggered(false)
			end)
		end)
		local holdBeganConn = prompt.PromptButtonHoldBegan:Connect(function()
			setScale({
				start = 1,
				target = 1.05,
				speed = 22,
				damper = 0.5,
			})

			setHoldActive(true)
			setProgress({
				start = 0,
				target = 1,
				info = TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			})
			local start = tick()
			timestart.current = start
		end)

		local holdEndedConn = prompt.PromptButtonHoldEnded:Connect(function()
			setScale({
				target = 1,
				speed = 22,
				damper = 0.5,
			})
			setHoldActive(false)
			setProgress({
				target = 0,
				info = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			})
			local ended = tick()
		end)

		return function()
			holdBeganConn:Disconnect()
			holdEndedConn:Disconnect()
			trigger:Disconnect()
		end
	end, {})

	return e("ImageButton", {
		Size = UDim2.new(0, 200, 0, 50),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Active = not props.isClosing,
		Position = position:map(function(n)
			return UDim2.new(1, -200, 1, -200 + n)
		end),
		[React.Event.MouseButton1Down] = function()
			prompt:InputHoldBegin()
		end,
		[React.Event.MouseButton1Up] = function()
			prompt:InputHoldEnd()
		end,
		BackgroundTransparency = 1,
		ImageColor3 = Color3.new(1, 1, 0),
		Image = "rbxassetid://139863296810113",
		ImageTransparency = 0.6,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		UIScale = e("UIScale", { Scale = scale }),
		ProgressBar = e("Frame", {
			Size = progress:map(function(p)
				return UDim2.new(1, 0, p, 0)
			end),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(100, 200, 255),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		}),
		Text = e("TextLabel", {
			Text = inputIndicator .. " " .. prompt.ActionText,
			TextSize = 24,
			Font = "FredokaOne",
			TextStrokeTransparency = 0,
			TextColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}),
		Indicator = e(PromptIndicator, {
			prompt = prompt,
			isClosing = props.isClosing,
			progress = progress,
			triggered = triggered,
		}),
	})
end

PromptIndicator = function(props: {
	prompt: ProximityPrompt,
	isClosing: boolean?,
	progress: any,
	triggered: boolean,
})
	local prompt = props.prompt
	local offset, setOffset = useSpring({
		start = 0,
		target = 0,
		speed = 22,
		damper = 0.7,
	})
	local scale, setScale = useSpring({
		start = 0,
		target = 0,
		speed = 22,
		damper = 0.5,
	})
	local rot, setRot = useSpring({
		start = 0,
		target = 0,
		speed = 22,
		damper = 0.5,
	})

	useEffect(function()
		if props.triggered then
			setRot({
				start = 0,
				target = 15,
				speed = 45,
				damper = 0.1,
			})
			setScale({
				start = 1,
				target = 1.1,
				speed = 22,
				damper = 0.5,
			})

			task.wait(0.2)
			setRot({
				target = 0,
				speed = 45,
				damper = 0.1,
			})
			setScale({
				target = 1,
				speed = 22,
				damper = 0.5,
			})
		end
	end, { props.triggered })

	useEffect(function()
		setOffset({
			start = 0,
			target = 1,
			speed = 22,
			damper = 0.5,
		})
		setScale({
			start = 0,
			target = 1,
			speed = 22,
			damper = 0.5,
		})
	end, {})

	useEffect(function()
		if not props.isClosing then
			local highlightRef = prompt and prompt:FindFirstChild("Highlight")
			local obj = highlightRef and highlightRef.Value
			local highlight
			if obj then
				highlight = Instance.new("Highlight", obj)
				highlight.Adornee = obj
				highlight.FillColor = Color3.new(1, 1, 1)
				highlight.FillTransparency = 0.8
				highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			end
			return function()
				if highlight then
					highlight:Destroy()
				end
			end
		end
		setOffset({
			start = 1,
			target = 0,
			speed = 22,
			damper = 0.5,
		})
		setScale({
			start = 1,
			target = 0,
			speed = 22,
			damper = 0.5,
		})
	end, { props.isClosing })
	local customer = prompt:GetAttribute("customer")
	return e("BillboardGui", {
		Adornee = prompt.Parent,
		Size = UDim2.new(0, 90, 0, 90),
		AlwaysOnTop = true,
		SizeOffset = customer and Vector2.new() or offset:map(function(n)
			return Vector2.new(0, n)
		end),
		StudsOffset = customer and Vector3.new(0, -1, 0) or Vector3.new(),
	}, {
		CircularProgress = not customer and e("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 1,
			-- Rotation = rot:map(function(r)
			-- 	return (customer and 180 or 0) + r
			-- end),
		}, {
			LeftGradient = e("Frame", {
				Size = UDim2.new(0.5, 1, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
			}, {
				ProgressBarImage = e("ImageLabel", {
					Size = UDim2.new(2, 0, 1, 0),
					Position = UDim2.new(0, 0, 0, 0),
					BackgroundTransparency = 1,
					Image = "rbxassetid://12403099647",
					ImageColor3 = Color3.fromRGB(255, 100, 100),
				}, {
					UIGradient = e("UIGradient", {
						Rotation = props.progress:map(function(p)
							return math.clamp(p * 360, 180, 360)
						end),
						Transparency = RING_TRANSPARENCY,
					}),
				}),
			}),
			RightGradient = e("Frame", {
				Size = UDim2.new(0.5, 1, 1, 0),
				Position = UDim2.new(0.5, -1, 0, 0),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
			}, {
				ProgressBarImage = e("ImageLabel", {
					Size = UDim2.new(2, 0, 1, 0),
					Position = UDim2.new(-1, 0, 0, 0),
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Image = "rbxassetid://12403099647",
					ImageColor3 = Color3.fromRGB(255, 100, 100),
				}, {
					UIGradient = e("UIGradient", {
						Rotation = props.progress:map(function(p)
							return math.clamp(p * 360, 0, 180)
						end),
						Transparency = RING_TRANSPARENCY,
					}),
				}),
			}),
			UIScale = e("UIScale", { Scale = scale }),
		}),
		Frame = e("ImageLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BorderSizePixel = 4,
			BackgroundTransparency = 1,
			Image = customer and "rbxassetid://104551724222085" or "rbxassetid://12403099647",
			BorderMode = Enum.BorderMode.Outline,
		}, {
			UIScale = e("UIScale", { Scale = scale }),
		}),
		Text = e("TextLabel", {
			Text = prompt.ObjectText,
			TextSize = 24,
			Font = "FredokaOne",
			AnchorPoint = Vector2.new(0.5, 0),

			Rotation = rot:map(function(r)
				return (customer and 180 or 0) + r
			end),
			TextStrokeTransparency = 0,
			TextColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0.5, 0, 1, -5),
			BackgroundTransparency = 1,
		}, {
			UIScale = e("UIScale", { Scale = scale }),
		}),
	})
end

TimingBar = function(props: {
	prompt: ProximityPrompt,
	isClosing: boolean?,
	id: string,
})
	local prompt = props.prompt
	local scoreText, setScoreText = useState("")
	local scale, setScale = useSpring({
		start = 0,
		target = 0,
		speed = 22,
		damper = 0.5,
	})
	local rot, setRot = useSpring({
		start = 0,
		target = 0,
		damper = 0.5,
		speed = 20,
	})

	local progress, setProgress = useTween({
		start = 0,
		target = 0,
		info = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
	})
	local textY, setTextY = useTween({
		start = 0,
		target = 0,
		info = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
	})
	local textScale, setTextScale = useTween({
		start = 0,
		target = 0,
		info = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
	})
	local textTransparency, setTextTransparency = useTween({
		start = 1,
		target = 1,
		info = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
	})

	useEffect(function()
		setScale({
			start = 0,
			target = 1,
			speed = 22,
			damper = 0.5,
		})
	end, {})

	useEffect(function()
		if not props.isClosing then
			return
		end

		setScale({
			start = 1,
			target = 0,
			speed = 22,
			damper = 0.5,
		})
	end, { props.isClosing })

	useEffect(function()
		local holdBeganConn = prompt.PromptButtonHoldBegan:Connect(function()
			setProgress({
				start = 0,
				target = 1,
				info = TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Circular, Enum.EasingDirection.In),
			})
		end)

		local holdEndedConn = prompt.PromptButtonHoldEnded:Connect(function()
			-- Fire remote event to server with ingredient name and time elapsed
			local ingredientId = prompt.Name
			-- local score = calculateScore(elapsed, prompt.HoldDuration)
			local value = progress:getValue()
			setProgress({
				-- start = value,
				target = value,
				info = TweenInfo.new(0, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			})
			local validatedScore = Remotes.AddIngredient:InvokeServer(ingredientId, value) -- this yields
			if validatedScore == 1 then
				setRot({
					start = 4,
					target = 0,
					damper = 0.1,
					speed = 20,
				})
			elseif validatedScore == 2 then
				setRot({
					start = 6,
					target = 0,
					damper = 0.1,
					speed = 20,
				})
				setScoreText("Nice!")
				setTextY({
					start = 0,
					target = -80,
					info = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
				})
				setTextScale({
					start = 0.5,
					target = 1.2,
					info = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
				})
				setTextTransparency({
					start = 0,
					target = 1,
					info = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
				})
			elseif validatedScore == 3 then
				setRot({
					start = 8,
					target = 0,
					damper = 0.1,
					speed = 20,
				})
				setScoreText("Perfect!")
				setTextY({
					start = 0,
					target = -80,
					info = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
				})
				setTextScale({
					start = 0.5,
					target = 1.3,
					info = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
				})
				setTextTransparency({
					start = 0,
					target = 1,
					info = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
				})
			end
		end)

		return function()
			holdBeganConn:Disconnect()
			holdEndedConn:Disconnect()
		end
	end, {})

	return e("Frame", {
		Size = UDim2.new(0, 300, 0, 50),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -200, 1, -270),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 4,
		Rotation = rot,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Thickness = 4,
			Color = Color3.new(1, 1, 1),
		}),
		UIScale = e("UIScale", { Scale = scale }),
		Score2 = e("Frame", {
			Size = UDim2.new(0.5, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(160, 160, 20),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0.5, 0),
			ZIndex = -3,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),
		Score3 = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0.15, 0, 1, 0),
			BackgroundTransparency = 0.3,
			BackgroundColor3 = Color3.fromRGB(50, 200, 50),
			BorderSizePixel = 0,
			ZIndex = -2,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),
		Score1 = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0.8, 0, 1, 0),
			BackgroundTransparency = 0.3,
			BackgroundColor3 = Color3.fromRGB(0, 100, 0),
			BorderSizePixel = 0,
			ZIndex = -5,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),

		ProgressFill = e("Frame", {
			Size = UDim2.new(0, 5, 2, 0),
			Position = progress:map(function(p)
				return UDim2.new(p, 0, 0.5, 0)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),
		ScoreText = scoreText ~= "" and e("TextLabel", {
			Text = scoreText,
			TextSize = 32,
			Font = "FredokaOne",
			TextStrokeTransparency = 0,
			TextColor3 = scoreText == "Perfect!" and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(255, 255, 100),
			Size = UDim2.new(1, 0, 1, 0),
			Position = textY:map(function(y)
				return UDim2.new(0.5, 0, 0.5, y)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			TextTransparency = textTransparency,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			ZIndex = 10,
		}, {
			UIScale = e("UIScale", {
				Scale = textScale,
			}),
		}),
	})
end

local function IngredientProximityPrompts(props)
	local prompts, setPrompts = useState({} :: { [string]: ProximityPrompt })
	local timingBars, setTimingBars = useState({} :: { [string]: ProximityPrompt })

	useEffect(function()
		local connection = ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
			if not table.find(prompt:GetTags(), "ingredients") and not prompt:GetAttribute("customer") then
				return
			end
			local id = tostring(tick())

			-- Create timing bar for ingredients (not customers)
			if table.find(prompt:GetTags(), "ingredients") then
				setTimingBars(function(prev)
					local newBars = table.clone(prev)
					newBars[id] = {
						prompt = prompt,
					}
					return newBars
				end)
			end

			setPrompts(function(prev)
				local newPrompts = table.clone(prev)
				newPrompts[id] = {
					prompt = prompt,
					inputType = inputType,
				}
				return newPrompts
			end)
			prompt.PromptHidden:Wait()

			-- Close timing bar
			setTimingBars(function(prev)
				local newBars = table.clone(prev)
				local bar = newBars[id]
				if bar then
					bar.isClosing = true
				end
				return newBars
			end)

			setPrompts(function(prev)
				local newPrompts = table.clone(prev)
				local xprompt = newPrompts[id]
				if xprompt then
					xprompt.isClosing = true
				end
				return newPrompts
			end)
			task.wait(1) -- wait for animation

			-- Remove timing bar
			setTimingBars(function(prev)
				local newBars = table.clone(prev)
				newBars[id] = nil
				return newBars
			end)

			setPrompts(function(prev)
				local newPrompts = table.clone(prev)
				newPrompts[id] = nil
				return newPrompts
			end)
		end)
		return function()
			if connection then
				connection:Disconnect()
			end
		end
	end, {})
	local children = {}
	for i, prompt: { prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType, isClosing: boolean? } in prompts do
		children[i] = e(PromptButton, {
			IngredientId = prompt.prompt:GetAttribute("IngredientId"),
			prompt = prompt.prompt,
			inputType = prompt.inputType,
			isClosing = prompt.isClosing,
		})
	end

	-- Add timing bars
	for i, bar: { prompt: ProximityPrompt, isClosing: boolean? } in timingBars do
		if bar.prompt.Name == "cup" or bar.prompt.Name == "trash" then
			continue
		end
		children["timingBar_" .. i] = e(TimingBar, {
			prompt = bar.prompt,
			isClosing = bar.isClosing,
			id = i,
		})
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, children)
end

return IngredientProximityPrompts
