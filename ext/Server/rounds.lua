roundTimer = 0.0
roundState = RoundState.Idle
local roundUpdateTimer = 5.0
local roundStateTimer = 10.0

-- Send round info to a player as soon as they join.
NetEvents:Subscribe(NetMessage.C2S_CLIENT_READY, function(player)
	NetEvents:SendTo(NetMessage.S2C_ROUND_INFO, player, {
		roundTime = roundTimer,
		roundState = roundState,
	})
end)

local function broadcastRoundInfo()
	NetEvents:Broadcast(NetMessage.S2C_ROUND_INFO, {
		roundTime = roundTimer,
		roundState = roundState,
	})
end

local function broadcastRoundState()
	if roundState == RoundState.PreRound then
		ChatManager:Yell('Round starts in ' .. tostring(math.floor(roundTimer + 0.5)) .. ' seconds.', 4)
	elseif roundState == RoundState.Hiding then
		ChatManager:Yell(tostring(math.floor(roundTimer + 0.5)) .. ' seconds left to hide.', 4)
	elseif roundState == RoundState.Seeking then
		ChatManager:Yell('Round ends in ' .. tostring(math.floor(roundTimer + 0.5)) .. ' seconds.', 4)
	end
end

local function enterStateHiding()
	roundTimer = Config.HidingTime
	roundState = RoundState.Hiding

	broadcastRoundInfo()
	assignTeams()
	spawnAllPlayers()

	-- Make prop players into props and seekers into seekers.
	local players = PlayerManager:GetPlayers()

	for _, player in pairs(players) do
		if player.teamId == TeamId.Team1 then
			makePlayerSeeker(player)

			-- For seekers we also want to fade their screen to black.
			player:Fade(1.0, true)

			-- And also prevent them from moving.
			player:EnableInput(EntryInputActionEnum.EIAThrottle, false)
			player:EnableInput(EntryInputActionEnum.EIAStrafe, false)
			player:EnableInput(EntryInputActionEnum.EIAFire, false)
		else
			makePlayerProp(player)
		end
	end
end

local function enterStateSeeking()
	roundTimer = Config.TimeLimit
	roundState = RoundState.Seeking

	broadcastRoundInfo()

	-- Fade in all the seekers and allow them to move again.
	local players = PlayerManager:GetPlayers()

	for _, player in pairs(players) do
		if player.teamId == TeamId.Team1 then
			player:Fade(1.0, false)

			player:EnableInput(EntryInputActionEnum.EIAThrottle, true)
			player:EnableInput(EntryInputActionEnum.EIAStrafe, true)
			player:EnableInput(EntryInputActionEnum.EIAFire, true)
		end
	end
end

local function enterStatePostRound()
	roundTimer = Config.PostRoundTime
	roundState = RoundState.PostRound

	broadcastRoundInfo()

	-- TODO: Actual messages.
	if getSeekerCount() == 0 then
		ChatManager:Yell('Props win!', 20)
	elseif getPropCount() == 0 then
		ChatManager:Yell('Seekers win!', 20)
	else
		ChatManager:Yell('Props win!', 20)
	end
end

local function exitStatePostRound()
	roundTimer = 0
	roundState = RoundState.Idle

	broadcastRoundInfo()

	-- Restart level.
	RCON:SendCommand('mapList.restartRound')
end

local function updateRoundActive(dt)
	roundTimer = roundTimer - dt
	roundUpdateTimer = roundUpdateTimer - dt
	roundStateTimer = roundStateTimer - dt

	-- Round phase has ended. We need to move to the next one.
	if roundTimer <= 0.0 then
		if roundState == RoundState.PreRound then
			enterStateHiding()
		elseif roundState == RoundState.Hiding then
			enterStateSeeking()
		elseif roundState == RoundState.Seeking then
			enterStatePostRound()
		elseif roundState == RoundState.PostRound then
			exitStatePostRound()
		end
	end

	-- Broadcast round info to all players even 5 seconds.
	if roundUpdateTimer <= 0.0 then
		broadcastRoundInfo()
		roundUpdateTimer = 5.0
	end

	if roundStateTimer <= 0.0 then
		broadcastRoundState()

		if roundState == RoundState.Seeking then
			roundStateTimer = 30.0
		else
			roundStateTimer = 10.0
		end
	end

	-- If all seekers are dead or all props are dead, the game is over
	if roundState == RoundState.Seeking and (getSeekerCount() == 0 or getPropCount() == 0) then
		enterStatePostRound()
	end
end

local function updateRoundInactive(dt)
	-- Check if we have enough players to start the game.
	if #readyPlayers < Config.MinPlayers then
		return
	end

	-- We have enough players, start the round start countdown.
	roundTimer = Config.RoundStartCountdown
	roundState = RoundState.PreRound

	-- Notify clients of round state change.
	broadcastRoundInfo()
end

Events:Subscribe('Engine:Update', function(dt)
	if roundState ~= RoundState.Idle then
		updateRoundActive(dt)
	else
		updateRoundInactive(dt)
	end
end)

-- Reset round info when a level is loading.
Events:Subscribe('Level:LoadResources', function()
	roundTimer = 0.0
	roundState = RoundState.Idle

	broadcastRoundInfo()
end)
