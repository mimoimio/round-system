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
	Kills: number,
	Assists: number,
	Wins: number,
	[string]: any,
}

export type Phase = "WaitingForPlayers" | "Intermission" | "ActionInput" | "Resolution" | "Ended"
export type PendingAction = "None" | "Load" | "Shield" | "Shoot"

export type ParticipantEntity = {
	PlayerId: string,
	IsAlive: boolean,
	Bullets: number,
	PendingAction: PendingAction,
	PendingShields: number,
	PendingTargets: { [string]: number },
	IsReady: boolean,
}

export type RoundState = {
	Phase: Phase,
	TimeEnd: number,
	TurnIndex: number,
	WinnerParticipantId: string?,
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
	setRoundTurnIndex: (turnIndex: number) -> (),
	setRoundWinnerParticipant: (participantId: string?) -> (),
	addParticipant: (playerId: string, participantId: string) -> (),
	removeParticipant: (participantId: string) -> (),
	setParticipantAlive: (participantId: string, isAlive: boolean) -> (),
	setParticipantBullets: (participantId: string, bullets: number) -> (),
	addParticipantBullets: (participantId: string, amount: number) -> (),
	setParticipantPendingAction: (participantId: string, action: PendingAction) -> (),
	setParticipantReady: (participantId: string, isReady: boolean) -> (),
	addParticipantShield: (participantId: string, amount: number) -> (),
	clearParticipantPending: (participantId: string) -> (),
	setParticipantTargetAllocation: (participantId: string, targetParticipantId: string, amount: number) -> (),
	resetParticipantForRound: (participantId: string, bullets: number) -> (),
	addPlayerKill: (participantId: string, amount: number) -> (),
	addPlayerAssist: (participantId: string, amount: number) -> (),
	addPlayerWin: (participantId: string, amount: number) -> (),
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
		TurnIndex = 0,
		WinnerParticipantId = nil,
		Participants = {},
	},
}

local function updateParticipant(
	state: PlayersState,
	participantId: string,
	updater: (participant: ParticipantEntity) -> ParticipantEntity
): PlayersState
	local participant = state.CurrentRound.Participants[participantId]
	if not participant then
		return state
	end

	return Merge(state, {
		CurrentRound = Merge(state.CurrentRound, {
			Participants = Set(state.CurrentRound.Participants, participantId, updater(participant)),
		}),
	})
end

local function ensureCombatStats(data: Data): Data
	local kills = if type(data.Kills) == "number" then data.Kills else 0
	local assists = if type(data.Assists) == "number" then data.Assists else 0
	local wins = if type(data.Wins) == "number" then data.Wins else 0

	return Merge(data, {
		Kills = math.max(0, kills),
		Assists = math.max(0, assists),
		Wins = math.max(0, wins),
	})
end

local function updateParticipantPlayerData(
	state: PlayersState,
	participantId: string,
	updater: (data: Data) -> Data
): PlayersState
	local participant = state.CurrentRound.Participants[participantId]
	if not participant then
		return state
	end

	local playerId = participant.PlayerId
	local playerEntity = state.players[playerId]
	if not playerEntity then
		return state
	end

	return Merge(state, {
		players = Set(
			state.players,
			playerId,
			Merge(playerEntity, {
				Data = updater(ensureCombatStats(playerEntity.Data)),
			})
		),
	})
end

