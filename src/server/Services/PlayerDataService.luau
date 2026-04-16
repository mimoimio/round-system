local DATASTORENAME = "CRAFTCOFFEE"
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStoreModule = require(game.ServerScriptService.Server.Modules.ProfileStore) -- Adjust path if needed
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Reflex = require(game.ReplicatedStorage.Packages.Reflex)
local PlayerSessions = require(ReplicatedStorage.Shared.producers.PlayerSessions)
local Mionum = require(ReplicatedStorage.Packages.Mionum)
local Signal = require(game.ReplicatedStorage.Packages.Signal)

local GLOBAL_ACTIONS = {
	setPhase = true,
	addParticipant = true,
	removeParticipant = true,
	setRoundWinner = true,
	setParticipantCupId = true,
	setParticipantAssignedKitchenId = true,
	setParticipantActiveOrders = true,
	addParticipantPoint = true,
}

type Profile = ProfileStoreModule.Profile<PlayerData> -- Typed Profile object
export type PotionInstance = {
	UID: string,
	PotionId: string,
	VariationId: string,
	Size: number,
}

local Potions = {}
local PROFILE_TEMPLATE: PlayerSessions.Data = {
	Cash = 50,
	Cauldrons = {},
	Potions = Potions,
	PotionSlots = {},
	PotionBook = {
		none = {},
	},
	Ingredients = {},
	Multipliers = {}, -- { [multiplierId]: { DisplayName, Value (bonus %), Expire } }
	Collectors = {},
	ShopCycles = {},
	TutorialFinished = false,
	Gifts = {},
	MusicVolume = 0.3, -- [0,1]
	SFXVolume = 0.3,
	LastRouletteClaimTime = nil,
	LastOnline = nil,
	CurrentLoginSnapshot = nil,
}

local function selectPlayerData(player: Player)
	local playerId = tostring(player.UserId)
	return function(state)
		return state.players[playerId] and state.players[playerId].Data
	end
end

local function selectPlayerCash(player: Player)
	local playerId = tostring(player.UserId)
	return function(state)
		local playerEntity = state.players[playerId]
		return if playerEntity and playerEntity.Data then playerEntity.Data.Cash else 0
	end
end

local function ensureLeaderstatsCash(player: Player, initialCash: number): NumberValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local cashValue = leaderstats:FindFirstChild("Cash")
	if not cashValue or not cashValue:IsA("NumberValue") then
		if cashValue then
			cashValue:Destroy()
		end

		cashValue = Instance.new("NumberValue")
		cashValue.Name = "Cash"
		cashValue.Parent = leaderstats
	end

	cashValue.Value = initialCash
	return cashValue
end

-- 3. Create the ProfileStore object using New()
local PlayerProfileStore = ProfileStoreModule.New(
	DATASTORENAME, -- Your DataStore name
	PROFILE_TEMPLATE
)

-- 4. Cache for active player profiles on this server
local Profiles: { [Player]: Profile } = {}

-- Service module to return
local PlayerDataService = {}
PlayerDataService.PlayerSessions = {}
PlayerDataService.PROFILE_TEMPLATE = PROFILE_TEMPLATE
function PlayerDataService:GetProfile(player: Player)
	return Profiles[player]
end

-- create bindable events
local ProfileCreated = Signal.new()
PlayerDataService.ProfileCreated = ProfileCreated

local ProfileSessionEnded = Signal.new()
PlayerDataService.ProfileSessionEnded = ProfileSessionEnded

-- Function to handle when a player joins the game
local function OnPlayerAdded(player: Player)
	local profileKey = tostring(player.UserId) -- Use UserId as the key

	-- Load and session-lock the profile asynchronously
	local profile: Profile? = PlayerProfileStore:StartSessionAsync(profileKey)
	print("profile", profileKey, profile)
	if profile then
		-- Add GDPR compliance UserIds (Recommended)
		profile:AddUserId(player.UserId)

		-- Fill in missing data fields from the template
		profile:Reconcile()

		-- Store the active profile in the cache
		Profiles[player] = profile

		ProfileCreated:Fire()
	else
		-- The profile couldn't be loaded
		warn(`Critical error: Failed to load profile for {player.Name} ({player.UserId}). Kicking.`)
		-- player:Kick("Failed to load your data. Please try rejoining the server.")
	end
end

