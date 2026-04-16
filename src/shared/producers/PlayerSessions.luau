--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Reflex = require(ReplicatedStorage.Packages.Reflex)
local Sift = require(ReplicatedStorage.Packages.Sift)
local Dictionary = Sift.Dictionary
local Merge = Dictionary.merge
local Set = Dictionary.set
local RemoveKey = Dictionary.removeKey

export type Data = {
	Cash: number,
	MusicVolume: number?,
	SFXVolume: number?,
	[string]: any,
}

export type Phase = "WaitingForPlayers" | "Intermission" | "Starting" | "InProgress" | "Ended"
export type TeamColor = "Red" | "Blue" | "Draw" | "None"

export type ParticipantEntity = {
	Team: TeamColor,
	PlayerId: string,
	Points: number,
	Inventory: { string },
	AssignedKitchenId: string,
	CupId: string,
	ActiveOrders: { string },
}

export type RoundState = {
	Phase: Phase,
	TimeEnd: number,
	Winner: TeamColor,
	Participants: { [string]: ParticipantEntity },
}

export type PlayerEntity = {
	Data: Data,
	Character: Model?,
	Plot: Model?,
}

export type PlayersActions = {
	addPlayer: (playerId: string, data: Data) -> (),
	removePlayer: (playerId: string) -> (),
	addPlayerCash: (playerId: string, amt: number) -> (),
	deductPlayerCash: (playerId: string, amt: number) -> (),
	setMusicVolume: (playerId: string, volume: number) -> (),
	setSFXVolume: (playerId: string, volume: number) -> (),
	setCharacter: (playerId: string, character: Model?) -> (),
	setPhase: (newPhase: Phase, duration: number) -> (),
	addParticipant: (playerId: string?, userId: string, team: TeamColor) -> (), -- playerId may be nil cuz bot
	removeParticipant: (userId: string) -> (),
	setRoundWinner: (team: TeamColor) -> (),
	setParticipantCupId: (userId: string, cupId: string) -> (),
	setParticipantAssignedKitchenId: (userId: string, kitchenId: string) -> (),
	setParticipantActiveOrders: (userId: string, orders: { string }) -> (),
	addParticipantPoint: (userId: string, amount: number) -> (),
}

export type PlayersState = {
	players: { [string]: PlayerEntity },
	CurrentRound: RoundState,
}

local initialState: PlayersState = {
	players = {},
	CurrentRound = {
		Phase = "WaitingForPlayers",
		TimeEnd = 0,
		Winner = "None",
		Participants = {},
	},
}

