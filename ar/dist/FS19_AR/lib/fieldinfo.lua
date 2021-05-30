--[[
	FIELDINFO
]]

-- lib
local fieldinfo = {};
local cache     = {};

-- when the field status is outdated
local UPDATE_INTERVAL_MILLISECONDS = (60 * 1000);
local DAY_INTERVAL_MILLISECONDS    = (24 * 60 * 60 * 1000);

-- export
FS19_AR.lib.fieldinfo = fieldinfo;

-- import shortcuts
local logging;
local hud;

-- required
function fieldinfo:load(mod)
	-- refs
	logging = FS19_AR.lib.logging;
	hud     = FS19_AR.lib.hud;

	-- register colors
	-- blue
	hud.COLOR.LIME      = {  81 / 255, 212 / 255, 173 / 255, 1 };
	-- red
	hud.COLOR.PLOWING   = { 206 / 255,  64 / 255,  64 / 255, 1 };
	-- violet
	hud.COLOR.WEEDS     = { 163 / 255,  73 / 255, 164 / 255, 1 };

	-- register color names
	hud.COLORNAME.LIME    = "LIME";
	hud.COLORNAME.PLOWING = "PLOWING";
	hud.COLORNAME.WEEDS   = "WEEDS";
end

-- internal
local function createFieldStatus(field)
	return {
		-- internal fields
		field = field,
		nextUpdate = 0,
		-- public data
		data = {
			lime            = 0, -- [0, 1]
			plowing         = 0, -- [0, 1]
			weed            = 0, -- [0, 1]
			fertilization   = 0, -- [0, 1]
			limeRequired    = false,
			plowingRequired = false,			
			text            = {}
		}
	};
end

-- internal
-- see FieldInfoDisplay:setFruitType
local function updateFruitType(fieldStatus, data)
	local fruitIndex = 0;
	local fruitState = 0;
	local maxPixels  = 0;

	for fruitDescIndex, state in pairs(data.fruits) do
		if data.fruitPixels[fruitDescIndex] > maxPixels then
			maxPixels  = data.fruitPixels[fruitDescIndex];
			fruitIndex = fruitDescIndex;
			fruitState = state;
		end
	end

	if  (fruitTypeIndex == 0) then
		-- nothing
		return;
	end

	local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex);
	
	if (not fruitType) then
		-- unknown
		return;
	end

	fieldStatus.data.fruitName = fruitType.fillType.title;

	local witheredState = fruitType.maxHarvestingGrowthState + 1;

	if fruitType.maxPreparingGrowthState >= 0 then
		witheredState = fruitType.maxPreparingGrowthState + 1;
	end

	local maxGrowingState = fruitType.minHarvestingGrowthState - 1;

	if fruitType.minPreparingGrowthState >= 0 then
		maxGrowingState = math.min(maxGrowingState, fruitType.minPreparingGrowthState - 1);
	end

	local value;

	if fruitState == fruitType.cutState + 1 then
		-- Abgeerntet
		value = g_i18n:getText(FieldInfoDisplay.L10N_SYMBOL.GROWTH_STATE_CUT);
		table.insert(fieldStatus.data.text, { value = value, color = hud.COLORNAME.DEFAULT });
	elseif fruitState == witheredState + 1 then
		-- Verdorrt/Verfault
		value = g_i18n:getText(FieldInfoDisplay.L10N_SYMBOL.GROWTH_STATE_WITHERED);
		table.insert(fieldStatus.data.text, { value = value, color = hud.COLORNAME.DEFAULT });
	elseif fruitState > 0 and fruitState <= maxGrowingState + 1 then
		-- Im Wachstum
		value = g_i18n:getText(FieldInfoDisplay.L10N_SYMBOL.GROWTH_STATE_GROWING);
		table.insert(fieldStatus.data.text, { value = value, color = hud.COLORNAME.DEFAULT });
	elseif fruitType.minPreparingGrowthState >= 0 and fruitState >= fruitType.minPreparingGrowthState and fruitState <= fruitType.maxPreparingGrowthState + 1 then
		-- Kraut entfernen
		value = g_i18n:getText(FieldInfoDisplay.L10N_SYMBOL.GROWTH_STATE_NEED_PREP)
		table.insert(fieldStatus.data.text, { value = value, color = hud.COLORNAME.DEFAULT });
	elseif fruitState >= fruitType.minHarvestingGrowthState + 1 and fruitState <= fruitType.maxHarvestingGrowthState + 1 then
		-- Erntereif
		value = g_i18n:getText(FieldInfoDisplay.L10N_SYMBOL.GROWTH_STATE_CAN_HARVEST);
		table.insert(fieldStatus.data.text, { value = value, color = hud.COLORNAME.DEFAULT });
	end
