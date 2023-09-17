
local FaceDisplay = {}
FaceDisplay.__index = FaceDisplay

local function otherNormals(dir: Vector3)
	if math.abs(dir.X) > 0 then
		return Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
	elseif math.abs(dir.Y) > 0 then
		return Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
	else
		return Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
	end
end

type Face = {
	Object: BasePart,
	Normal: Enum.NormalId,
	IsWedge: boolean?,
}

local function renderWedge(parent: Instance, face: Face, color: Color3, trans: number, zmod: number)
	local hsize = face.Object.Size / 2
	local cf = face.Object.CFrame
	local upDir = (cf.YVector * hsize.Z - cf.ZVector * hsize.Y).Unit
	local rotation = CFrame.fromMatrix(Vector3.zero, cf.XVector, upDir)
	local halfWidth = math.sqrt(hsize.Y^2 + hsize.Z^2)
	--
	local handle = Instance.new("BoxHandleAdornment")
	handle.Adornee = workspace.Terrain
	handle.Size = Vector3.new(hsize.X * 2, 0.1, halfWidth * 2)
	handle.CFrame = rotation + face.Object.Position
	handle.ZIndex = 1 + zmod
	handle.AlwaysOnTop = true
	handle.Transparency = 0.5
	handle.Color3 = color
	handle.Parent = parent
	--
	local edge1 = Instance.new("CylinderHandleAdornment")
	edge1.Color3 = color
	edge1.ZIndex = 2 + zmod
	edge1.Adornee = face.Object
	edge1.Height = halfWidth * 2 + 0.4
	edge1.AlwaysOnTop = false
	edge1.Radius = 0.05
	edge1.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, (Vector3.yAxis * hsize.Y + Vector3.zAxis * hsize.Z).Unit:Cross(Vector3.xAxis))
	edge1.SizeRelativeOffset = Vector3.xAxis
	edge1.Parent = parent
	--
	local edge2 = edge1:Clone()
	edge2.SizeRelativeOffset = -Vector3.xAxis
	edge2.Parent = parent
	--
	local edge3 = edge1:Clone()
	edge3.Height = hsize.X * 2 + 0.4
	edge3.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.zAxis)
	edge3.SizeRelativeOffset = Vector3.yAxis + Vector3.zAxis
	edge3.Parent = parent
	--
	local edge4 = edge3:Clone()
	edge4.SizeRelativeOffset = -(Vector3.yAxis + Vector3.zAxis)
	edge4.Parent = parent

	return {handle, edge1, edge2, edge3, edge4}
end

local function renderSquare(parent: Instance, face: Face, color: Color3, trans: number, zmod: number)
	local hsize = face.Object.Size / 2
	local faceDir = Vector3.fromNormalId(face.Normal)
	local faceA, faceB = otherNormals(faceDir)
	--
	local handle = Instance.new("BoxHandleAdornment")
	handle.Adornee = workspace.Terrain
	handle.Size = faceA * hsize * 2 + faceB * hsize * 2 + faceDir * 0.1
	handle.CFrame = face.Object.CFrame * CFrame.new(faceDir * hsize)
	handle.ZIndex = 1 + zmod
	handle.AlwaysOnTop = true
	handle.Transparency = 0.5
	handle.Color3 = color
	handle.Parent = parent
	--
	local baseEdgeCFrameA = CFrame.fromMatrix(Vector3.new(), faceA:Cross(faceB).Unit, faceA)
	local baseEdgeCFrameB = CFrame.fromMatrix(Vector3.new(), faceB:Cross(faceA).Unit, faceB)
	--
	local edge1 = Instance.new("CylinderHandleAdornment")
	edge1.Color3 = color
	edge1.ZIndex = 2 + zmod
	edge1.Adornee = face.Object
	edge1.Height = (faceB * hsize * 2).Magnitude + 0.4
	edge1.AlwaysOnTop = false
	edge1.Radius = 0.05
	edge1.CFrame = baseEdgeCFrameA
	edge1.SizeRelativeOffset = faceDir + faceA
	edge1.Parent = parent
	--
	local edge2 = edge1:Clone()
	edge2.SizeRelativeOffset = faceDir - faceA
	edge2.Parent = parent
	--
	local edge3 = edge1:Clone()
	edge3.Height = (faceA * hsize * 2).Magnitude + 0.4
	edge3.SizeRelativeOffset = faceDir + faceB
	edge3.CFrame = baseEdgeCFrameB
	edge3.Parent = parent
	--
	local edge4 = edge3:Clone()
	edge4.SizeRelativeOffset = faceDir - faceB
	edge4.Parent = parent
	
	return {handle, edge1, edge2, edge3, edge4}
end

function FaceDisplay.new(parent: Instance, face: Face, color: Color3, trans: number, zmod: number)
	local result = 
		if face.IsWedge then renderWedge(parent, face, color, trans, zmod) else renderSquare(parent, face, color, trans, zmod)
	return setmetatable(result, FaceDisplay)
end

function FaceDisplay:destroy()
	for _, part in self do
		part:Destroy()
	end
end

export type T = typeof(FaceDisplay.new(...))

return FaceDisplay
