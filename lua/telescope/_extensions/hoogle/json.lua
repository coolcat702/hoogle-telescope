local json = {}

local function skip_delim(str, pos, delim, err_if_missing)
	pos = pos + #str:match("^%s*", pos)
	if str:sub(pos, pos) ~= delim then
		if err_if_missing then
			error("Expected " .. delim .. " near position " .. pos)
		end
		return pos, false
	end
	return pos + 1, true
end

-- Expects the given pos to be the first character after the opening quote.
-- Returns val, pos; the returned pos is after the closing quote character.
local function parse_str_val(str, pos, val)
	val = val or ""
	local early_end_error = "End of input found while parsing string."
	if pos > #str then
		error(early_end_error)
	end
	local c = str:sub(pos, pos)
	if c == '"' then
		return val, pos + 1
	end
	if c ~= "\\" then
		return parse_str_val(str, pos + 1, val .. c)
	end
	-- We must have a \ character.
	local esc_map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
	local nextc = str:sub(pos + 1, pos + 1)
	if not nextc then
		error(early_end_error)
	end
	return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

-- Returns val, pos; the returned pos is after the number's final character.
local function parse_num_val(str, pos)
	local num_str = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
	local val = tonumber(num_str)
	if not val then
		error("Error parsing number at position " .. pos .. ".")
	end
	return val, pos + #num_str
end

json.null = {}

function json.parse(str, pos, end_delim)
	pos = pos or 1
	if pos > #str then
		error("Reached unexpected end of input.")
	end
	local pos = pos + #str:match("^%s*", pos)
	local first = str:sub(pos, pos)
	if first == "{" then
		local obj, key, delim_found = {}, true, true
		pos = pos + 1
		while true do
			key, pos = json.parse(str, pos, "}")
			if key == nil then
				return obj, pos
			end
			if not delim_found then
				error("Comma missing between object items.")
			end
			pos = skip_delim(str, pos, ":", true) -- true -> error if missing.
			obj[key], pos = json.parse(str, pos)
			pos, delim_found = skip_delim(str, pos, ",")
		end
	elseif first == "[" then -- Parse an array.
		local arr, val, delim_found = {}, true, true
		pos = pos + 1
		while true do
			val, pos = json.parse(str, pos, "]")
			if val == nil then
				return arr, pos
			end
			if not delim_found then
				error("Comma missing between array items.")
			end
			arr[#arr + 1] = val
			pos, delim_found = skip_delim(str, pos, ",")
		end
	elseif first == '"' then -- Parse a string.
		return parse_str_val(str, pos + 1)
	elseif first == "-" or first:match("%d") then -- Parse a number.
		return parse_num_val(str, pos)
	elseif first == end_delim then -- End of an object or array.
		return nil, pos + 1
	else -- Parse true, false, or null.
		local literals = { ["true"] = true, ["false"] = false, ["null"] = json.null }
		for lit_str, lit_val in pairs(literals) do
			local lit_end = pos + #lit_str - 1
			if str:sub(pos, lit_end) == lit_str then
				return lit_val, lit_end + 1
			end
		end
		local pos_info_str = "position " .. pos .. ": " .. str:sub(pos, pos + 10)
		error("Invalid json syntax starting at " .. pos_info_str)
	end
end

return json
