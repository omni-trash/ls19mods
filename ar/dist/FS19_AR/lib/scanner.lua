--[[
	SCANNER
]]

-- lib
local scanner = {
	scan = {
		fields      = true,
		husbandries = true,
		vehicles    = false
	}
};

-- scan frequency
local NEXTSCAN_INTERVAL_MILLISECONDS = 1000;
local nextScanTime = 0;
local lastCameraId = 0;

-- local cache
local cache = {
	results      = {},
	vehicleNames = {}
};

-- export
FS19_AR.lib.scanner = scanner;

-- import shortcuts
local logging;
local detector;
local fieldinfo;
local utils;
local hud;

-- required
function scanner:load(mod)
	-- refs
	logging   = FS19_AR.lib.logging;
	detector  = FS19_AR.lib.detector;
	fieldinfo = FS19_AR.lib.fieldinfo;
	utils     = FS19_AR.lib.utils;
	hud       = FS19_AR.lib.hud;
end

function scanner:update(dt)
	local cameraId   = getCamera();
	local scanResult = cache.results[cameraId];

	if (nextScanTime > g_time and lastCameraId == cameraId) then
		if scanResult then
			-- update position, if needed
			table.foreach(scanResult ,function(index, info)
				-- fields or husbandries have a fix position, and the center is calculated by GIANTS,
				-- so we use these values for x, y, z, to have the correct values.
				-- the position of movable elements, like vehicles, are requested by getWorldTranslation.
				-- i think these positions are not the mass center points, but ok.
				if info.movable then
					info.worldPosition = utils.getWorldPosition(info.rootNode);
				end
			end);
		end

		return;
	end

	if (lastCameraId == cameraId) then
		scanResult = {};
		
		if self.scan.fields == true then
			table.foreach(self:scanFields(), function(k, v) 
				table.insert(scanResult, v) 
			end);
		end
		
		if self.scan.husbandries == true then
			table.foreach(self:scanHusbandries(), function(k, v) 
				table.insert(scanResult, v) 
			end);
		end
		
		if self.scan.vehicles == true then
			table.foreach(self:scanVehicles(), function(k, v) 
				table.insert(scanResult, v) 
			end);
		end
	end

	cache.results[cameraId] = scanResult;
	nextScanTime = g_time + NEXTSCAN_INTERVAL_MILLISECONDS;
	lastCameraId = cameraId;
end

function scanner:getScanResult()
	return cache.results[lastCameraId];
end

