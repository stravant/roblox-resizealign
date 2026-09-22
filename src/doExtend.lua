--!strict
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local DraggerService = game:GetService("DraggerService")

local Src = script.Parent
local Packages = Src.Parent.Packages

local DraggerFramework = require(Packages.DraggerFramework)
local JointMaker = require(DraggerFramework.Utility.JointMaker)

local copyPartProps = require(Src.copyPartProps)
local Settings = require(Src.Settings)
local ShapeUtils = require(Src.ShapeUtils)
local SplineJoin = require(Src.SplineJoin)

local otherNormals = ShapeUtils.otherNormals
local isWedgeShape = ShapeUtils.isWedgeShape
local isCornerWedgeShape = ShapeUtils.isCornerWedgeShape

local WEDGE_PART = Instance.new("Part")
WEDGE_PART.Shape = Enum.PartType.Wedge

export type Face = {
	Object: BasePart,
	Normal: Enum.NormalId,
	IsWedge: boolean?,
	CornerWedgeSide: ("Right" | "Back")?,
}

export type ResizeMode = Settings.ResizeMode

-- Face normals within this sine-of-angle of one another are considered exactly
-- parallel. float32 CFrame rotation error is on the order of 1e-7, so this is
-- safely above pure floating point noise while still permitting deliberate
-- angles ~1000x smaller than kNearParallelSinAngle.
local kParallelSinAngle = 1e-5

-- Below this angle (~0.57 degrees) faces used to be unconditionally treated as
-- parallel. Now the true angled solve is attempted first, and this instead
-- bounds where the parallel behavior is used as the *fallback* when that solve
-- requires an absurdly distant intersection or an impossible shrink. Above
-- this angle failed solves remain a no-op, as they always have been.
local kNearParallelSinAngle = 0.01

