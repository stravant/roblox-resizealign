--!strict

local function otherNormals(dir: Vector3): (Vector3, Vector3)
	if math.abs(dir.X) > 0 then
		return Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
	elseif math.abs(dir.Y) > 0 then
		return Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
	else
		return Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
	end
end

local function isWedgeShape(part: BasePart): boolean
	return part:IsA("WedgePart") or (part:IsA("Part") and part.Shape == Enum.PartType.Wedge)
end

local function isCornerWedgeShape(part: BasePart): boolean
	return part:IsA("CornerWedgePart") or (part:IsA("Part") and part.Shape == Enum.PartType.CornerWedge)
end

return {
	otherNormals = otherNormals,
	isWedgeShape = isWedgeShape,
	isCornerWedgeShape = isCornerWedgeShape,
}
