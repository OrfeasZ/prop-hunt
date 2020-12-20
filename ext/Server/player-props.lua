local playerPropNames = {}
local playerProps = {}
local playerPropPositions = {}
local collisionLookupTable = {}
local playerIdToSoldierInstance = {}

function setPlayerProp(player, bpName)
	print('Setting prop for player')
    print(bpName)
	print(player)

	-- Make sure the player is alive and on the right team.
	if player.soldier == nil then
		return
	end

	if player.teamId ~= TeamId.Team2 then
		return
	end

    -- Check if this bp exists.
    local bp = ResourceManager:LookupDataContainer(ResourceCompartment.ResourceCompartment_Game, bpName)

    if bp == nil then
        return
    end

    -- Set the prop for this player.
    local oldProp = playerPropNames[player.id]

    -- If it has not changed then do nothing.
	if oldProp == bpName then
		return
	end

	-- TODO: Server-side prop creation is currently disabled because it results
	-- in collision between the player and the prop and some props end up making
	-- the player start flying.

	-- If we have an old prop, delete it.
	--[[if playerProps[player.id] ~= nil then
		for _, entity in pairs(playerProps[player.id].entities) do
			PhysicsEntity(entity):Destroy()
		end

		playerProps[player.id] = nil
		collisionLookupTable[player.soldier.physicsEntityBase.instanceId] = nil
    end

    local realBp = Blueprint(bp)
    print('Creating player prop with BP: ' .. realBp.name)

    -- Create the new player prop.
    local bus = EntityManager:CreateEntitiesFromBlueprint(bp, player.soldier.transform)

    if bus == nil or #bus.entities == 0 then
        print('Failed to create prop entity for client.')
        return
	end

	collisionLookupTable[player.soldier.physicsEntityBase.instanceId] = {}
	playerIdToSoldierInstance[player.id] = player.soldier.physicsEntityBase.instanceId

	-- Cast and initialize the entity.
	for _, entity in pairs(bus.entities) do
		entity:Init(Realm.Realm_Server, true)

		-- Make sure these props can't be damaged.
		if entity:Is('ServerPhysicsEntity') then
			print('Got physics entity')
			PhysicsEntity(entity):RegisterDamageCallback(function() return false end)

			table.insert(collisionLookupTable[player.soldier.physicsEntityBase.instanceId], PhysicsEntity(entity).physicsEntityBase.instanceId)
		end
	end

	playerPropPositions[player.id] = player.soldier.transform
	playerProps[player.id] = bus]]

	playerPropNames[player.id] = bpName

	NetEvents:Broadcast(NetMessage.S2C_PROP_CHANGED, player.id, bpName)
end

NetEvents:Subscribe(NetMessage.C2S_SET_PROP, function(player, bpName)
	setPlayerProp(player, bpName)
end)

Events:Subscribe('Engine:Update', function()
	for id, bus in pairs(playerProps) do
        local player = PlayerManager:GetPlayerById(id)

        if player == nil or player.soldier == nil then
            goto continue
		end

		local transform = player.soldier.transform

		if playerPropPositions[player.id] == transform then
			goto continue
		end

		playerPropPositions[player.id] = transform

		local entity = SpatialEntity(bus.entities[1])
		entity.transform = transform
		entity:FireEvent('Disable')
		entity:FireEvent('Enable')

        ::continue::
    end
end)

NetEvents:Subscribe(NetMessage.C2S_CLIENT_READY, function(player)
	-- Sync existing props to connecting clients.
	for id, bpName in pairs(playerPropNames) do
		NetEvents:Broadcast(NetMessage.S2C_PROP_CHANGED, id, bpName)
	end
end)

local function destroyPropForPlayer(player)
	local bus = playerProps[player.id]

	if bus ~= nil then
		for _, entity in pairs(bus.entities) do
			entity:Destroy()
		end

		playerProps[player.id] = nil
	end

	if player.soldier ~= nil then
		player.soldier.forceInvisible = false
	end

	if playerIdToSoldierInstance[player.id] ~= nil then
		collisionLookupTable[playerIdToSoldierInstance[player.id]] = nil
		playerIdToSoldierInstance[player.id] = nil
	end

	playerPropNames[player.id] = nil
	playerPropPositions[player.id] = nil

	NetEvents:Broadcast(NetMessage.S2C_REMOVE_PROP, player.id)

end

Events:Subscribe('Player:Killed', function(player)
	destroyPropForPlayer(player)
end)

Events:Subscribe('Player:Destroyed', function(player)
	destroyPropForPlayer(player)
end)

Hooks:Install('Entity:ShouldCollideWith', 100, function(hook, entityA, entityB)
	local entities = collisionLookupTable[entityA.instanceId]

	if entities ~= nil then
		for _, entityId in pairs(entities) do
			if entityId == entityB.instanceId then
				hook:Return(false)
				return
			end
		end
	else
		entities = collisionLookupTable[entityB.instanceId]

		if entities ~= nil then
			for _, entityId in pairs(entities) do
				if entityId == entityA.instanceId then
					hook:Return(false)
					return
				end
			end
		end
	end
end)

function makePlayerProp(player)
	player.soldier.forceInvisible = true

	-- Set default prop for player.
	setPlayerProp(player, 'XP2/Objects/SkybarBarStool_01/SkybarBarStool_01')

	player:EnableInput(EntryInputActionEnum.EIAFire, false)
	player:EnableInput(EntryInputActionEnum.EIAZoom, false)
	player:EnableInput(EntryInputActionEnum.EIAProne, false)
	player:EnableInput(EntryInputActionEnum.EIAReload, false)
	player:EnableInput(EntryInputActionEnum.EIAMeleeAttack, false)
	player:EnableInput(EntryInputActionEnum.EIAThrowGrenade, false)
	player:EnableInput(EntryInputActionEnum.EIAToggleParachute, false)

	NetEvents:SendTo(NetMessage.S2C_MAKE_PROP, player)
end

function makePlayerSeeker(player)
	player.soldier.forceInvisible = false

	player:EnableInput(EntryInputActionEnum.EIAFire, true)
	player:EnableInput(EntryInputActionEnum.EIAZoom, true)
	player:EnableInput(EntryInputActionEnum.EIAProne, true)
	player:EnableInput(EntryInputActionEnum.EIAReload, true)
	player:EnableInput(EntryInputActionEnum.EIAMeleeAttack, false)
	player:EnableInput(EntryInputActionEnum.EIAThrowGrenade, false)
	player:EnableInput(EntryInputActionEnum.EIAToggleParachute, false)

	NetEvents:Broadcast(NetMessage.S2C_REMOVE_PROP, player.id)
	NetEvents:SendTo(NetMessage.S2C_MAKE_SEEKER, player)
end

local function cleanupRound()
	for _, prop in pairs(playerProps) do
		for _, entity in pairs(prop.entities) do
			entity:Destroy()
		end
	end

	playerPropNames = {}
	playerProps = {}
	playerPropPositions = {}
	collisionLookupTable = {}
	playerIdToSoldierInstance = {}

	for _, player in pairs(PlayerManager:GetPlayers()) do
		if player.soldier ~= nil then
			player.soldier.forceInvisible = false
		end
	end
end

Events:Subscribe('Level:Destroy', cleanupRound)
Events:Subscribe('Extension:Unloading', cleanupRound)
