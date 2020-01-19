--[[
	FS19_Stallbursche
	This file is the released version.
]]

local mod = {
	name = "FS19_Stallbursche",
	version = "1.20.1.19",
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
rules["pallets"] 		= ruleOverflow80;  -- pallets (egg, wool), note: dont work
--animals, unused

local function trace(message)
	print(string.format("@%s [%s]: %s", mod.name, getDate("%H:%M:%S"), message));
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
	return (info.foodGroup or info.fillType).title;
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
			local percentageMessage = percentage .. "% " .. title;
			-- "84% Protein (Sojabohnen, Raps, Sonnenblumen)"
			local percentageMessageWithDetails = percentage .. "% " .. self:getFillInfoTitleWithDetails(info);

			-- that's the item we want to check
			local item = {
				-- needed to have the correct rule
				moduleName = data.moduleName,
				-- needed to check the rule (note: we dont use FOOD_CONSUME_TYPE_PARALLEL or FOOD_CONSUME_TYPE_SERIAL)
				percentage = percentage,
				-- "Schweinegehege 84% Protein (Sojabohnen, Raps, Sonnenblumen)"
				message = hotspot .. " " .. percentageMessageWithDetails,
				-- unique key to indentify
				-- "Animals_PIG_food_Protein", "Animals_PIG_food_Basisfutter" etc.
				key = data.husbandry.saveId .. "_" .. data.moduleName .. "_" .. title,
			};

			table.insert(items, item);
			table.insert(messages, percentageMessage);
		elseif data.moduleName == "pallets" then
			-- wrong ... superClass() ?
			-- no capacity for eggs or wool, they are in a box or pallet

--[[ TODO: how many pallets can be dropped?
			-- "67"
			local percentage = math.floor(#data.husbandry.pickObjects);
			-- "Wolle"
			local title = self:getFillInfoTitle(info);
			-- "67% Wolle"
			local percentageMessage = percentage .. "% " .. title;
			-- "67% Wolle"
			local percentageMessageWithDetails = percentage .. "% " .. self:getFillInfoTitleWithDetails(info);

			-- that's the item we want to check
			local item = {
				-- needed to have the correct rule
				moduleName = data.moduleName,
				-- needed to check the rule
				percentage = percentage,
				-- "Schafweide 67% Wolle"
				message = hotspot .. " " .. percentageMessageWithDetails,
				-- unique key to indentify
				-- "Animals_SHEEP_pallets_Wolle", "Animals_CHICKEN_pallets_Eier" etc.
				key = data.husbandry.saveId .. "_" .. data.moduleName .. "_" .. title,
			};

			table.insert(items, item);
			table.insert(messages, percentageMessage);
]]
		end
	end

	if #items > 0 then
		local fillinfo = {
			-- use for ingame notifications (self.data.fillInfoItems)
			items = items,
			-- use for top message on screen (self.data.screenMessage)
			-- "Schweinegehege 86% Basisfutter, 84% Getreide, 84% Protein, 83% Wurzelfrüchte"
			message = hotspot .. " " .. table.concat(messages, ", ")
		};

		return fillinfo;
	end
end

-- this function returns the fill level info from a module, if available. there are modules for straw, water, milk and so on.
-- the module system is new in FS19. each husbandry can have different modules. chickens dont have milk, so they dont have a milk module.
-- the original getFilltypeInfos is wrapped in a custom data table, so we can use it also for cleanliness.
function mod:getFillInfoFromModule(_module)
	local fillinfo = self:getFillInfo({
		husbandry = _module.owner,
		moduleName = _module.moduleName,
		filltypeInfo = _module:getFilltypeInfos()});

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
		if type(_module.getFilltypeInfos) == "function" then
			local fillinfo = self:getFillInfoFromModule(_module);
			self:addFillInfoItems(fillinfo);
		end
	end

	-- cleanliness (not a module, we have to take the values from folldSpillage module)
	local foodSpillageFactor = husbandry:getFoodSpillageFactor();

	if foodSpillageFactor ~= nil then
		local fillinfo = self:getFillInfo({
			husbandry = husbandry,
			moduleName = "cleanliness",
			filltypeInfo = {{fillLevel = foodSpillageFactor, capacity = 1, fillType = {title = g_i18n.texts.statistic_cleanliness}}}
		})

		self:addFillInfoItems(fillinfo);
	end
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
