function setPlayerSpectating(player, spectating)
	if spectating then
		player.teamId = TeamId.TeamNeutral
		NetEvents:SendTo(NetMessage.S2C_SET_SPECTATING, player, true)
	else
		player.teamId = TeamId.Team1
		NetEvents:SendTo(NetMessage.S2C_SET_SPECTATING, player, false)
		spawnSeeker(player)
	end
end
