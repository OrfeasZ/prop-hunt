require('__shared/net')
require('__shared/round-state')

require('config')
require('prop-damage')
require('player-props')
require('spawning')
require('rounds')
require('teams')
require('spectating')

Events:Subscribe('Player:Chat', function(player, recipientMask, message)
	if message == '' or player == nil then
		return
	end

	--[[if message == 'prop' then
		spawnHider(player)
        makePlayerProp(player)
    end

    if message == 'seeker' then
		spawnSeeker(player)
        makePlayerSeeker(player)
    end

    if message == 'pos' then
        if player.soldier == nil then
            return
        end

        print(player.soldier.transform)
    end]]
end)

ServerUtils:SetCustomGameModeName('Prop Hunt')
