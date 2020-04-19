--[[
	FS19_Uhrzeit
	This file is the released version.
]]

local xPixel = 1 / g_screenWidth;
local yPixel = 1 / g_screenHeight;

local mod = {
	name = "FS19_Uhrzeit",
	version = "1.20.4.19",
	dir = g_currentModDirectory,
	modName = g_currentModName,
	data = {
		fontSize = HUDElement.TEXT_SIZE.DEFAULT_TEXT * yPixel,
		fps = 0,
		drawTime = 0,
		drawCounter = 0,
		-- background
		overlay = nil,
		padding = {left = 2 * xPixel, top = 2 * yPixel, right = 2 * xPixel, bottom = 2 * yPixel},
		-- see IngameMap.getBackgroundPosition
		-- https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=97&class=10216
		position = {x = g_safeFrameOffsetX, y = g_safeFrameOffsetY},
		-- the size of our image (2^n)
		size = {w = 128 * xPixel, h = 128 * yPixel},
		backgroundImage = g_currentModDirectory .. "overlay.png",
		backgroundColor =  {0, 0, 0, 0.3}
	}
};

-- when the mission starts
function mod:onStartMission()
	-- setup overlay (background)
	self.data.overlay = Overlay:new(self.data.backgroundImage, self.data.position.x, self.data.position.y, self.data.size.w, self.data.size.h);
	self.data.overlay:setColor(unpack(self.data.backgroundColor));
end

-- update FPS
function mod:updateFPS()
	local diff = g_time - self.data.drawTime;
	local rate = 1000; -- we calculate the value every 1000 ms

	self.data.drawCounter = self.data.drawCounter + 1;

	if (diff > rate) then
		-- normalize time diff to 1s
		self.data.fps = math.floor(self.data.drawCounter / diff * 1000 + 0.5);
		self.data.drawTime = g_time;
		self.data.drawCounter = 0;
	end
end

-- render background
function mod:renderOverlay(displayString)
	-- update size
	self.data.overlay.width = getTextWidth(self.data.fontSize, displayString) + self.data.padding.left + self.data.padding.right;
	self.data.overlay.height = self.data.fontSize + self.data.padding.top + self.data.padding.bottom;
	self.data.overlay.offsetY = -self.data.overlay.height;
	self.data.overlay:render();
end

-- render text
function mod:renderText(displayString)
	setTextBold(false);
	setTextColor(unpack(HUDPopupMessage.COLOR.TEXT));
	setTextAlignment(RenderText.ALIGN_LEFT);

	-- y is not correct but gives the best result
	local x = self.data.overlay.x + self.data.padding.left;
	local y = self.data.overlay.y - self.data.fontSize;
	renderText(x, y, self.data.fontSize, displayString);
end

-- draw on game loop (each frame)
function mod:draw()
	self:updateFPS();

	local displayString = string.format("%s FPS %d", getDate("%d.%m.%Y %H:%M:%S"), self.data.fps);
	--local displayString = string.format("%s FPS %d", getDate("%x %X"), self.data.fps);

	self:renderOverlay(displayString);
	self:renderText(displayString);
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
