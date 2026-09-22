--!strict
local Src = script.Parent
local Packages = Src.Parent.Packages
local React = require(Packages.React)

local Colors = require("./PluginGui/Colors")
local Settings = require("./Settings")
local SplineJoin = require("./SplineJoin")
local ShapeUtils = require("./ShapeUtils")

local e = React.createElement

type ResizeMode = Settings.ResizeMode

local otherNormals = ShapeUtils.otherNormals

local PART_A_COLOR = Color3.fromRGB(200, 50, 50)
local PART_B_COLOR = Color3.fromRGB(50, 80, 220)
local FILLER_COLOR = Color3.fromRGB(80, 200, 50)

--------------------------------------------------------------------------------
-- Geometry helpers (mirrors doExtend logic for demo computation)
--------------------------------------------------------------------------------

local function getFaceCorners(cf: CFrame, size: Vector3, normalId: Enum.NormalId): { Vector3 }
	local hsize = size / 2
	local faceDir = Vector3.fromNormalId(normalId)
	local ax, bx = otherNormals(faceDir)
	local fd = faceDir * hsize
	local fa = ax * hsize
	local fb = bx * hsize
	return {
		cf:PointToWorldSpace(fd + fa + fb),
		cf:PointToWorldSpace(fd + fa - fb),
		cf:PointToWorldSpace(fd - fa - fb),
		cf:PointToWorldSpace(fd - fa + fb),
	}
end

local function getFaceBasis(cf: CFrame, size: Vector3, normalId: Enum.NormalId): (Vector3, Vector3)
	local hsize = size / 2
	local faceDir = Vector3.fromNormalId(normalId)
	return cf:PointToWorldSpace(faceDir * hsize), cf:VectorToWorldSpace(faceDir)
end

local function maxPointToPlane(basePoint: Vector3, normal: Vector3, points: { Vector3 }): Vector3
	local best = -math.huge
	local result = points[1]
	for _, p in points do
		local d = (p - basePoint):Dot(normal)
		if d > best then
			best = d
			result = p
		end
	end
	return result
end

local function minPointToPlane(basePoint: Vector3, normal: Vector3, points: { Vector3 }): Vector3
	local best = math.huge
	local result = points[1]
	for _, p in points do
		local d = (p - basePoint):Dot(normal)
		if d < best then
			best = d
			result = p
		end
	end
	return result
end

--------------------------------------------------------------------------------
-- Compute extended CFrame and Size for a part after resizing a face by delta
--------------------------------------------------------------------------------

local function computeExtended(cf: CFrame, size: Vector3, face: Enum.NormalId, delta: number)
	local axis = Vector3.fromNormalId(face)
	local sizeAxis = Vector3.new(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z))
	return {
		CFrame = cf * CFrame.new(axis * (delta / 2)),
		Size = size + sizeAxis * delta,
	}
end

--------------------------------------------------------------------------------
-- Compute demo deltas for a given mode (mirrors doExtend.lua algorithm)
--------------------------------------------------------------------------------

type FaceSpec = {
	cf: CFrame,
	size: Vector3,
	face: Enum.NormalId,
}

