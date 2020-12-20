Events:Subscribe('Partition:Loaded', function(partition)
	for _, instance in pairs(partition.instances) do
		if instance.instanceGuid == Guid('705967EE-66D3-4440-88B9-FEEF77F53E77') then
			-- Disable spawn protection.
			local healthData = VeniceSoldierHealthModuleData(instance)
			healthData:MakeWritable()

			healthData.immortalTimeAfterSpawn = 0.0
		elseif instance.instanceGuid == Guid('5FA66B8C-BE0E-3758-7DE9-533EA42F5364') then
			-- Get rid of the PreRoundEntity. We don't need preround in this gamemode.
			local bp = LogicPrefabBlueprint(instance)
			bp:MakeWritable()

			for i = #bp.objects, 1, -1 do
				if bp.objects[i]:Is('PreRoundEntityData') then
					bp.objects:erase(i)
				end
			end

			for i = #bp.eventConnections, 1, -1 do
				if bp.eventConnections[i].source:Is('PreRoundEntityData') or bp.eventConnections[i].target:Is('PreRoundEntityData') then
					bp.eventConnections:erase(i)
				end
			end
		elseif instance.instanceGuid == Guid('0D126546-B7A4-4C76-B41F-719B6BFB2053') then
			-- Disable weapon pickups.
			local data = KitPickupEntityData(instance)
			data:MakeWritable()

			data.enabled = false
			data.allowPickup = false
			data.timeToLive = 0.0
		end
	end
end)
