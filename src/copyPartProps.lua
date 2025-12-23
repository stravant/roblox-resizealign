local ReflectionService = game:GetService("ReflectionService")

local BASE_PART_PROPS = {} :: { string }

for _, property in ReflectionService:GetPropertiesOfClass("BasePart") do
	if property.Permits.Write and property.Permits.Read and property.Serialized then
		table.insert(BASE_PART_PROPS, property.Name :: string)
	end
end

return function(fromPart: BasePart, toPart: BasePart)
	for _, property in BASE_PART_PROPS do
		(toPart :: any)[property] = (fromPart :: any)[property]
	end
end