local function computeDemoDeltas(fA: FaceSpec, fB: FaceSpec, mode: ResizeMode): (number, number, any?, Vector3)
	local pointsA = getFaceCorners(fA.cf, fA.size, fA.face)
	local pointsB = getFaceCorners(fB.cf, fB.size, fB.face)
	local dirA = fA.cf:VectorToWorldSpace(Vector3.fromNormalId(fA.face))
	local dirB = fB.cf:VectorToWorldSpace(Vector3.fromNormalId(fB.face))
	local basisA = getFaceBasis(fA.cf, fA.size, fA.face)
	local basisB = getFaceBasis(fB.cf, fB.size, fB.face)

	local a, b, c = dirA:Dot(dirA), dirA:Dot(dirB), dirB:Dot(dirB)
	local denom = a * c - b * b

	-- Select extend points based on mode
	local extendPointA: Vector3
	local extendPointB: Vector3

	if mode == "OuterTouch" or mode == "WedgeJoin" or mode == "ButtJoint" or mode == "ExtendInto" then
		extendPointA = maxPointToPlane(basisB, dirB, pointsA)
		extendPointB = maxPointToPlane(basisA, dirA, pointsB)
	elseif mode == "InnerTouch" or mode == "ExtendUpTo" then
		extendPointA = minPointToPlane(basisB, dirB, pointsA)
		extendPointB = minPointToPlane(basisA, dirA, pointsB)
	elseif mode == "RoundedJoin" then
		extendPointA = basisA
		local fillAxis = dirA:Cross(dirB).Unit
		local radiusA = -math.huge
		for _, point in pointsA do
			local projPt = extendPointA + fillAxis * (point - extendPointA):Dot(fillAxis)
			radiusA = math.max(radiusA, (point - projPt).Magnitude)
		end
		extendPointB = maxPointToPlane(basisA, dirA, pointsB)
		local proj = (extendPointB - basisB):Dot(fillAxis)
		local projPt = basisB + fillAxis * proj
		local distToAxis = (extendPointB - projPt).Magnitude
		extendPointB = extendPointB:Lerp(projPt, radiusA / distToAxis)
	end

	-- Solve for extension lengths
	local startSep = extendPointB - extendPointA
	local d_val = dirA:Dot(startSep)
	local e_val = dirB:Dot(startSep)
	local lenA = -(b * e_val - c * d_val) / denom
	local lenB = -(a * e_val - b * d_val) / denom

	-- ExtendUpTo / ExtendInto: only Part A moves
	if mode == "ExtendUpTo" or mode == "ExtendInto" then
		local denom2 = dirA:Dot(dirB)
		if math.abs(denom2) > 0.0001 then
			lenA = -(extendPointA - extendPointB):Dot(dirB) / denom2
			lenB = 0
		end
	end

	-- ButtJoint: shrink Part A by the face-B width projection
	if mode == "ButtJoint" then
		local axisB = Vector3.fromNormalId(fB.face)
		local sizeAxisB = Vector3.new(math.abs(axisB.X), math.abs(axisB.Y), math.abs(axisB.Z))
		local newBCF = fB.cf * CFrame.new(axisB * (lenB / 2))
		local newBSize = fB.size + sizeAxisB * lenB
		local newPointsB = getFaceCorners(newBCF, newBSize, fB.face)
		local minV, maxV = math.huge, -math.huge
		for _, v in newPointsB do
			local proj = (v - extendPointA):Dot(dirA)
			if proj < minV then
				minV = proj
			end
			if proj > maxV then
				maxV = proj
			end
		end
		lenA += -(maxV - minV)
	end

	-- WedgeJoin: recompute with inner extend points, build wedge fillers
	local fillerData = nil
	local innerExtendPointA: Vector3? = nil
	if mode == "WedgeJoin" then
		local outerLenA, outerLenB = lenA, lenB
		local innerPointA = minPointToPlane(basisB, dirB, pointsA)
		innerExtendPointA = innerPointA
		local innerPointB = minPointToPlane(basisA, dirA, pointsB)
		local innerSep = innerPointB - innerPointA
		local id_val = dirA:Dot(innerSep)
		local ie_val = dirB:Dot(innerSep)
		lenA = -(b * ie_val - c * id_val) / denom
		lenB = -(a * ie_val - b * id_val) / denom

		local crossAxis = dirA:Cross(dirB)
		if crossAxis.Magnitude > 0.001 then
			crossAxis = crossAxis.Unit
		end

		local function computeWedge(
			fSpec: FaceSpec,
			dirSelf: Vector3,
			dirOther: Vector3,
			innerLen: number,
			extraLen: number
		)
			local axisF = Vector3.fromNormalId(fSpec.face)
			local sizeAxisF = Vector3.new(math.abs(axisF.X), math.abs(axisF.Y), math.abs(axisF.Z))
			local newCF = fSpec.cf * CFrame.new(axisF * (innerLen / 2))
			local newSize = fSpec.size + sizeAxisF * innerLen
			local facePoint = getFaceBasis(newCF, newSize, fSpec.face)

			local faceDir = Vector3.fromNormalId(fSpec.face)
			local tangentA_local, tangentB_local = otherNormals(faceDir)
			local tangentA_world = newCF:VectorToWorldSpace(tangentA_local)
			local tangentB_world = newCF:VectorToWorldSpace(tangentB_local)

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

			local outerSign = if perpTangent_world:Dot(dirOther) > 0 then 1 else -1
			local outerDir = perpTangent_world * outerSign
			local crossHalf = math.abs(crossTangent_local:Dot(newSize)) / 2
			local perpHalf = math.abs(perpTangent_local:Dot(newSize)) / 2

			return {
				CFrame = CFrame.fromMatrix(facePoint + dirSelf * extraLen / 2, dirSelf:Cross(outerDir), dirSelf),
				Size = Vector3.new(2 * crossHalf, extraLen, 2 * perpHalf),
			}
		end

		local extraA = outerLenA - lenA
		local extraB = outerLenB - lenB
		local wedges = {}
		if extraA > 0.001 then
			table.insert(wedges, computeWedge(fA, dirA, dirB, lenA, extraA))
		end
		if extraB > 0.001 then
			table.insert(wedges, computeWedge(fB, dirB, dirA, lenB, extraB))
		end
		if #wedges > 0 then
			fillerData = { wedges = wedges }
		end
	end

	-- RoundedJoin: compute filler cylinder
	if mode == "RoundedJoin" then
		local fillAxis = dirA:Cross(dirB).Unit
		local fillPoint = extendPointA + dirA * lenA
		local maxProj, minProj, maxRadius = -math.huge, math.huge, -math.huge
		for _, p in pointsA do
			local mp = p + dirA * lenA
			local proj = (mp - fillPoint):Dot(fillAxis)
			maxProj = math.max(maxProj, proj)
			minProj = math.min(minProj, proj)
			maxRadius = math.max(maxRadius, (mp - (fillPoint + fillAxis * proj)).Magnitude)
		end
		for _, p in pointsB do
			local mp = p + dirB * lenB
			local proj = (mp - fillPoint):Dot(fillAxis)
			maxProj = math.max(maxProj, proj)
			minProj = math.min(minProj, proj)
		end
		local center = fillPoint + fillAxis * (0.5 * (minProj + maxProj))
		local length = maxProj - minProj
		-- Nudge toward camera (+Z) so the filler renders in front of the parts
		center += Vector3.new(0, 0, 0.05)
		fillerData = {
			CFrame = CFrame.fromMatrix(center, fillAxis, dirB),
			Size = Vector3.new(length, 2 * maxRadius, 2 * maxRadius),
		}
	end

	-- Compute the intersection highlight point (projected to Z=0 scene plane)
	local highlightPoint: Vector3
	if mode == "RoundedJoin" and fillerData then
		highlightPoint = fillerData.CFrame.Position
	elseif mode == "WedgeJoin" and innerExtendPointA then
		highlightPoint = innerExtendPointA + dirA * lenA
	else
		highlightPoint = extendPointA + dirA * lenA
	end
	-- Flatten to scene plane and nudge toward camera so it renders in front
	highlightPoint = Vector3.new(highlightPoint.X, highlightPoint.Y, 0.5)

	return lenA, lenB, fillerData, highlightPoint
