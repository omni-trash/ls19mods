--[[
	MAIN
]]

-- lib
local main = { 
	-- AR on/off
	enabled = true,
	-- internal for development
	debugEnabled = false
};

-- internal
local scanResult = {};

-- export
FS19_AR.lib.main = main;

-- import shortcuts
local logging;
local hud;
local debugging;
local scanner;
local utils;
local config;

-- required
function main:load(mod)
	-- refs
	logging   = FS19_AR.lib.logging;
	hud       = FS19_AR.lib.hud;
	debugging = FS19_AR.lib.debugging;
	scanner   = FS19_AR.lib.scanner;
	utils     = FS19_AR.lib.utils;
	config    = FS19_AR.lib.config;
end

function main:loaded()
	-- global action events
	FSBaseMission.registerActionEvents = utils.combineFunction(function()
		main:registerGlobalActionEvents();
	end, FSBaseMission.registerActionEvents);

	-- player action events
	Player.registerActionEvents = utils.combineFunction(function()
		main:registerPlayerActionEvents();
	end, Player.registerActionEvents);

	-- attach to the mission start event
	FSBaseMission.onStartMission = utils.combineFunction(function()
		main:onStartMission();
	end, FSBaseMission.onStartMission);

	-- savegame
	FSCareerMissionInfo.saveToXMLFile = utils.combineFunction(function()
		config.saveSettings("FS19_AR", FS19_AR);
	end, FSCareerMissionInfo.saveToXMLFile);

	config.loadSettings("FS19_AR", FS19_AR);
end

-- unused, we dont have player action events to register
function main:registerPlayerActionEvents()
end

-- unused, we dont have global action events to register
function main:registerGlobalActionEvents()
--[[
	https://gdn.giants-software.com/thread.php?categoryId=3&threadId=9036
	https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=28&class=281#registerActionEvents3130
	https://github.com/scfmod/fs19_lua
	g_inputBinding:registerActionEvent(actionId, self, callback, triggerUp, triggerDown, triggerAlways, startActive, callbackState, flag)

	triggerUp     : on key up
	triggerDown   : on key down
	triggerAlways : repeat on key pressed
	startActive   : trigger is active
	callbackState : unused (passed to the callback)
	flag          : unused
]]

	g_inputBinding:registerActionEvent(InputAction.AUGMENTED_REALITY_TOGGLE, self, self.onAugmentedRealityToggle, true, false, false, true);
end

-- when the mission starts
function main:onStartMission()
	-- we use a timer to call the onMissionStarted
	addTimer(0, "elapsed", {
		elapsed = function()
			main:onMissionStarted();
			return false;
		end
	});
end

-- when the mission was started
function main:onMissionStarted()
end

function main:onAugmentedRealityToggle(actionName, keyState, callbackState)
	if (keyState == 0) then
		self.enabled = (not self.enabled);
		logging.trace("Augmented Reality was turned " .. (self.enabled and "on" or "off"));
	end
end

function main:applyScanResult(scanResult)
	-- for each info in scan result
	for number, info in pairs(scanResult) do
		local slot = hud:getSlot(number);

		----------------------------------------------------------
		-- Text
		----------------------------------------------------------

		slot.title = { value = info.title, color = hud.COLORNAME.HIGHLIGHT };
		slot.text  = info.text;

		----------------------------------------------------------
		-- Position
		----------------------------------------------------------

		-- Transform vector from world space into screen space
		local x, y, z = project(info.worldPosition.x, info.worldPosition.y, info.worldPosition.z);

		if (z > 1) then
			-- behind us, dont show
			slot.visible = false;
		else
			-- screen to viewport
			x = x - 0.5;
			y = y - 0.5;

			-- the panel
			slot.rootNode   = info.rootNode;
			slot.position.x = x;
			slot.position.y = y;
			slot.visible    = true;
		end
	end
end

-- draw on game loop (each frame)
function main:draw()
	if not self.enabled then
		return;
	end
	
	hud:draw();
	self:debugDraw();
end

function main:debugDraw()
	if (self.debugEnabled ~= true) then
		return;
	end

	if not scanResult then
		return;
	end

	-- visual helper, draw a box over the field partitions
	for _, result in pairs(scanResult) do
		if (result.profile == "field") then
			debugging.drawFieldPartitions(result.field);
			debugging.drawFieldCenterBox(result.field);
		elseif (result.profile == "husbandry") then
			debugging.drawHusbandryBox(result.husbandry);
			debugging.drawHusbandryCenterBox(result.husbandry);
		end
	end
end

function main:update(dt)
	if not self.enabled then
		return;
	end

	scanner:update(dt);
	scanResult = scanner:getScanResult();

	if scanResult then
		self:applyScanResult(scanResult);
	end

	hud:update(dt);
end
