local SplineJoin = require(script.Parent.SplineJoin)
local ShapeUtils = require(script.Parent.ShapeUtils)
local doExtend = require(script.Parent.doExtend)
local TestTypes = require(script.Parent.TestTypes)

type TestContext = TestTypes.TestContext
type Segment = SplineJoin.Segment

local X_AXIS = vector.create(1, 0, 0)
local Y_AXIS = vector.create(0, 1, 0)
local Z_AXIS = vector.create(0, 0, 1)

local WORKSPACE_PADDINGS = { 0, 0.6 }
local SELECTION_ORDERS = { false, true }
local SIGNS = { -1, 1 }

--------------------------------------------------------------------------------
-- Roblox vector boundaries
--------------------------------------------------------------------------------

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

local function CFrame_VectorToObjectSpace(cframe: CFrame, value: vector): vector
	return CAST_VECTOR(cframe:VectorToObjectSpace(CAST_VECTOR3(value)))
end

local function CFrame_PointToWorldSpace(cframe: CFrame, point: vector): vector
	return CAST_VECTOR(cframe:PointToWorldSpace(CAST_VECTOR3(point)))
end

local function CFrame_PointToObjectSpace(cframe: CFrame, point: vector): vector
	return CAST_VECTOR(cframe:PointToObjectSpace(CAST_VECTOR3(point)))
end

local function CFrame_fromVector(value: vector): CFrame
	return CFrame.new(CAST_VECTOR3(value))
end

local function CFrame_fromMatrix(position: vector, x: vector, y: vector): CFrame
	return CFrame.fromMatrix(CAST_VECTOR3(position), CAST_VECTOR3(x), CAST_VECTOR3(y))
end

local function translateCFrame(cframe: CFrame, offset: vector): CFrame
	return cframe + CAST_VECTOR3(offset)
end

local function normalFromId(normalId: Enum.NormalId): vector
	return CAST_VECTOR(Vector3.fromNormalId(normalId))
end

local function createFolder(): WorldModel
	return Instance.new("WorldModel")
end

local function createPart(size: vector, cframe: CFrame?, parent: Instance?): Part
	local part = Instance.new("Part")
	part.Size = CAST_VECTOR3(size)
	if cframe then
		part.CFrame = cframe
	end
	part.Parent = parent
	return part
end

--------------------------------------------------------------------------------
-- Geometry checks and fixtures
--------------------------------------------------------------------------------

local function near(a: vector, b: vector)
	assert(vector.magnitude(a - b) < 0.0001, `Expected {a} to meet {b}`)
end

local function isInside(segment: Segment, point: vector): boolean
	local localPoint = CFrame_PointToObjectSpace(segment.CFrame, point)
	local size = segment.Size
	return math.abs(localPoint.x) <= size.x / 2 + 0.0001
		and math.abs(localPoint.y) <= size.y / 2 + 0.0001
		and math.abs(localPoint.z) <= size.z / 2 + 0.0001
end

local function inside(segment: Segment, point: vector)
	assert(isInside(segment, point), "Point is outside the segment")
end

-- The end segments turn away from the selected faces straight away, so a face
-- is not contained by one aligned segment any more. On the inside of a tight
-- bend the segments even fold back behind the face, into the selected part.
-- What must never happen is a gap in front of the face, so look from a point on
-- the face back into its part: a segment has to be there, or close behind.
-- A tilted segment's corners can also graze out of its neighbors by float error.
local function reachesFacePoint(segments: { Segment }, point: vector, inward: vector, depth: number)
	for _, segment in segments do
		-- Slab test of the ray from the point into the part against this box
		local origin = CFrame_PointToObjectSpace(segment.CFrame, point)
		local direction = CFrame_VectorToObjectSpace(segment.CFrame, inward)
		local half = segment.Size / 2 + vector.one * 0.005
		local enter, leave = 0, depth
		for _, component in { "x", "y", "z" } do
			local o, d, h = (origin :: any)[component], (direction :: any)[component], (half :: any)[component]
			if math.abs(d) < 1e-9 then
				if math.abs(o) > h then
					enter, leave = 1, 0
				end
			else
				local t1, t2 = (-h - o) / d, (h - o) / d
				enter = math.max(enter, math.min(t1, t2))
				leave = math.min(leave, math.max(t1, t2))
			end
		end
		if enter <= leave then
			return
		end
	end
	error(`The join leaves a gap in front of the face at {point}`)
end

-- Without the face's axis, settle for the chain ending close to the point
local function endsNear(segments: { Segment }, point: vector, tolerance: number)
	for _, segment in segments do
		local excess = vector.abs(CFrame_PointToObjectSpace(segment.CFrame, point)) - segment.Size / 2
		if math.max(excess.x, excess.y, excess.z) <= tolerance then
			return
		end
	end
	error(`No segment reaches {point}`)
end

local function jointBetween(a: Segment, b: Segment, normal: vector): (vector, vector, vector)
	local direction = CFrame_VectorToWorldSpace(a.CFrame, normal)
	local nextDirection = CFrame_VectorToWorldSpace(b.CFrame, normal)
	local cross = vector.cross(direction, nextDirection)
	local center = CAST_VECTOR(a.CFrame.Position)
	local nextCenter = CAST_VECTOR(b.CFrame.Position)
	local joint = (center + nextCenter) / 2
	if vector.magnitude(cross) >= 0.00001 then
		joint = center
			+ direction
				* (vector.dot(vector.cross(nextCenter - center, nextDirection), cross) / vector.dot(cross, cross))
	end
	return joint, direction, nextDirection
end

local function overlapsOnAxis(a: Segment, b: Segment, axis: vector): boolean
	if vector.magnitude(axis) < 0.000001 then
		return true
	end
	axis = vector.normalize(axis)
	local radiusA = vector.dot(vector.abs(CFrame_VectorToObjectSpace(a.CFrame, axis)), a.Size) / 2
	local radiusB = vector.dot(vector.abs(CFrame_VectorToObjectSpace(b.CFrame, axis)), b.Size) / 2
	local separation = CAST_VECTOR(b.CFrame.Position) - CAST_VECTOR(a.CFrame.Position)
	return math.abs(vector.dot(separation, axis)) <= radiusA + radiusB + 0.0001
end

local function areOverlapping(a: Segment, b: Segment): boolean
	local axesA = {
		CAST_VECTOR(a.CFrame.XVector),
		CAST_VECTOR(a.CFrame.YVector),
		CAST_VECTOR(a.CFrame.ZVector),
	}
	local axesB = {
		CAST_VECTOR(b.CFrame.XVector),
		CAST_VECTOR(b.CFrame.YVector),
		CAST_VECTOR(b.CFrame.ZVector),
	}
	for _, axis in axesA do
		if not overlapsOnAxis(a, b, axis) then
			return false
		end
	end
	for _, axis in axesB do
		if not overlapsOnAxis(a, b, axis) then
			return false
		end
	end
	for _, axisA in axesA do
		for _, axisB in axesB do
			if not overlapsOnAxis(a, b, vector.cross(axisA, axisB)) then
				return false
			end
		end
	end
	return true
end

local function checkOverlap(a: Segment, b: Segment)
	assert(areOverlapping(a, b), "Adjacent segments have a separating gap")
end

local function checkPlan(segments: { Segment }, first: vector, last: vector, normal: vector, size: vector)
	local crossSection = vector.one - vector.abs(normal)
	local tolerance = vector.magnitude(size * crossSection) * 0.05
	endsNear(segments, first, tolerance)
	endsNear(segments, last, tolerance)
	for i, segment in segments do
		near(segment.Size * crossSection, size * crossSection)
		if i < #segments then
			checkOverlap(segment, segments[i + 1])
		end
	end
end

-- Check the entire miter on well-conditioned quarter-circle fixtures. Inferring
-- an infinite miter from nearly parallel, rounded CFrames amplifies float error.
local function checkMiters(segments: { Segment }, size: vector)
	for i = 1, #segments - 1 do
		local a = segments[i]
		local b = segments[i + 1]
		local joint, direction, nextDirection = jointBetween(a, b, X_AXIS)
		local plane = direction + nextDirection
		for _, y in SIGNS do
			for _, z in SIGNS do
				local offset = CFrame_VectorToWorldSpace(a.CFrame, vector.create(0, y * size.y, z * size.z) / 2)
				local corner = joint + offset - direction * (vector.dot(offset, plane) / vector.dot(direction, plane))
				inside(a, corner)
				inside(b, corner)
			end
		end
	end
end