-- Bounds on how far a part may be extended to meet the true intersection of
-- two nearly parallel faces before falling back to the parallel behavior:
-- an Vector3.Abs bound of the Roblox max part size (larger isn't buildable), and
-- a relative bound of a multiple of the size of the geometry being operated
-- on (an intersection many times further away than the parts are large is not
-- what the user was aiming for).
local kMaxExtension = 2048
local kMaxExtensionFactor = 8

-- The type solver does not know that Vector3 and vector have the same runtime representation.
local function CAST_VECTOR(value: Vector3): vector
	return value :: any
end

local function CAST_VECTOR3(value: vector): Vector3
	return value :: any
end

local function CFrame_VectorToWorldSpace(cframe: CFrame, value: vector): vector
	return CAST_VECTOR(cframe:VectorToWorldSpace(CAST_VECTOR3(value)))
end

local function COLOR3_TO_VECTOR(color3: Color3): vector
	return vector.create(color3.R, color3.G, color3.B)
end

local function VECTOR_TO_COLOR3(vec: vector): Color3
	return Color3.new(vec.x, vec.y, vec.z)
end

local function getFacePoints(face: Face)
	local hsize = face.Object.Size / 2
	local cf = face.Object.CFrame
	if face.CornerWedgeSide == "Right" then
		-- Peak at E=(hx,hy,-hz). Right slope triangle ACE:
		-- A=(-hx,-hy,-hz), C=(-hx,-hy,hz), E=(hx,hy,-hz)
		return {
			cf:PointToWorldSpace(Vector3.new(-hsize.X, -hsize.Y, -hsize.Z)),
			cf:PointToWorldSpace(Vector3.new(-hsize.X, -hsize.Y, hsize.Z)),
			cf:PointToWorldSpace(Vector3.new(hsize.X, hsize.Y, -hsize.Z)),
		}
	elseif face.CornerWedgeSide == "Back" then
		-- Peak at E=(hx,hy,-hz). Back slope triangle CDE:
		-- C=(-hx,-hy,hz), D=(hx,-hy,hz), E=(hx,hy,-hz)
		return {
			cf:PointToWorldSpace(Vector3.new(-hsize.X, -hsize.Y, hsize.Z)),
			cf:PointToWorldSpace(Vector3.new(hsize.X, -hsize.Y, hsize.Z)),
			cf:PointToWorldSpace(Vector3.new(hsize.X, hsize.Y, -hsize.Z)),
		}
	elseif isCornerWedgeShape(face.Object) and face.Normal == Enum.NormalId.Front then
		-- Front face triangle ABE: A=(-hx,-hy,-hz), B=(hx,-hy,-hz), E=(hx,hy,-hz)
		return {
			cf:PointToWorldSpace(Vector3.new(-hsize.X, -hsize.Y, -hsize.Z)),
			cf:PointToWorldSpace(Vector3.new(hsize.X, -hsize.Y, -hsize.Z)),
			cf:PointToWorldSpace(Vector3.new(hsize.X, hsize.Y, -hsize.Z)),
		}
	elseif isCornerWedgeShape(face.Object) and face.Normal == Enum.NormalId.Right then
		-- Right face triangle BDE: B=(hx,-hy,-hz), D=(hx,-hy,hz), E=(hx,hy,-hz)
		return {
			cf:PointToWorldSpace(Vector3.new(hsize.X, -hsize.Y, -hsize.Z)),
			cf:PointToWorldSpace(Vector3.new(hsize.X, -hsize.Y, hsize.Z)),
			cf:PointToWorldSpace(Vector3.new(hsize.X, hsize.Y, -hsize.Z)),
		}
	elseif face.IsWedge then
		-- Slope face corners: top-back edge to bottom-front edge
		return {
			cf:PointToWorldSpace(Vector3.new(hsize.X, hsize.Y, hsize.Z)),
			cf:PointToWorldSpace(Vector3.new(-hsize.X, hsize.Y, hsize.Z)),
			cf:PointToWorldSpace(Vector3.new(hsize.X, -hsize.Y, -hsize.Z)),
			cf:PointToWorldSpace(Vector3.new(-hsize.X, -hsize.Y, -hsize.Z)),
		}
	else
		local faceDir = Vector3.fromNormalId(face.Normal)
		local faceA, faceB = otherNormals(faceDir)
		faceDir, faceA, faceB = faceDir * hsize, faceA * hsize, faceB * hsize
		return {
			cf:PointToWorldSpace(faceDir + faceA + faceB),
			cf:PointToWorldSpace(faceDir + faceA - faceB),
			cf:PointToWorldSpace(faceDir - faceA - faceB),
			cf:PointToWorldSpace(faceDir - faceA + faceB),
		}
	end
end

local function getPoints(part: BasePart): { Vector3 }
	local hsize = part.Size / 2
	local cf = part.CFrame
	local points = {}
	for i = -1, 1, 2 do
		for j = -1, 1, 2 do
			for k = -1, 1, 2 do
				table.insert(points, cf:PointToWorldSpace(Vector3.new(i, j, k) * hsize))
			end
		end
	end
	return points
end

local function getNormal(face: Face)
	if face.CornerWedgeSide then
		local hsize = face.Object.Size / 2
		local cf = face.Object.CFrame
		if face.CornerWedgeSide == "Right" then
			-- Outward normal direction in local space: (-hy, hx, 0)
			return (cf.YVector * hsize.X - cf.XVector * hsize.Y).Unit
		else
			-- Outward normal direction in local space: (0, hz, hy)
			return (cf.YVector * hsize.Z + cf.ZVector * hsize.Y).Unit
		end
	elseif face.IsWedge then
		local hsize = face.Object.Size / 2
		local cf = face.Object.CFrame
		return (cf.YVector * hsize.Z - cf.ZVector * hsize.Y).Unit
	else
		return face.Object.CFrame:VectorToWorldSpace(Vector3.fromNormalId(face.Normal))
	end
end

-- Returns true if the face can't be resized normally and must be extruded
local function isExtrusionFace(face: Face): boolean
	if face.IsWedge or face.CornerWedgeSide then
		return true
	end
	return false
end

local function getDimension(face: Face)
	if isExtrusionFace(face) then
		return Vector3.zero
	end
	local dir = Vector3.fromNormalId(face.Normal)
	return Vector3.new(math.abs(dir.X), math.abs(dir.Y), math.abs(dir.Z))
end

local function getBasis(face: Face)
	if face.IsWedge or face.CornerWedgeSide then
		return face.Object.Position, getNormal(face)
	else
		local hsize = face.Object.Size / 2
		local faceDir = Vector3.fromNormalId(face.Normal)
		local faceNormal = face.Object.CFrame:VectorToWorldSpace(faceDir)
		local facePoint = face.Object.CFrame:PointToWorldSpace(faceDir * hsize)
		return facePoint, faceNormal
	end
end

local function getPositivePointToFace(face: Face, points: { Vector3 }): Vector3
	local basePoint, normal = getBasis(face)
	local maxDist = -math.huge
	local maxPoint = nil
	for _, point in points do
		local dist = (point - basePoint):Dot(normal)
		if dist > maxDist then
			maxDist = dist
			maxPoint = point
		end
	end
	return maxPoint
end

local function getNegativePointToFace(face: Face, points: { Vector3 }): Vector3
	local basePoint, normal = getBasis(face)
	local minDist = math.huge
	local minPoint = nil
	for _, point in points do
		local dist = (point - basePoint):Dot(normal)
		if dist < minDist then
			minDist = dist
			minPoint = point
		end
	end
	return minPoint
end

local function resizePart(face: Face, delta: number)
	if face.CornerWedgeSide then
		if math.abs(delta) < 0.001 then
			return
		end
		local normal = getNormal(face)
		local cf = face.Object.CFrame
		local size = face.Object.Size
		local hsize = size / 2

		-- Peak at E=(hx,hy,-hz). The WedgePart right angle is at local (-SY/2, +SZ/2),
		-- so +Y maps to one leg and -Z maps to the other. The leg assignments must
		-- satisfy: normal:Cross(legUpDir) = -legAlongDir (the ZVector equation).
		local legUpDir, legUpLen, legAlongLen
		if face.CornerWedgeSide == "Right" then
			-- Right slope triangle ACE: A=(-hx,-hy,-hz), C=(-hx,-hy,hz), E=(hx,hy,-hz)
			-- Right angle at A. Y-axis = A→E, -Z axis = A→C.
			local A = cf:PointToWorldSpace(Vector3.new(-hsize.X, -hsize.Y, -hsize.Z))
			local C = cf:PointToWorldSpace(Vector3.new(-hsize.X, -hsize.Y, hsize.Z))
			local E = cf:PointToWorldSpace(Vector3.new(hsize.X, hsize.Y, -hsize.Z))
			legUpDir = (E - A).Unit
			legUpLen = (E - A).Magnitude
			legAlongLen = (C - A).Magnitude
		else
			-- Back slope triangle CDE: C=(-hx,-hy,hz), D=(hx,-hy,hz), E=(hx,hy,-hz)
			-- Right angle at D. Y-axis = D→C, -Z axis = D→E.
			local C = cf:PointToWorldSpace(Vector3.new(-hsize.X, -hsize.Y, hsize.Z))
			local D = cf:PointToWorldSpace(Vector3.new(hsize.X, -hsize.Y, hsize.Z))
			local E = cf:PointToWorldSpace(Vector3.new(hsize.X, hsize.Y, -hsize.Z))
			legUpDir = (C - D).Unit
			legUpLen = (C - D).Magnitude
			legAlongLen = (E - D).Magnitude
		end

		local wedge = Instance.new("WedgePart")
		copyPartProps(face.Object, wedge)
		wedge.Size = Vector3.new(delta, legUpLen, legAlongLen)
		wedge.CFrame = CFrame.fromMatrix(face.Object.Position + normal * (delta / 2), normal, legUpDir)
		wedge.Parent = face.Object.Parent
		wedge.Name = face.Object.Name .. "_Extended"
	elseif face.IsWedge then
		if math.abs(delta) < 0.001 then
			return
		end
		local point, normal = getBasis(face)
		local part = Instance.new("Part")
		copyPartProps(face.Object, part)
		part.CFrame = CFrame.fromMatrix(point + normal * 0.5 * delta, face.Object.CFrame.XVector, normal)
		local size = face.Object.Size
		part.Size = Vector3.new(size.X, delta, math.sqrt(size.Y ^ 2 + size.Z ^ 2))
		part.Parent = face.Object.Parent
		part.Name = face.Object.Name .. "_Extended"
	else
		local joiner = JointMaker.new(false)
		joiner:pickUpParts({ face.Object })
		joiner:breakJointsToOutsiders()

		local axis = Vector3.fromNormalId(face.Normal)
		face.Object.Size += Vector3.new(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z)) * delta
		face.Object.CFrame *= CFrame.new(axis * (delta / 2))

		if DraggerService.JointsEnabled then
			joiner:computeJointPairs():createJoints()
		end
		joiner:putDownParts()
	end