-- Function to handle when a player leaves the game
local function OnPlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile then
		-- End the session - this saves the data and unlocks the session
		profile.Data.LastOnline = workspace:GetServerTimeNow()
		profile:EndSession()
		print(`Ending session profile for {player.Name} ({player.UserId}) on leave.`)
	end
end

-- Function to handle server shutdown
local function OnShutdown()
	-- warn("Server shutting down. Ending sessions for all active player profiles...")
	local startTime = os.clock()

	-- Iterate through all active profiles and end sessions concurrently
	local threads = {}
	for player, profile in pairs(Profiles) do
		-- Check if the profile session is still active before trying to end it
		if profile:IsActive() then -- IsActive() is still valid
			table.insert(
				threads,
				task.spawn(function()
					profile:EndSession() -- Yields until saved and released
					print(`Profile session for {player.Name} ended during shutdown.`)
				end)
			)
		end
	end

	-- Wait for all end session threads to complete
	for _, thread in ipairs(threads) do
		task.wait(thread) -- Wait for each coroutine to finish
	end

	local duration = os.clock() - startTime
	warn(`All profile sessions ended. Shutdown process took {string.format("%.2f", duration)} seconds.`)
end

function PlayerDataService.initialize()
	PlayerDataService.initialized = true
	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)
	-- Bind the shutdown function
	game:BindToClose(OnShutdown)
end

local broadcaster = Reflex.createBroadcaster({
	producers = {
		PlayerSessions = PlayerSessions,
	},
	beforeHydrate = function(
		player --[[,state]]
	)
		local state = PlayerSessions:getState()
		local playerId = tostring(player.UserId)
		return {
			players = { [playerId] = state.players[playerId] },
			CurrentRound = state.CurrentRound,
		}
	end,
	dispatch = function(player, actions)
		local playerId = tostring(player.UserId)
		local relevantActions = {}

		for _, action in actions do
			local targetPlayer = action.arguments[1]
			-- Logic:
			-- 1. If targetPlayer matches the current player (Private)
			-- 2. OR if targetPlayer is nil (Global - send to everyone)
			-- if action.name == "emptyCollector" then
			-- 	continue
			-- end
			if GLOBAL_ACTIONS[action.name] then
				table.insert(relevantActions, action)
			elseif targetPlayer == playerId or targetPlayer == nil then
				table.insert(relevantActions, action)
			elseif action.name == "setCurrentSeed" or action.name == "updateAllCollectors" then
				table.insert(relevantActions, action)
			end
		end

		if #relevantActions > 0 then
			Remotes.dispatch:FireClient(player, relevantActions)
		end
	end,
})

PlayerSessions:applyMiddleware(broadcaster.middleware)

Remotes.start.OnServerEvent:Connect(function(player)
	broadcaster:start(player)
	local profile
	local timeout = 10 -- seconds
	local elapsed = 0
	repeat
		profile = Profiles[player]
		task.wait(0.1)
		elapsed += 0.1
		if elapsed >= timeout then
			player:Kick("Failed to load your data. Please try rejoining.")
			return
		end
	until profile
	local character = player.Character or player.CharacterAdded:Wait()
	local playerId = tostring(player.UserId)
	PlayerSessions.addPlayer(playerId, profile.Data)
	local cashValue = ensureLeaderstatsCash(player, profile.Data.Cash or 0)
	local selectData = selectPlayerData(player)
	local selectCash = selectPlayerCash(player)
	local unsubscribe = PlayerSessions:subscribe(selectData, function(state, prevData)
		profile.Data = state
	end)
	local unsubscribeCash = PlayerSessions:subscribe(selectCash, function(cash)
		cashValue.Value = cash
	end)

	task.spawn(function()
		PlayerSessions.setCharacter(playerId, character)
	end)

	player.CharacterAdded:Connect(function(character)
		-- PlayerSessions.setCharacter(playerId, character)
		-- local entity = PlayerSessions:getState().players[playerId]
		-- if not (entity and entity.Plot) then
		-- 	return
		-- end
		-- character:PivotTo(entity.Plot:GetPivot())
	end)

	profile.OnSessionEnd:Connect(function()
		unsubscribe()
		unsubscribeCash()
		Profiles[player] = nil
		PlayerSessions.removePlayer(playerId)
		player:Kick("Your data session has ended. Please rejoin.")
		ProfileSessionEnded:Fire()
	end)
end)

return PlayerDataService