local function checkSingleOwnerMiters(segments: { Segment }, normal: vector, guideOffset: vector)
	local count = #segments
	for i = 1, count - 1 do
		local segment = segments[i]
		local following = segments[i + 1]
		local direction = CFrame_VectorToWorldSpace(segment.CFrame, normal)
		local nextDirection = CFrame_VectorToWorldSpace(following.CFrame, normal)
		local center = CAST_VECTOR(segment.CFrame.Position) + CFrame_VectorToWorldSpace(segment.CFrame, guideOffset)
		local nextCenter = CAST_VECTOR(following.CFrame.Position)
			+ CFrame_VectorToWorldSpace(following.CFrame, guideOffset)
		local cross = vector.cross(direction, nextDirection)
		assert(vector.magnitude(cross) >= 0.00001, "The twisted fixture must bend at every tested joint")
		local joint = center
			+ direction
				* (vector.dot(vector.cross(nextCenter - center, nextDirection), cross) / vector.dot(cross, cross))
		local segmentHalfLength = vector.dot(segment.Size, vector.abs(normal)) / 2
		local followingHalfLength = vector.dot(following.Size, vector.abs(normal)) / 2
		local segmentEnd = CAST_VECTOR(segment.CFrame.Position) + direction * segmentHalfLength
		local followingStart = CAST_VECTOR(following.CFrame.Position) - nextDirection * followingHalfLength
		assert(
			math.abs(vector.dot(segmentEnd - joint, direction)) <= 0.0001
				or math.abs(vector.dot(followingStart - joint, nextDirection)) <= 0.0001,
			"Only one segment may own each twisted miter"
		)
	end
end

local function withParts(callback)
	local folder = createFolder()
	local a = createPart(vector.create(4, 2, 3), CFrame.new(-2, 0, 0), folder)
	a.Anchored = true
	a.Color = Color3.fromRGB(51, 123, 201)
	a:SetAttribute("ArcTemplate", true)
	local attachment = Instance.new("Attachment")
	attachment.Name = "TemplateAttachment"
	attachment.Parent = a
	local b = createPart(vector.create(2, 4, 3), CFrame.new(10, 12, 0), folder)
	b.Anchored = true
	callback(
		folder,
		a,
		b,
		{ Object = a, Normal = Enum.NormalId.Right },
		{ Object = b, Normal = Enum.NormalId.Bottom }
	)
	folder:Destroy()
end

-- The unequal-height E/C regression, mirrored and selected in either order.
local function tiltedJoin(reverse: boolean, mirror: number)
	local shortFrame = CFrame.new(-1.85, 0, 0)
	local tallFrame = CFrame.new(9.4763, -6.11964 * mirror, 0) * CFrame.Angles(0, 0, -math.atan2(2, 3) * mirror)
	local shortSize = vector.create(3.7, 0.7, 1)
	local tallSize = vector.create(19.35, 2, 1)
	local first = if reverse then tallFrame else shortFrame
	local second = if reverse then shortFrame else tallFrame
	local firstSize = if reverse then tallSize else shortSize
	local secondSize = if reverse then shortSize else tallSize
	local n1 = if reverse then -X_AXIS else X_AXIS
	local n2 = if reverse then X_AXIS else -X_AXIS
	local start = first * CFrame_fromVector(n1 * firstSize / 2)
	local target = second * CFrame_fromVector(n2 * secondSize / 2)
	return start, target, firstSize, secondSize, n1, n2
end

-- inward points from the face into the part it belongs to
local function checkEndFace(segments: { Segment }, frame: CFrame, size: vector, inward: vector)
	for _, y in SIGNS do
		for _, z in SIGNS do
			reachesFacePoint(
				segments,
				CFrame_PointToWorldSpace(frame, vector.create(0, y * size.y, z * size.z) / 2),
				inward,
				vector.magnitude(size)
			)
		end
	end
end

-- For X-facing fixtures whose two parts differ in height. The template lands
-- centered on finish, flush with one edge of the target, so only the area the
-- two cross-sections share is really a face that the join has to reach.
local function checkTargetFace(
	segments: { Segment },
	target: CFrame,
	targetSize: vector,
	targetNormal: vector,
	finish: vector,
	size: vector
)
	local center = CFrame_PointToObjectSpace(target, finish)
	local low = vector.max(center - size / 2, -targetSize / 2)
	local high = vector.min(center + size / 2, targetSize / 2)
	for _, y in { low.y, high.y } do
		for _, z in { low.z, high.z } do
			reachesFacePoint(
				segments,
				CFrame_PointToWorldSpace(target, vector.create(0, y, z)),
				-CFrame_VectorToWorldSpace(target, targetNormal),
				vector.magnitude(size)
			)
		end
	end
end

local function angleBetween(a: vector, b: vector): number
	return math.atan2(vector.magnitude(vector.cross(a, b)), vector.dot(a, b))
end

