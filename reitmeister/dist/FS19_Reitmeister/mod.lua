--[[
	FS19_Reitmeister
	This file is the released version.
]]

local mod = {
	name = "FS19_Reitmeister",
	version = "1.20.8.16",
	dir = g_currentModDirectory,
	modName = g_currentModName,
	data = {
		-- ingame time
		hour = 0,
		minute = 0
	}
};

-- start riding a horse on the planned time (ingame time)
-- the values are generated by makePlanForRiding in the format of {"08:05", .., "09:12"}
-- 16 horses are supported
local rideTheHorses = {};

local function trace(message)
	print(string.format("@%s [%s]: %s", mod.name, getDate("%H:%M:%S"), message));
end

-- formats a string, formatString("{key1} {key2}!", {key1 = "Hello", key2 = "World}") => "Hello World!"
local function formatString(format, args)
	local str = tostring(format or "");

	for k, v in pairs(args) do
		str = string.gsub(str, string.format("{%s}", tostring(k)), tostring(v));
	end

	return str;
end

-- hope farmId works in MP
local function getAnimalsHorse(farmId)
	local animals = {};

	for _, husbandry in pairs(g_currentMission:getHusbandries()) do
		if ((husbandry.ownerFarmId == farmId) and (husbandry.saveId == "Animals_HORSE")) then
			for _, animal in pairs(husbandry:getAnimals()) do
				if ((animal.owner.ownerFarmId == farmId) and (animal.className == Horse.className)) then
					table.insert(animals, animal);
				end
			end
		end
	end

	return next, animals;
end

-- when the mission is started
function mod:onStartMission()
	self.data.hour = g_currentMission.environment.currentHour;
	self.data.minute = g_currentMission.environment.currentMinute;

	-- attach to changed listener
	g_currentMission.environment:addDayChangeListener(self);
	g_currentMission.environment:addHourChangeListener(self);
	g_currentMission.environment:addMinuteChangeListener(self);

	-- create a time plan
	self:makePlanForRiding();
end

function mod:timestr(hour, minute)
	return string.format("%s:%s", string.sub("00" .. (hour or self.data.hour), -2), string.sub("00" .. (minute or self.data.minute), -2));
end

-- creates a time plan
function mod:makePlanForRiding()
	local timePlan = {};

	-- start at 08:00
	local minutes = 8 * 60;

	-- DAILY_TARGET_RIDING_TIME are milliseconds
	local ridingTimeInMinutes = math.ceil(Horse.DAILY_TARGET_RIDING_TIME / 1000 / 60);

	while #timePlan < 16 do
		-- ride the horse
		minutes = minutes + ridingTimeInMinutes;

		-- grooming the horse
		minutes = minutes + math.random(3, 7);

		-- adjust to 10 minutes
		minutes = math.ceil(minutes / 10) * 10;

		-- completed
		table.insert(timePlan, self:timestr(math.floor(minutes / 60), minutes % 60));

		-- have a break or some work
		minutes = minutes + math.random(10, 30);
	end

	trace("ride the horses at: " .. table.concat(timePlan, ", "));

	-- apply
	rideTheHorses = {};

	for _, t in pairs(timePlan) do
		rideTheHorses[t] = true;
	end
end

-- ingame day changed
function mod:dayChanged(hour)
	self:makePlanForRiding();
end

-- ingame hour changed
function mod:hourChanged(hour)
	self.data.hour = g_currentMission.environment.currentHour;
end

-- ingame minute changed
function mod:minuteChanged()
	self.data.minute = g_currentMission.environment.currentMinute;

	if self.data.minute == 0 then
		-- it seems to be a bug, minuteChanged fired but currentHour is not updated yet
		-- so we use own times
		self.data.hour = self.data.hour + 1;

		if self.data.hour > 23 then
			self.data.hour = 0;
		end
	end

	local timestr = self:timestr();

	-- check the time plan to ride a horse
	if rideTheHorses[timestr] == true then
		for _, animal in getAnimalsHorse(g_currentMission.player.farmId) do	
			-- take a horse without 100%
			if animal.ridingScale < 1 then
				animal.ridingTimer = animal.DAILY_TARGET_RIDING_TIME;
				animal.ridingScale = 1;

				local args = {
					horse = animal.name,
					player = g_gameSettings.nickname,
					time = timestr,
					minutes = string.format("%g", animal.DAILY_TARGET_RIDING_TIME / 60000),
					fitness = math.floor(animal.fitnessScale * 100),
					fitnessTitle = tostring(g_i18n.texts.ui_horseFitness)
				};

				self:displayAlert(formatString(g_i18n:getText("DISPLAYTEXT"), args));
				break;
			end
		end
	end
end

-- displays the message as ingame notification
function mod:displayAlert(msg)
	-- random delay between 2s and 20s
	local interval = math.random(2 * 1000, 20 * 1000);

	addTimer(interval, "onTimer", {
		onTimer = function()
			trace(msg);
			g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, msg)

			-- https://gdn.giants-software.com/tutorial04.php
			-- You can remove a timer within the callback function by returning false
			return false;
		end;
	});
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

