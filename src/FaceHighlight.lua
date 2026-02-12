--!strict
local Src = script.Parent
local Packages = Src.Parent.Packages

local React = require(Packages.React)
local e = React.createElement

local doExtend = require(Src.doExtend)
type Face = doExtend.Face

local function isCornerWedgeShape(part: BasePart)
	return part:IsA("CornerWedgePart") or (part:IsA("Part") and part.Shape == Enum.PartType.CornerWedge)
end

local function otherNormals(dir: Vector3)
	if math.abs(dir.X) > 0 then
		return Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
	elseif math.abs(dir.Y) > 0 then
		return Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
	else
		return Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
	end
end

-- B should be vertex at the right angle
local function RightAngleTriangleHandleAdornment(props: {
	A: Vector3,
	B: Vector3,
	C: Vector3,
	Transparency: number,
	ZIndexOffset: number?,
	Color: Color3,
})
	local ab = (props.B - props.A)
	local bc = (props.C - props.B)
	local normal = ab:Cross(bc).Unit
	local mid = (props.A + props.C) * 0.5
	local abmid = (props.A + 0.5 * ab)
	local bcmid = (props.B + 0.5 * bc)

	return e(React.Fragment, nil, {
		A = e("ConeHandleAdornment", {
			Adornee = workspace.Terrain,
			Height = (mid - abmid).Magnitude,
			Radius = ab.Magnitude / 2,
			CFrame = CFrame.fromMatrix(abmid, ab.Unit, Vector3.zero, ab.Unit:Cross(normal).Unit),
			ZIndex = 1 + (props.ZIndexOffset or 0),
			AlwaysOnTop = true,
			Transparency = props.Transparency,
			Color3 = props.Color,
		}),
		B = e("ConeHandleAdornment", {
			Adornee = workspace.Terrain,
			Height = (mid - bcmid).Magnitude,
			Radius = bc.Magnitude / 2,
			CFrame = CFrame.fromMatrix(bcmid, ab.Unit:Cross(normal).Unit, Vector3.zero, ab.Unit),
			ZIndex = 1 + (props.ZIndexOffset or 0),
			AlwaysOnTop = true,
			Transparency = props.Transparency,
			Color3 = props.Color,
		}),
	})
end

local function WedgeFaceHighlight(props: {
	Face: Face,
	Color: Color3,
	Transparency: number,
	ZIndexOffset: number?,
})
	local face = props.Face
	local hsize = face.Object.Size / 2
	local cf = face.Object.CFrame
	local upDir = (cf.YVector * hsize.Z - cf.ZVector * hsize.Y).Unit
	local rotation = CFrame.fromMatrix(Vector3.zero, cf.XVector, upDir)
	local halfWidth = math.sqrt(hsize.Y^2 + hsize.Z^2)
	local zmod = props.ZIndexOffset or 0
	local baseCFrame = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, (Vector3.yAxis * hsize.Y + Vector3.zAxis * hsize.Z).Unit:Cross(Vector3.xAxis))

	return e(React.Fragment, nil, {
		Handle = e("BoxHandleAdornment", {
			Adornee = workspace.Terrain,
			Size = Vector3.new(hsize.X * 2, 0.1, halfWidth * 2),
			CFrame = rotation + face.Object.Position,
			ZIndex = 1 + zmod,
			AlwaysOnTop = true,
			Transparency = props.Transparency,
			Color3 = props.Color,
		}),
		Edge1 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = halfWidth * 2 + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = baseCFrame,
			SizeRelativeOffset = Vector3.xAxis,
		}),
		Edge2 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = halfWidth * 2 + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = baseCFrame,
			SizeRelativeOffset = -Vector3.xAxis,
		}),
		Edge3 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = hsize.X * 2 + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.zAxis),
			SizeRelativeOffset = Vector3.yAxis + Vector3.zAxis,
		}),
		Edge4 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = hsize.X * 2 + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.zAxis),
			SizeRelativeOffset = -(Vector3.yAxis + Vector3.zAxis),
		}),
	})
end

-- CFrame whose ZVector = dir (the axis CylinderHandleAdornment extends along)
local function cylinderCFrame(dir: Vector3)
	local d = dir.Unit
	local perp
	if math.abs(d:Dot(Vector3.zAxis)) < 0.9 then
		perp = d:Cross(Vector3.zAxis).Unit
	else
		perp = d:Cross(Vector3.xAxis).Unit
	end
	return CFrame.fromMatrix(Vector3.zero, perp, d:Cross(perp).Unit)
