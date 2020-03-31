--[[
	FS19_Stallbursche
	This file is the released version.
]]

local mod = {
	name = "FS19_Stallbursche",
	version = "1.20.3.31",
	dir = g_currentModDirectory,
	modName = g_currentModName,
	data = {
		-- for ingame notifications
		timerId = 0,
		timerInterval = 0,
		alerts = 0,
		fillInfoItems = {},

		-- for top message on screen
		observedModules = {},
		screenMessage = "",
		lastUpdateTime = 0
	}
};

local function ruleUnderflow90(p)
	return p < 90;
end

local function ruleOverflow80(p)
	return p > 80;
end

local function ruleOverflow70(p)
	return p > 70;
end

-- rules for known modules
-- we show the notification on overflow or underflow.
local rules = {};
rules["food"] 			= ruleUnderflow90;
rules["straw"] 			= ruleUnderflow90;
rules["manure"] 		= ruleOverflow80;
rules["liquidManure"] 	= ruleOverflow80;
rules["water"] 			= ruleUnderflow90;
rules["milk"] 			= ruleOverflow80;
rules["cleanliness"] 	= ruleUnderflow90; -- cleanliness from foodSpillage
rules["pallets"] 		= ruleOverflow70;  -- num of pallets (egg, wool)
rules["animals"] 		= ruleOverflow80;  -- num of animals in the husbandry
rules["productivity"]   = ruleUnderflow90; -- from husbandry

local function trace(message)
	print(string.format("@%s [%s]: %s", mod.name, getDate("%H:%M:%S"), message));
end

-- for internal use, see DebugUtil.printTableRecursively
local function printTable(name, inputTable, deep, refs)
	if (type(inputTable) ~= "table") then
		trace(name .. " [" .. type(inputTable) .. "] is not a table: " .. tostring(inputTable));
		return;
	end

	refs = refs or {};

	if refs[tostring(inputTable)] ~= nil then
		trace(name .. "[" .. tostring(inputTable) .. "]: REFERENCE: " .. refs[tostring(inputTable)]);
		return;
	end

	refs[tostring(inputTable)] = name;

	local mt = getmetatable(inputTable);

	if type(mt) == "table" then
		printTable(name .. "_mt", mt, deep, refs);
	end

	for k, v in pairs(inputTable) do
		trace(name .. "." .. tostring(k) .. " [" .. type(v) .. "]: " .. tostring(v));

		if (((deep or 0) > 0) and (type(v) == "table")) then
			printTable(name .. "." .. tostring(k), v, deep - 1, refs);
		end		
	end
end

-- hope farmId works in MP
local function getHusbandries(farmId)
	local husbandries = {};

	for _, husbandry in pairs(g_currentMission:getHusbandries()) do
		if (husbandry.ownerFarmId == farmId) then
			table.insert(husbandries, husbandry);
		end
	end

	return next, husbandries;
end

-- when the mission starts
function mod:onStartMission()
	-- 10s after mission starts in user time (not ingame time)
	self:updateTimerInterval(10 * 1000);
	self.data.timerId = addTimer(self.data.timerInterval, "onTimer", self);
end

-- updates our timer interval
function mod:updateTimerInterval(interval)
	-- interval + some random values
	self.data.timerInterval = interval + math.random(1000, 5000);
end

-- our timer callback (user time). we dont use minuteChanged (ingame time)
function mod:onTimer()
	self:collectData();	
	self:displayAlerts();

	-- every 15min in user time (not ingame time)
	self:updateTimerInterval(15 * 60 * 1000);
	setTimerTime(self.data.timerId, self.data.timerInterval);
	return true;
end

-- draw on game loop (each frame)
function mod:draw()
	if ((self.data.lastUpdateTime + 5000) < g_time) then
		-- "fadeOut"
		return;
	end

	local fontSize = HUDElement.TEXT_SIZE.DEFAULT_TITLE / g_screenHeight;

	setTextBold(false);
	setTextColor(unpack(HUDPopupMessage.COLOR.TEXT));
	setTextAlignment(RenderText.ALIGN_CENTER);
	renderText(0.5, 1 - (g_currentMission.hud.topNotification.overlay.height * 0.5) - (fontSize * 0.5), fontSize, self.data.screenMessage);
