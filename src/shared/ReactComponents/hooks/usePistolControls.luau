local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundController = require(ReplicatedStorage.Shared.Controllers.SoundController)

local useEffect = React.useEffect
local useRef = React.useRef
local useState = React.useState

export type InputMode = "Shield" | "Aim" | "Load" | "None"

type Controls = {
	mode: InputMode,
	setMode: (mode: InputMode) -> (),
	sendInput: (request: string, targetParticipantId: string?) -> (),
}

local localPlayer = Players.LocalPlayer
local DEBUG_CONTROL_LOGS = true
local MOBILE_DOUBLE_TAP_WINDOW = 0.3

local function logControl(message: string)
	if DEBUG_CONTROL_LOGS then
		print("[Pistol/MainControls] " .. message)
	end
end

local function usePistolControls(roundPhase: string, canControl: boolean): Controls
	local mode, setMode = useState("None" :: InputMode)
	local lastTouchTapAtRef = useRef(0)

	local function sendInput(request: string, targetParticipantId: string?)
		if not canControl then
			logControl(string.format("Blocked %s: no active participant control", request))
			return
		end

		if roundPhase ~= "ActionInput" then
			logControl(string.format("Blocked %s: phase=%s", request, roundPhase))
			return
		end

		if request == "AddShield" then
			SoundController.Sound("Click")
		elseif request == "RemoveShield" then
			SoundController.Sound("Click")
		elseif request == "Aim" then
			SoundController.Sound("Click")
		elseif request == "Load" then
			SoundController.Sound("Click")
		elseif request == "ToggleReady" then
			SoundController.Sound("Click")
		end

		logControl(string.format("Send %s target=%s", request, tostring(targetParticipantId)))
		Remotes.PistolInput:FireServer(request, targetParticipantId)
	end

	useEffect(function()
		if not canControl then
			return function() end
		end

		local click1 = localPlayer:GetMouse().Button1Down:Connect(function()
			if mode == "Shield" then
				sendInput("AddShield")
			end
		end)

		local click2 = localPlayer:GetMouse().Button2Down:Connect(function()
			if mode == "Shield" then
				sendInput("RemoveShield")
			end
		end)

		local keyboard = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end

			if input.KeyCode == Enum.KeyCode.Q then
				setMode("Shield")
				sendInput("AddShield")
			elseif input.KeyCode == Enum.KeyCode.E then
				setMode("Aim")
				sendInput("Aim")
			elseif input.KeyCode == Enum.KeyCode.R then
				setMode("Load")
				logControl("Pressed R (Load mode + request)")
				sendInput("Load")
			elseif input.KeyCode == Enum.KeyCode.Space then
				sendInput("ToggleReady")
			end
		end)

		local touchTap = UserInputService.TouchTap:Connect(function(_touchPositions, gameProcessed)
			if gameProcessed then
				return
			end

			local nowAt = os.clock()
			local isDoubleTap = (nowAt - lastTouchTapAtRef.current) <= MOBILE_DOUBLE_TAP_WINDOW
			lastTouchTapAtRef.current = nowAt

			if mode == "Shield" then
				if isDoubleTap then
					sendInput("RemoveShield")
				else
					sendInput("AddShield")
				end
				return
			end
		end)

		return function()
			click1:Disconnect()
			click2:Disconnect()
			keyboard:Disconnect()
			touchTap:Disconnect()
		end
	end, { mode, roundPhase, canControl })

	useEffect(function()
		setMode("None")
	end, { roundPhase, canControl })

	return {
		mode = mode,
		setMode = setMode,
		sendInput = sendInput,
	}
end

return usePistolControls