end

local function CornerWedgeFaceHighlight(props: {
	Face: Face,
	Color: Color3,
	Transparency: number,
	ZIndexOffset: number?,
})
	local face = props.Face
	local hsize = face.Object.Size / 2
	local cf = face.Object.CFrame
	local zmod = props.ZIndexOffset or 0

	-- Peak at E=(hx,hy,-hz). Triangle vertices (SizeRelativeOffset) and edge directions (local space).
	local v1sro, v2sro, v3sro
	local edge12dir, edge13dir, edge23dir
	if face.CornerWedgeSide == "Right" then
		-- Right slope ACE: A=(-hx,-hy,-hz), C=(-hx,-hy,hz), E=(hx,hy,-hz)
		v1sro = Vector3.new(-1, -1, -1)  -- A (right angle)
		v2sro = Vector3.new(-1, -1, 1)   -- C
		v3sro = Vector3.new(1, 1, -1)    -- E
		edge12dir = Vector3.zAxis                              -- A→C
		edge13dir = Vector3.new(hsize.X, hsize.Y, 0)          -- A→E
		edge23dir = Vector3.new(hsize.X, hsize.Y, -hsize.Z)   -- C→E
	else
		-- Back slope CDE: C=(-hx,-hy,hz), D=(hx,-hy,hz), E=(hx,hy,-hz)
		v1sro = Vector3.new(1, -1, 1)    -- D (right angle)
		v2sro = Vector3.new(1, 1, -1)    -- E
		v3sro = Vector3.new(-1, -1, 1)   -- C
		edge12dir = Vector3.new(0, hsize.Y, -hsize.Z)         -- D→E
		edge13dir = -Vector3.xAxis                             -- D→C
		edge23dir = Vector3.new(-hsize.X, -hsize.Y, hsize.Z)  -- E→C
	end

	-- Compute world-space centroid for box highlight
	local v1 = cf:PointToWorldSpace(v1sro * hsize)
	local v2 = cf:PointToWorldSpace(v2sro * hsize)
	local v3 = cf:PointToWorldSpace(v3sro * hsize)

	-- Edge lengths
	local len12 = (v2 - v1).Magnitude
	local len13 = (v3 - v1).Magnitude
	local len23 = (v3 - v2).Magnitude

	return e(React.Fragment, nil, {
		Handle = e(RightAngleTriangleHandleAdornment, {
			A = v2,
			B = v1,
			C = v3,
			ZIndexOffset = props.ZIndexOffset,
			Transparency = props.Transparency,
			Color = props.Color,
		}),
		Edge1 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = len12 + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = cylinderCFrame(edge12dir),
			SizeRelativeOffset = (v1sro + v2sro) / 2,
		}),
		Edge2 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = len13 + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = cylinderCFrame(edge13dir),
			SizeRelativeOffset = (v1sro + v3sro) / 2,
		}),
		Edge3 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = len23 + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = cylinderCFrame(edge23dir),
			SizeRelativeOffset = (v2sro + v3sro) / 2,
		}),
	})
end

local function SquareFaceHighlight(props: {
	Face: Face,
	Color: Color3,
	Transparency: number,
	ZIndexOffset: number?,
})
	local face = props.Face
	local hsize = face.Object.Size / 2
	local faceDir = Vector3.fromNormalId(face.Normal)
	local faceA, faceB = otherNormals(faceDir)
	local zmod = props.ZIndexOffset or 0

	local baseEdgeCFrameA = CFrame.fromMatrix(Vector3.new(), faceA:Cross(faceB).Unit, faceA)
	local baseEdgeCFrameB = CFrame.fromMatrix(Vector3.new(), faceB:Cross(faceA).Unit, faceB)

	return e(React.Fragment, nil, {
		Handle = e("BoxHandleAdornment", {
			Adornee = workspace.Terrain,
			Size = faceA * hsize * 2 + faceB * hsize * 2 + faceDir * 0.1,
			CFrame = face.Object.CFrame * CFrame.new(faceDir * hsize),
			ZIndex = 1 + zmod,
			AlwaysOnTop = true,
			Transparency = props.Transparency,
			Color3 = props.Color,
		}),
		Edge1 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = (faceB * hsize * 2).Magnitude + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = baseEdgeCFrameA,
			SizeRelativeOffset = faceDir + faceA,
		}),
		Edge2 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = (faceB * hsize * 2).Magnitude + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = baseEdgeCFrameA,
			SizeRelativeOffset = faceDir - faceA,
		}),
		Edge3 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = (faceA * hsize * 2).Magnitude + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = baseEdgeCFrameB,
			SizeRelativeOffset = faceDir + faceB,
		}),
		Edge4 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = (faceA * hsize * 2).Magnitude + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = baseEdgeCFrameB,
			SizeRelativeOffset = faceDir - faceB,
		}),
	})
