local json = {}

local escapes = {
	["\\"] = "\\",
	["\""] = "\"",
	["\b"] = "b",
	["\f"] = "f",
	["\n"] = "n",
	["\r"] = "r",
	["\t"] = "t"
}

local reverseEscapes = {
	["/"] = "/"
}

for char, esc in pairs(escapes) do
	reverseEscapes[esc] = char
end

local function escapeChar(c)
	return "\\" .. (escapes[c] or string.format("u%04x", string.byte(c)))
end

local function encodeNil()
	return "null"
end

local function encodeString(str)
	return '"' .. str:gsub("[%z\1-\31\\\"]", escapeChar) .. '"'
end

local function encodeNumber(num)
	assert(not (num ~= num or num == math.huge or num == -math.huge), "Invalid or NaN number value: " .. tostring(num))
	return tostring(num)
end

local function encodeTable(tbl, pretty, indentLevel, seen)
	assert(seen[tbl] == nil, "Circular reference")
	seen[tbl] = true
	local isArray = #tbl > 0
	local result = {}
	local indent = pretty and string.rep("  ", indentLevel) or ""
	local newline = pretty and "\n" or ""
	local separator = pretty and ": " or ":"
	local delimiter = pretty and ",\n" or ","

	if isArray then
		if #tbl == 0 then
			seen[tbl] = nil
			return "[]"
		end
		for i, v in ipairs(tbl) do
			table.insert(result, (pretty and indent .. "  " or "") .. json.encode(v, pretty, indentLevel + 1, seen))
		end
		seen[tbl] = nil
		return "[" .. newline .. table.concat(result, delimiter) .. (pretty and newline .. indent or "") .. "]"
	else
		local hasEntries = false
		for key, value in pairs(tbl) do
			hasEntries = true
			assert(type(key) == "string", "Table keys must be strings")
			local pair = encodeString(key) .. separator .. json.encode(value, pretty, indentLevel + 1, seen)
			table.insert(result, (pretty and indent .. "  " or "") .. pair)
		end
		seen[tbl] = nil
		if not hasEntries then
			return "[]"
		end
		return "{" .. newline .. table.concat(result, delimiter) .. (pretty and newline .. indent or "") .. "}"
	end
end

local function encodeInstance()
	return '"Instance"'
end

local function encodeFunction()
	return '"function"'
end

local function encodeVector3(vector)
    return encodeString(`[Vector3 {vector.X},{vector.Y},{vector.Z}]`)
end

local function encodeVector2(vector)
    return encodeString(`[Vector2 {vector.X},{vector.Y}]`)
end

local function encodeColor3(color)
    return encodeString(`[Color3 {math.ceil(color.R * 255)},{math.ceil(color.G * 255)},{math.ceil(color.B * 255)}]`)
end

local function encodeUDim(udim)
    return encodeString(`[UDim {udim.Scale},{udim.Offset}]`)
end

local function encodeUDim2(udim)
    return encodeString(`[UDim2 {udim.X.Scale},{udim.X.Offset},{udim.Y.Scale},{udim.Y.Offset}]`)
end

local function encodeCFrame(cframe)
    return encodeString(`[CFrame {tostring(cframe):gsub(" ", "")}]`)
end

local encoders = {
	["nil"] = encodeNil,
	["string"] = encodeString,
	["number"] = encodeNumber,
	["boolean"] = tostring,
	["table"] = encodeTable,
	["Instance"] = encodeInstance,
    ["Vector3"] = encodeVector3,
    ["Vector2"] = encodeVector2,
    ["Color3"] = encodeColor3,
    ["UDim"] = encodeUDim,
    ["UDim2"] = encodeUDim2,
    ["CFrame"] = encodeCFrame,
    ["function"] = encodeFunction,
}

local function skipWhitespace(str, index)
	return string.find(str, "[^%s]", index) or #str + 1
end

local function decodeError(message, str, index)
	local line, col = 1, 1
	for i = 1, index - 1 do
		col += 1
		if str:sub(i, i) == "\n" then
			line += 1
			col = 1
		end
	end
	error(string.format("%s at %d:%d", message, line, col))
end

local function decodeString(str, index)
	local result, i = {}, index + 1
	while i <= #str do
		local char = str:sub(i, i)
		if char == '"' then
			return table.concat(result), i + 1
		elseif char == "\\" then
			local nextChar = str:sub(i + 1, i + 1)
			if nextChar == "u" then
				local hex = str:sub(i + 2, i + 5)
				table.insert(result, utf8.char(tonumber(hex, 16) or 0))
				i += 6
			else
				table.insert(result, reverseEscapes[nextChar] or decodeError("Invalid escape sequence", str, i))
				i += 2
			end
		else
			table.insert(result, char)
			i += 1
		end
	end
	decodeError("Unterminated string", str, index)

	return
end

