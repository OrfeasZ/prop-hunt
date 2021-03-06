local startingSpawns = {
	Vec3(21.154095, 10.881368, 8.301152),
}

function spawnSeeker(player)
	print('Spawning seeker ' .. player.name)

	local seekerSoldier = ResourceManager:SearchForDataContainer('Gameplay/Kits/USSupport')

	local assaultAppearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/Us/MP_US_Assault_Appearance01')
	local engiAppearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/Us/MP_US_Engi_Appearance01')
	local reconAppearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/Us/MP_US_Recon_Appearance01')
	local supportAppearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/Us/MP_US_Support_Appearance01')

	local appearances = {
		assaultAppearance,
		engiAppearance,
		reconAppearance,
		supportAppearance,
	}

	local mpSoldierBp = ResourceManager:SearchForDataContainer('Characters/Soldiers/MpSoldier')

    -- Select spawn point randomly from predetermined list.
	local spawnTransform = LinearTransform()
	spawnTransform.trans = startingSpawns[MathUtils:GetRandomInt(1, #startingSpawns)]

	-- bots.spawn Bot1 Team2 Squad2 -100.150360 37.779110 -62.015625
	local randomAppearance = appearances[MathUtils:GetRandomInt(1, #appearances)]

	player:SelectUnlockAssets(seekerSoldier, { randomAppearance })

	if player.soldier == nil then
		local soldier = player:CreateSoldier(mpSoldierBp, spawnTransform)
		player:SpawnSoldierAt(soldier, spawnTransform, CharacterPoseType.CharacterPoseType_Stand)
	end

	local knife = ResourceManager:SearchForDataContainer('Weapons/Knife/U_Knife')

	local p90 = ResourceManager:SearchForDataContainer('Weapons/P90/U_P90')
	local p90Attachments = { 'Weapons/P90/U_P90_Kobra', 'Weapons/P90/U_P90_Targetpointer' }

	local mp7 = ResourceManager:SearchForDataContainer('Weapons/MP7/U_MP7')
	local mp7Attachments = { 'Weapons/MP7/U_MP7_Kobra', 'Weapons/MP7/U_MP7_ExtendedMag' }

	local asval = ResourceManager:SearchForDataContainer('Weapons/ASVal/U_ASVal')
	local asvalAttachments = { 'Weapons/ASVal/U_ASVal_Kobra', 'Weapons/ASVal/U_ASVal_ExtendedMag' }

	local loadouts = {
		{ p90, p90Attachments },
		{ mp7, mp7Attachments },
		{ asval, asvalAttachments },
	}

	local function setAttachments(unlockWeapon, attachments)
		for _, attachment in pairs(attachments) do
			local unlockAsset = UnlockAsset(ResourceManager:SearchForDataContainer(attachment))
			unlockWeapon.unlockAssets:add(unlockAsset)
		end
	end

	local m1911 = ResourceManager:SearchForDataContainer('Weapons/M1911/U_M1911')

	-- Create the seeker customization
	local seekerCustomization = CustomizeSoldierData()
	seekerCustomization.activeSlot = WeaponSlot.WeaponSlot_0
	seekerCustomization.removeAllExistingWeapons = true
	seekerCustomization.overrideCriticalHealthThreshold = 1.0

	-- Pick a random loadout.
	local loadout = loadouts[MathUtils:GetRandomInt(1, #loadouts)]

	local primaryWeapon = UnlockWeaponAndSlot()
	primaryWeapon.weapon = SoldierWeaponUnlockAsset(loadout[1])
	primaryWeapon.slot = WeaponSlot.WeaponSlot_0
	setAttachments(primaryWeapon, loadout[2])

	local secondaryWeapon = UnlockWeaponAndSlot()
	secondaryWeapon.weapon = SoldierWeaponUnlockAsset(m1911)
	secondaryWeapon.slot = WeaponSlot.WeaponSlot_1

	local meleeWeapon = UnlockWeaponAndSlot()
	meleeWeapon.weapon = SoldierWeaponUnlockAsset(knife)
	meleeWeapon.slot = WeaponSlot.WeaponSlot_5

	seekerCustomization.weapons:add(primaryWeapon)
	seekerCustomization.weapons:add(secondaryWeapon)
	seekerCustomization.weapons:add(meleeWeapon)

	player.soldier:ApplyCustomization(seekerCustomization)

	player.teamId = TeamId.Team1
	player:Fade(1.0, false)
end

function spawnHider(player, position)
    print('Spawning hider ' .. player.name)

	local hiderSoldier = ResourceManager:SearchForDataContainer('Gameplay/Kits/RUEngineer')
	local engiAppearance = ResourceManager:SearchForDataContainer('Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Engi_Appearance01')

	local mpSoldierBp = ResourceManager:SearchForDataContainer('Characters/Soldiers/MpSoldier')

    -- TODO: Select spawn point randomly from predetermined list.
	local spawnTransform = LinearTransform()

	if position == nil then
		position = startingSpawns[MathUtils:GetRandomInt(1, #startingSpawns)]
	end

	spawnTransform.trans = position

	player:SelectUnlockAssets(hiderSoldier, { engiAppearance })

	if player.soldier == nil then
		local soldier = player:CreateSoldier(mpSoldierBp, spawnTransform)
		player:SpawnSoldierAt(soldier, spawnTransform, CharacterPoseType.CharacterPoseType_Stand)
	end

	local knife = ResourceManager:SearchForDataContainer('Weapons/Knife/U_Knife')

	-- Create the infection customization
	local hiderCustomization = CustomizeSoldierData()
	hiderCustomization.activeSlot = WeaponSlot.WeaponSlot_5
	hiderCustomization.removeAllExistingWeapons = true
	hiderCustomization.overrideCriticalHealthThreshold = 1.0

	local unlockWeapon = UnlockWeaponAndSlot()
	unlockWeapon.weapon = SoldierWeaponUnlockAsset(knife)
	unlockWeapon.slot = WeaponSlot.WeaponSlot_5

	hiderCustomization.weapons:add(unlockWeapon)

	player.soldier:ApplyCustomization(hiderCustomization)
	player.soldier.health = 100

	player.teamId = TeamId.Team2
end

function spawnAllPlayers()
	local players = PlayerManager:GetPlayers()

	for _, player in pairs(players) do
		if player.teamId == TeamId.Team1 then
			spawnSeeker(player)
		elseif player.teamId == TeamId.Team2 then
			spawnHider(player)
		end
	end
end

-- This starts the round manually, skipping any preround logic.
-- It also requires the PreRoundEntity to be removed for it to work properly.
Hooks:Install('EntityFactory:CreateFromBlueprint', 100, function(hook, blueprint, transform, variation, parentRepresentative)
	if Blueprint(blueprint).name == 'Gameplay/Level_Setups/Complete_setup/Full_TeamDeathmatch' then
		local tdmBus = hook:Call()

		for _, entity in pairs(tdmBus.entities) do
			if entity:Is('ServerInputRestrictionEntity') then
				entity:FireEvent('Deactivate')
			elseif entity:Is('ServerRoundOverEntity') then
				entity:FireEvent('RoundStarted')
			elseif entity:Is('EventGateEntity') and entity.data.instanceGuid == Guid('B7F13498-C61B-47E6-895E-0ED2048E7AF4') then
				entity:FireEvent('Close')
			end
		end
	end
end)