end

function mod:getFillInfoTitle(info)
	-- "Protein"
	return (info.foodGroup or info.fillType).title or "no title";
end

function mod:getFillInfoTitleWithDetails(info)
	local strings = {};
	local details = {};

	-- "Protein"
	table.insert(strings, self:getFillInfoTitle(info));

	-- get the details
	if type(info.foodGroup) == "table" then
		for _, num in pairs(info.foodGroup.fillTypes) do
			table.insert(details, g_fillTypeManager.fillTypes[num].title);
		end
	end

	if #details > 0 then
		table.insert(strings, " ");
		table.insert(strings, "(");
		table.insert(strings, table.concat(details, ", "));
		table.insert(strings, ")");
	end

	-- "Protein (Sojabohnen, Raps, Sonnenblumen)"
	return table.concat(strings, "");
end

-- obtain the fill levels and creates output messages. data is in the format of {husbandry, moduleName, filltypeInfo}.
-- Note: not all modules have a filltypeInfo, so we wrap them into the custom data format.
function mod:getFillInfo(data)
	if data.husbandry:getNumOfAnimals() == 0 then
		-- dont show any message for husbandries without animals
		return nil;
	end

	local items = {};
	local messages = {};
	local hotspot = data.husbandry.mapHotspots[1].fullViewName;

	for _, info in pairs(data.filltypeInfo) do
		if (info.capacity > 0) then
			-- there is a builtin storage of whatever

			-- "84"
			local percentage = math.floor(info.fillLevel * 100 / info.capacity);
			-- "Protein"
			local title = self:getFillInfoTitle(info);
			-- "84% Protein"
			local percentageMessage = string.format("%d%% %s", percentage, title);
			-- "84% Protein (Sojabohnen, Raps, Sonnenblumen)"
			local percentageMessageWithDetails = string.format("%d%% %s", percentage, self:getFillInfoTitleWithDetails(info));

			-- that's the item we want to check
			local item = {
				-- needed to have the correct rule
				moduleName = data.moduleName,
				-- needed to check the rule (note: we dont use FOOD_CONSUME_TYPE_PARALLEL or FOOD_CONSUME_TYPE_SERIAL)
				percentage = percentage,
				-- "Schweinegehege 84% Protein (Sojabohnen, Raps, Sonnenblumen)"
				message = string.format("%s %s", hotspot, percentageMessageWithDetails),
				-- unique key to indentify
				-- "Animals_PIG_food_Protein", "Animals_PIG_food_Basisfutter" etc.
				key = string.format("%s_%s_%s", tostring(data.husbandry.saveId), data.moduleName, (info.key or title)),
			};

			-- notifications
			table.insert(items, item);
			-- on screen
			table.insert(messages, percentageMessage);		
		end
	end

	if #items > 0 then
		local fillinfo = {
			-- use for ingame notifications (self.data.fillInfoItems)
			items = items,
			-- use for top message on screen (self.data.screenMessage)
			-- "Schweinegehege 86% Basisfutter, 84% Getreide, 84% Protein, 83% Wurzelfrüchte"
			message = string.format("%s %s", hotspot, table.concat(messages, ", "))
		};

		return fillinfo;
	end
end

-- special getFillInfo, animal module dont have a fill level, so we check the num of animals in the husbandry with a reproduction rate
function mod:getFillInfoFromAnimalModule(animalModule)
	local husbandry = animalModule.owner;
	local reproduction = false;
	local typedAnimals = animalModule:getTypedAnimals();

	-- can have different animals (color, gender)
	for fillTypeIndex, _ in pairs(typedAnimals) do
		if (husbandry:getReproductionTimePerDay(fillTypeIndex) or 0) > 0 then
			reproduction = true;
			break;
		end
	end

	if (reproduction == true) then
		local key = string.format("statistic_%sOwned", string.lower(animalModule:getAnimalType()));
		local title = string.format("%s (%d/%d)", tostring(g_i18n.texts[key]), husbandry:getNumOfAnimals(), husbandry:getMaxNumAnimals());

		return self:getFillInfo({
			husbandry = husbandry,
			moduleName = animalModule.moduleName,
			filltypeInfo = {{fillLevel = husbandry:getNumOfAnimals(), capacity = husbandry:getMaxNumAnimals(), key = "animals", fillType = {title = title}}}
		})
	end