local function decodeNumber(str, index)
	local numEnd = string.find(str, "[^%d%.%-+eE]", index) or (#str + 1)
	local num = tonumber(str:sub(index, numEnd - 1))
	if not num then
		decodeError("Invalid number", str, index)
	end
	return num, numEnd
end

local decodeValue -- i put this here, so i can still use the function before its definition without deoptimizing the environment,

local function decodeArray(str, index)
	local result, i = {}, index + 1
	while true do
		i = skipWhitespace(str, i)
		if str:sub(i, i) == "]" then
			return result, i + 1
		end
		local value
		value, i = decodeValue(str, i)
		table.insert(result, value)
		i = skipWhitespace(str, i)
		local nextChar = str:sub(i, i)
		if nextChar == "]" then
			return result, i + 1
		elseif nextChar ~= "," then
			decodeError("Expected ',' or ']' in array", str, i)
		end
		i += 1
	end
end

local function decodeObject(str, index)
	local result, i = {}, index + 1
	while true do
		i = skipWhitespace(str, i)
		if str:sub(i, i) == "}" then
			return result, i + 1
		end
		local key
		key, i = decodeString(str, i)
		i = skipWhitespace(str, i)
		if str:sub(i, i) ~= ":" then
			decodeError("Expected ':' after object key", str, i)
		end
		i = skipWhitespace(str, i + 1)
		local value
		value, i = decodeValue(str, i)
		result[key] = value
		i = skipWhitespace(str, i)
		local nextChar = str:sub(i, i)
		if nextChar == "}" then
			return result, i + 1
		elseif nextChar ~= "," then
			decodeError("Expected ',' or '}' in object", str, i)
		end
		i += 1
	end
end

local function decodeVector2(str, index)
    local vectorStr, i = decodeString(str, index)
    local x, y = vectorStr:match("%[Vector2 (%d+%.?%d*)%s*,%s*(%d+%.?%d*)%]")
    return Vector2.new(tonumber(x), tonumber(y)), i
end

local function decodeVector3(str, index)
    local vectorStr, i = decodeString(str, index)
    local x, y, z = vectorStr:match("%[Vector3 (%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%]")
    return Vector3.new(tonumber(x), tonumber(y), tonumber(z)), i
end

local function decodeColor3(str, index)
    local colorStr, i = decodeString(str, index)
    local r, g, b = colorStr:match("%[Color3 (%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%]")
    return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)), i
end

local function decodeUDim(str, index)
    local udimStr, i = decodeString(str, index)
    local s, o = udimStr:match("%[UDim (%d+%.?%d*)%s*,%s*(%d+%.?%d*)%]")
    return UDim.new(tonumber(s), tonumber(o)), i
end

local function decodeUDim2(str, index)
    local udimStr, i = decodeString(str, index)
    local xs, xo, ys, yo = udimStr:match("%[UDim (%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%]")
    return UDim2.new(tonumber(xs), tonumber(xo), tonumber(ys), tonumber(yo)), i
end

local function decodeCFrame(str, index)
    local cfstring, i = decodeString(str, index)
    local match = {cfstring:match("%[UDim%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)%]")}

    for mi, v in ipairs(match) do
        match[mi] = tonumber(v)
    end
    
    return CFrame.new(unpack(match)), i
end

local function startsWith(str: string, index: number, value: string)
    local sub = str:sub(index):sub(1, #value)
    return sub == value
end

decodeValue = function(str, index)
	local firstChar = str:sub(index, index)

	if firstChar == '"' then
        if startsWith(str, index, '"[Vector2') then
            return decodeVector2(str, index)
        elseif startsWith(str, index, '"[Vector3') then
            return decodeVector3(str, index)
        elseif startsWith(str, index, '"[Color3') then
            return decodeColor3(str, index)
        elseif startsWith(str, index, '"[UDim') then
            return decodeUDim(str, index)
        elseif startsWith(str, index, '"[UDim2') then
            return decodeUDim2(str, index)
        elseif startsWith(str, index, '"[CFrame') then
            return decodeCFrame(str, index)
        end

		return decodeString(str, index)
	elseif firstChar:match("[%d%-]") then
		return decodeNumber(str, index)
	elseif firstChar == "{" then
		return decodeObject(str, index)
	elseif firstChar == "[" then
		return decodeArray(str, index)
	elseif firstChar == "t" then
		return true, index + 4
	elseif firstChar == "f" then
		return false, index + 5
	elseif firstChar == "n" then
		return nil, index + 4
	else
		decodeError("Unexpected character", str, index)
	end

	return
end

function json.encode(value: {any}, pretty: boolean?, indentLevel: number?, seen:{ [{string}]: boolean }?)
	seen = seen or {}
    pretty = pretty or false
	indentLevel = indentLevel or 2
	local valueType = typeof(value)
	local encoder = encoders[valueType]
	assert(encoder, "Unsupported data type: " .. valueType)
	return encoder(value, pretty, indentLevel, seen)
end

function json.decode(str: string)
	local value, index = decodeValue(str, skipWhitespace(str, 1))
	index = skipWhitespace(str, index)
	if index <= #str then
		decodeError("Trailing characters", str, index)
	end
	return value
end

return json
