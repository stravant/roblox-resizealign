--!strict

local ShapeUtils = require("./ShapeUtils")

local X_AXIS = vector.create(1, 0, 0)
local Y_AXIS = vector.create(0, 1, 0)
local Z_AXIS = vector.create(0, 0, 1)

local REFINED_PARAMETERS: { number } = {}
local TRANSPORTED_FRAMES: { CFrame } = {}
local START_REACHES: { number } = {}
local END_REACHES: { number } = {}
local DIRECTIONS: { vector } = {}
local PARAMETERS: { number } = {}
local MEASURES: { number } = {}
local POINTS: { vector } = {}
local INNER_JOINTS: { boolean } = {}

-- type solver doesn't know that Vector3 and vector are the same
local function CAST_VECTOR(vec: Vector3): vector
	return vec :: any
end

local function CAST_VECTOR3(vec: vector): Vector3
	return vec :: any
end

local function CFrame_VectorToWorldSpace(cframe: CFrame, vec: vector): vector
	return CAST_VECTOR(cframe:VectorToWorldSpace(CAST_VECTOR3(vec)))
end

local function CFrame_VectorToObjectSpace(cframe: CFrame, vec: vector): vector
	return CAST_VECTOR(cframe:VectorToObjectSpace(CAST_VECTOR3(vec)))
end

local function CFrame_fromAxisAngle(vec: vector, r: number): CFrame
	return CFrame.fromAxisAngle(CAST_VECTOR3(vec), r)
end

local function CFrame_fromVector(vec: vector): CFrame
	return CFrame.new(CAST_VECTOR3(vec))
end

local function CFrame_fromMatrix(position: vector, x: vector, y: vector, z: vector): CFrame
	return CFrame.fromMatrix(CAST_VECTOR3(position), CAST_VECTOR3(x), CAST_VECTOR3(y), CAST_VECTOR3(z))
end

-- context for name being the way it is:
-- https://create.roblox.com/docs/reference/engine/datatypes/CFrame#CFrame-+-Vector3
local function translateCFrameToVectorWorldSpace(cframe: CFrame, vec: vector): CFrame
	return cframe + CAST_VECTOR3(vec)
end

local function crossSectionRadius(rotation: CFrame, halfSize: vector, direction: vector): number
	local crossSectionVector = vector.abs(CFrame_VectorToObjectSpace(rotation, direction)) * halfSize
	return crossSectionVector.x + crossSectionVector.y + crossSectionVector.z
end

local function rotateAlong(rotation: CFrame, from: vector, to: vector, localNormal: vector, bendAxis: vector?): CFrame
	local dot = math.clamp(vector.dot(from, to), -1, 1)
	local axis = vector.cross(from, to)
	local axis_magnitude = vector.magnitude(axis)

	if axis_magnitude > 1e-6 then
		return CFrame_fromAxisAngle(vector.normalize(axis), math.atan2(axis_magnitude, dot)) * rotation
	elseif dot < 0 then
		-- At a half-turn, use the curve's plane instead of choosing an unrelated
		-- local axis and flipping the cross-section at the final segment.
		if bendAxis and vector.magnitude(bendAxis) > 1e-6 then
			return CFrame_fromAxisAngle(vector.normalize(bendAxis), math.pi) * rotation
		end

		local perpendicular = if math.abs(localNormal.y) < 0.5 then Y_AXIS else X_AXIS
		return CFrame_fromAxisAngle(CFrame_VectorToWorldSpace(rotation, perpendicular), math.pi) * rotation
	end
	return rotation
end

local SplineJoin = {}