end

-- internal
-- see FieldInfoDisplay:onFieldDataUpdateFinished
local function updateFieldStatus(fieldStatus)

	local callback = {
		onFieldDataUpdateFinished = function(self, data)
			fieldStatus.nextUpdate = g_time + UPDATE_INTERVAL_MILLISECONDS;

			if (data == nil) then
				return;
			end

			local missionInfo = g_currentMission.missionInfo;
			local text = {};

			-- kalken
			local limeRequired = (data.needsLimeFactor > FieldInfoDisplay.LIME_REQUIRED_THRESHOLD);

			if (missionInfo.limeRequired and limeRequired) then
				local value = g_i18n:getText(FieldInfoDisplay.L10N_SYMBOL.NEED_LIME);
				table.insert(text, { value = value, color = hud.COLORNAME.LIME });
			end

			-- pflügen
			local plowingRequired = (data.needsPlowFactor > FieldInfoDisplay.PLOWING_REQUIRED_THRESHOLD);

			if (missionInfo.plowingRequiredEnabled and plowingRequired) then			
				local value = g_i18n:getText(FieldInfoDisplay.L10N_SYMBOL.NEED_PLOWING);
				table.insert(text, { value = value, color = hud.COLORNAME.PLOWING });
			end

			-- unkraut
			if (missionInfo.weedsEnabled and data.weedFactor > 0) then
				local label = g_i18n:getText(FieldInfoDisplay.L10N_SYMBOL.WEED);
				local value = string.format("%s %d %%", label, data.weedFactor * 100);
				table.insert(text, { value = value, color = hud.COLORNAME.WEEDS });
			end

			-- dünger
			if (data.fertilizerFactor > 0) then
				local label = g_i18n:getText(FieldInfoDisplay.L10N_SYMBOL.FERTILIZATION);
				local value = string.format("%s %d %%", label, data.fertilizerFactor * 100);
				table.insert(text, { value = value, color = "DEFAULT" });
			end

			-- apply values
			fieldStatus.data.lime            = math.max(0, math.min(1, data.needsLimeFactor / FieldInfoDisplay.LIME_REQUIRED_THRESHOLD));
			fieldStatus.data.plowing         = math.max(0, math.min(1, data.needsPlowFactor / FieldInfoDisplay.PLOWING_REQUIRED_THRESHOLD));
			fieldStatus.data.weed            = math.max(0, math.min(1, data.weedFactor));
			fieldStatus.data.fertilization   = math.max(0, math.min(1, data.fertilizerFactor));
			fieldStatus.data.limeRequired    = limeRequired;
			fieldStatus.data.plowingRequired = plowingRequired;
			fieldStatus.data.text            = text;
			fieldStatus.data.fruitName       = nil;

			updateFruitType(fieldStatus, data);
		end
	};

	-- middle center of field
	local posX = fieldStatus.field.posX;
	local posZ = fieldStatus.field.posZ;
	local size = 10; -- meters

	-- point (x/z)
	local startX  = posX - (size / 2);
	local startZ  = posZ - (size / 2);

	-- point (x/z)
	local heightX = startX;
	local heightZ = startZ + size;

	-- point (x/z)
	local widthX  = startX + size;
	local widthZ  = startZ;

	FSDensityMapUtil.getFieldStatusAsync(startX, startZ, heightX, heightZ, widthX, widthZ, callback.onFieldDataUpdateFinished, callback);
end

-- returns informations about the field.
-- the status for every requested field is cached 
-- and would be updated every minute. 
-- the informations contains is plowing required,
-- how much weeds and so on. we are check the
-- center of the field. we are do not check every
-- field partition.
function fieldinfo:getFieldStatusData(field)
	local fieldStatus = cache[field.fieldId];

	if (fieldStatus == nil) then
		fieldStatus = createFieldStatus(field);
		cache[field.fieldId] = fieldStatus;
	end

	if (fieldStatus.nextUpdate < g_time) then
		-- prevent next call of getFieldStatusData
		fieldStatus.nextUpdate = g_time + DAY_INTERVAL_MILLISECONDS;
		updateFieldStatus(fieldStatus);
	end

	return fieldStatus.data;
end
