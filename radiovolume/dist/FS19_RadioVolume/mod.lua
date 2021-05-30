--[[
	FS19_RadioVolume
	This file is the released version.
	
	*******************************************
	default radio volume input bindings (this mod)
	NUMPAD +  	volume up
	NUMPAD -  	volume down

	*******************************************
	default input bindings for radio (game default)
	F4 			radio prev
	F5 			radio on/off
	F6 			radio next
]]

-- global shared
FS19_RadioVolume = { lib  = {} };

-- load source files
source(g_currentModDirectory .. "lib/hud.lua");
source(g_currentModDirectory .. "lib/logging.lua");
source(g_currentModDirectory .. "lib/main.lua");

local mod = {
	name    = "FS19_RadioVolume",
	version = "1.21.5.30",
	dir     = g_currentModDirectory,
	modName = g_currentModName
};

-- import shortcuts
local logging = FS19_RadioVolume.lib.logging;
local main    = FS19_RadioVolume.lib.main;

-- setup the mod, or whatever
function mod:onLoadMap()
	-- setup libs
	for _, lib in pairs(FS19_RadioVolume.lib) do
		if (type(lib.load) == "function") then
			lib:load(mod);
		end
	end
end

-- draw on game loop (each frame)
function mod:draw()
	main:draw();
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

		mod:onLoadMap();
	end
});
