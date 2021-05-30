--[[
	CONFIG
]]

-- lib
local config     = {};
local rootName   = "Settings";
local objectName = nil;
local fileName   = nil;

-- export
FS19_AR.lib.config = config;

-- import shortcuts
local logging;
local utils;

-- supported types
local xmlWriter = {
	["string"]  = setXMLString,
	["boolean"] = setXMLBool,
	["number"]  = function(file, path, value)
		if math.floor(value) == value then
			setXMLInt(file, path, value);
		else
			setXMLFloat(file, path, value);
		end
	end
};

-- supported types
local xmlReader = {
	["string"]  = getXMLString,
	["boolean"] = getXMLBool,
	["number"]  = getXMLFloat
};

function config:load(mod)
	-- refs
	logging = FS19_AR.lib.logging;
	utils   = FS19_AR.lib.utils;

	-- for XML API
	objectName = mod.name;
	fileName   = "Mod_" .. config.escapeName(mod.name) .. ".xml";
end

-- filename is "Mod_<mod.name>.xml"
function config.getXmlFile()
	local xmlFile = { filespec = g_currentMission.missionInfo.savegameDirectory .. "/" .. fileName };

	if not fileExists(xmlFile.filespec) then
		xmlFile.file = createXMLFile(objectName, xmlFile.filespec, rootName);
	else
		xmlFile.file = loadXMLFile(objectName, xmlFile.filespec);
	end

	return xmlFile;
end

-- escape tagname (XML)
function config.escapeName(name)
	return tostring(name):gsub("[^a-zA-Z0-9_]", function(v)
		return string.format("-0x%02X-", string.byte(v, 1, 2));
	end);
end

-- read settings
function config.loadSettings(name, settings)
	local xmlFile = config.getXmlFile();

	if not xmlFile.file then
		logging.trace("file not found: " .. tostring(config.filespec));
		return;
	end

	-- base attribute path
	local root = string.format("%s.%s", rootName, config.escapeName(name or "Default"));

	utils.traverseTable(root, settings, function(data)
		local typeName = type(data.value);
		local readXml  = xmlReader[typeName];

		if not readXml then
			return;
		end

		local path  = string.format("%s.%s_%s", data.entry.path, typeName, config.escapeName(data.key));
		local value = readXml(xmlFile.file, path);

		if value ~= nil then
			data.entry.object[data.key] = value;
		end
	end);
end

-- write settings
function config.saveSettings(name, settings)
	local xmlFile = config.getXmlFile();

	if not xmlFile.file then
		logging.trace("file not found: " .. tostring(xmlFile.filespec));
		return;
	end

	-- base attribute path
	local root = string.format("%s.%s", rootName, config.escapeName(name or "Default"));

	utils.traverseTable(root, settings, function(data)
		local typeName = type(data.value);
		local writeXml = xmlWriter[typeName];

		if not writeXml then
			return;
		end

		local path   = string.format("%s.%s_%s", data.entry.path, typeName, config.escapeName(data.key));
		local result = writeXml(xmlFile.file, path, data.value);
	end);

	saveXMLFile(xmlFile.file);
end