-- get fields in range and put all these informations into the results
function scanner:scanFields()
	-- 10 meters
	local fieldsInRange = detector.getFieldsInRange(10);
	local results = {};

	for _, fieldInRage in pairs(fieldsInRange) do
		local info = {
			profile       = "field",
			field         = fieldInRage.field,
			distance      = fieldInRage.distance,
			worldPosition = fieldInRage.worldPosition,
			rootNode      = fieldInRage.field.rootNode,
			title         = "Feld " .. fieldInRage.field.mapHotspot.fullViewName,
			text          = {}
		};

		local fieldStatus = fieldinfo:getFieldStatusData(fieldInRage.field);
		local fruitName   = fieldStatus.fruitName;

		if (not fruitName and info.field.fruitType) then
			fruitName = g_fruitTypeManager.fruitTypeIndexToFillType[info.field.fruitType].title;
		end

		if (fruitName ~= nil) then
			table.insert(info.text, { value = fruitName, color = hud.COLORNAME.DEFAULT });
		end

		for _, text in pairs(fieldStatus.text) do
			table.insert(info.text, text);
		end

		-- check we have some text to show
		if (#info.text > 0) then
			table.insert(results, info);
		end
	end

	return results;
end

-- get husbandries in range and put all these informations into the results
function scanner:scanHusbandries()
	-- 50 meters
	local husbandriesInRange = detector.getHusbandriesInRange(50);
	local results = {};

	for _, husbandryInRange in pairs(husbandriesInRange) do
		local info = {
			profile       = "husbandry",
			husbandry     = husbandryInRange.husbandry,
			distance      = husbandryInRange.distance,
			worldPosition = husbandryInRange.worldPosition,
			rootNode      = husbandryInRange.husbandry.nodeId,
			title         = husbandryInRange.husbandry.mapHotspots[1].fullViewName,
			text          = {}
		};

		-- from animals module
		local animals = info.husbandry.modulesByName.animals;

		if animals then
			local key   = string.format("ui_statisticView_%s", string.lower(animals:getAnimalType()));
			local label = g_i18n.texts[key] or g_i18n.texts[ui_statisticViewAnimals] or "Tiere";
			local value = string.format("%s %d/%d", tostring(label), info.husbandry:getNumOfAnimals(), info.husbandry:getMaxNumAnimals());

			local reproduction = false;

			-- can have different animals (color, gender)
			for fillTypeIndex, animal in pairs(animals:getTypedAnimals()) do
				-- lets check the animal
				-- note: can be failed if animal was sold during the loop
				if (animal and animal[1] and animal[1].subType.breeding.birthRatePerDay > 0) then
					reproduction = true;
					break;
				end
			end

			-- highlight when we have reproduction cycles only
			local p     = info.husbandry:getNumOfAnimals() / info.husbandry:getMaxNumAnimals();
			local color = ((p < 0.9 or not reproduction) and hud.COLORNAME.DEFAULT) or hud.COLORNAME.DEFAULT;

			table.insert(info.text, { value = value, color = color });
		end

		-- from foodSpillage module
		local foodSpillage = info.husbandry.modulesByName.foodSpillage;
		
		if foodSpillage then
			local foodSpillageFactor = foodSpillage:getSpillageFactor();
			local label = g_i18n.texts.statistic_cleanliness;
			local value = string.format("%s %d%%", tostring(label), MathUtil.round(foodSpillageFactor * 100));

			-- highlighting
			local p     = foodSpillageFactor;
			local color = (p > 0.9 and hud.COLORNAME.DEFAULT) or hud.COLORNAME.HIGHLIGHT;

			table.insert(info.text, { value = value, color = color });			
		end

		-- from some known modules with fillLevel and capacity (underflow)
		local modules = {
			info.husbandry.modulesByName.straw,
			info.husbandry.modulesByName.water
		};

		for _, _module in pairs(modules) do
			if _module then
				for _, fti in pairs(_module:getFilltypeInfos()) do
					local label   = (fti.foodGroup or fti.fillType).title or "no title";
					local percent = math.floor(fti.fillLevel * 100 / fti.capacity);
					local value   = string.format("%s %d%%", label, percent);

					-- highlighting
					local p     = fti.fillLevel / fti.capacity;
					local color = (p > 0.9 and hud.COLORNAME.DEFAULT) or hud.COLORNAME.HIGHLIGHT;

					table.insert(info.text, { value = value, color = color });				
				end
			end
		end

		-- from some known modules with fillLevel and capacity (overflow)
		local modules = {
			info.husbandry.modulesByName.milk,
			info.husbandry.modulesByName.liquidManure,
			info.husbandry.modulesByName.manure
		};

		for _, _module in pairs(modules) do
			if _module then
				for _, fti in pairs(_module:getFilltypeInfos()) do
					local label   = (fti.foodGroup or fti.fillType).title or "no title";
					local percent = math.floor(fti.fillLevel * 100 / fti.capacity);
					local value   = string.format("%s %d%% (%.1fK)", label, percent, fti.fillLevel / 1000);

					-- highlighting
					local p     = fti.fillLevel / fti.capacity;
					local color = (p < 0.9 and hud.COLORNAME.DEFAULT) or hud.COLORNAME.HIGHLIGHT;

					table.insert(info.text, { value = value, color = color });			
				end
			end
		end

		-- check we have some text to show
		if (#info.text > 0) then
			table.insert(results, info);
		end
	end

	return results;
end

local function getVehicleFullName(vehicle)
	local name = cache.vehicleNames[vehicle.rootNode];
	
	if not name then
		name = vehicle:getName();
		local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName);

		if storeItem then
			local brand = g_brandManager:getBrandByIndex(storeItem.brandIndex);

			if brand then
				name = brand.title .. " " .. name;
			end
		end

		cache.vehicleNames[vehicle.rootNode] = name;
	end

	return name;
end

-- get vehicles in range and put all these informations into the results
function scanner:scanVehicles()
	-- 20 meters
	local vehiclesInRange = detector.getVehiclesInRange(20);
	local results = {};

	for _, vehicleInRange in pairs(vehiclesInRange) do
		local info = {
			profile       = "vehicle",
			vehicle       = vehicleInRange.vehicle,
			distance      = vehicleInRange.distance,
			worldPosition = vehicleInRange.worldPosition,
			rootNode      = vehicleInRange.vehicle.rootNode,
			title         = vehicleInRange.vehicle.typeDesc,
			text          = {},
			movable       = true
		};
		
		table.insert(info.text, { value = getVehicleFullName(info.vehicle), color = hud.COLORNAME.DEFAULT });

		--logging.trace(utils.formatString("{rootNode} {typeName} {typeDesc} {speedLimit} km/h", vehicle));
		local maxSpeed = info.vehicle:getSpeedLimit();
	
		if maxSpeed ~= math.huge then
			table.insert(info.text, { value = utils.formatString("Max Speed {1} km/h", { math.floor(info.vehicle:getSpeedLimit()) }), color = hud.COLORNAME.DEFAULT });
		end

		if info.vehicle.speedLimit and info.vehicle.speedLimit ~= math.huge then
			table.insert(info.text, { value = utils.formatString("Speed Limit {1} km/h", { info.vehicle.speedLimit }), color = "DEFAULT" });
		end

		if info.vehicle.getWearTotalAmount then
			local totalAmount = info.vehicle:getWearTotalAmount();

			if totalAmount then
				table.insert(info.text, { value = utils.formatString("Zustand {1} %", { math.floor((1 - totalAmount) * 100) }), color = (totalAmount < 0.2 and hud.COLORNAME.DEFAULT or hud.COLORNAME.HIGHLIGHT) });
			end
		end

		table.insert(info.text, { value = utils.formatString("Gesamtgewicht {1} kg", { (math.ceil(info.vehicle:getTotalMass(true) * 1000)) }), color = hud.COLORNAME.DEFAULT });
		--table.insert(info.text, { value = utils.formatString("Distance {1} m", { string.format("%0.1f", vehicleInRange.distance) }), color = hud.COLORNAME.DEFAULT });
		
		local spec_motorized = info.vehicle.spec_motorized;

		if spec_motorized and spec_motorized.isMotorStarted then
			-- Umdrehung
			if spec_motorized.motor then
				local rpm = math.floor(spec_motorized.motor:getEqualizedMotorRpm());

				if rpm > 0 then
					table.insert(info.text, { value = utils.formatString("Umdrehung {1} U/min", { rpm }), color = hud.COLORNAME.DEFAULT });
				end
			end

			-- Temperatur
			if spec_motorized.motorTemperature then
				table.insert(info.text, { value = utils.formatString("Temperatur {1} °C", { string.format("%.1f", spec_motorized.motorTemperature.value) }), color = hud.COLORNAME.DEFAULT });
			end
		end

		--Vehicle:getFillLevelInformation(fillLevelInformations)

		-- check we have some text to show
		if (#info.text > 0) then
			table.insert(results, info);
		end
	end

	return results;
end