end

-- special getFillInfo, take cleanliness from food spillage module
function mod:getFillInfoFromFoodSpillageModule(foodSpillageModule)
	local husbandry = foodSpillageModule.owner;
	-- same as husbandry:getFoodSpillageFactor()
	local foodSpillageFactor = foodSpillageModule:getSpillageFactor();

	if foodSpillageFactor ~= nil then
		return self:getFillInfo({
			husbandry = husbandry,
			moduleName = "cleanliness",
			filltypeInfo = {{fillLevel = foodSpillageFactor, capacity = 1, key = "cleanliness", fillType = {title = tostring(g_i18n.texts.statistic_cleanliness)}}}
		})
	end
end

--[[
coordinate system, (0,0,0) is top left of map

              y+  (N)
              |   z-
              |  /
              | /
              |/
(W) x- -------0------- x+ (E)
             /|
            / |
           /  |
          z+  |
        (S)   y-
]]

-- special getFillInfo, pallet module dont have a fill level, so we take the free space of the spawner area
function mod:getFillInfoFromPalletModule(palletModule)
	local husbandry = palletModule.owner;

	-- the pallet module has the size of the provided pallet and the size of the pallet spawner area.
	-- so we use a physics collision detection for each possible pallet position in the spawner area and
	-- if we found an object, then we have to check that the object is a pallet or not. thats the base idea,
	-- and that is what giants does in the HusbandryModulePallets. so we know how many pallets are currently
	-- in the area and how many pallets can be in the area. thats enough.
	-- see: https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=84&class=10077

	local rotationX, rotationY, rotationZ = getWorldRotation(palletModule.palletSpawnerNode); 

	-- pallet size (note: pallet/box is a specialized vehicle -> FillUnit)
	local width = palletModule.sizeWidth;
	local height = palletModule.sizeLength;

	-- why? +25%
	height = height * 1.25;

	-- how many pallets can be in the area (note: these values dont reflect the real behaviour)
	local numMaxPalletsWidth = math.floor(palletModule.palletSpawnerAreaSizeX / width);
	local numMaxPalletsHeight = math.floor(palletModule.palletSpawnerAreaSizeZ / height);
	local numMaxPallets = numMaxPalletsWidth * numMaxPalletsHeight;

	-- half size
	local widthHalf = width * 0.5;
	local heightHalf = height * 0.5;

	-- stateful resolver to detect pallets
	local palletsResolver = {
		numPallets = 0,
		numPalletsOnGround = 0,
		sumFillLevel = 0,
		fillTypeTitle = "n/a",
		transformIds = {},
		palletSpawnerCollisionTestCallback = function(self, transformId)
			if (self.transformIds[transformId] == nil) then
				local object = g_currentMission:getNodeObject(transformId);
				local isPallet = (object ~= nil and object.isa ~= nil and object:isa(Vehicle) and object.typeName == "pallet");

				if (isPallet == true) then
					self.numPallets = self.numPallets + 1;

					local x, y, z = localToLocal(object.rootNode, palletModule.palletSpawnerNode, 0, 0, 0);

					if (y < 0.001) then
						-- means the pallet is not stacked
						self.numPalletsOnGround = self.numPalletsOnGround + 1;
					end

					-- fill level and fill type
					local fillTypeIndex = object:getFillUnitFillType(1);
					local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex);

					if (fillType ~= nil) then
						self.sumFillLevel = self.sumFillLevel + (object:getFillUnitFillLevel(1) or 0);
						self.fillTypeTitle = fillType.title;
					end
				end

				-- remember is counted
				self.transformIds[transformId] = transformId;
			end

			return true;
		end
	};

	local overlapFunctionCallback = "palletSpawnerCollisionTestCallback";
	local targetObject = palletsResolver;
	local collisionMask = nil;
	local includeDynamics = true;
	local includeStatics = false;
	local exactTest = true;

	-- for each possible pallet position (raster) in the spawner area
	for dx = widthHalf, palletModule.palletSpawnerAreaSizeX - widthHalf, width do 
		 for dz = heightHalf, palletModule.palletSpawnerAreaSizeZ - heightHalf, height do
			local x, y, z = localToWorld(palletModule.palletSpawnerNode, dx, 0, dz);
			local centerX = x;
			local centerY = y - 5;
			local centerZ = z;
			local extentX = widthHalf;
			local extentY = 10;
			local extentZ = heightHalf;

			overlapBox(centerX, centerY, centerZ, rotationX, rotationY, rotationZ, extentX, extentY, extentZ, overlapFunctionCallback, targetObject, collisionMask, includeDynamics, includeStatics, exactTest);
		 end
	end

	if numMaxPallets > 0 then
		-- "Paletten (2/4)"
		local title = string.format("%s (%d/%d)", tostring(g_i18n.texts.category_pallets), targetObject.numPalletsOnGround, numMaxPallets);

		if (targetObject.numPalletsOnGround ~= targetObject.numPallets) then
			-- "Paletten (2/4) [Gesamt: 7]"
			title = string.format("%s [%s: %d]", title, tostring(g_i18n.texts.ui_total), targetObject.numPallets);
		end

		-- "Paletten (2/4) [Gesamt: 7] 1524 Wolle"
		title = string.format("%s %d %s", title, math.floor(targetObject.sumFillLevel), targetObject.fillTypeTitle);

		return self:getFillInfo({
			husbandry = husbandry,
			moduleName = palletModule.moduleName,
			filltypeInfo = {{fillLevel = targetObject.numPalletsOnGround, capacity = numMaxPallets, key = "pallets", fillType = {title = title}}}
		});
	end
