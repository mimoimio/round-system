local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DispatchEvent = require(ReplicatedStorage.Shared.Controllers.DispatchEvent)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundController = require(ReplicatedStorage.Shared.Controllers.SoundController)

local useEffect = React.useEffect
local useRef = React.useRef

type ParticipantEntity = {
	Bullets: number,
}

type Props = {
	LocalPlayerId: string,
	IsParticipant: boolean,
	Participant: ParticipantEntity?,
	Toast: {
		open: (message: string) -> (),
	}?,
}

local function useCombatToasts(props: Props)
	local previousBulletsRef = useRef(nil :: number?)

	useEffect(function()
		local unsubscribeCash = DispatchEvent.OnEvent("addPlayerCash", function(playerId, amt)
			if props.Toast and playerId == props.LocalPlayerId then
				SoundController.Sound("Cash")
				props.Toast.open("+$" .. amt)
			end
		end)

		return function()
			unsubscribeCash()
		end
	end, { props.LocalPlayerId, props.Toast })

	useEffect(function()
		local combatFeedbackConnection = Remotes.CombatFeedback.OnClientEvent:Connect(function(
			eventType: string,
			payload: { [string]: any }
		)
			if not props.Toast then
				return
			end
			if not props.IsParticipant then
				return
			end

			if eventType == "kill" then
				SoundController.Sound("Plink")
				local targetId = payload and payload.targetId
				if type(targetId) == "string" and targetId ~= "" then
					props.Toast.open("you killed " .. targetId)
				else
					props.Toast.open("you killed an opponent")
				end
			elseif eventType == "assist" then
				SoundController.Sound("Plink")
				local targetId = payload and payload.targetId
				if type(targetId) == "string" and targetId ~= "" then
					props.Toast.open("assist on " .. targetId)
				else
					props.Toast.open("assist")
				end
			elseif eventType == "death" then
				SoundController.Sound("Plink")
				local killerIds = payload and payload.killerIds
				if type(killerIds) == "table" then
					local killers = {}
					for _, killerId in killerIds do
						if type(killerId) == "string" and killerId ~= "" then
							table.insert(killers, killerId)
						end
					end

					if #killers == 1 then
						props.Toast.open("you died to " .. killers[1])
					elseif #killers > 1 then
						props.Toast.open("you died to " .. table.concat(killers, ", "))
					else
						props.Toast.open("you died")
					end
				else
					props.Toast.open("you died")
				end
			elseif eventType == "block" then
				SoundController.Sound("Done")
				local blocked = payload and payload.incoming
				if type(blocked) == "number" and blocked > 0 then
					props.Toast.open("blocked " .. tostring(blocked) .. " shot")
				else
					props.Toast.open("block")
				end
			end
		end)

		return function()
			combatFeedbackConnection:Disconnect()
		end
	end, { props.Toast, props.IsParticipant })

	useEffect(function()
		if not props.IsParticipant then
			previousBulletsRef.current = nil
			return
		end

		local participant = props.Participant
		if participant and props.Toast then
			local previousBullets = previousBulletsRef.current
			if previousBullets ~= nil and participant.Bullets > previousBullets then
				SoundController.Sound("Ices")
				props.Toast.open("Loaded")
			end

			previousBulletsRef.current = participant.Bullets
		end
	end, { props.Participant, props.Toast, props.IsParticipant })
end

return useCombatToasts