end

local function fillJoint(
	faceA: Face,
	faceB: Face,
	fillPoint: Vector3,
	fillAxis: Vector3,
	pointsA: { Vector3 },
	pointsB: { Vector3 },
	offsetA: Vector3,
	offsetB: Vector3,
	minRadius: number
)
	local maxProj = -math.huge
	local minProj = math.huge
	local maxRadius = -math.huge
	for _, point in pointsA do
		local modPoint = point + offsetA
		local proj = (modPoint - fillPoint):Dot(fillAxis)
		maxProj = math.max(maxProj, proj)
		minProj = math.min(minProj, proj)
		local toAxis = (modPoint - (fillPoint + fillAxis * proj)).Magnitude
		maxRadius = math.max(maxRadius, toAxis)
	end
	for _, point in pointsB do
		local modPoint = point + offsetB
		local proj = (modPoint - fillPoint):Dot(fillAxis)
		maxProj = math.max(maxProj, proj)
		minProj = math.min(minProj, proj)
	end
	local centerPoint = fillPoint + fillAxis * (0.5 * (minProj + maxProj))
	local length = (maxProj - minProj)
	-- A smaller filler than the faces need would leave the gap exposed
	local radius = math.max(maxRadius, minRadius)
	local cyl = Instance.new("Part")
	copyPartProps(faceB.Object, cyl)
	if ShapeUtils.isCylinder(faceA.Object) and ShapeUtils.isCylinder(faceB.Object) then
		cyl.Shape = Enum.PartType.Ball
	else
		cyl.Shape = Enum.PartType.Cylinder
	end
	cyl.Size = Vector3.new(length, 2 * radius, 2 * radius)
	cyl.CFrame = CFrame.fromMatrix(centerPoint, fillAxis, getNormal(faceB))
	cyl.Parent = faceB.Object.Parent
