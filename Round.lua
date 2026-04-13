--!strict
export type PlayerId = string
export type ParticipantId = string
export type Phase = "Intermission" | "Starting" | "InProgress" | "Ended"
export type TeamColor = "Red" | "Blue" | "Draw" | "None"

export type TeamData = {
	Points: number,
}
export type State = {
	Players: { [PlayerId]: PlayerEntity },
	CurrentRound: RoundState?,
}
export type RoundState = {
	Participants: { [ParticipantId]: ParticipantEntity },
	Teams: { [TeamColor]: TeamData },
	RoundPhase: string,
	Winner: string,
	TimeStart: number,
}
export type PlayerEntity = {
	Cash: number,
	Wins: number,
}
export type ParticipantEntity = {
	Points: number,
	Inventory: { any },
	Character: Model?,
}
