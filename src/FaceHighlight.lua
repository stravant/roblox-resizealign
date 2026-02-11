local Src = script.Parent
local Packages = Src.Parent.Packages

local React = require(Packages.React)
local e = React.createElement

local doExtend = require(Src.doExtend)
type Face = doExtend.Face

local function otherNormals(dir: Vector3)
	if math.abs(dir.X) > 0 then
		return Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
	elseif math.abs(dir.Y) > 0 then
		return Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
	else
		return Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
	end
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

local function FaceHighlight(props: {
	Face: Face,
	Color: Color3,
	Transparency: number,
	ZIndexOffset: number?,
})
	if props.Face.IsWedge then
		return e(WedgeFaceHighlight, props)
	else
		return e(SquareFaceHighlight, props)
	end
end

return FaceHighlight