end

--------------------------------------------------------------------------------
-- Demo scene definitions
--------------------------------------------------------------------------------

-- Angled scene: Part A horizontal, Part B at 45 degrees (thicker, narrower)
local ANG_A: FaceSpec = {
	cf = CFrame.new(-1.8, -0.2, 0),
	size = Vector3.new(2, 1.0, 0.8),
	face = Enum.NormalId.Right,
}
local ANG_B: FaceSpec = {
	cf = CFrame.new(1.4, 1.4, 0) * CFrame.Angles(0, 0, math.rad(45)),
	size = Vector3.new(3, 1.0, 0.8),
	face = Enum.NormalId.Left,
}
local ANG_CAM = CFrame.lookAt(Vector3.new(0.3, 0.0, 4), Vector3.new(0.3, 0.0, 0))

-- Right-angle scene: Part A horizontal, Part B vertical with bottom face selected
local RT_A: FaceSpec = {
	cf = CFrame.new(-1, -0.5, 0),
	size = Vector3.new(2, 1.0, 0.8),
	face = Enum.NormalId.Right,
}
local RT_B: FaceSpec = {
	cf = CFrame.new(1.5, 0.75, 0),
	size = Vector3.new(1.5, 2, 0.8),
	face = Enum.NormalId.Bottom,
}
local RT_CAM = CFrame.lookAt(Vector3.new(0.7, -0.3, 3.2), Vector3.new(0.7, -0.3, 0))

