--[[
	HUD
]]

-- lib
local hud = {
	model = {
		channel    = "",
		title      = "",
		disclaimer = "",
		volume     = 0
	}
};

local controller     = nil;
local guiXml         = g_currentModDirectory .. "assets/hud_gui.xml";
local guiProfilesXml = g_currentModDirectory .. "assets/hud_profiles.xml";

-- export
FS19_RadioVolume.lib.hud = hud;

-- import shortcuts
local logging;

-- required
function hud:load(mod)
	-- refs
	logging = FS19_RadioVolume.lib.logging;

	-- controller is GuiElement
	controller = FrameElement:new();

	-- Register a collection of control IDs for direct access in GUI views.
	controller:registerControls({ "textChannel", "textTitle", "textDisclaimer", "textVolume", "currentValue" });

	-- load from template
	g_gui:loadProfiles(guiProfilesXml);
	g_gui:loadGui(guiXml, "FS19_RadioVolume_hud", controller);
end

-- should be called by the mod or whatever
function hud:draw()
	if (controller.visible == true) then
		controller:draw();
	end
end

local function validateModel(model)
	model.channel    = model.channel    or "";
	model.title      = model.title      or "";
	model.disclaimer = model.disclaimer or "";
	model.volume     = math.min(1, math.max(0, model.volume));
end

function hud:updateView()
	validateModel(self.model);

	controller.textChannel:setText(self.model.channel);
	controller.textTitle:setText(self.model.title);
	controller.textDisclaimer:setText(self.model.disclaimer);
	controller.textVolume:setText(string.format("Volume %s%%", math.floor(self.model.volume * 100)));

	-- change width (progress bar value)
	controller.currentValue.size[1] = self.model.volume * controller.currentValue.parent.size[1];
end

