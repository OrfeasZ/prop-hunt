readyPlayers = {}

NetEvents:Subscribe(NetMessage.C2S_CLIENT_READY, function(player)
	table.insert(readyPlayers, player)

	-- If the game has already started then just set the player as a spectator.
	if roundState == RoundState.Hiding or roundState == RoundState.Seeking or roundState == RoundState.PostRound then
		setPlayerSpectating(player, true)
		return
	end

	-- Otherwise, set the player to Team1 and spawn them.
	setPlayerSpectating(player, false)
    player.teamId = TeamId.Team1

    -- Spawn the player.
    spawnSeeker(player)
end)

-- Remove player from list of ready players when they disconnect.
Events:Subscribe('Player:Destroyed', function(player)
	for i, readyPlayer in pairs(readyPlayers) do
		if readyPlayer == player then
			table.remove(readyPlayers, i)
			break
		end
	end
end)

-- Clear all ready players when a new level is loading.
Events:Subscribe('Level:Destroy', function()
	readyPlayers = {}
end)

function assignTeams()
	-- Randomly assign teams to players.
	local players = PlayerManager:GetPlayers()

	-- We want a third of the players to be seekers and the rest props
	local halfPlayers = #players / 3

	if halfPlayers == 0 then
		halfPlayers = 1
	end

	local seekerPlayers = 0

	-- First we assign everyone to neutral.
	for _, player in pairs(players) do
		player.teamId = TeamId.TeamNeutral
	end

	local seekerChance = 1.0 / #players
	math.randomseed(SharedUtils:GetTimeMS())

	-- Then we start going through everyone, randomly selecting seekers
	-- until we have filled our quota.
	while seekerPlayers < halfPlayers do
		for _, player in pairs(players) do
			if seekerPlayers >= halfPlayers then
				goto assign_continue
			end

			if player.teamId ~= TeamId.TeamNeutral then
				goto assign_continue
			end

			if math.random() <= seekerChance then
				player.teamId = TeamId.Team1
				seekerPlayers = seekerPlayers + 1
			end

			::assign_continue::
		end
	end

	-- Set everyone that's left to the prop team.
	for _, player in pairs(players) do
		if player.teamId == TeamId.TeamNeutral then
			player.teamId = TeamId.Team2
		end
	end
end

function isSeeker(player)
	return player.teamId == TeamId.Team1
end

function isProp(player)
	return player.teamId == TeamId.Team2
end

function isSpectator(player)
	return player.teamId == TeamId.TeamNeutral
end

function getSeekerCount()
	local seekerCount = 0

	for _, player in pairs(PlayerManager:GetPlayersByTeam(TeamId.Team1)) do
		-- Ignore bots and dead players.
		if player.onlineId ~= 0 and player.soldier ~= nil then
			seekerCount = seekerCount + 1
		end
	end

	return seekerCount
end

function getPropCount()
	local propCount = 0

	for _, player in pairs(PlayerManager:GetPlayersByTeam(TeamId.Team2)) do
		-- Ignore bots and dead players.
		if player.onlineId ~= 0 and player.soldier ~= nil  then
			propCount = propCount + 1
		end
	end

	return propCount
end