-- Align the top/bottom edges chosen by the shorter part. The offset remains
-- signed when the template is taller, so its outside surface stays flush.
-- Pass the returned rotation to plan/getTangents to retain the target face roll.
function SplineJoin.getTargetPoint(
	startFrame: CFrame,
	targetFrame: CFrame,
	size: vector,
	targetSize: vector,
	localNormal: vector,
	targetLocalNormal: vector
): (vector, vector, CFrame)
	local up = if math.abs(targetLocalNormal.y) < 0.5 then Y_AXIS else Z_AXIS
	local targetUp = CFrame_VectorToWorldSpace(targetFrame, up)
	local endNormal = CFrame_VectorToWorldSpace(targetFrame, targetLocalNormal)
	local startNormal = CFrame_VectorToWorldSpace(startFrame, localNormal)
	local targetPosition = CAST_VECTOR(targetFrame.Position)
	local separation = targetPosition - CAST_VECTOR(startFrame.Position)

	local rotation =
		rotateAlong(startFrame.Rotation, startNormal, -endNormal, localNormal, vector.cross(startNormal, separation))
	-- A direction fixes the end face's normal, but not its roll. Keep the
	-- template's up axis parallel to the target face's up axis as well.
	local startUp = if math.abs(localNormal.y) < 0.5 then Y_AXIS else Z_AXIS
	do
		local rotatedUp = CFrame_VectorToWorldSpace(rotation, startUp)
		local sideAxis = vector.abs(vector.cross(targetLocalNormal, up))
		local targetSide = CFrame_VectorToWorldSpace(targetFrame, sideAxis)
		if math.abs(vector.dot(rotatedUp, targetSide)) > math.abs(vector.dot(rotatedUp, targetUp)) then
			up = sideAxis
			targetUp = targetSide
		end
		local alignedUp = if vector.dot(rotatedUp, targetUp) < 0 then -targetUp else targetUp
		--stylua: ignore
		local roll = math.atan2(
				vector.dot(-endNormal, vector.cross(rotatedUp, alignedUp)),
				vector.dot(rotatedUp, alignedUp)
			)
		rotation = CFrame_fromAxisAngle(-endNormal, roll) * rotation
	end
	local dimension = vector.abs(localNormal)
	local radius = crossSectionRadius(rotation, size * (vector.one - dimension) / 2, targetUp)
	local targetRadius = vector.dot(targetSize, up) / 2
	local offset = targetRadius - radius
	-- Measure height in the shorter part's frame. Averaging both up axes
	-- lets horizontal separation change which edge is considered nearer.
	local heightAxis = if radius > targetRadius then targetUp else CFrame_VectorToWorldSpace(startFrame, startUp)
	local relativeHeight = vector.dot(separation, heightAxis) * (if radius > targetRadius then 1 else -1)
	local side = if relativeHeight >= 0 then 1 else -1

	return targetPosition + targetUp * (side * offset),
		CFrame_VectorToObjectSpace(rotation, targetUp * (side * radius)),
		rotation
end

local function pointAt(
	startPoint: vector,
	controlA: vector,
	controlB: vector,
	endPoint: vector,
	t: number,
	lateral: vector
): vector
	local s = 1 - t
	local squared = s * s
	local vec = startPoint * (squared * s) + controlA * (3 * squared * t)

	-- luau doesnt free up no-longer used variable slots so we're manually overwriting it
	squared = t * t
	return vec
		+ controlB * (3 * s * squared)
		+ endPoint * (squared * t)
		+ lateral * (squared * (t * (10 + t * (-15 + 6 * t)) - (3 - 2 * t)))
end

local function tangentAt(
	startPoint: vector,
	controlA: vector,
	controlB: vector,
	endPoint: vector,
	t: number,
	lateral: vector
): vector
	local s = 1 - t
	return vector.normalize(
		(controlA - startPoint) * (s * s)
			+ (controlB - controlA) * (2 * s * t)
			+ (endPoint - controlB) * (t * t)
			+ lateral * (10 * t * t * s * s - 2 * t * s)
	)
end

local function distanceToSegmentSquared(point: vector, a: vector, b: vector): number
	local chord = b - a
	local lengthSquared = vector.dot(chord, chord)
	local t = if lengthSquared > 0 then math.clamp(vector.dot(point - a, chord) / lengthSquared, 0, 1) else 0
	local difference = point - (a + chord * t)
	return vector.dot(difference, difference)
