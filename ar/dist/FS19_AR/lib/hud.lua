--[[
	HUD
	
	9 slots are supported

	initial position
	+-------+ +-------+ +-------+
	|   1   | |   2   | |   3   |
	+-------+ +-------+ +-------+
	+-------+ +-------+ +-------+
	|   4   | |   5   | |   6   |
	+-------+ +-------+ +-------+
	+-------+ +-------+ +-------+
	|   7   | |   8   | |   9   |
	+-------+ +-------+ +-------+

	internal panel name per slot
	+-------+ +-------+ +-------+
	|  S1   | |  S2   | |  S3   |
	+-------+ +-------+ +-------+
	+-------+ +-------+ +-------+
	|  S4   | |  S5   | |  S6   |
	+-------+ +-------+ +-------+
	+-------+ +-------+ +-------+
	|  S7   | |  S8   | |  S9   |
	+-------+ +-------+ +-------+

	panel layout
	+---------------------------+
	| TITLE                     |
	| TEXT1                     |
	| TEXT2                     |
	| TEXT3                     |
	| TEXT4                     |
	+---------------------------+

	*****************************************************************************************

	= Screen =

	       g_screenWidth  
		         |
		+--------+--------+
		|                 |


	   0,1               1,1
		+-----------------+           -+
		|                 | \          |
		|                 |  \         |
		|                 |   fovY     +- g_screenHeight
		|                 |  /         |
		|                 | /          |
		+-----------------+           -+
	   0,0               1,0

	local radFovY = getFovY(getCamera());
	local degFovY = math.deg(radFovY);

	local radFovX = math.atan(math.tan(radFovY * 0.5) * g_screenAspectRatio) * 2;
	local degFovX = math.deg(radFovX);


	= Viewport =

				0.5
		+--------+--------+
		|        |        |
		|        |        |
	-0.5+--------+--------+ 0.5
		|        |        |
		|        |        |
		+--------+--------+
	           -0.5


	= Right Triangle =

		  a
	    C-----B
		|    /
		|   /
       b|  /c
	    |w/
		|/
		A

	sin(w) = a / c
	cos(w) = b / c
	tan(w) = a / b

	sec(w) = c / b = 1 / cos(a)
	cot(w) = b / a = 1 / tan(w)
	csc(w) = c / a = 1 / sin(a)


	= Bearing (angle, yaw) =


                0°
				|
                |
				|
	  270° -----+----- 90°
				|
				|
				|
			   180°
 

	= Pitch =

	   up
	   +90°
		|
		|
		|
		|
		+--------> 0° straight on
		|
		|
		|
	   -90°
	   down
]]

-- lib
local hud = {
	COLOR = {
		-- white
		DEFAULT   = FieldInfoDisplay.COLOR.TEXT_DEFAULT,
		-- orange yellow
		HIGHLIGHT = FieldInfoDisplay.COLOR.TEXT_HIGHLIGHT
	},
	COLORNAME = {
		DEFAULT   = "DEFAULT",
		HIGHLIGHT = "HIGHLIGHT"
	}
};

-- export
FS19_AR.lib.hud = hud;

-- import shortcuts
local logging;
local utils;

-- base
local MAXSLOT        = 9;
local slots          = {};
local controller     = nil;
local guiXml         = g_currentModDirectory .. "assets/hud_gui.xml";
local guiProfilesXml = g_currentModDirectory .. "assets/hud_profiles.xml";

-- pixels
local xPixel  = 1 / g_screenWidth;
local yPixel  = 1 / g_screenHeight;

-- panel size (see FS19_AR_hud_panel_base)
local panelW  = 220;
local panelH  = 116;

-- space around
local marginX = (100 + panelW / 2) * xPixel;
local marginY = (100 + panelH / 2) * yPixel;

local cols    = math.floor((1 - 2 * marginX) / (panelW * xPixel));
local rows    = math.floor((1 - 2 * marginY) / (panelH * yPixel));

local cellW   = 1 / cols;
local cellH   = 1 / rows;

-- note viewport
local maxXPos =  0.5 - marginX;
local maxYPos =  0.5 - marginY;
local minXPos = -0.5 + marginX;
local minYPos = -0.5 + marginY;

-- for each root node (motion)
-- lowpass filter etc.
local settings = {};

-- internal
-- low pass filters to prevent "flickering" while the panel is moving
local function createLowPassFilter(alpha, value)
	return {
		alpha   = alpha,
		value   = value or 0,
		lowPass = function(self, input)
			self.value = self.value + self.alpha * (input - self.value);
			return self.value;
		end
	};