end

local function CornerWedgeFlatFaceHighlight(props: {
	Face: Face,
	Color: Color3,
	Transparency: number,
	ZIndexOffset: number?,
})
	local face = props.Face
	local hsize = face.Object.Size / 2
	local cf = face.Object.CFrame
	local zmod = props.ZIndexOffset or 0

	local v1sro, v2sro, v3sro
	local edge12dir, edge13dir, edge23dir
	if face.Normal == Enum.NormalId.Front then
		-- Front face ABE: A=(-hx,-hy,-hz), B=(hx,-hy,-hz), E=(hx,hy,-hz)
		-- Right angle at B
		v1sro = Vector3.new(1, -1, -1)   -- B (right angle)
		v2sro = Vector3.new(-1, -1, -1)  -- A
		v3sro = Vector3.new(1, 1, -1)    -- E
		edge12dir = -Vector3.xAxis                          -- B→A
		edge13dir = Vector3.yAxis                           -- B→E
		edge23dir = Vector3.new(hsize.X, hsize.Y, 0)       -- A→E
	else -- Right
		-- Right face BDE: B=(hx,-hy,-hz), D=(hx,-hy,hz), E=(hx,hy,-hz)
		-- Right angle at B
		v1sro = Vector3.new(1, -1, -1)   -- B (right angle)
		v2sro = Vector3.new(1, -1, 1)    -- D
		v3sro = Vector3.new(1, 1, -1)    -- E
		edge12dir = Vector3.zAxis                           -- B→D
		edge13dir = Vector3.yAxis                           -- B→E
		edge23dir = Vector3.new(0, hsize.Y, -hsize.Z)      -- D→E
	end

	local v1 = cf:PointToWorldSpace(v1sro * hsize)
	local v2 = cf:PointToWorldSpace(v2sro * hsize)
	local v3 = cf:PointToWorldSpace(v3sro * hsize)

	local len12 = (v2 - v1).Magnitude
	local len13 = (v3 - v1).Magnitude
	local len23 = (v3 - v2).Magnitude

	return e(React.Fragment, nil, {
		Handle = e(RightAngleTriangleHandleAdornment, {
			A = v2,
			B = v1,
			C = v3,
			ZIndexOffset = props.ZIndexOffset,
			Transparency = props.Transparency,
			Color = props.Color,
		}),
		Edge1 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = len12 + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = cylinderCFrame(edge12dir),
			SizeRelativeOffset = (v1sro + v2sro) / 2,
		}),
		Edge2 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = len13 + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = cylinderCFrame(edge13dir),
			SizeRelativeOffset = (v1sro + v3sro) / 2,
		}),
		Edge3 = e("CylinderHandleAdornment", {
			Color3 = props.Color,
			ZIndex = 2 + zmod,
			Adornee = face.Object,
			Height = len23 + 0.4,
			AlwaysOnTop = false,
			Radius = 0.05,
			CFrame = cylinderCFrame(edge23dir),
			SizeRelativeOffset = (v2sro + v3sro) / 2,
		}),
	})
end

local function FaceHighlight(props: {
	Face: Face,
	Color: Color3,
	Transparency: number,
	ZIndexOffset: number?,
})
	if props.Face.CornerWedgeSide then
		return e(CornerWedgeFaceHighlight, props)
	elseif props.Face.IsWedge then
		return e(WedgeFaceHighlight, props)
	elseif isCornerWedgeShape(props.Face.Object) and (props.Face.Normal == Enum.NormalId.Front or props.Face.Normal == Enum.NormalId.Right) then
		return e(CornerWedgeFlatFaceHighlight, props)
	else
		return e(SquareFaceHighlight, props)
	end
end

return FaceHighlight