end

local function surfaceIntervalError(
	left: number,
	right: number,
	startPoint: vector,
	controlA: vector,
	controlB: vector,
	endPoint: vector,
	lateral: vector
): number
	local a = pointAt(startPoint, controlA, controlB, endPoint, left, lateral)
	local b = pointAt(startPoint, controlA, controlB, endPoint, right, lateral)
	local errorSquared = 0
	for quarter = 1, 3 do
		local point = pointAt(startPoint, controlA, controlB, endPoint, left + (right - left) * quarter / 4, lateral)
		errorSquared = math.max(errorSquared, distanceToSegmentSquared(point, a, b))
	end
	return errorSquared
end

local function miterExtension(rotation: CFrame, halfSection: vector, direction: vector, plane: vector): number
	local denominator = math.abs(vector.dot(direction, plane))
	if denominator < 1e-6 then
		return math.huge
	end
	return crossSectionRadius(rotation, halfSection, plane) / denominator
end

local function arcHandles(
	startPoint: vector,
	endPoint: vector,
	startNormal: vector,
	endNormal: vector,
	angle: number,
	cross: vector,
	crossSquared: number
): (number, number, vector?)
	local distance = vector.magnitude((endPoint - startPoint))
	local handleLength = 2 * distance / (3 * (1 + math.cos(angle / 2)))
	local handleA = handleLength
	local handleB = handleLength
	local tangentCorner: vector? = nil

	if crossSquared > 1e-10 then
		local separation = endPoint - startPoint
		local reachA = vector.dot(vector.cross(separation, endNormal), cross) / crossSquared
		local reachB = vector.dot(vector.cross(separation, startNormal), cross) / crossSquared
		if reachA > 0 and reachB > 0 then
			-- Unequal tangent reaches need unequal handles. Equal handles can
			-- push the middle control points past one another and create an S.
			local fraction = 4 / 3 * math.tan(angle / 4) / math.tan(angle / 2)
			handleA = reachA * fraction
			handleB = reachB * fraction
			tangentCorner = (startPoint + startNormal * reachA + endPoint + endNormal * reachB) / 2
		end
	end

	return handleA, handleB, tangentCorner
end

local function getSplineGuide(
	startFrame: CFrame,
	endPoint: vector,
	endNormal: vector,
	localNormal: vector,
	surfaceOffset: vector?,
	targetRotation: CFrame?
): (vector, vector, vector, vector, vector, vector?)
	local startPoint = CAST_VECTOR(startFrame.Position)
	local startNormal = CFrame_VectorToWorldSpace(startFrame, localNormal)
	local angle = math.acos(math.clamp(-vector.dot(startNormal, endNormal), -1, 1))
	local cross = vector.cross(startNormal, endNormal)
	local crossSquared = vector.dot(cross, cross)
	local planar = crossSquared > 1e-10
		and math.abs(vector.dot(endPoint - startPoint, vector.normalize(cross))) < 0.0001
	local handleA, handleB, tangentCorner =
		arcHandles(startPoint, endPoint, startNormal, endNormal, angle, cross, crossSquared)
	local guideOffset = vector.zero

	if surfaceOffset and (not planar or tangentCorner == nil) then
		-- Fitting a tight reverse bend through the centers makes its visible
		-- edge curl more sharply as the template gets taller. Fit that edge
		-- directly, then offset each clone back by its unchanged thickness.
		guideOffset = surfaceOffset
		startPoint += CFrame_VectorToWorldSpace(startFrame, guideOffset)
		local endRotation = targetRotation
			or rotateAlong(
				startFrame.Rotation,
				startNormal,
				-endNormal,
				localNormal,
				vector.cross(startNormal, endPoint - startPoint)
			)
		endPoint += CFrame_VectorToWorldSpace(endRotation, guideOffset)
		handleA, handleB, tangentCorner =
			arcHandles(startPoint, endPoint, startNormal, endNormal, angle, cross, crossSquared)
	end

	return startPoint, endPoint, guideOffset, startNormal * handleA, endNormal * handleB, tangentCorner