end

local function fillAcuteGap(face: Face, dirSelf: Vector3, dirOther: Vector3, crossAxis: Vector3, extraLen: number)
	if extraLen < 0.001 then
		return
	end

	local faceDir = Vector3.fromNormalId(face.Normal)
	local tangentA_local, tangentB_local = otherNormals(faceDir)
	local cf = face.Object.CFrame
	local tangentA_world = cf:VectorToWorldSpace(tangentA_local)
	local tangentB_world = cf:VectorToWorldSpace(tangentB_local)

	local crossTangent_local, perpTangent_local, perpTangent_world
	if math.abs(tangentA_world:Dot(crossAxis)) > math.abs(tangentB_world:Dot(crossAxis)) then
		crossTangent_local = tangentA_local
		perpTangent_local = tangentB_local
		perpTangent_world = tangentB_world
	else
		crossTangent_local = tangentB_local
		perpTangent_local = tangentA_local
		perpTangent_world = tangentA_world
	end

	-- The outer direction is toward the corner where the gap is largest
	local outerSign = if perpTangent_world:Dot(dirOther) > 0 then 1 else -1
	local outerDir = perpTangent_world * outerSign

	local size = face.Object.Size
	local crossHalf = math.abs(crossTangent_local:Dot(size)) / 2
	local perpHalf = math.abs(perpTangent_local:Dot(size)) / 2

	-- Face center point (post-resize, so already at the inner-touch position)
	local facePoint = getBasis(face)

	-- WedgePart orientation:
	-- Y = dirSelf (extension direction), Z (+back) = outerDir (full height at outer edge)
	-- Slope goes from zero height at inner edge to extraLen at outer edge
	local wedge = Instance.new("WedgePart")
	copyPartProps(face.Object, wedge)
	wedge.Size = Vector3.new(2 * crossHalf, extraLen, 2 * perpHalf)
	wedge.CFrame = CFrame.fromMatrix(facePoint + dirSelf * extraLen / 2, dirSelf:Cross(outerDir), dirSelf)
	wedge.Parent = face.Object.Parent
end

