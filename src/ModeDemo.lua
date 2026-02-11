local Src = script.Parent
local Packages = Src.Parent.Packages
local React = require(Packages.React)

local Colors = require("./PluginGui/Colors")
local Settings = require("./Settings")

local e = React.createElement

type ResizeMode = Settings.ResizeMode

local PART_A_COLOR = Color3.fromRGB(200, 50, 50)
local PART_B_COLOR = Color3.fromRGB(50, 80, 220)
local FILLER_COLOR = Color3.fromRGB(80, 200, 50)

--------------------------------------------------------------------------------
-- Geometry helpers (mirrors doExtend logic for demo computation)
--------------------------------------------------------------------------------

local function otherNormals(dir: Vector3): (Vector3, Vector3)
	if math.abs(dir.X) > 0 then
		return Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
	elseif math.abs(dir.Y) > 0 then
		return Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
	else
		return Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
	end
end

local function getFaceCorners(cf: CFrame, size: Vector3, normalId: Enum.NormalId): {Vector3}
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

local function maxPointToPlane(basePoint: Vector3, normal: Vector3, points: {Vector3}): Vector3
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

local function minPointToPlane(basePoint: Vector3, normal: Vector3, points: {Vector3}): Vector3
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

local function computeDemoDeltas(
	fA: FaceSpec, fB: FaceSpec, mode: ResizeMode
): (number, number, any?)
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

	if mode == "OuterTouch" or mode == "ButtJoint" or mode == "ExtendInto" then
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
			if proj < minV then minV = proj end
			if proj > maxV then maxV = proj end
		end
		lenA += -(maxV - minV)
	end

	-- RoundedJoin: compute filler cylinder
	local fillerData = nil
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
local ANG_CAM = CFrame.lookAt(Vector3.new(0.5, 0.4, 5), Vector3.new(0.5, 0.4, 0))

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
local RT_CAM = CFrame.lookAt(Vector3.new(0.9, 0, 4), Vector3.new(0.9, 0, 0))

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

local DEMO_DATA: { [ResizeMode]: any } = {
	OuterTouch = buildDemo(ANG_A, ANG_B, ANG_CAM, "OuterTouch"),
	InnerTouch = buildDemo(ANG_A, ANG_B, ANG_CAM, "InnerTouch"),
	RoundedJoin = buildDemo(ANG_A, ANG_B, ANG_CAM, "RoundedJoin"),
	ButtJoint = buildDemo(RT_A, RT_B, RT_CAM, "ButtJoint"),
	ExtendUpTo = buildDemo(ANG_A, ANG_B, ANG_CAM, "ExtendUpTo"),
	ExtendInto = buildDemo(ANG_A, ANG_B, ANG_CAM, "ExtendInto"),
}

--------------------------------------------------------------------------------
-- ModeDemo React component
--------------------------------------------------------------------------------

local function ModeDemo(props: {
	ResizeMode: ResizeMode,
	Animate: boolean?,
	Size: UDim2?,
	LayoutOrder: number?,
})
	local mode = props.ResizeMode
	local animate = if props.Animate ~= nil then props.Animate else true
	local data = DEMO_DATA[mode]

	local viewportRef = React.useRef(nil :: any)
	local cameraRef = React.useRef(nil :: any)
	local partARef = React.useRef(nil :: any)
	local partBRef = React.useRef(nil :: any)
	local fillerRef = React.useRef(nil :: any)
	local highlightRef = React.useRef(nil :: any)

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
		local highlight = highlightRef.current
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
		if highlight then
			highlight.Transparency = 0
		end
	end, { animate, mode } :: { any })

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
				local highlight = highlightRef.current
				if not (partA and partB) then
					task.wait(0.1)
					continue
				end

				-- Snap to start state
				partA.CFrame = data.partAStart.CFrame
				partA.Size = data.partAStart.Size
				partB.CFrame = data.partBStart.CFrame
				partB.Size = data.partBStart.Size
				if filler then
					filler.Transparency = 1
				end
				if highlight then
					highlight.Transparency = 1
				end

				task.wait(0.6)

				-- Animate to end state
				local STEPS = 20
				local ANIM_TIME = 0.4
				for i = 1, STEPS do
					local t = i / STEPS
					partA.CFrame = data.partAStart.CFrame:Lerp(data.partAEnd.CFrame, t)
					partA.Size = data.partAStart.Size:Lerp(data.partAEnd.Size, t)
					partB.CFrame = data.partBStart.CFrame:Lerp(data.partBEnd.CFrame, t)
					partB.Size = data.partBStart.Size:Lerp(data.partBEnd.Size, t)
					if filler and data.filler then
						filler.Transparency = 1 - t
					end
					task.wait(ANIM_TIME / STEPS)
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
	end, { animate, mode } :: { any })

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

	worldChildren.Highlight = e("Part", {
		ref = highlightRef,
		Anchored = true,
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(data.highlightPoint),
		Size = Vector3.new(0.28, 0.28, 0.28),
		Color = Color3.fromRGB(255, 255, 80),
		Material = Enum.Material.Neon,
		Transparency = initHighlightTransparency,
	})

	return e("ViewportFrame", {
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
			CornerRadius = UDim.new(0, 4),
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
