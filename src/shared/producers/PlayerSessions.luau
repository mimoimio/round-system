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
	Points: number,
	Inventory: { string },
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
	addParticipant: (userId: string, team: TeamColor) -> (),
	removeParticipant: (userId: string) -> (),
	setRoundWinner: (team: TeamColor) -> (),
}

export type PlayersState = {
	players: { [any]: PlayerEntity },
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
	addPlayer = function(state: PlayersState, playerId: any, data: Data)
		return Merge(state, {
			players = Set(state.players, playerId, {
				Data = data,
			}),
		})
	end,

	removePlayer = function(state: PlayersState, playerId: any)
		return Merge(state, {
			players = RemoveKey(state.players, playerId),
		})
	end,

	addPlayerCash = function(state: PlayersState, playerId: any, amt: number)
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

	deductPlayerCash = function(state: PlayersState, playerId: any, amt: number)
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

	setMusicVolume = function(state: PlayersState, playerId: any, volume: number)
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

	setSFXVolume = function(state: PlayersState, playerId: any, volume: number)
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

	setCharacter = function(state: PlayersState, playerId: any, character: Model?)
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

	addParticipant = function(state: PlayersState, userId: string, team: TeamColor)
		local existing = state.CurrentRound.Participants[userId]
		local participant: ParticipantEntity = if existing
			then Merge(existing, {
				Team = team,
			})
			else {
				Team = team,
				Points = 0,
				Inventory = {},
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
}
local producer = Reflex.createProducer(initialState, actions)

return producer :: Reflex.Producer<PlayersState, PlayersActions>