-- The first and last segments are part of the curve: they have already begun
-- turning away from the selected faces, but only by a share of the whole turn.
-- travelIn and travelOut are the directions the join leaves and arrives along.
local function checkTurningEnds(segments: { Segment }, normal: vector, travelIn: vector, travelOut: vector, limit: number)
	local first = angleBetween(CFrame_VectorToWorldSpace(segments[1].CFrame, normal), travelIn)
	local last = angleBetween(CFrame_VectorToWorldSpace(segments[#segments].CFrame, normal), travelOut)
	assert(first > 0.0001, "The first segment runs straight out of its face instead of curving")
	assert(last > 0.0001, "The last segment runs straight into its face instead of curving")
	assert(first <= limit, `The first segment turns {math.deg(first)} degrees away from its face`)
	assert(last <= limit, `The last segment turns {math.deg(last)} degrees away from its face`)
end

-- Frozen workspace fixtures: these must also pass without the user's place open.
local function workspacePair(name: string): (CFrame, vector)
	if name == "TOPRAIL" then
		return CFrame.new(-11.3750019, 23.5999985, 2.5000014) * CFrame.Angles(0, math.pi / 2, 0),
			vector.create(0.6, 0.2, 4.65)
	elseif name == "C" or name == "F" or name == "K" then
		local z = if name == "C" then 2.5 elseif name == "F" then 15.275 else 25.3
		return CFrame.new(if name == "K" then -14.7250013 else -11.8500013, 20.8500004, z),
			vector.create(3.7, 0.7, 1)
	else
		local z = if name == "D" then 12.95 elseif name == "E" then 2.5 else 22.975
		return CFrame.new(-0.5237015, 14.7303591, z) * CFrame.Angles(0, 0, -math.atan2(2, 3)),
			vector.create(19.35, 2, 1)
	end
end

-- sign is -1 where the template leaves its part, and 1 where it enters the target
local function checkFittedFace(
	segments: { Segment },
	point: vector,
	rotation: CFrame,
	size: vector,
	normal: vector,
	sign: number
)
	local axisA3, axisB3 = ShapeUtils.otherNormals(CAST_VECTOR3(normal))
	local axisA = CAST_VECTOR(axisA3)
	local axisB = CAST_VECTOR(axisB3)
	for _, a in SIGNS do
		for _, b in SIGNS do
			reachesFacePoint(
				segments,
				point + CFrame_VectorToWorldSpace(rotation, size * (axisA * a + axisB * b) / 2),
				CFrame_VectorToWorldSpace(rotation, normal) * sign,
				vector.magnitude(size)
			)
		end
	end
end

-- Inspect overlapping upper-face corners, where a spatial join can form a
-- visible step even when its centerline and endpoint faces are both correct.
local function checkSurfaceSteps(segments: { Segment }, normal: vector, limit: number)
	for i = 1, #segments - 1 do
		local adjacentPairs = {
			{ segments[i], segments[i + 1], 1 },
			{ segments[i + 1], segments[i], -1 },
		}
		for _, pair in adjacentPairs do
			local segment = pair[1]
			local other = pair[2]
			local sign = pair[3]
			for _, z in SIGNS do
				local segmentSize = segment.Size
				local corner = CFrame_PointToWorldSpace(
					segment.CFrame,
					normal * (sign * segmentSize.x / 2)
						+ vector.create(0, segmentSize.y / 2, z * segmentSize.z / 2)
				)
				local point = CFrame_PointToObjectSpace(other.CFrame, corner)
				local otherSize = other.Size
				if math.abs(point.x) < otherSize.x / 2 and math.abs(point.z) < otherSize.z / 2 then
					assert(
						point.y - otherSize.y / 2 <= limit,
						`The spatial bend has a harsh surface step of {point.y - otherSize.y / 2} at segment {i} of {#segments}`
					)
				end
			end
		end
	end
end

-- One-to-one matching ignores creation order but still detects duplicate,
-- missing, misplaced, incorrectly rotated, or incorrectly sized parts.
local function checkExpectedParts(actual: { BasePart }, expected: { Segment })
	assert(#actual == #expected, `Expected {#expected} generated parts, got {#actual}`)
	local matched: { [number]: boolean } = {}
	for _, part in actual do
		local found = false
		for i, wanted in expected do
			if matched[i] then
				continue
			end
			local relative = wanted.CFrame:ToObjectSpace(part.CFrame)
			-- Compare the basis vectors rather than ToAxisAngle: the angle of a
			-- near-identity rotation is only accurate to about 3e-4 in float32
			local rotationError = math.max(
				vector.magnitude(CAST_VECTOR(relative.XVector) - X_AXIS),
				vector.magnitude(CAST_VECTOR(relative.YVector) - Y_AXIS)
			)
			if vector.magnitude(CAST_VECTOR(relative.Position)) < 0.0001
				and rotationError < 0.0001
				and vector.magnitude(CAST_VECTOR(part.Size) - wanted.Size) < 0.0001
			then
				matched[i] = true
				found = true
				break
			end
		end
		assert(found, `Unexpected generated part at {part.Position}, size {part.Size}`)
	end
end

local function expectedPart(
	x: number,
	y: number,
	z: number,
	angle: number,
	sizeX: number,
	sizeY: number,
	sizeZ: number
): Segment
	return {
		CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, angle),
		Size = vector.create(sizeX, sizeY, sizeZ),
	}
end

--------------------------------------------------------------------------------
-- Slope profiles
--------------------------------------------------------------------------------

return function(t: TestContext)

	-- Profile frames below come from the highlighted slope edges, independently
	-- of the Spline Join planner. Test both endpoints and both selection orders.
	local slopeCases = {
		{
			Name = "wedge",
			Class = "WedgePart",
			IsWedge = true,
			Frame = CFrame_fromMatrix(vector.zero, X_AXIS, vector.normalize(vector.create(0, 3, -1))),
			Profile = vector.create(4, 2, math.sqrt(40)),
			Axis = Y_AXIS,
			TargetClass = "Part",
			TargetFace = Enum.NormalId.Bottom,
			Turn = -math.pi / 2,
		},
		{
			Name = "part wedge",
			Class = "Part",
			IsWedge = true,
			Frame = CFrame_fromMatrix(vector.zero, X_AXIS, vector.normalize(vector.create(0, 3, -1))),
			Profile = vector.create(4, 2, math.sqrt(40)),
			Axis = Y_AXIS,
			TargetClass = "Part",
			TargetFace = Enum.NormalId.Bottom,
			Turn = -math.pi / 2,
		},
		{
			Name = "corner wedge right",
			Class = "CornerWedgePart",
			Side = "Right",
			Frame = CFrame_fromMatrix(
				vector.zero,
				vector.normalize(vector.create(-1, 2, 0)),
				vector.normalize(vector.create(2, 1, 0))
			),
			Profile = vector.create(2, math.sqrt(20), 6),
			Axis = X_AXIS,
			TargetClass = "WedgePart",
			TargetFace = Enum.NormalId.Left,
			Turn = math.pi / 2,
		},
		{
			Name = "corner wedge back",
			Class = "CornerWedgePart",
			Side = "Back",
			Frame = CFrame_fromMatrix(vector.zero, vector.normalize(vector.create(0, 3, 1)), -X_AXIS),
			Profile = vector.create(2, 4, math.sqrt(40)),
			Axis = X_AXIS,
			TargetClass = "WedgePart",
			TargetFace = Enum.NormalId.Left,
			Turn = math.pi / 2,
		},
	}
	for _, fixture in slopeCases do
		for _, reverse in SELECTION_ORDERS do
			t.test(`SplineJoin: {fixture.Name} slope connects in {if reverse then "reverse" else "forward"} order`, function()
				local folder = createFolder()
				local slope = Instance.new(fixture.Class)
				slope.Size = CAST_VECTOR3(vector.create(4, 2, 6))
				slope.CFrame = CFrame.identity
				if fixture.Class == "Part" then
					slope.Shape = Enum.PartType.Wedge
				end
				slope.Parent = folder

				local target = Instance.new(fixture.TargetClass)
				target.Size = CAST_VECTOR3(fixture.Profile)

				local rotation = fixture.Frame * CFrame.Angles(0, 0, fixture.Turn)
				local startDirection = CFrame_VectorToWorldSpace(fixture.Frame, fixture.Axis)
				local endDirection = CFrame_VectorToWorldSpace(rotation, fixture.Axis)
				local targetFace = translateCFrame(rotation, (startDirection + endDirection) * 10)
				target.CFrame = translateCFrame(
					targetFace,
					endDirection * (vector.dot(CAST_VECTOR(target.Size), fixture.Axis) / 2)
				)
				target.Parent = folder

				local first = {
					Object = slope,
					Normal = Enum.NormalId.Top,
					IsWedge = fixture.IsWedge,
					CornerWedgeSide = fixture.Side,
				}
				local last = { Object = target, Normal = fixture.TargetFace }
				if reverse then
					first, last = last, first
				end

				local segmentCount = 12
				local targetFrame, targetSize = target.CFrame, target.Size
				doExtend(first, last, "SplineJoin", nil, segmentCount)

				-- Neither selected part is resized or replaced
				t.expect(target.CFrame).toBe(targetFrame)
				t.expect(target.Size).toBe(targetSize)

				targetFace = target.CFrame
					* CFrame_fromVector(normalFromId(fixture.TargetFace) * CAST_VECTOR(target.Size) / 2)

				-- Every clone extrudes the selected profile, as the class that can
				-- represent it, and the chain runs from one face to the other.
				local segments: { Segment } = {}
				for _, part in folder:GetChildren() do
					if part ~= slope and part ~= target then
						t.expect(part.ClassName).toBe(fixture.TargetClass)
						near(
							CAST_VECTOR(part.Size) * (vector.one - fixture.Axis),
							fixture.Profile * (vector.one - fixture.Axis)
						)
						table.insert(segments, { CFrame = part.CFrame, Size = CAST_VECTOR(part.Size) })
					end
				end
				t.expect(#segments).toBe(12)
				endsNear(segments, CAST_VECTOR(fixture.Frame.Position), 0.0001)
				endsNear(segments, CAST_VECTOR(targetFace.Position), 0.0001)

				-- The clones at the ends keep the profile's orientation, other
				-- than having begun the turn
				local slopeEnd = if reverse then segments[#segments] else segments[1]
				local targetEnd = if reverse then segments[1] else segments[#segments]
				local ends = { { slopeEnd, fixture.Frame }, { targetEnd, targetFace } }
				for _, pair in ends do
					local segment: Segment, frame: CFrame = pair[1], pair[2]
					assert(
						angleBetween(CAST_VECTOR(segment.CFrame.UpVector), CAST_VECTOR(frame.UpVector)) <= math.rad(10)
							and angleBetween(CAST_VECTOR(segment.CFrame.RightVector), CAST_VECTOR(frame.RightVector))
								<= math.rad(10),
						"The generated curve did not meet the selected slope profile"
					)
				end

				near(CAST_VECTOR(slope.Size), vector.create(4, 2, 6))
				folder:Destroy()
			end)
		end
	end

	-- Planner state

	t.test("SplineJoin: reused buffers keep retained plans and short subsequent calls intact", function()
		local finish = vector.create(10, 10, 0)
		local size = vector.create(4, 2, 3)
		local template = createPart(size)
		local retained = assert(SplineJoin.plan(template, CFrame.identity, finish, -Y_AXIS, X_AXIS, 8))

		local saved: { Segment } = {}
		for i, segment in retained do
			saved[i] = { CFrame = segment.CFrame, Size = segment.Size }
		end

		SplineJoin.plan(template, CFrame.identity, vector.create(4096, 0, 0), -X_AXIS, X_AXIS, 1024)

		local start, target, firstSize, targetSize, normal, targetNormal = tiltedJoin(false, 1)
		local point, offset, rotation = SplineJoin.getTargetPoint(start, target, firstSize, targetSize, normal, targetNormal)
		template.Size = CAST_VECTOR3(firstSize)
		SplineJoin.plan(
			template,
			start,
			point,
			CFrame_VectorToWorldSpace(target, targetNormal),
			normal,
			nil,
			offset,
			rotation
		)

		template.Size = CAST_VECTOR3(size)
		local repeated = assert(SplineJoin.plan(template, CFrame.identity, finish, -Y_AXIS, X_AXIS, 8))

		t.expect(#retained).toBe(8)
		t.expect(#repeated).toBe(8)
		for i, original in saved do
			t.expect(retained[i].CFrame).toBe(original.CFrame)
			t.expect(retained[i].Size).toBe(original.Size)
			t.expect(repeated[i].CFrame).toBe(original.CFrame)
			t.expect(repeated[i].Size).toBe(original.Size)
		end
	end)

	-- Workspace regressions
	t.test("SplineJoin: K to H fills the seam immediately before the target face", function()
		local folder = createFolder()
		local kFrame, kSize = workspacePair("K")
		local hFrame, hSize = workspacePair("H")
		local k = createPart(kSize, kFrame, folder)
		local h = createPart(hSize, hFrame, folder)
		local target = h.CFrame * CFrame.new(-hSize.x / 2, (hSize.y - kSize.y) / 2, 0)

		doExtend({ Object = k, Normal = Enum.NormalId.Right }, { Object = h, Normal = Enum.NormalId.Left }, "SplineJoin")

		-- These points lie just beneath the top surface, where the old
		-- miters left a slit despite the final face itself matching H.
		local seamPositions = {
			vector.create(-0.0738, 0.34, 0),
			vector.create(-0.0745, 0.34, 0),
			vector.create(-0.075, 0.34, 0),
			vector.create(0, -0.35, -0.5),
			vector.create(0, -0.35, 0.5),
			vector.create(0, 0.35, -0.5),
			vector.create(0, 0.35, 0.5),
		}
		local segments: { Segment } = {}
		for _, part in folder:GetChildren() do
			if part ~= k and part ~= h and part:IsA("BasePart") then
				table.insert(segments, { CFrame = part.CFrame, Size = CAST_VECTOR(part.Size) })
			end
		end
		for _, position in seamPositions do
			local point = CFrame_PointToWorldSpace(target, position)
			if position.x == 0 then
				-- On the face itself the last segment has only to reach H
				reachesFacePoint(segments, point, CAST_VECTOR(h.CFrame.XVector), vector.magnitude(kSize))
				continue
			end
			local covered = false
			for _, segment in segments do
				local excess = vector.abs(CFrame_PointToObjectSpace(segment.CFrame, point)) - segment.Size / 2
				if math.max(excess.x, excess.y, excess.z) < 0.00001 then
					covered = true
					break
				end
			end
			assert(covered, `K/H has an uncovered seam at {point}`)
		end

		folder:Destroy()
	end)

	-- Accepted C/E geometry. These values are intentionally literal: deriving
	-- the expectation with SplineJoin.plan would repeat its bugs.
	local expectedJoins = {
		{
			Reverse = false,
			Parts = {
				expectedPart(-9.65048981, 20.8420887, 2.5, -0.02263264, 0.71504617, 0.7, 1),
				expectedPart(-9.07727051, 20.81659126, 2.5, -0.07801541, 0.471726, 0.7, 1),
				expectedPart(-8.71518517, 20.77879333, 2.5, -0.14554892, 0.30406141, 0.7, 1),
				expectedPart(-8.49506664, 20.7395916, 2.5, -0.22568452, 0.19957048, 0.7, 1),
				expectedPart(-8.3628664, 20.70423126, 2.5, -0.31742084, 0.13865893, 0.7, 1),
				expectedPart(-8.28252697, 20.67417908, 2.5, -0.41885191, 0.10416722, 0.7, 1),
				expectedPart(-8.23202133, 20.64887619, 2.5, -0.52807295, 0.08550502, 0.7, 1),
			},
		},
		{
			Reverse = true,
			Parts = {
				expectedPart(-8.57699394, 20.09894943, 2.5, -0.52696651, 0.12964386, 2, 1),
				expectedPart(-8.59322071, 20.10722733, 2.5, -0.41579896, 0.12942073, 2, 1),
				expectedPart(-8.62056541, 20.11735153, 2.5, -0.31082782, 0.13912168, 2, 1),
				expectedPart(-8.6757431, 20.1315155, 2.5, -0.21498802, 0.16676375, 2, 1),
				expectedPart(-8.7957449, 20.15096092, 2.5, -0.1320951, 0.2424425, 2, 1),
				expectedPart(-9.06309223, 20.17446136, 2.5, -0.06596876, 0.42687386, 2, 1),
				expectedPart(-9.62253857, 20.19340706, 2.5, -0.01746705, 0.78997731, 2, 1),
			},
		},
	}
	for _, fixture in expectedJoins do
		t.test(`SplineJoin: {if fixture.Reverse then "E to C" else "C to E"} matches the expected generated parts`, function()
			local folder = createFolder()
			local cFrame, cSize = workspacePair("C")
			local eFrame, eSize = workspacePair("E")
			local c = createPart(cSize, cFrame, folder)
			local e = createPart(eSize, eFrame, folder)

			local segmentCount = 0

			local first = {
				Object = if fixture.Reverse then e else c,
				Normal = if fixture.Reverse then Enum.NormalId.Left else Enum.NormalId.Right,
			}
			local second = {
				Object = if fixture.Reverse then c else e,
				Normal = if fixture.Reverse then Enum.NormalId.Right else Enum.NormalId.Left,
			}
			doExtend(first, second, "SplineJoin", nil, segmentCount)

			local generated: { BasePart } = {}
			for _, part in folder:GetChildren() do
				if part ~= c and part ~= e and part:IsA("BasePart") then
					generated[#generated + 1] = part
				end
			end

			checkExpectedParts(generated, fixture.Parts)
			folder:Destroy()
		end)
	end

	local joins = {
		{ "TOPRAIL", "Front", "C", "Left" },
		{ "H", "Left", "K", "Right" },
		{ "D", "Left", "F", "Right" },
		{ "D", "Left", "F", "Front" },
		{ "F", "Front", "D", "Front" },
		{ "F", "Right", "D", "Back" },
	}
	for _, pair in joins do
		for _, reverse in SELECTION_ORDERS do
			local name = if reverse then `{pair[3]} {pair[4]} to {pair[1]} {pair[2]}` else table.concat(pair, " ")
			t.test(`SplineJoin: workspace {name} reaches both endpoint faces`, function()
				local first, size = workspacePair(pair[1])
				local second, targetSize = workspacePair(pair[3])
				local normal = normalFromId(Enum.NormalId[pair[2]])
				local targetNormal = normalFromId(Enum.NormalId[pair[4]])
				if reverse then
					first, second, size, targetSize, normal, targetNormal =
						second, first, targetSize, size, targetNormal, normal
				end

				local template = createPart(size)

				for _, padding in WORKSPACE_PADDINGS do
					local start = first * CFrame_fromVector(normal * size / 2 + normal * padding)
					local target = second * CFrame_fromVector(targetNormal * targetSize / 2 + targetNormal * padding)
					local finish, offset, rotation =
						SplineJoin.getTargetPoint(start, target, size, targetSize, normal, targetNormal)

					local segments = assert(
						SplineJoin.plan(
							template,
							start,
							finish,
							CFrame_VectorToWorldSpace(target, targetNormal),
							normal,
							nil,
							offset,
							rotation
						)
					)
					local tangentStart, tangentFinish = SplineJoin.getTangents(
						start,
						finish,
						CFrame_VectorToWorldSpace(target, targetNormal),
						normal,
						offset,
						rotation
					)
					local retained = assert(
						SplineJoin.plan(
							template,
							start,
							finish,
							CFrame_VectorToWorldSpace(target, targetNormal),
							normal,
							nil,
							offset,
							rotation,
							tangentStart,
							tangentFinish
						)
					)

					for i, segment in segments do
						t.expect(retained[i].CFrame).toBe(segment.CFrame)
						t.expect(retained[i].Size).toBe(segment.Size)
					end

					checkPlan(segments, CAST_VECTOR(start.Position), finish, normal, size)
					checkFittedFace(segments, CAST_VECTOR(start.Position), start.Rotation, size, normal, -1)
					checkFittedFace(segments, finish, rotation, size, normal, 1)
					assert(
						math.abs(vector.dot(CAST_VECTOR(rotation.UpVector), CAST_VECTOR(target.UpVector))) > 0.9999,
						"The target cross-section must not roll across its face"
					)

					for _, segment in segments do
						assert(
							vector.dot(segment.Size, vector.abs(normal))
								<= vector.magnitude(finish - CAST_VECTOR(start.Position)) * 2 + vector.magnitude(size),
							"Join generated a spike"
						)
						if pair[2] == "Left" and pair[4] == "Right" then
							assert(
								math.abs(CAST_VECTOR(segment.CFrame.UpVector).z) < 0.0001,
								"The shared side axis must not roll near either endpoint"
							)
						end
					end

					if pair[1] == "H" then
						near(
							finish + CAST_VECTOR(rotation.UpVector) * size.y / 2,
							CAST_VECTOR(target.Position) + CAST_VECTOR(target.UpVector) * targetSize.y / 2
						)
					end
					if padding == 0 and pair[2] == "Left" and pair[4] == "Right" then
						checkSurfaceSteps(segments, normal, if pair[1] == "H" then 0.02 else 0.03)
					end
					if pair[1] == "TOPRAIL" and padding == 0 then
						assert(#segments <= 24, `A short rail return generated {#segments} segments`)
					end
					if
						pair[1] == "D"
						and pair[2] == "Left"
						and pair[3] == "F"
						and pair[4] == "Front"
						and reverse
						and padding == 0
					then
						checkSingleOwnerMiters(segments, normal, offset)
						assert(#segments >= 17 and #segments <= 26, `The wide spatial bend generated {#segments} segments`)
						-- The wide section fans about a pivot on its own inside edge,
						-- so the slivers around the pivot all share it and overlap.
						-- What must not happen is the join doubling back on itself:
						-- segments far apart along the chain stay clear of each other.
						local apart = math.ceil(#segments * 0.6)
						for i = 1, #segments - apart do
							for j = i + apart, #segments do
								assert(not areOverlapping(segments[i], segments[j]), `F/D segments {i} and {j} overlap`)
							end
						end
					end
				end
			end)

			if pair[2] == "Left" and pair[4] == "Right" then
				t.test(`RoundedJoin: workspace {name} retains the target face orientation`, function()
					local world = createFolder()
					local aFrame, aSize = workspacePair(pair[1])
					local bFrame, bSize = workspacePair(pair[3])
					local a = createPart(aSize, aFrame, world)
					local b = createPart(bSize, bFrame, world)

					local faceA = { Object = a, Normal = Enum.NormalId[pair[2]] }
					local faceB = { Object = b, Normal = Enum.NormalId[pair[4]] }
					if reverse then
						a, b, faceA, faceB = b, a, faceB, faceA
					end
					a:SetAttribute("KeepGeneratedEnds", true)

					doExtend(faceA, faceB, "RoundedJoin", false, nil, false)

					local parts = world:GetChildren()
					local last = parts[#parts]
					-- The last segment is still finishing the turn, but it must
					-- not roll about the axis it shares with the target
					assert(
						angleBetween(
							CFrame_VectorToWorldSpace(last.CFrame, normalFromId(faceA.Normal)),
							-CFrame_VectorToWorldSpace(b.CFrame, normalFromId(faceB.Normal))
						) <= math.rad(10),
						"Rounded Join does not arrive along the target's normal"
					)
					-- (its chord still carries a little of the sideways offset)
					assert(
						math.abs(vector.dot(CAST_VECTOR(last.CFrame.ZVector), CAST_VECTOR(b.CFrame.ZVector)))
							> 0.999,
						"Rounded Join twists into the target"
					)

					if pair[2] == "Left" and pair[4] == "Right" then
						for _, part in parts do
							assert(
								math.abs(CAST_VECTOR(part.CFrame.UpVector).z) < 0.0001,
								"Rounded Join rolls around a shared side axis"
							)
						end
					end

					world:Destroy()
				end)
			end
		end
	end

	-- Rounded Join integration
	t.test("RoundedJoin: derives tangent endpoints from the original filler radius", function()
		local thicknesses = { 2, 4 }
		for _, thickness in thicknesses do
			withParts(function(folder, a, b, faceA, faceB)
				a.Size = CAST_VECTOR3(vector.create(4, thickness, 3))
				b.Size = CAST_VECTOR3(vector.create(thickness, 4, 3))
				b.Color = a.Color
				local ignoredSegmentCount = 1
				doExtend(faceA, faceB, "RoundedJoin", false, ignoredSegmentCount, false)
				local radius = thickness / 2
				t.expect(CAST_VECTOR(a.Size).x >= 14 - radius).toBe(true)
				near(CAST_VECTOR(a.Size) * vector.create(0, 1, 1), vector.create(0, thickness, 3))
				near(CAST_VECTOR(b.Size), vector.create(thickness, 14 - radius, 3))
				local segments = { { CFrame = a.CFrame, Size = CAST_VECTOR(a.Size) } }
				for _, part in folder:GetChildren() do
					if part ~= a and part ~= b then
						t.expect(part.Color).toBe(a.Color)
						t.expect(part:GetAttribute("ArcTemplate")).toBe(true)
						table.insert(segments, { CFrame = part.CFrame, Size = CAST_VECTOR(part.Size) })
					end
				end
				t.expect(#segments >= 9).toBe(true)
				checkPlan(
					segments,
					vector.create(10 - radius, 0, 0),
					vector.create(10, radius, 0),
					X_AXIS,
					vector.create(4, thickness, 3)
				)
			end)
		end
	end)

	t.test("RoundedJoin: cylinder option, the default, restores the original filler and endpoints", function()
		-- An omitted option must behave the same as an explicit Cylinder
		local optionArguments: { { boolean } } = { { true }, {} }
		for _, arguments in optionArguments do
			withParts(function(folder, a, b, faceA, faceB)
				doExtend(faceA, faceB, "RoundedJoin", false, nil, arguments[1])
				near(CAST_VECTOR(a.Size), vector.create(14, 2, 3))
				near(CAST_VECTOR(b.Size), vector.create(2, 14, 3))
				t.expect(#folder:GetChildren()).toBe(3)
				for _, part in folder:GetChildren() do
					if part ~= a and part ~= b then
						t.expect(part.Shape).toBe(Enum.PartType.Cylinder)
						near(CAST_VECTOR(part.Position), vector.create(10, 0, 0))
						near(CAST_VECTOR(part.Size), vector.create(3, 2, 2))
					end
				end
			end)
		end
	end)

	t.test("RoundedJoin: radius insets the cylinder filler to stay tangent to both parts", function()
		-- Below the automatic radius of 1 the filler would not cover the gap
		local cases = { { Radius = 2.5, Expected = 2.5 }, { Radius = 0.5, Expected = 1 } }
		for _, case in cases do
			withParts(function(folder, a, b, faceA, faceB)
				doExtend(faceA, faceB, "RoundedJoin", false, nil, true, case.Radius)
				-- The outer surfaces are y = -1 on the first part and x = 11 on
				-- the second, and both parts end level with the filler's center
				local radius = case.Expected
				local center = vector.create(11 - radius, -1 + radius, 0)
				near(CAST_VECTOR(a.Size), vector.create(center.x + 4, 2, 3))
				near(CAST_VECTOR(b.Size), vector.create(2, 14 - center.y, 3))
				near(CAST_VECTOR(a.Position), vector.create((center.x - 4) / 2, 0, 0))
				near(CAST_VECTOR(b.Position), vector.create(10, (14 + center.y) / 2, 0))
				t.expect(#folder:GetChildren()).toBe(3)
				for _, part in folder:GetChildren() do
					if part ~= a and part ~= b then
						t.expect(part.Shape).toBe(Enum.PartType.Cylinder)
						near(CAST_VECTOR(part.Position), center)
						near(CAST_VECTOR(part.Size), vector.create(3, 2 * radius, 2 * radius))
					end
				end
			end)
		end
	end)

	t.test("RoundedJoin: a larger cylinder filler is tangent to angled parts", function()
		local radius = 3
		for _, angle in { 30, 60, 120 } do
			local folder = createFolder()
			local a = createPart(vector.create(8, 2, 3), CFrame.new(-4, 0, 0), folder)
			local b = createPart(
				vector.create(8, 1, 3),
				CFrame.new(12, 0, 0) * CFrame.Angles(0, 0, math.rad(angle)) * CFrame.new(10, 0, 0),
				folder
			)
			doExtend(
				{ Object = a, Normal = Enum.NormalId.Right },
				{ Object = b, Normal = Enum.NormalId.Left },
				"RoundedJoin",
				false,
				nil,
				true,
				radius
			)
			t.expect(#folder:GetChildren()).toBe(3)
			local filler
			for _, part in folder:GetChildren() do
				if part ~= a and part ~= b then
					filler = part
				end
			end
			near(CAST_VECTOR(filler.Size), vector.create(3, 2 * radius, 2 * radius))
			for _, part in { a, b } do
				local center = CFrame_PointToObjectSpace(part.CFrame, CAST_VECTOR(filler.Position))
				local size = CAST_VECTOR(part.Size)
				-- The joined face passes through the filler's center...
				assert(math.abs(math.abs(center.x) - size.x / 2) < 0.0001, `{angle}: the part does not end at the filler`)
				-- ...and one side surface sits exactly a radius away from it
				local surfaceError = math.min(
					math.abs(math.abs(center.y - size.y / 2) - radius),
					math.abs(math.abs(center.y + size.y / 2) - radius)
				)
				assert(surfaceError < 0.0001, `{angle}: the filler is not tangent, off by {surfaceError}`)
			end
			folder:Destroy()
		end
	end)

	t.test("RoundedJoin: radius sets the outer radius of the spline filler's bend", function()
		-- Expected is the radius of the center line, which runs half of the
		-- 2 stud thickness inside the outer surface. The automatic bend, with a
		-- center radius of 1 and so an outer radius of 2, is the tightest.
		local cases = {
			{ Radius = 5, Expected = 4 },
			{ Radius = 2.5, Expected = 1.5 },
			{ Radius = 1.5, Expected = 1 },
			{ Radius = 0, Expected = 1 },
		}
		for _, case in cases do
			withParts(function(folder, a, b, faceA, faceB)
				doExtend(faceA, faceB, "RoundedJoin", false, nil, false, case.Radius)
				local radius = case.Expected
				near(CAST_VECTOR(a.Size), vector.create(14 - radius, 2, 3))
				near(CAST_VECTOR(b.Size), vector.create(2, 14 - radius, 3))
				local segments = { { CFrame = a.CFrame, Size = CAST_VECTOR(a.Size) } }
				-- The bend turns about this point, and its outside is the part
				-- of the clones that lies furthest from it
				local turnCenter = vector.create(10 - radius, radius, 0)
				local outerRadius = 0
				for _, part in folder:GetChildren() do
					if part ~= a and part ~= b then
						table.insert(segments, { CFrame = part.CFrame, Size = CAST_VECTOR(part.Size) })
						for _, x in SIGNS do
							for _, y in SIGNS do
								local corner = CFrame_PointToWorldSpace(
									part.CFrame,
									CAST_VECTOR(part.Size) * vector.create(x, y, 0) / 2
								)
								outerRadius = math.max(outerRadius, vector.magnitude(corner - turnCenter))
							end
						end
					end
				end
				t.expect(#segments >= 9).toBe(true)
				-- Corners of straight clones stand slightly proud of the true arc
				local expectedOuter = math.max(case.Radius, 2)
				assert(
					outerRadius >= expectedOuter - 0.001 and outerRadius <= expectedOuter * 1.02,
					`Radius {case.Radius} produced an outer radius of {outerRadius}`
				)
				checkPlan(
					segments,
					vector.create(10 - radius, 0, 0),
					vector.create(10, radius, 0),
					X_AXIS,
					vector.create(4, 2, 3)
				)
			end)
		end
	end)

	-- Planner geometry
	t.test("SplineJoin: three-segment reverse bends cover both complete endpoint faces", function()
		for _, reverse in SELECTION_ORDERS do
			for _, mirror in SIGNS do
				local start, target, size, targetSize, normal, targetNormal = tiltedJoin(reverse, mirror)
				local template = createPart(size)

				start = translateCFrame(start, CFrame_VectorToWorldSpace(start, normal) * 0.6)
				target = translateCFrame(target, CFrame_VectorToWorldSpace(target, targetNormal) * 0.6)

				local finish, offset =
					SplineJoin.getTargetPoint(start, target, size, targetSize, normal, targetNormal)
				local segments = assert(
					SplineJoin.plan(
						template,
						start,
						finish,
						CFrame_VectorToWorldSpace(target, targetNormal),
						normal,
						3,
						offset
					)
				)

				t.expect(#segments).toBe(3)
				checkEndFace(segments, start, size, -CFrame_VectorToWorldSpace(start, normal))
				checkTargetFace(segments, target, targetSize, targetNormal, finish, size)
				checkPlan(segments, CAST_VECTOR(start.Position), finish, normal, size)
			end
		end
	end)

	t.test("SplineJoin: offset D/F endpoints retain their cross-section orientation", function()
		local d = CFrame.new(-0.6036731, 14.7836733, 12.95) * CFrame.Angles(0, 0, -math.atan2(2, 3))
		local f = CFrame.new(-11.85, 20.85, 15.275)
		local dSize = vector.create(19.5422287, 2, 1)
		local fSize = vector.create(3.7, 0.7, 1)
		for _, reverse in SELECTION_ORDERS do
			for _, padding in WORKSPACE_PADDINGS do
				local first = if reverse then d else f
				local second = if reverse then f else d
				local size = if reverse then dSize else fSize
				local targetSize = if reverse then fSize else dSize
				local normal = if reverse then -X_AXIS else X_AXIS
				local targetNormal = if reverse then X_AXIS else -X_AXIS
				local template = createPart(size)

				local start = first * CFrame_fromVector(normal * (size.x / 2 + padding))
				local target = second * CFrame_fromVector(targetNormal * (targetSize.x / 2 + padding))
				local finish, offset =
					SplineJoin.getTargetPoint(start, target, size, targetSize, normal, targetNormal)
				local segments = assert(
					SplineJoin.plan(
						template,
						start,
						finish,
						CFrame_VectorToWorldSpace(target, targetNormal),
						normal,
						nil,
						offset
					)
				)

				checkEndFace(segments, start, size, -CFrame_VectorToWorldSpace(start, normal))
				checkTargetFace(segments, target, targetSize, targetNormal, finish, size)
				assert(
					angleBetween(CAST_VECTOR(segments[#segments].CFrame.UpVector), CAST_VECTOR(target.UpVector)) <= math.rad(5),
					"The last segment's cross-section is not oriented like the target's"
				)

				if reverse then
					-- The surface must level out into F, rather than dipping as
					-- the taller template turns around the spatial curve.
					local top = CAST_VECTOR(target.Position).y + targetSize.y / 2
					for i = #segments - 3, #segments do
						local segment = segments[i]
						local surface = CAST_VECTOR(segment.CFrame.Position)
							+ CAST_VECTOR(segment.CFrame.UpVector) * size.y / 2
						assert(math.abs(surface.y - top) < 0.03, "The upper surface curls into F")
					end
				end

				checkPlan(segments, CAST_VECTOR(start.Position), finish, normal, size)
			end
		end
	end)

	t.test("SplineJoin: automatic tangents can be retained and edited explicitly", function()
		for _, reverse in SELECTION_ORDERS do
			local start, target, size, targetSize, normal, targetNormal = tiltedJoin(reverse, 1)
			local template = createPart(size)

			start = translateCFrame(start, CFrame_VectorToWorldSpace(start, normal) * 0.6)
			target = translateCFrame(target, CFrame_VectorToWorldSpace(target, targetNormal) * 0.6)

			local finish, offset =
				SplineJoin.getTargetPoint(start, target, size, targetSize, normal, targetNormal)
			local endNormal = CFrame_VectorToWorldSpace(target, targetNormal)
			local tangentStart, tangentFinish =
				SplineJoin.getTangents(start, finish, endNormal, normal, offset)

			local automatic = assert(SplineJoin.plan(template, start, finish, endNormal, normal, 8, offset))
			local explicit =
				assert(SplineJoin.plan(template, start, finish, endNormal, normal, 8, offset, nil, tangentStart, tangentFinish))

			for i, segment in automatic do
				t.expect(explicit[i].CFrame).toBe(segment.CFrame)
				t.expect(explicit[i].Size).toBe(segment.Size)
			end

			local original = tangentStart
			tangentStart *= 1.5
			local edited =
				assert(SplineJoin.plan(template, start, finish, endNormal, normal, 8, offset, nil, tangentStart, tangentFinish))

			assert(
				vector.magnitude(CAST_VECTOR(edited[4].CFrame.Position) - CAST_VECTOR(automatic[4].CFrame.Position))
					> 0.001
			)
			t.expect(tangentStart).toBe(original * 1.5)
			checkEndFace(edited, start, size, -CFrame_VectorToWorldSpace(start, normal))
			checkTargetFace(edited, target, targetSize, targetNormal, finish, size)
		end
	end)

	t.test("SplineJoin: explicit tangent directions can bend out of the endpoint plane", function()
		local size = vector.create(2, 0.5, 0.5)
		local finish = vector.create(8, 6, 0)
		local template = createPart(size)

		local tangentStart, tangentFinish =
			SplineJoin.getTangents(CFrame.identity, finish, -Y_AXIS, X_AXIS)
		tangentStart += Z_AXIS * 4
		tangentFinish += Z_AXIS * 2

		local segments = assert(
			SplineJoin.plan(
				template,
				CFrame.identity,
				finish,
				-Y_AXIS,
				X_AXIS,
				12,
				nil,
				nil,
				tangentStart,
				tangentFinish
			)
		)

		assert(CAST_VECTOR(segments[6].CFrame.Position).z > 1, "Explicit handles should change the curve's plane")
		checkPlan(segments, vector.zero, finish, X_AXIS, size)
		checkEndFace(segments, CFrame.identity, size, -X_AXIS)
		checkEndFace(segments, CFrame_fromVector(finish) * CFrame.Angles(0, 0, math.pi / 2), size, Y_AXIS)
	end)

	t.test("SplineJoin: manual count forms a curved connected chain", function()
		local size = vector.create(4, 2, 3)
		local template = createPart(size)

		local segments = assert(
			SplineJoin.plan(template, CFrame.identity, vector.create(10, 10, 0), -Y_AXIS, X_AXIS, 12)
		)

		t.expect(#segments).toBe(12)
		checkPlan(segments, vector.zero, vector.create(10, 10, 0), X_AXIS, size)
		-- An even quarter turn puts half a step's turn into each end segment
		checkTurningEnds(segments, X_AXIS, X_AXIS, Y_AXIS, math.rad(90 / 12))
		checkEndFace(segments, CFrame.identity, size, -X_AXIS)
		checkEndFace(segments, CFrame.new(10, 10, 0) * CFrame.Angles(0, 0, math.pi / 2), size, Y_AXIS)
		-- The middle of a quarter-circle is below the straight diagonal.
		t.expect(segments[6].CFrame.X - segments[6].CFrame.Y > 3).toBe(true)
	end)

	t.test("SplineJoin: thick coarse and fine arcs cover every miter corner", function()
		local segmentCounts = { 3, 12, 48 }
		for _, count in segmentCounts do
			local widths = { 2, 8 }
			for _, width in widths do
				local size = vector.create(4, width, 3)
				local template = createPart(size)
				local finish = vector.create(10, 10, 0)

				local segments =
					assert(SplineJoin.plan(template, CFrame.identity, finish, -Y_AXIS, X_AXIS, count))

				checkPlan(segments, vector.zero, finish, X_AXIS, size)
				checkMiters(segments, size)
			end
		end
	end)

	t.test("SplineJoin: target snaps to nearer top or bottom with clone thickness inset", function()
		local target = CFrame.new(10, 0, 0) * CFrame.Angles(0, 0, 0.4)
		for _, side in SIGNS do
			local start = target * CFrame.new(-10, side * 20, 0)
			local point = SplineJoin.getTargetPoint(
				start,
				target,
				vector.create(4, 2, 3),
				vector.create(4, 12, 3),
				X_AXIS,
				-X_AXIS
			)

			near(point, CFrame_PointToWorldSpace(target, vector.create(0, side * 5, 0)))
		end
	end)

	t.test("SplineJoin: taller templates align their edge to the shorter target", function()
		local target = CFrame.new(10, 0, 0) * CFrame.Angles(0, 0, 0.4)
		local size = vector.create(4, 12, 3)
		local template = createPart(size)
		for _, side in SIGNS do
			local start = target * CFrame.new(-10, -side * 20, 0)
			local point =
				SplineJoin.getTargetPoint(start, target, size, vector.create(4, 2, 3), X_AXIS, -X_AXIS)

			-- Whichever side the shorter target occupies, the matching surface
			-- is flush even though the clone's center lies beyond the target face.
			near(point, CFrame_PointToWorldSpace(target, vector.create(0, -side * 5, 0)))

			local targetUp = CAST_VECTOR(target.UpVector)
			local surface = point + targetUp * (side * size.y / 2)
			near(surface, CAST_VECTOR(target.Position) + targetUp * side)

			local segments = assert(SplineJoin.plan(template, start, point, -CAST_VECTOR(target.RightVector), X_AXIS, 12))
			checkPlan(segments, CAST_VECTOR(start.Position), point, X_AXIS, size)
		end
	end)

	t.test("SplineJoin: unequal-height tilted joins stay on the matching edge without an S bend", function()
		for _, mirror in SIGNS do
			for _, reverse in SELECTION_ORDERS do
				local start, target, firstSize, secondSize, n1, n2 = tiltedJoin(reverse, mirror)
				local template = createPart(firstSize)

				local finish = SplineJoin.getTargetPoint(start, target, firstSize, secondSize, n1, n2)

				near(
					finish,
					CAST_VECTOR(target.Position)
						+ CAST_VECTOR(target.UpVector) * (mirror * (secondSize.y - firstSize.y) / 2)
				)

				local segments =
					assert(SplineJoin.plan(template, start, finish, CFrame_VectorToWorldSpace(target, n2), n1, 24))

				checkTurningEnds(
					segments,
					n1,
					CFrame_VectorToWorldSpace(start, n1),
					-CFrame_VectorToWorldSpace(target, n2),
					math.rad(5)
				)

				local previous = CFrame_VectorToWorldSpace(start, n1)
				local turnSign = mirror * (if reverse then 1 else -1)
				for _, segment in segments do
					local direction = CFrame_VectorToWorldSpace(segment.CFrame, n1)
					t.expect(vector.cross(previous, direction).z * turnSign >= -0.0001).toBe(true)
					previous = direction
				end

				checkPlan(segments, CAST_VECTOR(start.Position), finish, n1, firstSize)
			end
		end
	end)

	t.test("SplineJoin: automatic tilted joins distribute the turn through both endpoints", function()
		for _, reverse in SELECTION_ORDERS do
			local start, target, size, targetSize, normal, targetNormal = tiltedJoin(reverse, 1)
			local template = createPart(size)

			local finish = SplineJoin.getTargetPoint(start, target, size, targetSize, normal, targetNormal)
			local segments = assert(
				SplineJoin.plan(
					template,
					start,
					finish,
					CFrame_VectorToWorldSpace(target, targetNormal),
					normal
				)
			)

			t.expect(#segments <= 8).toBe(true)

			local previous = CFrame_VectorToWorldSpace(start, normal)
			for _, segment in segments do
				local direction = CFrame_VectorToWorldSpace(segment.CFrame, normal)
				local turn = math.acos(math.clamp(vector.dot(previous, direction), -1, 1))
				assert(turn <= math.rad(6.5), "A coarse endpoint must not consume multiple turns")
				previous = direction
			end

			assert(
				angleBetween(previous, -CFrame_VectorToWorldSpace(target, targetNormal)) <= math.rad(6.5),
				"A coarse endpoint must not consume multiple turns"
			)
			if reverse then
				local penultimate = CFrame_VectorToWorldSpace(segments[#segments - 1].CFrame, normal)
				assert(
					math.acos(math.clamp(vector.dot(previous, penultimate), -1, 1)) < math.rad(3),
					"The broad flat end needs a smaller turn than the tight curved end"
				)
			end

			checkPlan(segments, CAST_VECTOR(start.Position), finish, normal, size)
		end
	end)

	t.test("SplineJoin: padding does not oversample tiny reverse bends", function()
		for _, reverse in SELECTION_ORDERS do
			local paddingValues = { 0.2, 0.3, 0.4, 0.5, 0.6 }

			for _, padding in paddingValues do
				local start, target, size, targetSize, normal, targetNormal = tiltedJoin(reverse, 1)
				local template = createPart(size)

				start = translateCFrame(start, CFrame_VectorToWorldSpace(start, normal) * padding)
				target = translateCFrame(target, CFrame_VectorToWorldSpace(target, targetNormal) * padding)

				local finish, surfaceOffset =
					SplineJoin.getTargetPoint(start, target, size, targetSize, normal, targetNormal)
				local endNormal = CFrame_VectorToWorldSpace(target, targetNormal)

				local segments =
					assert(SplineJoin.plan(template, start, finish, endNormal, normal, nil, surfaceOffset))

				assert(#segments <= 13, `Padding {padding} generated {#segments} segments`)
				checkPlan(segments, CAST_VECTOR(start.Position), finish, normal, size)
				checkTurningEnds(segments, normal, CFrame_VectorToWorldSpace(start, normal), -endNormal, math.rad(10))
			end
		end
	end)

	t.test("SplineJoin: C-first padding keeps inflection segments inside the join", function()
		local translations = { vector.zero, vector.create(-10, 20.85, 2.5) }

		for _, offset in translations do
			local paddingValues = { 0.5999, 0.6, 0.6001 }

			for _, padding in paddingValues do
				local start, target, size, targetSize, normal, targetNormal = tiltedJoin(false, 1)
				local template = createPart(size)

				start = translateCFrame(start, offset + CFrame_VectorToWorldSpace(start, normal) * padding)
				target = translateCFrame(
					target,
					offset + CFrame_VectorToWorldSpace(target, targetNormal) * padding
				)

				local finish, surfaceOffset =
					SplineJoin.getTargetPoint(start, target, size, targetSize, normal, targetNormal)
				local segments = assert(
					SplineJoin.plan(
						template,
						start,
						finish,
						CFrame_VectorToWorldSpace(target, targetNormal),
						normal,
						nil,
						surfaceOffset
					)
				)

				local startPosition = CAST_VECTOR(start.Position)
				local gap = vector.magnitude(finish - startPosition)

				for _, segment in segments do
					-- These connected segments were over 40 studs long in a gap
					-- under one stud: endpoint and overlap checks alone passed.
					assert(segment.Size.x <= gap, `Inflection produced a {segment.Size.x}-stud spike`)
					assert(
						vector.magnitude(CAST_VECTOR(segment.CFrame.Position) - startPosition) <= gap + size.y / 2,
						"Inflection moved a segment outside the join"
					)
				end

				checkPlan(segments, startPosition, finish, normal, size)
				assert(#segments <= 11, "The small padded join should not regain excessive detail")
			end
		end
	end)

	t.test("SplineJoin: padded E/C detail stays similar in either selection order", function()
		local counts = {}

		for _, reverse in SELECTION_ORDERS do
			local start, target, size, targetSize, normal, targetNormal = tiltedJoin(reverse, 1)
			local template = createPart(size)

			start = translateCFrame(start, CFrame_VectorToWorldSpace(start, normal) * 0.6)
			target = translateCFrame(target, CFrame_VectorToWorldSpace(target, targetNormal) * 0.6)

			local finish, surfaceOffset =
				SplineJoin.getTargetPoint(start, target, size, targetSize, normal, targetNormal)
			local segments = assert(
				SplineJoin.plan(
					template,
					start,
					finish,
					CFrame_VectorToWorldSpace(target, targetNormal),
					normal,
					nil,
					surfaceOffset
				)
			)

			if reverse then
				local endDirection = CFrame_VectorToWorldSpace(segments[#segments].CFrame, normal)
				local previousDirection = CFrame_VectorToWorldSpace(segments[#segments - 1].CFrame, normal)
				assert(
					math.acos(math.clamp(vector.dot(endDirection, previousDirection), -1, 1)) <= math.rad(7),
					"The E-first curve must meet C gently"
				)
			end

			local previous = CFrame_VectorToWorldSpace(start, normal)

			for _, segment in segments do
				local direction = CFrame_VectorToWorldSpace(segment.CFrame, normal)
				assert(
					math.acos(math.clamp(vector.dot(previous, direction), -1, 1)) <= math.rad(15),
					"Surface fitting must not concentrate the bend into a sharp block corner"
				)
				assert(
					CAST_VECTOR(segment.CFrame.RightVector).y <= math.sin(math.rad(16)),
					"The tall template must not amplify the small reverse bend into a large bulge"
				)
				previous = direction
			end

			table.insert(counts, #segments)
		end

		assert(math.abs(counts[1] - counts[2]) <= 1, "Selecting C first should not add unnecessary detail")
		t.expect(counts[1] <= 9).toBe(true)
		t.expect(counts[2] <= 9).toBe(true)
	end)

	t.test("SplineJoin: wedges meet along their thick edge whichever way they bend", function()
		local size = vector.create(6, 2, 3)
		local template = Instance.new("WedgePart")
		template.Size = CAST_VECTOR3(size)

		-- A wedge is thickest at its back, local +Z. Bending toward +Z puts that
		-- side inside the curve, where overlapping neighbors would come up
		-- through each other's slopes.
		for _, side in SIGNS do
			local segments = assert(
				SplineJoin.plan(template, CFrame.identity, vector.create(10, 0, 10 * side), -Z_AXIS * side, X_AXIS, 8)
			)
			t.expect(#segments).toBe(8)

			local function corner(segment: Segment, along: number, z: number): vector
				return CFrame_PointToWorldSpace(
					segment.CFrame,
					vector.create(along * segment.Size.x / 2, 0, z * segment.Size.z / 2)
				)
			end

			-- The thick edges meet at every joint, and touch the planes of both
			-- selected faces beside those faces' own thick edges. (A tilted
			-- wedge spans slightly more of the plane than the face does.)
			local first = corner(segments[1], -1, 1)
			local last = corner(segments[8], 1, 1)
			assert(math.abs(first.x) < 0.0001, "The first wedge's thick edge does not touch the first face")
			assert(math.abs(first.z - size.z / 2) < 0.05, "The first wedge is not beside the first face")
			assert(math.abs(last.z - 10 * side) < 0.0001, "The last wedge's thick edge does not touch the second face")
			assert(math.abs(last.x - (10 - side * size.z / 2)) < 0.05, "The last wedge is not beside the second face")
			for i = 1, 7 do
				near(corner(segments[i], 1, 1), corner(segments[i + 1], -1, 1))

				-- The thin edges overlap outside the bend, and part inside it
				local direction = CFrame_VectorToWorldSpace(segments[i].CFrame, X_AXIS)
				local thinGap = vector.dot(corner(segments[i + 1], -1, -1) - corner(segments[i], 1, -1), direction)
				if side == 1 then
					assert(thinGap > 0.01, "Wedges with their thick side inside the bend must not overlap")
				else
					assert(thinGap < -0.01, "Wedges with their thick side outside the bend must still overlap")
				end
			end

			for _, segment in segments do
				near(segment.Size * vector.create(0, 1, 1), size * vector.create(0, 1, 1))
				t.expect(segment.ClassName).toBe("WedgePart")
			end
		end
	end)

	t.test("SplineJoin: all six template faces keep their cross sections", function()
		local size = vector.create(4, 2, 3)
		local template = createPart(size)

		for _, normalId in Enum.NormalId:GetEnumItems() do
			local normal = normalFromId(normalId)
			local start = CFrame.new(5, 8, -2) * CFrame.Angles(0.4, 0.7, 0.2)
			local turn = if math.abs(normal.y) < 0.5 then Y_AXIS else X_AXIS
			local finish = CFrame_PointToWorldSpace(start, (normal + turn) * 10)

			local segments =
				assert(SplineJoin.plan(template, start, finish, -CFrame_VectorToWorldSpace(start, turn), normal, 9))

			checkPlan(segments, CAST_VECTOR(start.Position), finish, normal, size)
		end
	end)

	t.test("SplineJoin: automatic count responds to length and curvature", function()
		local size = vector.create(4, 2, 3)
		local template = createPart(size)

		local straight =
			assert(SplineJoin.plan(template, CFrame.identity, vector.create(8, 0, 0), -X_AXIS, X_AXIS))
		local long =
			assert(SplineJoin.plan(template, CFrame.identity, vector.create(80, 0, 0), -X_AXIS, X_AXIS))
		local curved =
			assert(SplineJoin.plan(template, CFrame.identity, vector.create(5, 5, 0), -Y_AXIS, X_AXIS))

		t.expect(#long > #straight).toBe(true)
		t.expect(#curved >= 9).toBe(true)
		checkPlan(straight, vector.zero, vector.create(8, 0, 0), X_AXIS, size)
	end)

	t.test("SplineJoin: large gaps and manual counts can exceed 512 segments", function()
		local size = vector.create(4, 2, 3)
		local finish = vector.create(4096, 0, 0)
		local template = createPart(size)

		local automatic = assert(SplineJoin.plan(template, CFrame.identity, finish, -X_AXIS, X_AXIS))
		t.expect(#automatic).toBe(1024)

		local manual = assert(SplineJoin.plan(template, CFrame.identity, finish, -X_AXIS, X_AXIS, 768))
		t.expect(#manual).toBe(768)

		local plans = { automatic, manual }
		for _, segments in plans do
			local length = 0
			for _, segment in segments do
				assert(segment.Size.x <= 2048, "The gap must be divided into valid part sizes")
				length += segment.Size.x
			end

			t.expect(length).toBe(finish.x)
			endsNear(segments, vector.zero, 0.0001)
			endsNear(segments, finish, 0.0001)
		end
	end)

	t.test("SplineJoin: skew and same-facing endpoints remain connected", function()
		local directions = { X_AXIS, -X_AXIS, Y_AXIS }
		local size = vector.create(4, 2, 3)
		local template = createPart(size)

		for _, direction in directions do
			local finish = vector.create(10, 10, 7)
			local segments = assert(SplineJoin.plan(template, CFrame.identity, finish, direction, X_AXIS, 20))

			checkPlan(segments, vector.zero, finish, X_AXIS, size)
		end
	end)

	-- doExtend integration
	t.test("SplineJoin: leaves both parts untouched and preserves clones", function()
		withParts(function(folder, a, b, faceA, faceB)
			b.Color = a.Color
			local segmentCount = 7
			doExtend(faceA, faceB, "SplineJoin", false, segmentCount)
			t.expect(#folder:GetChildren()).toBe(9)
			near(CAST_VECTOR(a.Size), vector.create(4, 2, 3))
			near(CAST_VECTOR(a.Position), vector.create(-2, 0, 0))
			near(CAST_VECTOR(b.Size), vector.create(2, 4, 3))
			near(CAST_VECTOR(b.Position), vector.create(10, 12, 0))
			local segments = {}
			for _, part in folder:GetChildren() do
				if part ~= a and part ~= b then
					t.expect(part.Color).toBe(a.Color)
					t.expect(part:GetAttribute("ArcTemplate")).toBe(true)
					t.expect(part:FindFirstChild("TemplateAttachment") ~= nil).toBe(true)
					table.insert(segments, { CFrame = part.CFrame, Size = CAST_VECTOR(part.Size) })
				end
			end
			checkPlan(segments, vector.create(0, 0, 0), vector.create(10, 10, 0), X_AXIS, vector.create(4, 2, 3))
			checkEndFace(segments, CFrame.identity, vector.create(4, 2, 3), -X_AXIS)
			checkTurningEnds(segments, X_AXIS, X_AXIS, Y_AXIS, math.rad(90 / 7))
		end)
	end)

	t.test("SplineJoin: fades Color and Transparency between parts that differ in them", function()
		local cases = {
			{ Color = Color3.new(0, 0, 1), Transparency = 0.5 },
			{ Color = Color3.new(0, 0, 1), Transparency = 0 },
			{ Color = Color3.new(1, 0, 0), Transparency = 0.5 },
			{ Color = Color3.new(1, 0, 0), Transparency = 0 },
		}
		for _, case in cases do
			withParts(function(folder, a, b, faceA, faceB)
				a.Color = Color3.new(1, 0, 0)
				b.Color = case.Color
				b.Transparency = case.Transparency
				local segmentCount = 8
				doExtend(faceA, faceB, "SplineJoin", false, segmentCount)

				-- Generated parts are parented in order from the first part to the second
				local previousBlue, previousTransparency = 0, 0
				local count = 0
				for _, part in folder:GetChildren() do
					if part == a or part == b then
						continue
					end
					count += 1
					if case.Color == a.Color then
						t.expect(part.Color).toBe(a.Color)
					else
						t.expect(part.Color.B > previousBlue and part.Color.B < 1).toBe(true)
						-- Part colors are stored with 8 bits per channel
						t.expect(math.abs(part.Color.R - (1 - part.Color.B)) < 2 / 255).toBe(true)
						previousBlue = part.Color.B
					end
					if case.Transparency == 0 then
						t.expect(part.Transparency).toBe(0)
					else
						t.expect(part.Transparency > previousTransparency and part.Transparency < 0.5).toBe(true)
						previousTransparency = part.Transparency
					end
				end
				t.expect(count >= 6).toBe(true)
				t.expect(a.Color).toBe(Color3.new(1, 0, 0))
				t.expect(b.Color).toBe(case.Color)
				t.expect(b.Transparency).toBe(case.Transparency)
			end)
		end
	end)

	t.test("SplineJoin: matching plain parts are not extended to absorb the end segments", function()
		withParts(function(folder, a, b, faceA, faceB)
			a:ClearAllChildren()
			a:SetAttribute("ArcTemplate", nil)
			b.Color = a.Color
			local segmentCount = 12
			doExtend(faceA, faceB, "SplineJoin", false, segmentCount)
			t.expect(#folder:GetChildren()).toBe(14)
			near(CAST_VECTOR(a.Size), vector.create(4, 2, 3))
			near(CAST_VECTOR(a.Position), vector.create(-2, 0, 0))
			near(CAST_VECTOR(b.Size), vector.create(2, 4, 3))
			near(CAST_VECTOR(b.Position), vector.create(10, 12, 0))
		end)
	end)

	t.test("SplineJoin: invalid counts leave sources untouched", function()
		local segmentCounts = { -1, 1.5, math.huge, 0 / 0 }
		for _, count in segmentCounts do
			withParts(function(folder, a, b, faceA, faceB)
				local segmentCount = count
				t.expect(function()
					doExtend(faceA, faceB, "SplineJoin", false, segmentCount)
				end).toThrow("Spline Join:")
				t.expect(#folder:GetChildren()).toBe(2)
				near(CAST_VECTOR(a.Size), vector.create(4, 2, 3))
				near(CAST_VECTOR(b.Size), vector.create(2, 4, 3))
			end)
		end
	end)
end