--------------------------------------------------------------------------------
-- Build demo data for each mode
--------------------------------------------------------------------------------

local function buildDemo(fA: FaceSpec, fB: FaceSpec, cam: CFrame, mode: ResizeMode)
	local deltaA, deltaB, fillerData, highlightPoint = computeDemoDeltas(fA, fB, mode)

	return {
		cameraCFrame = cam,
		partAStart = { CFrame = fA.cf, Size = fA.size },
		partAEnd = computeExtended(fA.cf, fA.size, fA.face, deltaA),
		partBStart = { CFrame = fB.cf, Size = fB.size },
		partBEnd = computeExtended(fB.cf, fB.size, fB.face, deltaB),
		filler = fillerData,
		highlightPoint = highlightPoint,
	}
end

local function buildRoundedDemo()
	local fA, fB = ANG_A, ANG_B
	local deltaA, deltaB, fillerData = computeDemoDeltas(fA, fB, "RoundedJoin")
	local normalA = fA.cf:VectorToWorldSpace(Vector3.fromNormalId(fA.face))
	local normalB = fB.cf:VectorToWorldSpace(Vector3.fromNormalId(fB.face))
	local angle = math.acos(math.clamp(-normalA:Dot(normalB), -1, 1))
	local setback = fillerData.Size.Y / 2 * math.tan(angle / 2)
	deltaA -= setback
	deltaB -= setback
	local pointA = getFaceBasis(fA.cf, fA.size, fA.face) + normalA * deltaA
	local pointB = getFaceBasis(fB.cf, fB.size, fB.face) + normalB * deltaB
	local start = CFrame.new(pointA) * fA.cf.Rotation
	local finish = SplineJoin.getTargetPoint(
		start,
		CFrame.new(pointB) * fB.cf.Rotation,
		fA.size,
		fB.size,
		Vector3.fromNormalId(fA.face),
		Vector3.fromNormalId(fB.face)
	)
	local template = Instance.new("Part")
	template.Size = fA.size
	fillerData = {
		segments = SplineJoin.plan(template, start, finish, normalB, Vector3.fromNormalId(fA.face), 6),
	}
	template:Destroy()
	return {
		cameraCFrame = ANG_CAM,
		partAStart = { CFrame = fA.cf, Size = fA.size },
		partAEnd = computeExtended(fA.cf, fA.size, fA.face, deltaA),
		partBStart = { CFrame = fB.cf, Size = fB.size },
		partBEnd = computeExtended(fB.cf, fB.size, fB.face, deltaB),
		filler = fillerData,
	}
end

