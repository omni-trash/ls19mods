--[[
	FS19_AR
	This file is the released version.
	
	*******************************************
	default input binding
	NUMPAD *  	on/off
]]

-- global shared
FS19_AR = { lib  = {} };

-- load source files
source(g_currentModDirectory .. "lib/config.lua");
source(g_currentModDirectory .. "lib/fieldinfo.lua");
source(g_currentModDirectory .. "lib/debugging.lua");
source(g_currentModDirectory .. "lib/detector.lua");
source(g_currentModDirectory .. "lib/hud.lua");
source(g_currentModDirectory .. "lib/logging.lua");
source(g_currentModDirectory .. "lib/main.lua");
source(g_currentModDirectory .. "lib/scanner.lua");
source(g_currentModDirectory .. "lib/utils.lua");

local mod = {
	name    = "FS19_AR",
	version = "1.21.5.30",
	dir     = g_currentModDirectory,
	modName = g_currentModName,
	-- error detection to prevent calls of draw or update on error
	enabled = true
};

-- import shortcuts
local logging = FS19_AR.lib.logging;
local main    = FS19_AR.lib.main;

-- setup the mod, or whatever
function mod:onLoadMap()
	-- setup libs
	for _, lib in pairs(FS19_AR.lib) do
		if (type(lib.load) == "function") then
			lib:load(mod);
		end
	end

	-- setup libs
	for _, lib in pairs(FS19_AR.lib) do
		if (type(lib.loaded) == "function") then
			lib:loaded();
		end
	end
end

-- draw on game loop (each frame)
function mod:draw()
	if (self.enabled ~= true) then
		return;
	end

	self.enabled = false;
	main:draw();
	self.enabled = true;
end

function mod:update(dt)
	if (self.enabled ~= true) then
		return;
	end

	self.enabled = false;
	main:update(dt);
	self.enabled = true;
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

		-- mod update
		self.update = function(self, dt)
			mod:update(dt);
		end

		mod:onLoadMap();
	end
});
