--[[
	MAIN
]]

-- lib
local main = {};
local data = {
	time1       = g_time,
	time2       = g_time,
	showExpires = 0,
	showTimeout = 2000
};

-- export
FS19_RadioVolume.lib.main = main;

-- import shortcuts
local logging;
local hud;

local function combineFunction(first, final)
	return function(...)
		local t = {...};
		local n = select('#', ...);
		first(unpack(t, 1, n));
		return final(unpack(t, 1, n));
	end
end

-- required
function main:load(mod)
	-- refs
	logging = FS19_RadioVolume.lib.logging;
	hud     = FS19_RadioVolume.lib.hud;

	-- global action events
	FSBaseMission.registerActionEvents = combineFunction(function()
		main:registerGlobalActionEvents();
	end, FSBaseMission.registerActionEvents);

	-- player action events
	Player.registerActionEvents = combineFunction(function()
		main:registerPlayerActionEvents();
	end, Player.registerActionEvents);

	-- attach to the mission start event
	FSBaseMission.onStartMission = combineFunction(function()
		-- initial update
		main:updateHud("---", "PAUSE", "");
	end, FSBaseMission.onStartMission);

	-- when radio stop playing
	FSBaseMission.pauseRadio = combineFunction(function()
		main:updateHud("---", "PAUSE", "");
	end, FSBaseMission.pauseRadio);

	-- when radio start playing or channel changed
	-- we attach to the onChange, so we have the arguments for channel and title
	-- alternative we can attach to the HUD.addTopNotification
	g_soundPlayer.onChange = combineFunction(function(g_soundPlayer, channel, title, isOnlineStream)
		local disclaimer = (isOnlineStream and "ONLINE STREAM") or "";
		main:updateHud(channel, title, disclaimer);
	end, g_soundPlayer.onChange);

	-- attach to HUD (hope radio only)
	-- when radio start playing or channel changed
	--[[
	HUD.addTopNotification = combineFunction(function(context, channel, title, disclaimer, source, timeout)
		main:updateHud(channel, title, disclaimer);
	end, HUD.addTopNotification);
	]]
end

-- unused, we dont have player action events to register
function main:registerPlayerActionEvents()
end

-- you have to register the action events every time the player enter, switch or leave the vehicle.
-- for us it is made by the FSBaseMission.registerActionEvents, which is automatically called by the engine.
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

	g_inputBinding:registerActionEvent(InputAction.RADIO_VOLUME_UP,   self, self.onRadioVolumeUpAction,   false, false, true, true);
	g_inputBinding:registerActionEvent(InputAction.RADIO_VOLUME_DOWN, self, self.onRadioVolumeDownAction, false, false, true, true);
end

function main:updateHud(channel, title, disclaimer)
	hud.model.channel    = channel;
	hud.model.title      = title;
	hud.model.disclaimer = disclaimer;
	hud.model.volume     = g_gameSettings.radioVolume;
	hud:updateView();

	-- show the hud without adjust the volume
	main:adjustRadioVolume();
end

function main:adjustRadioVolume(increase)
	-- show the radio volume hud
	data.showExpires = g_time + data.showTimeout;

	-- dont adjust but show the HUD
	if (increase == nil) then
		return;
	end

	-- radio should be turned on
	if (g_currentMission:getIsRadioPlaying() ~= true) then
		return;
	end

	data.time2 = g_time;

	-- diff in milliseconds
	local delta = (data.time2 - data.time1);

	-- adjust every 10 ms
	if (delta < 10) then
		return;
	end

	data.time1 = data.time2;

	-- we change the volume by 1 only for each call
	-- example from 74% to 75%
	local offset = (increase and 0.01) or -0.01;
	local volume = (g_gameSettings.radioVolume + offset);

	volume = math.min(1, math.max(0, volume));
	volume = MathUtil.round(volume, 2);

	if (volume ~= g_gameSettings.radioVolume) then
		g_currentMission:setRadioVolume(volume);

		hud.model.volume = volume;
		hud:updateView();
	end
end

function main:onRadioVolumeUpAction(actionName, keyState, callbackState)
	-- key pressed
	if (keyState == 1) then
		self:adjustRadioVolume(true);
	end
end

function main:onRadioVolumeDownAction(actionName, keyState, callbackState)
	-- key pressed
	if (keyState == 1) then
		self:adjustRadioVolume(false);
	end
end

-- draw on game loop (each frame)
function main:draw()
	-- dont show the volume if not changed
	if (data.showExpires < g_time) then
		return;
	end

	hud:draw();
end
