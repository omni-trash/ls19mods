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
		fps = 0,
		drawTime = 0,
		drawCounter = 0,
		ui = {
			fontSize = HUDElement.TEXT_SIZE.DEFAULT_TEXT * yPixel,
			textColor = HUDPopupMessage.COLOR.TEXT,
			background = {
				overlay = nil,
				padding = {left = 2 * xPixel, top = 2 * yPixel, right = 2 * xPixel, bottom = 2 * yPixel},
				-- see IngameMap.getBackgroundPosition
				-- https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=97&class=10216
				position = {x = g_safeFrameOffsetX, y = g_safeFrameOffsetY},
				-- the size of our image (2^n)
				size = {w = 128 * xPixel, h = 128 * yPixel},
				image = g_currentModDirectory .. "overlay.png",
				color =  {0, 0, 0, 0.3}
			}
		},
	}
};

-- when the mission starts
function mod:onStartMission()
	-- setup overlay (background)
	local background = self.data.ui.background;

	background.overlay = Overlay:new(background.image, background.position.x, background.position.y, background.size.w, background.size.h);
	background.overlay:setColor(unpack(background.color));
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
	local background = self.data.ui.background;

	background.size.w = getTextWidth(self.data.ui.fontSize, displayString) + background.padding.left + background.padding.right;
	background.size.h = self.data.ui.fontSize + background.padding.top + background.padding.bottom;

	-- apply and render
	background.overlay.width = background.size.w;
	background.overlay.height = background.size.h;
	background.overlay.offsetY = -background.overlay.height;
	background.overlay:render();
end

-- render text
function mod:renderText(displayString)
	setTextBold(false);
	setTextColor(unpack(self.data.ui.textColor));
	setTextAlignment(RenderText.ALIGN_LEFT);

	local background = self.data.ui.background;

	-- y is not correct but gives the best result
	local x = background.position.x + background.padding.left;
	local y = background.position.y - self.data.ui.fontSize;
	renderText(x, y, self.data.ui.fontSize, displayString);
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