-- Scene data, including the planned green parts, is built once at module load.
local function buildSplineDemo()
	local direction = Vector3.new(1, 1, 0).Unit
	local rotation = CFrame.Angles(0, 0, math.pi / 4)
	-- Spline Join leaves both parts as they are, so they have one state and
	-- the spline runs between their selected faces
	local partA = { CFrame = CFrame.new(-2.25, -0.2, 0), Size = Vector3.new(1.5, 1, 0.8) }
	local partB = { CFrame = CFrame.new(Vector3.new(0.8, 0.6, 0) + direction * 1.65) * rotation, Size = Vector3.new(1.9, 1, 0.8) }
	local start = partA.CFrame:PointToWorldSpace(Vector3.new(partA.Size.X / 2, 0, 0))
	local finish = partB.CFrame:PointToWorldSpace(Vector3.new(-partB.Size.X / 2, 0, 0))

	local template = Instance.new("Part")
	template.Size = Vector3.new(1, 1, 0.8)
	local demo = {
		-- Further back than the other scenes, to fit the parts and the gap
		-- between them that the spline has to cross
		cameraCFrame = CFrame.lookAt(Vector3.new(0.1, 0.55, 5), Vector3.new(0.1, 0.55, 0)),
		partAStart = partA,
		partAEnd = partA,
		partBStart = partB,
		partBEnd = partB,
		filler = {
			segments = SplineJoin.plan(template, CFrame.new(start), finish, -direction, Vector3.xAxis, 24),
		},
	}
	template:Destroy()
	return demo
end

export type PreviewMode = ResizeMode | "RoundedJoinCylinder"

local DEMO_DATA: { [PreviewMode]: any } = {
	OuterTouch = buildDemo(ANG_A, ANG_B, ANG_CAM, "OuterTouch"),
	InnerTouch = buildDemo(ANG_A, ANG_B, ANG_CAM, "InnerTouch"),
	WedgeJoin = buildDemo(ANG_A, ANG_B, ANG_CAM, "WedgeJoin"),
	RoundedJoin = buildRoundedDemo(),
	RoundedJoinCylinder = buildDemo(ANG_A, ANG_B, ANG_CAM, "RoundedJoin"),
	SplineJoin = buildSplineDemo(),
	ButtJoint = buildDemo(RT_A, RT_B, RT_CAM, "ButtJoint"),
	ExtendUpTo = buildDemo(ANG_A, ANG_B, ANG_CAM, "ExtendUpTo"),
	ExtendInto = buildDemo(ANG_A, ANG_B, ANG_CAM, "ExtendInto"),
}

--------------------------------------------------------------------------------
-- ModeDemo React component
--------------------------------------------------------------------------------

type PreviewProps = {
	PreviewMode: PreviewMode,
	JoinedLeft: boolean?,
	OpenBelow: boolean?,
	Animate: boolean?,
	Size: UDim2?,
	LayoutOrder: number?,
}