end

-- this function returns the fill level info from a module, if available. there are modules for straw, water, milk and so on.
-- the module system is new in FS19. each husbandry can have different modules. chickens dont have milk, so they dont have a milk module.
-- the original getFilltypeInfos is wrapped in a custom data table, so we can use it also for cleanliness, pallets and so on.
function mod:getFillInfoFromModule(_module)
	local husbandry = _module.owner;
	local fillinfo = nil;

	if (type(_module.getFilltypeInfos) == "function") then
		fillinfo = self:getFillInfo({
			husbandry = husbandry,
			moduleName = _module.moduleName,
			filltypeInfo = _module:getFilltypeInfos()});
	end

	-- some modules dont have getFilltypeInfos/capacity, so we use a special handling to get some useful informations
	if fillinfo == nil then
		if (_module.moduleName == "animals") then
			-- check num of animals in husbandry
			fillinfo = self:getFillInfoFromAnimalModule(_module);
		end

		if (_module.moduleName == "foodSpillage") then
			-- cleanliness (not a module, we have to take the values from folldSpillage module)
			fillinfo = self:getFillInfoFromFoodSpillageModule(_module);
		end

		if (_module.moduleName == "pallets") then
			-- get free spawner space
			fillinfo = self:getFillInfoFromPalletModule(_module);
		end
	end

	return fillinfo;
end

-- add/update the correct items to our "notification queue"
function mod:addFillInfoItems(fillinfo)
	if type(fillinfo) ~= "table" then
		return;
	end

	for _, item in pairs(fillinfo.items) do
		self.data.fillInfoItems[item.key] = item;
	end
end