end

-- internal
local function createSlot()
	return {
		title    = { value = "", color = nil },
		text     = {},
		visible  = false,
		position = { x = 0, y = 0 },
		rootNode = nil
	};
end

local function updateText(textElement, text)
	local value = (text and text.value) or "";
	local name  = (text and text.color) or hud.COLORNAME.DEFAULT;
	local color = hud.COLOR[name] or hud.COLOR.DEFAULT;

	textElement:setText(value);
	textElement.textColor = color;
end

-- internal
local function updatePanel(slot, number, grid)
	-- target
	local panel = controller["panel_S" .. number];

	panel:setVisible(slot.visible);

	if (slot.visible ~= true) then
		return;
	end

	----------------------------------------------------------
	-- Text
	----------------------------------------------------------

	-- we are paging all 5s through the messages, so we
	-- can show all messages, even we have 4 text elements.
	local count = #slot.text;
	local pages = math.floor((count - 1) / 4) + 1;
	local page  = math.floor(g_time / 5000) % pages;
	local index = page * 4;

	updateText(controller["title_S" .. number], slot.title);
	updateText(controller["text1_S" .. number], slot.text[index + 1]);
	updateText(controller["text2_S" .. number], slot.text[index + 2]);
	updateText(controller["text3_S" .. number], slot.text[index + 3]);
	updateText(controller["text4_S" .. number], slot.text[index + 4]);

	----------------------------------------------------------
	-- Position
	----------------------------------------------------------

	-- space around	(simple cut)
	--local x = math.min(maxXPos, math.max(minXPos, slot.position.x));
	--local y = math.min(maxYPos, math.max(minYPos, slot.position.y));

	local w = math.atan2(slot.position.x, slot.position.y);
	local x = slot.position.x;
	local y = slot.position.y;

	if x > maxXPos then
		local x1 = x - maxXPos;
		local y1 = x1 / math.tan(w);
		
		x = x - x1;
		y = y - y1;
	end

	if x < minXPos then
		local x1 = x - minXPos;
		local y1 = x1 / math.tan(w);

		x = x - x1;
		y = y - y1;
	end
	
	if y > maxYPos then
		local y1 = y - maxYPos;
		local x1 = y1 * math.tan(w);

		x = x - x1;
		y = y - y1;
	end

	if y < minYPos then
		local y1 = y - minYPos;
		local x1 = y1 * math.tan(w);

		x = x - x1;
		y = y - y1;
	end

	-- use a low pass filter
	local key     = getCamera() .. "#" .. (slot.rootNode or number);
	local options = (settings[key] or {
		lastUpdate = g_time,
		filter = {
			x = createLowPassFilter(0.02, x),
			y = createLowPassFilter(0.02, y)
		}
	});

	settings[key] = options;

	if (options.lastUpdate + 500 < g_time) then
		-- reset filter
		options.filter.x.value = x;
		options.filter.y.value = y;
	else
		-- apply filter
		x = options.filter.x:lowPass(x);
		y = options.filter.y:lowPass(y);
	end

	options.lastUpdate = g_time;

	panel:setPosition(x, y);

	-- must be set to true by next update
	slot.visible = false;
end

-- required
function hud:load(mod)
	-- refs
	logging = FS19_AR.lib.logging;
	utils   = FS19_AR.lib.utils;

	-- controller is GuiElement
	controller = FrameElement:new();
	
	-- Register a collection of control IDs for direct access in GUI views.
	local controls = {};

	-- build all control IDs
	for number = 1,MAXSLOT,1 do
		table.insert(controls, "panel_S" .. number);
		table.insert(controls, "title_S" .. number);
		table.insert(controls, "text1_S" .. number);
		table.insert(controls, "text2_S" .. number);
		table.insert(controls, "text3_S" .. number);
		table.insert(controls, "text4_S" .. number);

		-- ok let us create the slot
		self:getSlot(number);
	end

	controller:registerControls(controls);

	-- load from template
	g_gui:loadProfiles(guiProfilesXml);
	g_gui:loadGui(guiXml, "FS19_AR_hud", controller);
end

-- should be called by the mod or whatever
function hud:draw()
	if (controller.visible == true) then
		controller:draw();
	end
end

function hud:getSlot(number)
	local slot = (slots[number] or createSlot());
	slots[number] = slot;
	return slot;
end

function hud:update(dt)
	local grid = {};

	for number = 1,MAXSLOT,1 do
		updatePanel(self:getSlot(number), number, grid);
	end
end
