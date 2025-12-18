local ReflectionService = game:GetService("ReflectionService")

local BASE_PART_PROPS = {} :: { string }
local IGNORE_PROPS = {
	archivable = true,
	brickColor = true,
	BrickColor = true,
	Orientation = true,
	Position = true,
	Rotation = true,
	CFrame = true,
	PivotOffset = true,
	FrontParamA = true,
	FrontParamB = true,
	FrontSurface = true,
	FrontSurfaceInput = true,
	LeftParamA = true,
	LeftParamB = true,
	LeftSurface = true,
	LeftSurfaceInput = true,
	LocalTransparencyModifier = true,
	RightParamA = true,
	RightParamB = true,
	RightSurface = true,
	RightSurfaceInput = true,
	TopSurfaceInput = true,
	TopSurface = true,
	TopParamB = true,
	TopParamA = true,
	BackParamA = true,
	BackParamB = true,
	BackSurface = true,
	BackSurfaceInput = true,
	BottomParamA = true,
	BottomParamB = true,
	BottomSurface = true,
	BottomSurfaceInput = true,
	Name = true,
	Parent = true,
}

local testPart = Instance.new("Part")

for _, property in ReflectionService:GetPropertiesOfClass("BasePart") do
	local name = property.Name :: string

	-- not copying these properties
	if IGNORE_PROPS[name] then
		continue
	end

	local canWrite = pcall(function(name)
		(testPart :: any)[name] = (testPart :: any)[name]
	end, name)
	print(canWrite)

	if canWrite then
		table.insert(BASE_PART_PROPS, name)
	end
end

testPart:Destroy()

return function(fromPart: BasePart, toPart: BasePart)
	for _, property in BASE_PART_PROPS do
		(toPart :: any)[property] = (fromPart :: any)[property]
	end
end
