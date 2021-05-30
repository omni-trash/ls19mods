--[[
	UTILS
]]

-- lib
local utils = {};

-- export
FS19_AR.lib.utils = utils;

function utils.combineFunction(first, final)
	return function(...)
		local t = {...};
		local n = select('#', ...);
		first(unpack(t, 1, n));
		return final(unpack(t, 1, n));
	end
end

-- format the string, formatString("{key1} {key2}!", {key1 = "Hello", key2 = "World"}) => "Hello World!"
function utils.formatString(format, args)
	local str = tostring(format or "");

	for k, v in pairs(args) do
		-- gsub is here not usefult with the magic pattern stuff, so we use simple split + join
		str = table.concat(StringUtil.splitString(string.format("{%s}", tostring(k)), str), tostring(v));
	end

	return str;
end

function utils.getWorldPosition(nodeId)
	local x, y, z = getWorldTranslation(nodeId);
	return { x = x, y = y, z = z };
end

-- iterate over each property (see config.lua)
function utils.traverseTable(path, object, callback)
	local ref = {};
	local out = {{ path = path, object = object }};

	for i, e in ipairs(out) do
		if not ref[e.object] then
			ref[e.object] = e.object;

			for k, v in pairs(e.object) do
				local data = {
					entry  = e,
					key    = k,
					value  = v
				};

				callback(data);

				if type(v) == "table" then
					local path = e.path .. "." .. tostring(k);
					table.insert(out, { path = path, object = v });
				end
			end				
		end
	end
end
