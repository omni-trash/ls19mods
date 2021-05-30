--[[
	DETECTOR
]]

-- lib
local detector = {};

-- export
FS19_AR.lib.detector = detector;

-- import shortcuts
local logging;
local utils;

-- required
function detector:load(mod)
	-- refs
	logging = FS19_AR.lib.logging;
	utils   = FS19_AR.lib.utils;
end

-- we are looking down to the map and find the nearest fields
function detector.getFieldsInRange(maxDistance)
	-- ok thats yourself
	local player = g_currentMission.player;

	-- when the player is inside a vehicle, we have to use the position of that vehicle.
	-- in that case the player position is not updated. if the player is not in a vehicle, 
	-- means he is walking, the player position is correct.
	-- note: controlledVehicle can be nil
	local nodeToCheck = (g_currentMission.controlledVehicle or {}).rootNode or player.rootNode;

	-- the current player or vehicle (with player) position in the map (in meters and in realation to the center)
	local playerX, playerY, playerZ = getWorldTranslation(nodeToCheck);

	-- fields in range
	local fieldsInRange = {};

	for _, field in pairs(g_fieldManager:getFields()) do
		if (field.farmland.isOwned == true) then
			-- center to the player (for our calculations)
			local x = field.posX - playerX;
			local z = field.posZ - playerZ;

			-- from player to hotspot (middle of the field)
			local distance = (math.sqrt((x * x) + (z * z)));

			-- very very simple, there are no field width or height (shape)
			-- ok let's think the field is on farmland and it is a square,
			-- so we do calc that "square" by the area size (pure).
			-- fine, now we calc the length from the center to the corner.
			-- well we have a fictitious inaccurate distance of whatever.
			--[[
						edge
				      |     |
				+-----------+
				|         * |
				|       *   |
				|     x     |
				|           |
				|           |
				+-----------+

				length == "radius"
			]]
			local edge   = math.sqrt(field.farmland.areaInHa * 10000) / 2;
			local length = math.sqrt(edge * edge * 2);
			local distanceToCheck = MathUtil.round(math.max(0, distance - length));

			-- is in range (10 meters)
			if (distanceToCheck < maxDistance) then
				table.insert(fieldsInRange, {
					typeName      = "field",
					field         = field,
					distance      = distance,
					worldPosition = { 
						x = field.posX, 
						y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, field.posX, 300, field.posZ),
						z = field.posZ 
					}
				});
			end
		end
	end
	
	table.sort(fieldsInRange, function (a, b) 
			return a.distance < b.distance; 
	end);

	return fieldsInRange;
end

-- we are looking down to the map and find the nearest husbandries
function detector.getHusbandriesInRange(maxDistance)
	-- ok thats yourself
	local player = g_currentMission.player;

	-- when the player is inside a vehicle, we have to use the position of that vehicle.
	-- in that case the player position is not updated. if the player is not in a vehicle, 
	-- means he is walking, the player position is correct.
	-- note: controlledVehicle can be nil
	local nodeToCheck = (g_currentMission.controlledVehicle or {}).rootNode or player.rootNode;

	-- the current player or vehicle (with player) position in the map (in meters and in realation to the center)
	local playerX, playerY, playerZ = getWorldTranslation(nodeToCheck);

	-- husbandries in range
	local husbandriesInRange = {};

	for _, husbandry in pairs(g_currentMission:getHusbandries()) do
		if (husbandry.ownerFarmId == player.farmId) then
			local hotspot = husbandry.mapHotspots[1];

			-- center to the player (for our calculations)
			local x = hotspot.xMapPos - playerX;
			local z = hotspot.zMapPos - playerZ;

			-- from player to hotspot (middle of the field)
			local distance = (math.sqrt((x * x) + (z * z)));

			--[[
				     placementSizeX
				|                      |
				+----------------------+-
				|                   *  |
				|               *      |
				|           x          |  placementSizeZ
				|                      |
				|                      |
				+----------------------+-

				length == "radius"
			]]

			local length = math.sqrt(husbandry.placementSizeX * husbandry.placementSizeX + husbandry.placementSizeZ * husbandry.placementSizeZ) / 2;
			local distanceToCheck = MathUtil.round(math.max(0, distance - length));

			-- is in range (10 meters)
			if (distanceToCheck < maxDistance) then
				table.insert(husbandriesInRange, {
					typeName      = "husbandry",
					husbandry     = husbandry,
					distance      = distance,
					worldPosition = { 
						x = hotspot.xMapPos, 
						y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, hotspot.xMapPos, 300, hotspot.zMapPos),
						z = hotspot.zMapPos
					}
				});
			end
		end
	end
	
	table.sort(husbandriesInRange, function (a, b) 
			return a.distance < b.distance; 
	end);

	return husbandriesInRange;
end

-- we are looking down to the map and find the nearest vehicles
function detector.getVehiclesInRange(maxDistance)
	-- ok thats yourself
	local player = g_currentMission.player;

	-- when the player is inside a vehicle, we have to use the position of that vehicle.
	-- in that case the player position is not updated. if the player is not in a vehicle, 
	-- means he is walking, the player position is correct.
	-- note: controlledVehicle can be nil
	local nodeToCheck = (g_currentMission.controlledVehicle or {}).rootNode or player.rootNode;

	-- the current player or vehicle (with player) position in the map (in meters and in realation to the center)
	local playerX, playerY, playerZ = getWorldTranslation(nodeToCheck);

	-- vehicles in range
	local vehiclesInRange = {};

	-- callback object
	local resolver = {
		checked  = {},
		vehicles = {},
		callback = function(self, transformId)
			-- getRigidBodyType(transformId)
			local object = g_currentMission:getNodeObject(transformId);
			local key    = (object and object.id) or transformId;

			if not self.checked[key] then
				if (object ~= nil and object.isa ~= nil and object:isa(Vehicle)) then
					table.insert(self.vehicles, object);
				end

				-- remember was checked
				self.checked[key] = true;
			end

			-- continue
			return true;
		end
	};

	local callback        = "callback";
	local targetObject    = resolver;
	local collisionMask   = nil;
	local includeDynamics = true;
	local includeStatics  = false;
	local exactTest       = true;

	local x, y, z = getWorldTranslation(nodeToCheck);
	local centerX = x;
	local centerY = y;
	local centerZ = z;
	local extentX = 2 * maxDistance;
	local extentY = 10;
	local extentZ = 2 * maxDistance;

	overlapBox(centerX, centerY, centerZ, x, y, z, extentX, extentY, extentZ, callback, targetObject, collisionMask, includeDynamics, includeStatics, exactTest);

	for _, vehicle in pairs(resolver.vehicles) do	
		local vehicleX, vehicleY, vehicleZ = getWorldTranslation(vehicle.rootNode);
		local x = vehicleX - playerX;
		local z = vehicleZ - playerZ;
		local distance = (math.sqrt((x * x) + (z * z)));

		table.insert(vehiclesInRange, {
			typeName      = "vehicle",
			vehicle       = vehicle,
			distance      = distance,
			worldPosition = { 
				x = vehicleX,
				y = vehicleY,
				z = vehicleZ
			}
		});
	end

	table.sort(vehiclesInRange, function (a, b) 
			return a.distance < b.distance; 
	end);
	
	return vehiclesInRange;
end