-- Slopes use the same rectangular/triangular extrusion profiles as resizePart.
-- Their selected normal is not one of the original part's cardinal axes.
local function getSplineFace(face: Face): (CFrame, vector, vector, ("Part" | "WedgePart")?)
	local part = face.Object
	local cf = part.CFrame
	local size = part.Size
	local point, normal = getBasis(face)
	local depth = vector.dot(vector.abs(cf:VectorToObjectSpace(normal) :: any), size :: any)

	if face.CornerWedgeSide then
		local up, height, width

		if face.CornerWedgeSide == "Right" then
			height = math.sqrt(size.X * size.X + size.Y * size.Y)
			up = (cf.XVector * size.X + cf.YVector * size.Y) / height
			width = size.Z
		else
			height = size.X
			up = -cf.XVector
			width = math.sqrt(size.Y * size.Y + size.Z * size.Z)
		end

		return CFrame.fromMatrix(point, normal, up),
			vector.create(depth, height, width),
			vector.create(1, 0, 0),
			"WedgePart"
	elseif face.IsWedge then
		local width = math.sqrt(size.Y * size.Y + size.Z * size.Z)
		return CFrame.fromMatrix(point, cf.XVector, normal),
			vector.create(size.X, depth, width),
			vector.create(0, 1, 0),
			"Part"
	end
	return CFrame.new(point) * cf.Rotation, size :: any, Vector3.fromNormalId(face.Normal) :: any, nil
end

-- Rounded Join passes how far to resize each part before joining them, which
-- sets its two parts back from their corner. Spline Join leaves both parts alone.
local function createSplineJoin(faceA: Face, faceB: Face, segmentCount: number?, resizeA: number?, resizeB: number?)
	local paddingA = resizeA or 0
	local paddingB = resizeB or 0
	-- Rounded Join has already chosen both endpoints, so they are not refitted
	local fitSurface = resizeA == nil and resizeB == nil

	local frameA, profileA, localNormalA, extrusionClass = getSplineFace(faceA)
	local frameB, profileB, localNormalB = getSplineFace(faceB)
	local pointA = frameA.Position :: any
	local pointB = frameB.Position :: any
	local normalA = CFrame_VectorToWorldSpace(frameA, localNormalA)
	local normalB = CFrame_VectorToWorldSpace(frameB, localNormalB)
	local startPoint = pointA + normalA * paddingA
	local startFrame = CFrame.new(startPoint :: any) * frameA.Rotation
	local endPoint, surfaceOffset, targetRotation = SplineJoin.getTargetPoint(
		startFrame,
		CFrame.new((pointB + normalB * paddingB) :: any) * frameB.Rotation,
		profileA,
		profileB,
		localNormalA,
		localNormalB
	)

	local temporaryTemplate: BasePart?
	local template = faceA.Object

	if extrusionClass then
		local extrusion = if extrusionClass == "WedgePart" then WEDGE_PART:Clone() else Instance.new("Part")
		copyPartProps(template, extrusion)
		extrusion.Name = template.Name
		extrusion.Size = profileA :: any
		template = extrusion
		temporaryTemplate = extrusion
	end

	local parts = SplineJoin.plan(
		template,
		startFrame,
		endPoint,
		normalB,
		localNormalA,
		segmentCount,
		if fitSurface then surfaceOffset else nil,
		targetRotation
	)

	if temporaryTemplate then
		temporaryTemplate:Destroy()
	end

	if not parts then
		error("Spline Join: the segment count or resulting segment sizes cannot form a join.")
	end

	-- Color and Transparency are the visual properties that can be blended, so
	-- when the two parts differ in them, fade from one to the other along the
	-- spline. Each segment takes the blend at its middle, measured by length.
	local objectA = faceA.Object
	local objectB = faceB.Object
	local transparencyA = objectA.Transparency
	local transparencyB = objectB.Transparency
	local colorA = objectA.Color
	local colorB = objectB.Color

	if colorA ~= colorB or transparencyA ~= transparencyB then
		local transparencyDiff = transparencyB - transparencyA
		local lengthAxis = vector.abs(localNormalA)
		local totalLength = 0

		colorA = COLOR3_TO_VECTOR(colorA)
		colorB = COLOR3_TO_VECTOR(colorB)

		for _, part in parts do
			totalLength += vector.dot(part.Size :: any, lengthAxis)
		end

		local coveredLength = 0
		for _, part in parts do
			local length = vector.dot(part.Size :: any, lengthAxis)
			local alpha = (coveredLength + length / 2) / totalLength
			coveredLength += length
			part.Color = VECTOR_TO_COLOR3(vector.lerp(colorA, colorB, alpha))
			part.Transparency = math.lerp(transparencyA, transparencyDiff, alpha)
		end
	end

	local recording = ChangeHistoryService:TryBeginRecording("ResizeAlign")

	if paddingA ~= 0 then
		resizePart(faceA, paddingA)
	end

	if paddingB ~= 0 then
		resizePart(faceB, paddingB)
	end

	local parent = objectA.Parent

	for _, part in parts do
		part.Parent = parent
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end