local function ModeDemo(props: PreviewProps)
	local mode = props.PreviewMode
	local animate = if props.Animate ~= nil then props.Animate else true
	local data = DEMO_DATA[mode]
	local curved = data.filler ~= nil and data.filler.segments ~= nil

	local viewportRef = React.useRef(nil :: any)
	local cameraRef = React.useRef(nil :: any)
	local partARef = React.useRef(nil :: any)
	local partBRef = React.useRef(nil :: any)
	local fillerRef = React.useRef(nil :: any)
	local filler2Ref = React.useRef(nil :: any)
	local curveRefs = React.useRef({} :: { [number]: Part })
	local highlightRef = React.useRef(nil :: any)
	local highlightBRef = React.useRef(nil :: Part?)

	local function updateCurve(progress: number)
		if not data.filler or not data.filler.segments then
			return
		end
		local segments = data.filler.segments
		local highlightA, highlightB = highlightRef.current, highlightBRef.current
		if highlightA then
			highlightA.Transparency = 1 - progress
		end
		if highlightB then
			highlightB.Transparency = 1 - progress
		end
		for i, segment in segments do
			local part = curveRefs.current[i]
			if not part then
				continue
			end
			local fraction = math.clamp(progress * #segments - i + 1, 0, 1)
			part.Transparency = if fraction > 0 then 0 else 1
			if fraction > 0 then
				part.Size = Vector3.new(segment.Size.X * fraction, segment.Size.Y, segment.Size.Z)
				part.CFrame = segment.CFrame * CFrame.new(-segment.Size.X * (1 - fraction) / 2, 0, 0)
			end
		end
	end

	-- Link camera to viewport after each render
	React.useEffect(function()
		local vp = viewportRef.current
		local cam = cameraRef.current
		if vp and cam then
			vp.CurrentCamera = cam
		end
	end)

	-- When not animating, snap to end state
	React.useEffect(function()
		if animate then
			return
		end
		local partA = partARef.current
		local partB = partBRef.current
		local filler = fillerRef.current
		local filler2 = filler2Ref.current
		local highlight = highlightRef.current
		updateCurve(1)
		if partA then
			partA.CFrame = data.partAEnd.CFrame
			partA.Size = data.partAEnd.Size
		end
		if partB then
			partB.CFrame = data.partBEnd.CFrame
			partB.Size = data.partBEnd.Size
		end
		if filler and data.filler then
			filler.Transparency = 0
		end
		if filler2 and data.filler then
			filler2.Transparency = 0
		end
		if highlight then
			highlight.Transparency = 0
		end
	end, { animate, data } :: { any })

	-- Animation loop, only runs when animate is true
	React.useEffect(function()
		if not animate then
			return
		end

		local thread = task.spawn(function()
			while true do
				local partA = partARef.current
				local partB = partBRef.current
				local filler = fillerRef.current
				local filler2 = filler2Ref.current
				local highlight = highlightRef.current
				if not (partA and partB) then
					task.wait(0.1)
					continue
				end
				updateCurve(0)
				-- Snap to start state
				partA.CFrame = data.partAStart.CFrame
				partA.Size = data.partAStart.Size
				partB.CFrame = data.partBStart.CFrame
				partB.Size = data.partBStart.Size
				if filler then
					filler.Transparency = 1
				end
				if filler2 then
					filler2.Transparency = 1
				end
				if highlight then
					highlight.Transparency = 1
				end

				task.wait(0.6)

				-- Animate to end state, for the modes that move their parts
				local STEPS = if curved then 24 else 20
				local ANIM_TIME = if curved then 0.6 else 0.4
				local partsMove = data.partAStart ~= data.partAEnd or data.partBStart ~= data.partBEnd
				for i = 1, if partsMove then STEPS else 0 do
					local progress = i / STEPS
					local t = if curved then progress * progress * (3 - 2 * progress) else progress
					partA.CFrame = data.partAStart.CFrame:Lerp(data.partAEnd.CFrame, t)
					partA.Size = data.partAStart.Size:Lerp(data.partAEnd.Size, t)
					partB.CFrame = data.partBStart.CFrame:Lerp(data.partBEnd.CFrame, t)
					partB.Size = data.partBStart.Size:Lerp(data.partBEnd.Size, t)
					if filler and data.filler then
						filler.Transparency = 1 - t
					end
					if filler2 and data.filler then
						filler2.Transparency = 1 - t
					end
					task.wait(ANIM_TIME / STEPS)
				end

				if data.filler and data.filler.segments then
					for i = 1, 24 do
						local t = i / 24
						updateCurve(t * t * (3 - 2 * t))
						task.wait(0.4 / 24)
					end
				end
				-- Show highlight at intersection point
				if highlight then
					highlight.Transparency = 0
				end

				-- Hold end state
				task.wait(0.8)
			end
		end)

		return function()
			task.cancel(thread)
		end
	end, { animate, data } :: { any })

	-- Use end state for initial render when not animating
	local initA = if animate then data.partAStart else data.partAEnd
	local initB = if animate then data.partBStart else data.partBEnd
	local initFillerTransparency = if animate then 1 else 0
	local initHighlightTransparency = if animate then 1 else 0

	-- Build WorldModel children
	local worldChildren: { [string]: any } = {
		PartA = e("Part", {
			ref = partARef,
			Anchored = true,
			CFrame = initA.CFrame,
			Size = initA.Size,
			Color = PART_A_COLOR,
			Material = Enum.Material.SmoothPlastic,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
		}),
		PartB = e("Part", {
			ref = partBRef,
			Anchored = true,
			CFrame = initB.CFrame,
			Size = initB.Size,
			Color = PART_B_COLOR,
			Material = Enum.Material.SmoothPlastic,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
		}),
	}

	if data.filler then
		if data.filler.wedges then
			-- WedgeJoin: render wedge parts
			if data.filler.wedges[1] then
				worldChildren.Filler = e("WedgePart", {
					ref = fillerRef,
					Anchored = true,
					CFrame = data.filler.wedges[1].CFrame,
					Size = data.filler.wedges[1].Size,
					Color = FILLER_COLOR,
					Material = Enum.Material.SmoothPlastic,
					Transparency = initFillerTransparency,
					TopSurface = Enum.SurfaceType.Smooth,
					BottomSurface = Enum.SurfaceType.Smooth,
				})
			end
			if data.filler.wedges[2] then
				worldChildren.Filler2 = e("WedgePart", {
					ref = filler2Ref,
					Anchored = true,
					CFrame = data.filler.wedges[2].CFrame,
					Size = data.filler.wedges[2].Size,
					Color = FILLER_COLOR,
					Material = Enum.Material.SmoothPlastic,
					Transparency = initFillerTransparency,
					TopSurface = Enum.SurfaceType.Smooth,
					BottomSurface = Enum.SurfaceType.Smooth,
				})
			end
		elseif data.filler.segments then
			local parts = {}
			for i, segment in data.filler.segments do
				parts[i] = e("Part", {
					ref = function(part: Part?)
						curveRefs.current[i] = part
					end,
					Anchored = true,
					CFrame = segment.CFrame,
					Size = segment.Size,
					Color = FILLER_COLOR,
					Material = Enum.Material.SmoothPlastic,
					Transparency = initFillerTransparency,
				})
			end
			worldChildren.Filler = e("Model", {}, parts)
		else
			worldChildren.Filler = e("Part", {
				ref = fillerRef,
				Anchored = true,
				Shape = Enum.PartType.Cylinder,
				CFrame = data.filler.CFrame,
				Size = data.filler.Size,
				Color = FILLER_COLOR,
				Material = Enum.Material.SmoothPlastic,
				Transparency = initFillerTransparency,
				TopSurface = Enum.SurfaceType.Smooth,
				BottomSurface = Enum.SurfaceType.Smooth,
			})
		end
	end

	local highlightPoint = if curved
		then data.partAEnd.CFrame:PointToWorldSpace(
			Vector3.new(data.partAEnd.Size.X / 2, -data.partAEnd.Size.Y / 2, data.partAEnd.Size.Z / 2 + 0.1)
		)
		else data.highlightPoint
	worldChildren.Highlight = e("Part", {
		ref = highlightRef,
		Anchored = true,
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(highlightPoint),
		Size = Vector3.new(0.28, 0.28, 0.28),
		Color = Color3.fromRGB(255, 255, 80),
		Material = Enum.Material.Neon,
		Transparency = initHighlightTransparency,
	})

	if curved then
		worldChildren.HighlightB = e("Part", {
			ref = highlightBRef,
			Anchored = true,
			Shape = Enum.PartType.Ball,
			CFrame = data.partBEnd.CFrame
				* CFrame.new(-data.partBEnd.Size.X / 2, -data.partBEnd.Size.Y / 2, data.partBEnd.Size.Z / 2 + 0.1),
			Size = Vector3.new(0.28, 0.28, 0.28),
			Color = Color3.fromRGB(255, 255, 80),
			Material = Enum.Material.Neon,
			Transparency = initHighlightTransparency,
		})
	end

	return e("ViewportFrame", {
		ZIndex = 1,
		ClipsDescendants = true,
		ref = viewportRef,
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.GREY,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(140, 140, 140),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -1),
		LayoutOrder = props.LayoutOrder,
	}, {
		Corner = e("UICorner", {
			TopLeftRadius = UDim.new(0, if props.JoinedLeft then 0 else 4),
			BottomLeftRadius = UDim.new(0, if props.JoinedLeft or props.OpenBelow then 0 else 4),
			TopRightRadius = UDim.new(0, 4),
			BottomRightRadius = UDim.new(0, if props.OpenBelow then 0 else 4),
		}),
		Camera = e("Camera", {
			ref = cameraRef,
			CFrame = data.cameraCFrame,
			FieldOfView = 35,
		}),
		World = e("WorldModel", {}, worldChildren),
	})
end

return ModeDemo
