local ChangeHistoryService = game:GetService("ChangeHistoryService")
local DraggerService = game:GetService("DraggerService")

local Src = script.Parent
local Packages = Src.Parent.Packages

local DraggerFramework = require(Packages.DraggerFramework)
local JointMaker = require(DraggerFramework.Utility.JointMaker)

local copyPartProps = require(Src.copyPartProps)

export type Face = {
	Object: BasePart,
	Normal: Enum.NormalId,
	IsWedge: boolean?,
}

export type ResizeMode = "OuterTouch" | "InnerTouch" | "WedgeJoin" | "RoundedJoin" | "ButtJoint" | "ExtendUpTo" | "ExtendInto"

local function otherNormals(dir: Vector3)
	if math.abs(dir.X) > 0 then
		return Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
	elseif math.abs(dir.Y) > 0 then
		return Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
	else
		return Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
	end
end

local function getFacePoints(face: Face)
	local hsize = face.Object.Size / 2
	local cf = face.Object.CFrame
	if face.IsWedge then
		return {
			cf:PointToWorldSpace((Vector3.xAxis + Vector3.yAxis + Vector3.zAxis) * hsize),
			cf:PointToWorldSpace((Vector3.xAxis + Vector3.yAxis + Vector3.zAxis) * hsize),
			cf:PointToWorldSpace((-Vector3.xAxis - Vector3.yAxis - Vector3.zAxis) * hsize),
			cf:PointToWorldSpace((-Vector3.xAxis - Vector3.yAxis - Vector3.zAxis) * hsize),
		}
	else
		local faceDir = Vector3.fromNormalId(face.Normal)
		local faceA, faceB = otherNormals(faceDir)
		faceDir, faceA, faceB = faceDir*hsize, faceA*hsize, faceB*hsize
		return {
			cf:PointToWorldSpace(faceDir + faceA + faceB);
			cf:PointToWorldSpace(faceDir + faceA - faceB);
			cf:PointToWorldSpace(faceDir - faceA - faceB);
			cf:PointToWorldSpace(faceDir - faceA + faceB);
		}
	end
end

local function getPoints(part: BasePart): {Vector3}
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
	if face.IsWedge then
		local hsize = face.Object.Size / 2
		local cf = face.Object.CFrame
		return (cf.YVector * hsize.Z - cf.ZVector * hsize.Y).Unit
	else
		return face.Object.CFrame:VectorToWorldSpace(Vector3.fromNormalId(face.Normal))
	end
end

local function getDimension(face: Face)
	if face.IsWedge then
		return Vector3.zero
	else
		local dir = Vector3.fromNormalId(face.Normal)
		return Vector3.new(math.abs(dir.X), math.abs(dir.Y), math.abs(dir.Z))
	end
end

local function getBasis(face: Face)
	if face.IsWedge then
		return face.Object.Position, getNormal(face)
	else
		local hsize = face.Object.Size / 2
		local faceDir = Vector3.fromNormalId(face.Normal)
		local faceNormal = face.Object.CFrame:VectorToWorldSpace(faceDir)
		local facePoint = face.Object.CFrame:PointToWorldSpace(faceDir * hsize)
		return facePoint, faceNormal
	end
end

local function getPositivePointToFace(face: Face, points: {Vector3}): Vector3
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

local function getNegativePointToFace(face: Face, points: {Vector3}): Vector3
	local basePoint, normal = getBasis(face)
	local minDist = math.huge
	local minPoint = nil
	for _, point in pairs(points) do
		local dist = (point - basePoint):Dot(normal)
		if dist < minDist then
			minDist = dist
			minPoint = point
		end
	end
	return minPoint
end

local function isCylinder(part: BasePart)
	return part:IsA("Part") and part.Shape == Enum.PartType.Cylinder
end

local function resizePart(face: Face, delta: number)
	if face.IsWedge then
		if math.abs(delta) < 0.001 then
			return
		end
		local point, normal = getBasis(face)
		local part = Instance.new("Part")
		copyPartProps(face.Object, part)
		part.CFrame = CFrame.fromMatrix(point + normal * 0.5 * delta, face.Object.CFrame.XVector, normal)
		local size = face.Object.Size
		part.Size = Vector3.new(size.X, delta, math.sqrt(size.Y^2 + size.Z^2))
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = face.Object.Parent
		part.Name = face.Object.Name.."_Extended"
	else
		local joiner = JointMaker.new(false)
		joiner:pickUpParts({face.Object})
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

local function fillJoint(faceA: Face, faceB: Face, fillPoint: Vector3, fillAxis: Vector3, pointsA: {Vector3}, pointsB: {Vector3}, offsetA: Vector3, offsetB: Vector3)
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
	local radius = maxRadius
	local cyl = Instance.new("Part")
	if isCylinder(faceA.Object) and isCylinder(faceB.Object) then
		cyl.Shape = Enum.PartType.Ball
	else
		cyl.Shape = Enum.PartType.Cylinder
	end
	cyl.TopSurface = Enum.SurfaceType.Smooth
	cyl.BottomSurface = Enum.SurfaceType.Smooth
	copyPartProps(faceB.Object, cyl)
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
	wedge.CFrame = CFrame.fromMatrix(
		facePoint + dirSelf * extraLen / 2,
		dirSelf:Cross(outerDir),
		dirSelf
	)
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = face.Object.Parent
end