end

--[[
	Uses the same endpoint/visible-surface fit as plan. Returned offsets
	can be retained and edited by a dragger, then passed back to the planner.

	returns `tangentStart, tangentFinish`
]]
function SplineJoin.getTangents(
	startFrame: CFrame,
	endPoint: vector,
	endNormal: vector,
	localNormal: vector,
	surfaceOffset: vector?,
	targetRotation: CFrame?
): (vector, vector)
	local _, _, _, start, finish =
		getSplineGuide(startFrame, endPoint, endNormal, localNormal, surfaceOffset, targetRotation)
	return start, finish
end

-- startFrame retains the first part's axes at its selected face. Both normals
-- point out of the selected parts; tangent offsets point toward the controls.
-- Every generated part is a clone of template, laid along a chord of the curve,
-- so the first and last parts already turn away from the selected faces. Those
-- two reach back over the selected faces the same way neighbors cover a miter.
function SplineJoin.plan(
	template: BasePart,
	startFrame: CFrame,
	endPoint: vector,
	endNormal: vector,
	localNormal: vector,
	requestedSegments: number?,
	surfaceOffset: vector?,
	targetRotation: CFrame?,
	requestedTangentStart: vector?,
	requestedTangentFinish: vector?
): { BasePart }?
	if vector.magnitude((endPoint - CAST_VECTOR(startFrame.Position))) < 0.001 then
		return nil
	end

	if requestedSegments ~= nil and (requestedSegments < 1 or requestedSegments % 1 ~= 0) then
		return nil
	end

	local startPoint, finishPoint, guideOffset, tangentStart, tangentFinish, tangentCorner =
		getSplineGuide(startFrame, endPoint, endNormal, localNormal, surfaceOffset, targetRotation)

	if requestedTangentStart and requestedTangentFinish then
		tangentStart = requestedTangentStart
		tangentFinish = requestedTangentFinish
	end

	local controlA = startPoint + tangentStart
	local controlB = finishPoint + tangentFinish
	local startRotation = startFrame.Rotation
	local startNormal = CFrame_VectorToWorldSpace(startFrame, localNormal)
	local separation = finishPoint - startPoint
	local cross = vector.cross(startNormal, endNormal)
	local crossSquared = vector.dot(cross, cross)

	if crossSquared <= 1e-10 then
		cross = vector.cross(separation, startNormal)
		crossSquared = vector.dot(cross, cross)
	end

	local hasCurveAxis = crossSquared > 1e-10
	local crossAxis = if hasCurveAxis then vector.normalize(cross) else vector.zero
	local planar = hasCurveAxis
		and math.abs(vector.dot(separation, crossAxis)) < 0.0001
		and math.abs(vector.dot(tangentStart, crossAxis)) < 0.0001
		and math.abs(vector.dot(tangentFinish, crossAxis)) < 0.0001

	-- Ease lateral displacement with a quintic blend. The out-of-plane
	-- acceleration vanishes at both faces, so a spatial join levels into them.
	local lateral = if not planar and hasCurveAxis then crossAxis * vector.dot(separation, crossAxis) else vector.zero
	local endRotation = targetRotation or rotateAlong(startRotation, startNormal, -endNormal, localNormal, -cross)
	local sectionUp = if math.abs(localNormal.y) < 0.5 then Y_AXIS else Z_AXIS
	local endRoll = 0

	if planar then
		-- A planar centerline does not imply matching cross-section roll.
		-- Front/front faces can share a curve plane and still have tilted edges.
		local transported = rotateAlong(startRotation, startNormal, -endNormal, localNormal, -cross)
		local up = CFrame_VectorToWorldSpace(transported, sectionUp)
		local targetUp = CFrame_VectorToWorldSpace(endRotation, sectionUp)
		endRoll = math.atan2(vector.dot(-endNormal, vector.cross(up, targetUp)), vector.dot(up, targetUp))
	end

	local hasEndpointRoll = math.abs(endRoll) > 0.00001
	local sectionSide = vector.cross(localNormal, sectionUp)
	local startSide = CFrame_VectorToWorldSpace(startFrame, sectionSide)
	local endSide = CFrame_VectorToWorldSpace(endRotation, sectionSide)
	local sharedSide = vector.dot(startSide, endSide) > 0.9999
	local isTwistedSpatial = not planar and not sharedSide
	local sectionRotation = CFrame_fromMatrix(vector.zero, localNormal, sectionUp, sectionSide):Inverse()

	local dimension = vector.abs(localNormal)
	local size = CAST_VECTOR(template.Size)
	local halfSection = size * (vector.one - dimension) / 2
	local templateLength = vector.dot(size, dimension)
	local count: number
	local scratchParameters = REFINED_PARAMETERS
	local parameters = PARAMETERS
	local parameterCount = 1

	parameters[1] = 0

	-- Distribute samples by length and curvature, then refine the visible edge.
	do
		local samples = math.max(128, (requestedSegments or 0) * 4)
		local totalMeasure = 0
		local totalLength = 0
		local totalTurn = 0

		MEASURES[1] = 0

		local previousPoint = startPoint
		local previousDirection = startNormal
		local previousUp = CFrame_VectorToWorldSpace(startFrame, sectionUp)

		for i = 1, samples do
			local point = pointAt(startPoint, controlA, controlB, finishPoint, i / samples, lateral)
			local chord = point - previousPoint
			local length = vector.magnitude(chord)
			local turn = 0

			if length > 0 then
				local direction = if planar
					then tangentAt(startPoint, controlA, controlB, finishPoint, i / samples, lateral)
					else vector.normalize(chord)

				turn = math.acos(math.clamp(vector.dot(previousDirection, direction), -1, 1))
				previousDirection = direction
			end

			local surfaceTurn = 0

			if not planar and sharedSide and tangentCorner ~= nil then
				local tangent = tangentAt(startPoint, controlA, controlB, finishPoint, i / samples, lateral)
				local up = vector.normalize(vector.cross(startSide, tangent))
				surfaceTurn = math.acos(math.clamp(vector.dot(previousUp, up), -1, 1))
				previousUp = up
			end

			totalLength += length
			totalTurn += turn
			-- A spatial bend can turn sideways while its surface tilts sharply.
			-- Redistribute detail toward that tilt without increasing the count.
			totalMeasure += math.sqrt(length * turn) + turn * 2 + surfaceTurn * 14 + length / templateLength * 0.05
			MEASURES[i + 1] = totalMeasure
			previousPoint = point
		end

		do
			local endTurn = math.acos(math.clamp(vector.dot(previousDirection, -endNormal), -1, 1))
			totalTurn += endTurn
			totalMeasure += endTurn * 2
			MEASURES[samples + 1] = totalMeasure
		end

		local errorLimit: number
		do
			local turnSegments = math.ceil(totalTurn / math.rad(5))

			-- Angle alone overestimates detail on small bends. Estimate chord error
			-- relative to the width across the bend plane, which also keeps detail
			-- consistent when the selected ends have different heights.
			local axisA, axisB = ShapeUtils.otherNormals(CAST_VECTOR3(localNormal))
			local width = if hasCurveAxis
				then 2 * crossSectionRadius(startFrame, halfSection, crossAxis)
				else math.min(vector.dot(size, CAST_VECTOR(axisA)), vector.dot(size, CAST_VECTOR(axisB)))

			errorLimit = width * (if guideOffset == vector.zero then 0.002 elseif not planar then 0.004 else 0.003)

			if planar and guideOffset ~= vector.zero then
				errorLimit = math.max(errorLimit, totalLength * 0.002)
			end
			local errorSegments = math.ceil(math.sqrt(totalLength * totalTurn / (8 * errorLimit)))

			if not isTwistedSpatial then
				turnSegments = math.min(turnSegments, errorSegments)
			end

			count = requestedSegments or math.max(1, math.ceil(totalLength / templateLength), turnSegments)
		end

		do
			local intervals = count
			local sample = 1

			for i = 1, intervals do
				local progress = i / intervals
				-- Reverse bends need smaller direction changes where they meet the
				-- selected parts. Redistribute the existing samples toward both ends.
				if isTwistedSpatial then
					local squared = progress * progress
					local cubic = squared * (3 - 2 * progress)
					local quintic = squared * progress * (10 + progress * (-15 + 6 * progress))
					progress = cubic + (quintic - cubic) * 0.25
				elseif tangentCorner == nil or not planar then
					progress = (progress + progress * progress * (3 - 2 * progress)) / 2
				end
				local targetMeasure = totalMeasure * progress

				while sample < samples and MEASURES[sample + 1] < targetMeasure do
					sample += 1
				end

				local sampleMeasure = MEASURES[sample]
				local span = MEASURES[sample + 1] - sampleMeasure
				local fraction = if span > 0 then (targetMeasure - sampleMeasure) / span else 0
				local t = math.clamp((sample - 1 + fraction) / samples, 0, 1)
				parameters[i + 1] = t
			end
			parameterCount = intervals + 1
			parameters[parameterCount] = 1
		end

		if planar and count >= 3 and requestedSegments == nil and guideOffset ~= vector.zero then
			local turnAxis = -cross
			local subdivided = false

			repeat
				subdivided = false
				local refinedCount = 1
				scratchParameters[1] = parameters[1]

				for i = 1, parameterCount - 1 do
					local left = parameters[i]
					local right = parameters[i + 1]
					local middle = (left + right) / 2
					local a = pointAt(startPoint, controlA, controlB, finishPoint, left, lateral)
					local b = pointAt(startPoint, controlA, controlB, finishPoint, right, lateral)
					local midpoint = pointAt(startPoint, controlA, controlB, finishPoint, middle, lateral)
					local errorSquared =
						surfaceIntervalError(left, right, startPoint, controlA, controlB, finishPoint, lateral)

					if
						errorSquared > errorLimit * errorLimit
						and middle > left
						and middle < right
						and midpoint ~= a
						and midpoint ~= b
					then
						refinedCount += 1
						scratchParameters[refinedCount] = middle
						subdivided = true
					end

					refinedCount += 1
					scratchParameters[refinedCount] = right
				end

				parameters, scratchParameters = scratchParameters, parameters
				parameterCount = refinedCount
			until not subdivided

			-- Keep both endpoint transitions; omit redundant samples on the crest.
			if parameterCount >= 5 then
				local simplifiedCount = 2
				scratchParameters[1] = parameters[1]
				scratchParameters[2] = parameters[2]

				for i = 3, parameterCount - 2 do
					local left = scratchParameters[simplifiedCount]
					local middle = parameters[i]
					local right = parameters[i + 1]
					local a = tangentAt(startPoint, controlA, controlB, finishPoint, left, lateral)
					local b = tangentAt(startPoint, controlA, controlB, finishPoint, middle, lateral)
					local c = tangentAt(startPoint, controlA, controlB, finishPoint, right, lateral)
					local redundant = vector.dot(vector.cross(a, b), turnAxis) >= 0
						and vector.dot(vector.cross(b, c), turnAxis) >= 0
						and vector.dot(a, c) >= math.cos(math.rad(15))
						and surfaceIntervalError(left, right, startPoint, controlA, controlB, finishPoint, lateral)
							<= errorLimit * errorLimit

					if not redundant then
						simplifiedCount += 1
						scratchParameters[simplifiedCount] = middle
					end
				end

				scratchParameters[simplifiedCount + 1] = parameters[parameterCount - 1]
				scratchParameters[simplifiedCount + 2] = parameters[parameterCount]
				parameters, scratchParameters = scratchParameters, parameters
				parameterCount = simplifiedCount + 2
			end
			count = parameterCount - 1
		end
	end

	for i = 1, parameterCount do
		POINTS[i] = pointAt(startPoint, controlA, controlB, finishPoint, parameters[i], lateral)
	end
	POINTS[1] = startPoint
	POINTS[count + 1] = finishPoint

	local transportRoll = 0
	do
		local transported = startRotation
		local previousPoint = startPoint
		local previousDirection = startNormal

		for i = 1, count do
			local point = POINTS[i + 1]
			local chord = point - previousPoint

			local direction = vector.normalize(chord)
			DIRECTIONS[i] = direction

			if isTwistedSpatial then
				transported = rotateAlong(transported, previousDirection, direction, localNormal, -cross)
				TRANSPORTED_FRAMES[i] = transported
			end
			previousDirection = direction
			previousPoint = point
		end

		if isTwistedSpatial and count > 1 then
			local up = CFrame_VectorToWorldSpace(transported, sectionUp)
			local targetUp = CFrame_VectorToWorldSpace(endRotation, sectionUp)
			transportRoll =
				math.atan2(vector.dot(previousDirection, vector.cross(up, targetUp)), vector.dot(up, targetUp))
		end
	end

	local parts = table.create(count) :: { BasePart }

	do
		local previousPoint = startPoint

		for i = 1, count do
			local point = POINTS[i + 1]
			local direction = DIRECTIONS[i]
			local length = vector.magnitude(point - previousPoint)
			local midpoint = (previousPoint + point) / 2

			-- Spatial curves use a rotation-minimizing transported frame. Apply
			-- only the residual endpoint roll, spread smoothly across the arc.
			local rotation: CFrame
			if isTwistedSpatial then
				rotation = TRANSPORTED_FRAMES[i]
				if count > 1 then
					local progress = (i - 1) / (count - 1)
					rotation = CFrame_fromAxisAngle(direction, transportRoll * progress * progress * (3 - 2 * progress))
						* rotation
				end
			else
				local reference = if planar or count == 1
					then startRotation
					else startRotation:Lerp(endRotation, (i - 1) / (count - 1))
				rotation = rotateAlong(
					reference,
					CFrame_VectorToWorldSpace(reference, localNormal),
					direction,
					localNormal,
					-cross
				)
			end
			if not isTwistedSpatial and hasEndpointRoll and count > 1 then
				local progress = (i - 1) / (count - 1)
				rotation = CFrame_fromAxisAngle(direction, endRoll * progress * progress * (3 - 2 * progress))
					* rotation
			end
			if not planar and sharedSide and vector.magnitude(vector.cross(startSide, direction)) > 0.00001 then
				-- Shared side axes define the same section plane at both ends.
				-- Keep the up vector in that plane instead of introducing roll.
				local up = vector.normalize(vector.cross(startSide, direction))
				rotation = CFrame_fromMatrix(vector.zero, direction, up, vector.cross(direction, up)) * sectionRotation
			end
			local part = template:Clone()
			part.CFrame = CFrame_fromVector(midpoint - CFrame_VectorToWorldSpace(rotation, guideOffset)) * rotation
			part.Size = CAST_VECTOR3(size + dimension * (length - templateLength))
			parts[i] = part
			previousPoint = point
		end
	end

	-- A joint is normally covered by lengthening its two parts until their
	-- outside corners meet, which overlaps them on the inside of the bend. Inside
	-- a wedge that overlap is only hidden when the slope faces into the bend.
	-- Otherwise the neighbor's corner comes up through the slope, so those
	-- joints are shortened until the inside corners meet instead. The gap that
	-- leaves on the outside tapers away along with the wedge.
	-- INNER_JOINTS[i] is the joint before part i; count + 1 is the last face.
	local slopeNormal: vector? = nil
	if ShapeUtils.isWedgeShape(template) and math.abs(localNormal.x) > 0.5 then
		slopeNormal = vector.normalize(vector.create(0, size.z, -size.y))
	end
	for i = 1, count + 1 do
		local inner = false
		if slopeNormal then
			local before = if i == 1 then startNormal else DIRECTIONS[i - 1]
			local after = if i > count then -endNormal else DIRECTIONS[i]
			-- The bend's inside is the way the direction turns
			local turn = after - before
			local rotation = parts[math.min(i, count)].CFrame
			inner = vector.dot(turn, CFrame_VectorToWorldSpace(rotation, slopeNormal)) < -1e-6
		end
		INNER_JOINTS[i] = inner
	end

	do
		local previousDirection = startNormal

		for i, part in parts do
			local direction = DIRECTIONS[i]
			local nextDirection = if i < count then DIRECTIONS[i + 1] else -endNormal
			local startPlane = if i == 1 then startNormal else previousDirection + direction
			local endPlane = if i == count then -endNormal else direction + nextDirection
			local offset = CFrame_VectorToWorldSpace(part.CFrame, guideOffset)
			local startInner, endInner = INNER_JOINTS[i], INNER_JOINTS[i + 1]
			local startReach = miterExtension(part.CFrame, halfSection, direction, startPlane)
				* (if startInner then -1 else 1)
				- vector.dot(offset, startPlane) / vector.dot(direction, startPlane)
			local endReach = miterExtension(part.CFrame, halfSection, direction, endPlane)
				* (if endInner then -1 else 1)
				+ vector.dot(offset, endPlane) / vector.dot(direction, endPlane)

			if (not planar or hasEndpointRoll) and not (startInner or endInner) then
				if i > 1 then
					local previous = parts[i - 1].CFrame
					local previousOffset = CFrame_VectorToWorldSpace(previous, guideOffset)
					startReach = math.max(
						startReach,
						vector.dot((previousOffset - offset), direction)
							+ crossSectionRadius(previous, halfSection, direction)
					)
				end
				if i < count then
					local following = parts[i + 1].CFrame
					local nextOffset = CFrame_VectorToWorldSpace(following, guideOffset)
					endReach = math.max(
						endReach,
						vector.dot((offset - nextOffset), direction)
							+ crossSectionRadius(following, halfSection, direction)
					)
				end
			end
			START_REACHES[i], END_REACHES[i] = startReach, endReach
			previousDirection = direction
		end

		for i, part in parts do
			local before: number
			local after: number

			if INNER_JOINTS[i] or INNER_JOINTS[i + 1] then
				-- Both parts give way at an inner joint, so neither owns it
				local chordLength = vector.dot(CAST_VECTOR(part.Size), dimension)
				before = START_REACHES[i]
				after = END_REACHES[i]
				if not INNER_JOINTS[i] then
					before = math.max(before, 0)
				end
				if not INNER_JOINTS[i + 1] then
					after = math.max(after, 0)
				end
				-- A bend tighter than the wedge is wide cannot be inner joined
				local shortfall = 0.001 - (chordLength + before + after)
				if shortfall > 0 then
					before += shortfall / 2
					after += shortfall / 2
				end
			elseif isTwistedSpatial then
				-- Whichever neighbor needs less reach owns this joint. Ties go
				-- to the follower, except at the first joint: extending segment
				-- two backward can cross the selected front face. The end
				-- segments always own their joints with the selected faces.
				before = if i == 1 or (i > 2 and START_REACHES[i] <= END_REACHES[i - 1]) then START_REACHES[i] else 0
				after = if i == count or i == 1 or END_REACHES[i] < START_REACHES[i + 1] then END_REACHES[i] else 0
			else
				local chordLength = vector.dot(CAST_VECTOR(part.Size), dimension)
				before = math.max(START_REACHES[i], END_REACHES[i] - chordLength)
				after = math.max(END_REACHES[i], START_REACHES[i] - chordLength)
			end

			part.Size += CAST_VECTOR3(dimension * (before + after))
			part.CFrame = translateCFrameToVectorWorldSpace(part.CFrame, DIRECTIONS[i] * ((after - before) / 2))
		end
	end
	return parts
end

return table.freeze(SplineJoin)