local actions = {
	-- Player session management
	addPlayer = function(state: PlayersState, playerId: string, data: Data)
		return Merge(state, {
			players = Set(state.players, playerId, {
				Data = data,
			}),
		})
	end,

	removePlayer = function(state: PlayersState, playerId: string)
		return Merge(state, {
			players = RemoveKey(state.players, playerId),
		})
	end,

	addPlayerCash = function(state: PlayersState, playerId: string, amt: number)
		local playerEntity = state.players[playerId]
		if not playerEntity then
			return state
		end

		return Merge(state, {
			players = Set(
				state.players,
				playerId,
				Merge(playerEntity, {
					Data = Merge(playerEntity.Data, {
						Cash = (playerEntity.Data.Cash or 0) + amt,
					}),
				})
			),
		})
	end,

	deductPlayerCash = function(state: PlayersState, playerId: string, amt: number)
		local playerEntity = state.players[playerId]
		if not playerEntity then
			return state
		end

		return Merge(state, {
			players = Set(
				state.players,
				playerId,
				Merge(playerEntity, {
					Data = Merge(playerEntity.Data, {
						Cash = (playerEntity.Data.Cash or 0) - amt,
					}),
				})
			),
		})
	end,

	setMusicVolume = function(state: PlayersState, playerId: string, volume: number)
		local playerEntity = state.players[playerId]
		if not playerEntity then
			return state
		end

		return Merge(state, {
			players = Set(
				state.players,
				playerId,
				Merge(playerEntity, {
					Data = Merge(playerEntity.Data, {
						MusicVolume = volume,
					}),
				})
			),
		})
	end,

	setSFXVolume = function(state: PlayersState, playerId: string, volume: number)
		local playerEntity = state.players[playerId]
		if not playerEntity then
			return state
		end

		return Merge(state, {
			players = Set(
				state.players,
				playerId,
				Merge(playerEntity, {
					Data = Merge(playerEntity.Data, {
						SFXVolume = volume,
					}),
				})
			),
		})
	end,

	setCharacter = function(state: PlayersState, playerId: string, character: Model?)
		local playerEntity = state.players[playerId]
		if not playerEntity then
			return state
		end

		return Merge(state, {
			players = Set(
				state.players,
				playerId,
				Merge(playerEntity, {
					Character = character,
				})
			),
		})
	end,

	setPhase = function(state: PlayersState, newPhase: Phase, duration: number)
		local clampedDuration = math.max(0, duration)
		return Merge(state, {
			CurrentRound = Merge(state.CurrentRound, {
				Phase = newPhase,
				TimeEnd = os.time() + clampedDuration,
				Winner = if newPhase == "Ended" then state.CurrentRound.Winner else "None",
			}),
		})
	end,

	addParticipant = function(state: PlayersState, playerId: string, userId: string, team: TeamColor)
		local existing = state.CurrentRound.Participants[userId]
		local participant: ParticipantEntity = if existing
			then Merge(existing, {
				Team = team,
			})
			else {
				Team = team,
				PlayerId = playerId,
				Points = 0,
				Inventory = {},
				AssignedKitchenId = "",
				CupId = "Empty",
				ActiveOrders = {},
			}

		return Merge(state, {
			CurrentRound = Merge(state.CurrentRound, {
				Participants = Set(state.CurrentRound.Participants, userId, participant),
			}),
		})
	end,

	removeParticipant = function(state: PlayersState, userId: string)
		return Merge(state, {
			CurrentRound = Merge(state.CurrentRound, {
				Participants = RemoveKey(state.CurrentRound.Participants, userId),
			}),
		})
	end,

	setRoundWinner = function(state: PlayersState, team: TeamColor)
		return Merge(state, {
			CurrentRound = Merge(state.CurrentRound, {
				Winner = team,
			}),
		})
	end,

	setParticipantCupId = function(state: PlayersState, userId: string, cupId: string)
		local participant = state.CurrentRound.Participants[userId]
		if not participant then
			return state
		end

		return Merge(state, {
			CurrentRound = Merge(state.CurrentRound, {
				Participants = Set(
					state.CurrentRound.Participants,
					userId,
					Merge(participant, {
						CupId = cupId,
					})
				),
			}),
		})
	end,

	setParticipantAssignedKitchenId = function(state: PlayersState, userId: string, kitchenId: string)
		local participant = state.CurrentRound.Participants[userId]
		if not participant then
			return state
		end

		return Merge(state, {
			CurrentRound = Merge(state.CurrentRound, {
				Participants = Set(
					state.CurrentRound.Participants,
					userId,
					Merge(participant, {
						AssignedKitchenId = kitchenId,
					})
				),
			}),
		})
	end,

	setParticipantActiveOrders = function(state: PlayersState, userId: string, orders: { string })
		local participant = state.CurrentRound.Participants[userId]
		if not participant then
			return state
		end

		return Merge(state, {
			CurrentRound = Merge(state.CurrentRound, {
				Participants = Set(
					state.CurrentRound.Participants,
					userId,
					Merge(participant, {
						ActiveOrders = orders,
					})
				),
			}),
		})
	end,

	addParticipantPoint = function(state: PlayersState, userId: string, amount: number)
		local participant = state.CurrentRound.Participants[userId]
		if not participant then
			return state
		end

		return Merge(state, {
			CurrentRound = Merge(state.CurrentRound, {
				Participants = Set(
					state.CurrentRound.Participants,
					userId,
					Merge(participant, {
						Points = participant.Points + amount,
					})
				),
			}),
		})
	end,
}
local producer = Reflex.createProducer(initialState, actions)

return producer :: Reflex.Producer<PlayersState, PlayersActions>
