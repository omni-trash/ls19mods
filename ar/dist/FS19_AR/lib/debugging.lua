--[[
	DEBUGGING
]]

-- lib
local debugging = {};

-- export
FS19_AR.lib.debugging = debugging;

-- import shortcuts
local logging;

-- required
function debugging:load(mod)
	-- refs
	logging = FS19_AR.lib.logging;
end

-- draws a box on each partition (you have to press F5)
function debugging.drawFieldPartitions(field)
	local rotationX, rotationY, rotationZ = getWorldRotation(field.rootNode);
	local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, field.posX, 300, field.posZ);

	for _, partition in pairs(field.getFieldStatusPartitions) do
		local x = partition.x0;
		local z = partition.z0;
		local y = terrainHeight;

		local widthHalf  = partition.heightX / 2;
		local heightHalf = partition.widthZ  / 2;

		local centerX = x + widthHalf;
		local centerY = terrainHeight;
		local centerZ = z + heightHalf;
		local extentX = widthHalf;
		local extentY = 20;
		local extentZ = heightHalf;

		DebugUtil.drawOverlapBox(centerX, centerY, centerZ, rotationX, rotationY, rotationZ, extentX, extentY, extentZ, 1, 0, 0);
	end
end

-- draws a blue box on field center (you have to press F5)
function debugging.drawFieldCenterBox(field)
	local rotationX, rotationY, rotationZ = getWorldRotation(field.rootNode);
	local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, field.posX, 300, field.posZ);
	
	local x = field.posX;
	local z = field.posZ;
	local y = terrainHeight;

	local widthHalf  = 10 / 2;
	local heightHalf = 10 / 2;

	local centerX = x;
	local centerY = terrainHeight;
	local centerZ = z;
	local extentX = widthHalf;
	local extentY = 20;
	local extentZ = heightHalf;

	DebugUtil.drawOverlapBox(centerX, centerY, centerZ, rotationX, rotationY, rotationZ, extentX, extentY, extentZ, 0, 0, 1);
end

-- draws a red box on husbandry (you have to press F5)
function debugging.drawHusbandryBox(husbandry)
	local hotspot = husbandry.mapHotspots[1];

	local rotationX, rotationY, rotationZ = getWorldRotation(husbandry.nodeId);
	local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, hotspot.xMapPos, 300, hotspot.zMapPos);
	
	local x = hotspot.xMapPos;
	local z = hotspot.zMapPos;
	local y = terrainHeight;

	local widthHalf  = husbandry.placementSizeX / 2;
	local heightHalf = husbandry.placementSizeZ / 2;

	local centerX = x;
	local centerY = terrainHeight;
	local centerZ = z;
	local extentX = widthHalf;
	local extentY = 20;
	local extentZ = heightHalf;

	DebugUtil.drawOverlapBox(centerX, centerY, centerZ, rotationX, rotationY, rotationZ, extentX, extentY, extentZ, 1, 0, 0);
end

-- draws a blue box on husbandry center (you have to press F5)
function debugging.drawHusbandryCenterBox(husbandry)
	local hotspot = husbandry.mapHotspots[1];

	local rotationX, rotationY, rotationZ = getWorldRotation(husbandry.nodeId);
	local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, hotspot.xMapPos, 300, hotspot.zMapPos);

	local x = hotspot.xMapPos;
	local z = hotspot.zMapPos;
	local y = terrainHeight;

	local widthHalf  = 10 / 2;
	local heightHalf = 10 / 2;

	local centerX = x;
	local centerY = terrainHeight;
	local centerZ = z;
	local extentX = widthHalf;
	local extentY = 20;
	local extentZ = heightHalf;

	DebugUtil.drawOverlapBox(centerX, centerY, centerZ, rotationX, rotationY, rotationZ, extentX, extentY, extentZ, 0, 0, 1);
end
