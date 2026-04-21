local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)

local Primitives = ReplicatedStorage.Shared.ReactComponents.ui
local HStack = require(Primitives.HStack)
local SmallText = require(Primitives.SmallText)
local VStack = require(Primitives.VStack)

local e = React.createElement
local useEffect = React.useEffect
local useState = React.useState

local localPlayer = Players.LocalPlayer
local localPlayerId = tostring(localPlayer.UserId)

type StatsPanelProps = {
	LayoutOrder: number?,
}

local function StatItem(label: string, value: number, layoutOrder: number)
	return e(VStack, {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		VerticalFlex = Enum.UIFlexAlignment.None,
		Spacing = UDim.new(0, 2),
		LayoutOrder = layoutOrder,
	}, {
		Label = e(SmallText, {
			Text = label,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 1,
		}),
		Value = e(SmallText, {
			Text = tostring(value),
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 2,
		}),
	})
end

local function StatsPanel(props: StatsPanelProps)
	local data, setData = useState(function()
		local state = PlayerSessions:getState()
		local entity = state.players[localPlayerId]
		return if entity then entity.Data else nil
	end)

	useEffect(function()
		local unsubscribeStats = PlayerSessions:subscribe(function(state: PlayerSessions.PlayersState)
			local entity = state.players[localPlayerId]
			return if entity then entity.Data else nil
		end, function(nextData)
			setData(nextData)
		end)

		return function()
			unsubscribeStats()
		end
	end, {})

	local cash = if data and type(data.Cash) == "number" then data.Cash else 0
	local kills = if data and type(data.Kills) == "number" then data.Kills else 0
	local assists = if data and type(data.Assists) == "number" then data.Assists else 0
	local wins = if data and type(data.Wins) == "number" then data.Wins else 0

	return e(HStack, {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Spacing = UDim.new(0, 18),
		ZIndex = 10,
		Padding = {
			Left = UDim.new(0, 8),
			Right = UDim.new(0, 8),
			Top = UDim.new(0, 4),
			Bottom = UDim.new(0, 4),
		},
		LayoutOrder = props.LayoutOrder,
	}, {
		Cash = StatItem("Cash", cash, 1),
		Kills = StatItem("Kills", kills, 2),
		Assists = StatItem("Assists", assists, 3),
		Wins = StatItem("Wins", wins, 4),
	})
end

return StatsPanel
