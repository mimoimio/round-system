--!strict
export type PlayerId = string
export type ParticipantId = string
export type Phase = "Intermission" | "Starting" | "InProgress" | "Ended"
export type TeamColor = "Red" | "Blue" | "Draw" | "None"

export type State = {
	Players: { [PlayerId]: PlayerEntity },
	CurrentRound: RoundState?,
}
export type RoundState = {
	Participants: { [ParticipantId]: ParticipantEntity },
	RoundPhase: string,
	Winner: string,
	TimeEnd: number,
}
export type PlayerEntity = {
	Data: string,
}
export type Action = "Shoot" | "Shield" | "Load"
export type ParticipantEntity = {
	PlayerId: PlayerId?,
	Bullets: number,
	Shield: number,
	Action: Action,
}