local function doExtend(faceA: Face, faceB: Face, resizeMode: ResizeMode, acuteWedgeJoin: boolean?)
	local pointsA = getFacePoints(faceA)
	local pointsB = getFacePoints(faceB)
	local localDimensionA = getDimension(faceA)
	local localDimensionB = getDimension(faceB)
	local dirA = getNormal(faceA)
	local dirB = getNormal(faceB)

	local a, b, c = dirA:Dot(dirA), dirA:Dot(dirB), dirB:Dot(dirB)
	local denom = a*c - b*b
	local isParallel = math.abs(denom) < 0.001

	local extendPointA, extendPointB;
	if resizeMode == "ExtendInto" or resizeMode == "OuterTouch" or resizeMode == "WedgeJoin" or resizeMode == "ButtJoint" or (isParallel and resizeMode == "RoundedJoin") then
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
		local centerPointB = getBasis(faceB)
		extendPointB = getPositivePointToFace(faceA, pointsB)
		local proj = (extendPointB - centerPointB):Dot(fillAxis)
		local projPoint = centerPointB + fillAxis * proj
		local distanceToAxis = (extendPointB - projPoint).Magnitude
		local frac = radiusA / distanceToAxis
		extendPointB = extendPointB:Lerp(projPoint, frac)
	else
		error("unreachable")
	end

	local startSep = extendPointB - extendPointA
	local d, e = dirA:Dot(startSep), dirB:Dot(startSep)

	if isParallel then
		local lenA = (extendPointA - extendPointB):Dot(getNormal(faceB))
		if faceA.IsWedge then
			if lenA < 0 then
				return
			end
		else
			local extendableA = (localDimensionA * faceA.Object.Size).Magnitude
			if getNormal(faceA):Dot(getNormal(faceB)) > 0 then
				lenA = -lenA
			end
			if lenA < -extendableA then
				return
			end
		end

		local recording = ChangeHistoryService:TryBeginRecording("ResizeAlign")
		resizePart(faceA, lenA)
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
		return
	end

	local lenA = -(b*e - c*d) / denom
	local lenB = -(a*e - b*d) / denom

	-- For acute angles with OuterTouch, use InnerTouch + wedge fill for a sharp point
	local acuteOuterTouch = resizeMode == "WedgeJoin"
		or (resizeMode == "OuterTouch" and acuteWedgeJoin == true and dirA:Dot(dirB) > 0)
	local outerLenA, outerLenB
	if acuteOuterTouch then
		outerLenA, outerLenB = lenA, lenB
		local innerPointA = getNegativePointToFace(faceB, pointsA)
		local innerPointB = getNegativePointToFace(faceA, pointsB)
		local innerSep = innerPointB - innerPointA
		local id, ie = dirA:Dot(innerSep), dirB:Dot(innerSep)
		lenA = -(b*ie - c*id) / denom
		lenB = -(a*ie - b*id) / denom
	end

	if resizeMode == "ExtendInto" or resizeMode == "ExtendUpTo" then
		local denom2 = dirA:Dot(dirB)
		if math.abs(denom2) > 0.0001 then
			lenA = - (extendPointA - extendPointB):Dot(dirB) / denom2
			lenB = 0
		else
			local points = getPoints(faceB.Object)
			if resizeMode == "ExtendUpTo" then
				local smallestLen = math.huge
				for _, v in pairs(points) do
					local dist = (v - extendPointA):Dot(getNormal(faceA))
					if dist < smallestLen then
						smallestLen = dist
					end
				end
				lenA = smallestLen
			elseif resizeMode == "ExtendInto" then
				local largestLen = -math.huge
				for _, v in pairs(points) do
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

	local extendableA = (localDimensionA * faceA.Object.Size).Magnitude
	local extendableB = (localDimensionB * faceB.Object.Size).Magnitude
	if lenA < -extendableA then
		return
	end
	if lenB < -extendableB then
		return
	end

	local recording = ChangeHistoryService:TryBeginRecording("ResizeAlign")

	resizePart(faceA, lenA)
	resizePart(faceB, lenB)

	if acuteOuterTouch then
		local crossAxis = dirA:Cross(dirB).Unit
		if not faceA.IsWedge then
			fillAcuteGap(faceA, dirA, dirB, crossAxis, outerLenA - lenA)
		end
		if not faceB.IsWedge then
			fillAcuteGap(faceB, dirB, dirA, crossAxis, outerLenB - lenB)
		end
	end

	if resizeMode == "RoundedJoin" then
		local fillAxis = dirA:Cross(dirB).Unit
		fillJoint(faceA, faceB, extendPointA + dirA * lenA, fillAxis, pointsA, pointsB, dirA * lenA, dirB * lenB)
	end

	if resizeMode == "ButtJoint" then
		local points = getFacePoints(faceB)
		local minV =  math.huge
		local maxV = -math.huge
		for _, v in pairs(points) do
			local proj = (v - extendPointA):Dot(dirA)
			if proj < minV then minV = proj end
			if proj > maxV then maxV = proj end
		end
		resizePart(faceA, -(maxV - minV))
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end

return doExtend
