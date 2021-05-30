--[[
	LOGGING
]]

-- lib
local logging = {};
local modname = g_currentModName;

-- export
FS19_RadioVolume.lib.logging = logging;

-- required
function logging:load(mod)
end

-- internal
function logging.trace(message)
	print(string.format("@%s [%s]: %s", modname, getDate("%H:%M:%S"), message));
end

-- internal, see DebugUtil.printTableRecursively
function logging.printTable(name, inputTable, deep, refs, keylimit)
	keylimit = math.max(10, (keylimit or 8000));

	if (type(inputTable) ~= "table") then
		logging.trace(name .. " [" .. type(inputTable) .. "] is not a table: " .. tostring(inputTable));
		return;
	end

	refs = refs or {};

	if refs[tostring(inputTable)] ~= nil then
		logging.trace(name .. "[" .. tostring(inputTable) .. "]: REFERENCE: " .. refs[tostring(inputTable)]);
		return;
	end

	refs[tostring(inputTable)] = name;

	if (#refs > 100000) then
		logging.trace("================== to many refs ==================");
		return;
	end

	local mt = getmetatable(inputTable);

	if type(mt) == "table" then
		logging.printTable(name .. "_mt", mt, deep, refs, keylimit);
	end

	local keys = {};

	for k in pairs(inputTable) do
		table.insert(keys, k);
	end

	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b);
	end);
	
	local count = 0;

	for _, k in pairs(keys) do
		count = count + 1;

		if (count > keylimit) then
			logging.trace("================== to many keys ==================");
			break;
		end

		local v = inputTable[k];

		logging.trace(name .. "." .. tostring(k) .. " [" .. type(v) .. "]: " .. tostring(v));

		if (((deep or 0) > 0) and (type(v) == "table")) then
			logging.printTable(name .. "." .. tostring(k), v, deep - 1, refs, math.floor(keylimit / 4));
		end		
	end
end
