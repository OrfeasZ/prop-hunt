Hooks:Install('Soldier:Damage', 100, function(hook, soldier, info, giverInfo)
	if roundState ~= RoundState.Seeking then
		hook:Return()
		return
	end

	-- Prevent players on Team2 (hiders) from taking damage from other players.
	if giverInfo.giver ~= nil and soldier.player.teamId == TeamId.Team2 then
		hook:Return()
		return
	end
end)

local itemsHit = {}

Events:Subscribe('Engine:Update', function()
	itemsHit = {}
end)

Hooks:Install('BulletEntity:Collision', 100, function(hook, entity, hit, giverInfo)
	if giverInfo.giver == nil or hit.rigidBody == nil then
		return
	end

	-- Only apply one damage per tick.
	local hitId = tostring(giverInfo.giver.id) .. tostring(hit.rigidBody.instanceId)

	if itemsHit[hitId] then
		return
	end

	itemsHit[hitId] = true

	-- Damage the player on each hit.
	if giverInfo.giver.soldier ~= nil then
		local playerDamage = DamageInfo()
		playerDamage.damage = 3

		giverInfo.giver.soldier:ApplyDamage(playerDamage)
	end
end)

NetEvents:Subscribe(NetMessage.C2S_PROP_DAMAGE, function(player, targetId)
	local targetPlayer = PlayerManager:GetPlayerById(targetId)

	if targetPlayer == nil or targetPlayer.teamId ~= TeamId.Team2 or targetPlayer.soldier == nil or player.soldier == nil then
		return
	end

	-- Damage the target player and heal the one doing the damage.
	local propDamage = DamageInfo()
	propDamage.damage = 8

	targetPlayer.soldier:ApplyDamage(propDamage)

	local shooterHeal = DamageInfo()
	shooterHeal.damage = -5

	player.soldier:ApplyDamage(shooterHeal)
end)
