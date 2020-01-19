--[[
	FS19_ZoomOut
	This file is the released version.
]]

local mod = {
	name = "FS19_ZoomOut",
	version = "1.20.1.19",
	dir = g_currentModDirectory,
	modName = g_currentModName,
	data = {
		-- for internal use
		isCameraZoomedOut = false
	}
};

-- when the mission starts
function mod:onStartMission()
	self:enableCameraZoomOut();
end

-- auto zoom first time after mission starts
function mod:enableCameraZoomOut()
	if self.data.isCameraZoomedOut == true then
		-- done
		return;
	end

	local zoomedCameras = {};
	local guiTopDownCamera = g_currentMission.guiTopDownCamera;

	-- when the vehicle changed
	guiTopDownCamera.setControlledVehicle = Utils.appendedFunction(function(sender, vehicle)
		if vehicle ~= nil then
			-- each vehicle has its own camera, first time the camera is outside
			local activeCamera = vehicle:getActiveCamera();

			-- when the camera is outside and not already zoomed out
			if activeCamera ~= nil and activeCamera.isInside ~= true and zoomedCameras[activeCamera.cameraNode] ~= true then
				-- zoom out transLength 
				-- see: https://gdn.giants-software.com/documentation_scripting.php?version=script&category=69&class=3537
				--activeCamera.zoomTarget = 15;
				activeCamera:zoomSmoothly(15 - activeCamera.zoomTarget);
				-- remember camera was zoomed
				zoomedCameras[activeCamera.cameraNode] = true;
			end
		end
	end, guiTopDownCamera.setControlledVehicle);

	self.data.isCameraZoomOutEnabled = true;
end

-- we dont attach the mod directly, we use a wrapper
addModEventListener({
	name = mod.name .. "_listener",
	-- when the map is loading
	loadMap = function(self)
		if g_currentMission:getIsClient() ~= true then
			return;
		end

		-- attach to the mission start event
		g_currentMission.onStartMission = Utils.appendedFunction(g_currentMission.onStartMission, function()
			mod:onStartMission();
		end);
	end
});