-- this function attach to the onFillProgressChanged of a module, if supported.
-- every time the fill level of the module changes, we grab the fill level info to display on screen.
function mod:attachToModule(_module)
	if self.data.observedModules[_module] ~= nil then
		-- already attached
		return;
	end

	if type(_module) ~= "table" then
		trace("attachToModule with invalid argument of type " .. type(_module));
		return;
	end
	
	if type(_module.onFillProgressChanged) ~= "function" then
		-- not supported
		return;
	end
	
	if type(_module.getFilltypeInfos) ~= "function" then
		-- not supported
		return;
	end

	-- track onFillProgressChanged is invoked inside onIntervalUpdate
	local isModuleIntervalUpdate = false;
	local _module_onIntervalUpdate = _module.onIntervalUpdate;

	-- we dont want to use the trigger, but we have to know, that the trigger is running
	_module.onIntervalUpdate = function(m, dayInterval)
		isModuleIntervalUpdate = true;
		_module_onIntervalUpdate(m, dayInterval);
		isModuleIntervalUpdate = false;
	end

	-- track last message
	local lastMessage = nil;

	_module.onFillProgressChanged = Utils.appendedFunction(_module.onFillProgressChanged, function(m)
		if isModuleIntervalUpdate == true then
			-- we have our own interval
			return;
		end

		if m.owner.ownerFarmId == g_currentMission.player.farmId then
			local fillinfo = self:getFillInfoFromModule(m);

			if fillinfo ~= nil then
				-- we show the message on top only if there is a different.
				-- AnimalPenExtension use addFillLevelFromTool to increase the fill level (rain),
				-- but we want to see significant changes only.
				if lastMessage ~= nil and lastMessage ~= fillinfo.message then
					self:addFillInfoItems(fillinfo);
					self:displayMessage(fillinfo.message);
				end

				lastMessage = fillinfo.message;
			end
		end
	end);

	self.data.observedModules[_module] = _module;
end

-- this function attach to all modules of a husbandry, if not yet attached
function mod:attachToModules(husbandry)
	for _, _module in pairs(husbandry.modulesByName) do
		self:attachToModule(_module);
	end
end

-- this function takes all fill levels from the husbandry to display ingame notifications.
function mod:collectFromModules(husbandry)
	for _, _module in pairs(husbandry.modulesByName) do
		local fillinfo = self:getFillInfoFromModule(_module);
		self:addFillInfoItems(fillinfo);
	end

	-- there is no productivity module, take the values from the husbandry itself
	local productivity = husbandry:getGlobalProductionFactor() or 0;

	local fillinfo = self:getFillInfo({
		husbandry = husbandry,
		moduleName = "productivity",
		filltypeInfo = {{fillLevel = productivity, capacity = 1, key = "productivity", fillType = {title = tostring(g_i18n.texts.statistic_productivity)}}}
	})

	self:addFillInfoItems(fillinfo);
end

-- collect data from husbandries
function mod:collectData()
	for _, husbandry in getHusbandries(g_currentMission.player.farmId) do
		self:attachToModules(husbandry);
		self:collectFromModules(husbandry);
	end
end

-- evaluates all collected fill info items and show an alert
function mod:displayAlerts()
	for _, item in pairs(self.data.fillInfoItems) do
		local rule = rules[item.moduleName];

		if type(rule) ~= "function" then
			trace("rule for module '" .. item.moduleName .. "' was not found");
		elseif rule(item.percentage) == true then
			self:displayAlert(item.key);
		end
	end
end

-- displays the message as ingame notification
function mod:displayAlert(key)
	-- show the alerts every 30s
	local interval = self.data.alerts * 30 * 1000;

	self.data.alerts = self.data.alerts + 1;

	addTimer(interval, "onTimer", {
		onTimer = function()
			local item = self.data.fillInfoItems[key];

			if item ~= nil then
				trace(item.message);
				g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, item.message);
			end

			self.data.alerts = self.data.alerts - 1;

			-- https://gdn.giants-software.com/tutorial04.php
			-- You can remove a timer within the callback function by returning false
			return false;
		end
	});
end

-- displays the message on top of the screen
function mod:displayMessage(message)
	self.data.screenMessage = message;
	self.data.lastUpdateTime = g_time;
end

-- we dont attach the mod directly, we use a wrapper
addModEventListener({
	name = mod.name .. "_listener",
	-- when the map is loading
	loadMap = function(self)
		if g_currentMission:getIsClient() ~= true then
			return;
		end

		-- mod draw
		self.draw = function(self)
			mod:draw();
		end

		-- attach to the mission start event
		g_currentMission.onStartMission = Utils.appendedFunction(g_currentMission.onStartMission, function()
			mod:onStartMission();
		end);
	end
});
