--!strict

local function interpretExpression(input: string): number?
	-- Implicit divide by 360
	if input:sub(1, 1) == "/" then
		input = "360" .. input
	end
	local fragment, _err = loadstring("return " .. input)
	if fragment then
		local success, result = pcall(fragment)
		if success and typeof(result) == "number" then
			return result
		end
	end
	return nil
end

-- Interpret the text entered into a NumberInput, nil if it isn't a number.
-- With a zeroLabel, that label (in any case) or empty text means zero.
local function interpretNumberInput(input: string, zeroLabel: string?): number?
	local text = input:match("^%s*(.-)%s*$") :: string
	if text == "" then
		return if zeroLabel then 0 else nil
	end
	if zeroLabel and text:lower() == zeroLabel:lower() then
		return 0
	end
	return interpretExpression(text)
end

return interpretNumberInput