local function doExtend(
	faceA: Face,
	faceB: Face,
	resizeMode: ResizeMode,
	acuteWedgeJoin: boolean?,
	splineJoinSegments: number?,
	useCylinderForRoundedJoin: boolean?,
	roundedJoinRadius: number?
)
	local pointsA = getFacePoints(faceA)
	local pointsB = getFacePoints(faceB)
	local localDimensionA = getDimension(faceA)
	local localDimensionB = getDimension(faceB)
	local dirA = getNormal(faceA)
	local dirB = getNormal(faceB)

	-- Sine of the angle between the faces via the cross product, which stays
	-- well-conditioned at small angles (1 - cos^2 suffers cancellation there)
	local sinAngle = dirA:Cross(dirB).Magnitude

	-- Resize faceA to meet the plane of faceB. Used when the faces are
	-- parallel, or so close to parallel that meeting at the true intersection
	-- of the faces is not buildable.
	local function doParallelResize()
		local extendPointA, extendPointB
		if resizeMode == "ExtendUpTo" or resizeMode == "InnerTouch" then
			extendPointA = getNegativePointToFace(faceB, pointsA)
			extendPointB = getNegativePointToFace(faceA, pointsB)
		else
			extendPointA = getPositivePointToFace(faceB, pointsA)
			extendPointB = getPositivePointToFace(faceA, pointsB)
		end

		local lenA = (extendPointA - extendPointB):Dot(dirB)
		if dirA:Dot(dirB) > 0 then
			lenA = -lenA
		end
		if isExtrusionFace(faceA) then
			if lenA < 0 then
				return
			end
		else
			local extendableA = (localDimensionA * faceA.Object.Size).Magnitude
			if lenA < -extendableA then
				return
			end
		end

		local recording = ChangeHistoryService:TryBeginRecording("ResizeAlign")
		resizePart(faceA, lenA)
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
	end

	if resizeMode ~= "SplineJoin" and sinAngle < kParallelSinAngle then
		doParallelResize()
		return
	end

	if resizeMode == "SplineJoin" then
		local pointA = getBasis(faceA)
		local pointB = getBasis(faceB)
		local chord = pointB - pointA
		local chordLength = chord.Magnitude
		-- Parallel faces with a sideways offset still need a spline (TOPRAIL→C).
		-- Collinear facing faces are a straight Outer Touch, not a spline.
		if
			chordLength > 0.001
			and dirA:Dot(chord) >= 0.999 * chordLength
			and (-dirB):Dot(chord) >= 0.999 * chordLength
		then
			doParallelResize()
			return
		end

		-- Zero, like leaving it out, chooses the segment count automatically
		createSplineJoin(faceA, faceB, if splineJoinSegments == 0 then nil else splineJoinSegments)
		return
	end

	-- Two cylinders always get the sphere filler from fillJoint. The cylinder
	-- filler is the default, so only an explicit false picks the spline.
	local isCylinderPair = ShapeUtils.isCylinder(faceA.Object) and ShapeUtils.isCylinder(faceB.Object)
	local useSplineFiller = useCylinderForRoundedJoin == false and not isCylinderPair
	-- The sphere between two cylinders has to match their radius, so the
	-- radius option does not apply to it
	local minFillerRadius = if isCylinderPair then 0 else roundedJoinRadius or 0

	local extendPointA, extendPointB
	local roundedRadius: number? = nil
	if
		resizeMode == "ExtendInto"
		or resizeMode == "OuterTouch"
		or resizeMode == "WedgeJoin"
		or resizeMode == "ButtJoint"
	then
		extendPointA = getPositivePointToFace(faceB, pointsA)
		extendPointB = getPositivePointToFace(faceA, pointsB)
	elseif resizeMode == "ExtendUpTo" or resizeMode == "InnerTouch" then
		extendPointA = getNegativePointToFace(faceB, pointsA)
		extendPointB = getNegativePointToFace(faceA, pointsB)
	elseif resizeMode == "RoundedJoin" then
		extendPointA = getBasis(faceA)
		local fillAxis = dirA:Cross(dirB).Unit
		local radiusA = -math.huge
		for _, point in pointsA do
			local projPoint = extendPointA + fillAxis * (point - extendPointA):Dot(fillAxis)
			radiusA = math.max(radiusA, (point - projPoint).Magnitude)
		end
		roundedRadius = radiusA

		-- The filler is centered where lines running fillerRadius inside the
		-- outer surface of each part cross, making it tangent to both surfaces.
		-- The spline filler measures its own radius back from where the
		-- center lines cross, so it keeps the automatic radius here.
		local fillerRadius = if useSplineFiller then radiusA else math.max(radiusA, minFillerRadius)
		if fillerRadius > radiusA then
			local outerPointA = getPositivePointToFace(faceB, pointsA)
			local onAxisA = extendPointA + fillAxis * (outerPointA - extendPointA):Dot(fillAxis)
			extendPointA += (onAxisA - outerPointA).Unit * (fillerRadius - radiusA)
		end
		local centerPointB = getBasis(faceB)
		extendPointB = getPositivePointToFace(faceA, pointsB)
		local proj = (extendPointB - centerPointB):Dot(fillAxis)
		local projPoint = centerPointB + fillAxis * proj
		local distanceToAxis = (extendPointB - projPoint).Magnitude
		local frac = fillerRadius / distanceToAxis
		extendPointB = extendPointB:Lerp(projPoint, frac)
	else
		error("unreachable")
	end

	local startSep = extendPointB - extendPointA
	-- Closest-point-of-two-rays solve in cross product form, which keeps its
	-- precision at small angles. The classical dot product form
	-- (b*e - c*d) / (a*c - b*b) catastrophically cancels for nearly parallel
	-- rays, amplifying float32 input noise by 1/sin^2(angle).
	local crossDir = dirA:Cross(dirB)
	local denom = sinAngle * sinAngle

	local lenA = startSep:Cross(dirB):Dot(crossDir) / denom
	local lenB = startSep:Cross(dirA):Dot(crossDir) / denom

	-- For acute angles with OuterTouch, use InnerTouch + wedge fill for a sharp point
	local acuteOuterTouch = resizeMode == "WedgeJoin"
		or (resizeMode == "OuterTouch" and acuteWedgeJoin == true and dirA:Dot(dirB) > 0)
	local outerLenA, outerLenB
	if acuteOuterTouch then
		outerLenA, outerLenB = lenA, lenB
		local innerPointA = getNegativePointToFace(faceB, pointsA)
		local innerPointB = getNegativePointToFace(faceA, pointsB)
		local innerSep = innerPointB - innerPointA
		lenA = innerSep:Cross(dirB):Dot(crossDir) / denom
		lenB = innerSep:Cross(dirA):Dot(crossDir) / denom
	end

	local extendableA = (localDimensionA * faceA.Object.Size).Magnitude
	local extendableB = (localDimensionB * faceB.Object.Size).Magnitude

	-- Whether the parallel behavior should be used as the fallback if the
	-- angled solve turns out to require something unreasonable.
	local nearParallel = sinAngle < kNearParallelSinAngle

	-- The faces are angled, but if they're only barely angled and meeting at
	-- the true intersection requires an unreasonably large resize, do the
	-- parallel behavior instead. (ExtendInto/ExtendUpTo are exempt: they
	-- recompute their extension below by projection onto the target plane,
	-- which never blows up at small angles.)
	if nearParallel and resizeMode ~= "ExtendInto" and resizeMode ~= "ExtendUpTo" then
		local maxLen = math.max(math.abs(lenA), math.abs(lenB))
		if acuteOuterTouch then
			maxLen = math.max(maxLen, math.abs(outerLenA), math.abs(outerLenB))
		end
		local operationScale = extendableA + extendableB + startSep.Magnitude
		if maxLen > math.min(kMaxExtension, kMaxExtensionFactor * operationScale) then
			doParallelResize()
			return
		end
	end

	if resizeMode == "ExtendInto" or resizeMode == "ExtendUpTo" then
		local denom2 = dirA:Dot(dirB)
		if math.abs(denom2) > 0.0001 and not isExtrusionFace(faceA) then
			lenA = -(extendPointA - extendPointB):Dot(dirB) / denom2
			lenB = 0
		else
			local points = getPoints(faceB.Object)
			if resizeMode == "ExtendUpTo" then
				local smallestLen = math.huge
				for _, v in points do
					local dist = (v - extendPointA):Dot(getNormal(faceA))
					if dist < smallestLen then
						smallestLen = dist
					end
				end
				lenA = smallestLen
			elseif resizeMode == "ExtendInto" then
				local largestLen = -math.huge
				for _, v in points do
					local dist = (v - extendPointA):Dot(getNormal(faceA))
					if dist > largestLen then
						largestLen = dist
					end
				end
				lenA = largestLen
			end
			lenB = 0
		end
	end

	if lenA < -extendableA then
		if isExtrusionFace(faceA) then
			lenA = 0
		else
			-- Impossible shrink. If the faces are barely angled this used to
			-- get the parallel behavior, so fall back to it rather than
			-- silently doing nothing.
			if nearParallel then
				doParallelResize()
			end
			return
		end
	end
	if lenB < -extendableB then
		if isExtrusionFace(faceB) then
			lenB = 0
		else
			if nearParallel then
				doParallelResize()
			end
			return
		end
	end

	if roundedRadius and useSplineFiller then
		-- Preserve Rounded Join's original intersection and filler radius.
		-- For a fillet of radius R, the tangent points sit R*tan(turn/2)
		-- back from that intersection along each of the two source parts.
		local turn = math.acos(math.clamp(-dirA:Dot(dirB), -1, 1))
		-- The radius option measures the outside of the bend, as it does for
		-- the cylinder filler, while the spline is planned along its center
		-- line, which runs roundedRadius inside that. The automatic bend,
		-- whose center line has that same radius, is the tightest allowed.
		local centerRadius = math.max(roundedRadius, (roundedJoinRadius or 0) - roundedRadius)
		local setback = centerRadius * math.tan(turn / 2)
		local paddingA, paddingB = lenA - setback, lenB - setback
		if paddingA <= -extendableA + 0.001 or paddingB <= -extendableB + 0.001 then
			return
		end
		createSplineJoin(faceA, faceB, nil, paddingA, paddingB)
		return
	end

	local recording = ChangeHistoryService:TryBeginRecording("ResizeAlign")

	resizePart(faceA, lenA)
	resizePart(faceB, lenB)

	if acuteOuterTouch then
		local crossAxis = dirA:Cross(dirB).Unit
		if not faceA.IsWedge and not faceA.CornerWedgeSide then
			fillAcuteGap(faceA, dirA, dirB, crossAxis, outerLenA - lenA)
		end
		if not faceB.IsWedge and not faceB.CornerWedgeSide then
			fillAcuteGap(faceB, dirB, dirA, crossAxis, outerLenB - lenB)
		end
	end

	if resizeMode == "RoundedJoin" then
		local fillAxis = dirA:Cross(dirB).Unit
		fillJoint(
			faceA,
			faceB,
			extendPointA + dirA * lenA,
			fillAxis,
			pointsA,
			pointsB,
			dirA * lenA,
			dirB * lenB,
			minFillerRadius
		)
	end

	if resizeMode == "ButtJoint" then
		local points = getFacePoints(faceB)
		local minV = math.huge
		local maxV = -math.huge
		for _, v in points do
			local proj = (v - extendPointA):Dot(dirA)
			if proj < minV then
				minV = proj
			end
			if proj > maxV then
				maxV = proj
			end
		end
		resizePart(faceA, -(maxV - minV))
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end

return doExtend