local actions = {
	addPlayer = function(state: PlayersState, playerId: string, data: Data)
		return Merge(state, {
			players = Set(state.players, playerId, {
				Data = ensureCombatStats(data),
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
			}),
		})
	end,

	setRoundTurnIndex = function(state: PlayersState, turnIndex: number)
		return Merge(state, {
			CurrentRound = Merge(state.CurrentRound, {
				TurnIndex = math.max(0, turnIndex),
			}),
		})
	end,

	setRoundWinnerParticipant = function(state: PlayersState, participantId: string?)
		return Merge(state, {
			CurrentRound = Merge(state.CurrentRound, {
				WinnerParticipantId = participantId,
			}),
		})
	end,

	addParticipant = function(state: PlayersState, playerId: string, participantId: string)
		if state.CurrentRound.Participants[participantId] then
			return state
		end

		local participant: ParticipantEntity = {
			PlayerId = playerId,
			IsAlive = true,
			Bullets = 0,
			PendingAction = "None",
			PendingShields = 0,
			PendingTargets = {},
			IsReady = false,
		}

		return Merge(state, {
			CurrentRound = Merge(state.CurrentRound, {
				Participants = Set(state.CurrentRound.Participants, participantId, participant),
			}),
		})
	end,

	removeParticipant = function(state: PlayersState, participantId: string)
		return Merge(state, {
			CurrentRound = Merge(state.CurrentRound, {
				Participants = RemoveKey(state.CurrentRound.Participants, participantId),
			}),
		})
	end,

	setParticipantAlive = function(state: PlayersState, participantId: string, isAlive: boolean)
		return updateParticipant(state, participantId, function(participant)
			return Merge(participant, {
				IsAlive = isAlive,
			})
		end)
	end,

	setParticipantBullets = function(state: PlayersState, participantId: string, bullets: number)
		return updateParticipant(state, participantId, function(participant)
			return Merge(participant, {
				Bullets = math.max(0, bullets),
			})
		end)
	end,

	addParticipantBullets = function(state: PlayersState, participantId: string, amount: number)
		return updateParticipant(state, participantId, function(participant)
			return Merge(participant, {
				Bullets = math.max(0, participant.Bullets + amount),
			})
		end)
	end,

	setParticipantPendingAction = function(state: PlayersState, participantId: string, action: PendingAction)
		return updateParticipant(state, participantId, function(participant)
			return Merge(participant, {
				PendingAction = action,
			})
		end)
	end,

	setParticipantReady = function(state: PlayersState, participantId: string, isReady: boolean)
		return updateParticipant(state, participantId, function(participant)
			return Merge(participant, {
				IsReady = isReady,
			})
		end)
	end,

	addParticipantShield = function(state: PlayersState, participantId: string, amount: number)
		return updateParticipant(state, participantId, function(participant)
			return Merge(participant, {
				PendingShields = math.max(0, participant.PendingShields + amount),
			})
		end)
	end,

	clearParticipantPending = function(state: PlayersState, participantId: string)
		return updateParticipant(state, participantId, function(participant)
			return Merge(participant, {
				PendingAction = "None",
				PendingShields = 0,
				PendingTargets = {},
				IsReady = false,
			})
		end)
	end,

	setParticipantTargetAllocation = function(
		state: PlayersState,
		participantId: string,
		targetParticipantId: string,
		amount: number
	)
		return updateParticipant(state, participantId, function(participant)
			local nextTargets = participant.PendingTargets
			if amount <= 0 then
				nextTargets = RemoveKey(nextTargets, targetParticipantId)
			else
				nextTargets = Set(nextTargets, targetParticipantId, amount)
			end

			return Merge(participant, {
				PendingTargets = nextTargets,
			})
		end)
	end,

	resetParticipantForRound = function(state: PlayersState, participantId: string, bullets: number)
		return updateParticipant(state, participantId, function(participant)
			return Merge(participant, {
				IsAlive = true,
				Bullets = math.max(0, bullets),
				PendingAction = "None",
				PendingShields = 0,
				PendingTargets = {},
				IsReady = false,
			})
		end)
	end,

	addPlayerKill = function(state: PlayersState, participantId: string, amount: number)
		return updateParticipantPlayerData(state, participantId, function(data)
			return Merge(data, {
				Kills = math.max(0, data.Kills + amount),
			})
		end)
	end,

	addPlayerAssist = function(state: PlayersState, participantId: string, amount: number)
		return updateParticipantPlayerData(state, participantId, function(data)
			return Merge(data, {
				Assists = math.max(0, data.Assists + amount),
			})
		end)
	end,

	addPlayerWin = function(state: PlayersState, participantId: string, amount: number)
		return updateParticipantPlayerData(state, participantId, function(data)
			return Merge(data, {
				Wins = math.max(0, data.Wins + amount),
			})
		end)
	end,
}

local producer = Reflex.createProducer(initialState, actions)

return producer :: Reflex.Producer<PlayersState, PlayersActions>
