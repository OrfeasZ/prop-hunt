local Camera = require('Camera')

local playerPropBps = {}
local playerProps = {}

local soldierEntityInstanceId = nil
local propInstanceIds = {}

local function onPropDamaged(playerId, entity, damageInfo, damageGiverInfo)

	return false
end

function createPlayerProp(player, bp)
	local isLocalPlayer = PlayerManager:GetLocalPlayer() == player

    -- We are already this prop.
    if playerPropBps[player.id] == bp then
        return
    end

    -- Delete the old prop.
	if playerProps[player.id] ~= nil then
		playerProps[player.id].entities[1]:Destroy()
        playerProps[player.id] = nil
    end

    local realBp = Blueprint(bp)
    print('Creating player prop with BP: ' .. realBp.name)

    -- Create the new player prop.
    local bus = EntityManager:CreateEntitiesFromBlueprint(bp, player.soldier.transform)

    if bus == nil or #bus.entities == 0 then
        print('Failed to create prop entity for client.')
        return
    end

    -- Cast and initialize the entity.
	playerPropBps[player.id] = bp

	if isLocalPlayer then
		propInstanceIds = {}
	end

    playerProps[player.id] = bus

	for _, entity in pairs(bus.entities) do
		entity:Init(Realm.Realm_Client, true)

		if entity:Is('ClientPhysicsEntity') then
			if isLocalPlayer then
				table.insert(propInstanceIds, PhysicsEntity(entity).physicsEntityBase.instanceId)
			end

			PhysicsEntity(entity):RegisterDamageCallback(player.id, function() return false end)
		end
	end
end

function isPlayerProp(otherEntity)
	for _, bus in pairs(playerProps) do
		for _, entity in pairs(bus.entities) do
			if entity.instanceId == otherEntity.instanceId then
				return true
			end
		end
	end

	return false
end

Events:Subscribe('Engine:Update', function(delta, simDelta)
    for id, bus in pairs(playerProps) do
        local player = PlayerManager:GetPlayerById(id)

        if player == nil or player.soldier == nil then
            goto continue
        end

		local entity = SpatialEntity(bus.entities[1])

		entity.transform = player.soldier.transform
		entity:FireEvent('Disable')
		entity:FireEvent('Enable')

        ::continue::
    end
end)

NetEvents:Subscribe(NetMessage.S2C_PROP_CHANGED, function(playerId, bpName)
    local player = PlayerManager:GetPlayerById(playerId)

	if player == nil or player.soldier == nil then
		-- TODO: Queue this.
        return
    end

    local bp = ResourceManager:LookupDataContainer(ResourceCompartment.ResourceCompartment_Game, bpName)

    if bp == nil then
        return
    end

    createPlayerProp(player, bp)
end)

NetEvents:Subscribe(NetMessage.S2C_MAKE_PROP, function()
	isProp = true
	Camera:enable()
end)

NetEvents:Subscribe(NetMessage.S2C_REMOVE_PROP, function(playerId)
	local bus = playerProps[playerId]

	if bus == nil then
		return
	end

	for _, entity in pairs(bus.entities) do
		entity:Destroy()
	end

	playerProps[playerId] = nil
	playerPropBps[playerId] = nil
end)

Events:Subscribe('Player:Respawn', function(player)
	if PlayerManager:GetLocalPlayer() == player then
		soldierEntityInstanceId = player.soldier.physicsEntityBase.instanceId
	end
end)

Events:Subscribe('Player:Killed', function(soldier)
	if PlayerManager:GetLocalPlayer() == player then
		soldierEntityInstanceId = nil
	end
end)

-- TODO: Do we need to optimize this further?
Hooks:Install('Entity:ShouldCollideWith', 100, function(hook, entityA, entityB)
	if not isProp then
		return
	end

	if entityA.instanceId == soldierEntityInstanceId then
		for _, entityId in pairs(propInstanceIds) do
			if entityId == entityB.instanceId then
				hook:Return(false)
				return
			end
		end
	elseif entityB.instanceId == soldierEntityInstanceId then
		for _, entityId in pairs(propInstanceIds) do
			if entityId == entityA.instanceId then
				hook:Return(false)
				return
			end
		end
	end
end)

local bloodFx = nil

local function cleanupRound()
	for _, prop in pairs(playerProps) do
		for _, entity in pairs(prop.entities) do
			entity:Destroy()
		end
	end

	Camera:disable()

	playerProps = {}
	playerPropBps = {}
	soldierEntityInstanceId = nil
	propInstanceIds = {}
	bloodFx = nil
end

Events:Subscribe('Level:Destroy', cleanupRound)
Events:Subscribe('Extension:Unloading', cleanupRound)

Events:Subscribe('Extension:Loaded', function()
	local player = PlayerManager:GetLocalPlayer()

	if player ~= nil and player.soldier ~= nil then
		soldierEntityInstanceId = player.soldier.physicsEntityBase.instanceId
	end
end)

local playersHit = {}

Events:Subscribe('Engine:Update', function()
	playersHit = {}
end)

local function doPropDamage(playerId, position)
	-- Only apply damage once per tick.
	if playersHit[playerId] then
		return
	end

	playersHit[playerId] = true

	-- Spawn blood effect
	if bloodFx == nil then
		bloodFx = ResourceManager:SearchForDataContainer('FX/Impacts/Soldier/FX_Impact_Soldier_Body_S')
	end

	if bloodFx ~= nil then
		local transform = LinearTransform()
		transform.trans = position
		EffectManager:PlayEffect(bloodFx, transform, EffectParams(), false)
	end

	NetEvents:Send(NetMessage.C2S_PROP_DAMAGE, playerId)
end

Hooks:Install('BulletEntity:Collision', 100, function(hook, entity, hit, shooter)
	local localPlayer = PlayerManager:GetLocalPlayer()

	if shooter ~= localPlayer or hit.rigidBody == nil then
		return
	end

	for playerId, bus in pairs(playerProps) do
		if playerId ~= localPlayer.id then
			for _, prop in pairs(bus.entities) do
				if prop:Is('ClientPhysicsEntity') and PhysicsEntity(prop).physicsEntityBase.instanceId == hit.rigidBody.instanceId then
					doPropDamage(playerId, hit.position)
					return
				end
			end
		end
	end
end)
