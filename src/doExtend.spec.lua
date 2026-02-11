local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local doExtend = require(script.Parent.doExtend)

local EPSILON = 0.01

local function makeFace(part: BasePart, normal: Enum.NormalId): doExtend.Face
	return {
		Object = part,
		Normal = normal,
		IsWedge = false,
	}
end

local function approxEqual(a: number, b: number): boolean
	return math.abs(a - b) < EPSILON
end

local function makePart(cf: CFrame, size: Vector3): BasePart
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.Parent = workspace
	return part
end

local function cleanup(...: BasePart)
	for _, part in {...} do
		part:Destroy()
	end
	-- Also clean up any children that doExtend may have created (e.g. RoundedJoin filler, acute wedge fills)
	for _, child in workspace:GetChildren() do
		if child.Name:find("_Extended") or (child:IsA("Part") and child.Shape == Enum.PartType.Cylinder) or child:IsA("WedgePart") then
			child:Destroy()
		end
	end
end

return function(t: TestContext)
	--------------------------------------------------------------------------------
	-- OuterTouch
	--------------------------------------------------------------------------------

	t.test("OuterTouch resizes two axis-aligned parts", function()
		local partA = makePart(CFrame.new(-5, 0, 0), Vector3.new(4, 4, 4))
		local partB = makePart(CFrame.new(5, 0, 0), Vector3.new(4, 4, 4))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		doExtend(faceA, faceB, "OuterTouch")

		-- Part A should have grown along X (parallel path only resizes faceA)
		t.expect(partA.Size.X > 4).toBe(true)
		cleanup(partA, partB)
	end)

	t.test("OuterTouch: parallel faces meet at midpoint", function()
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(CFrame.new(3, 0, 0), Vector3.new(2, 2, 2))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		doExtend(faceA, faceB, "OuterTouch")

		-- Right face of A should meet left face of B
		local rightFaceA = partA.CFrame.Position.X + partA.Size.X / 2
		local leftFaceB = partB.CFrame.Position.X - partB.Size.X / 2
		t.expect(approxEqual(rightFaceA, leftFaceB)).toBe(true)
		cleanup(partA, partB)
	end)

	t.test("OuterTouch: already touching parts don't change", function()
		local partA = makePart(CFrame.new(-2, 0, 0), Vector3.new(4, 4, 4))
		local partB = makePart(CFrame.new(2, 0, 0), Vector3.new(4, 4, 4))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		doExtend(faceA, faceB, "OuterTouch")

		t.expect(approxEqual(partA.Size.X, 4)).toBe(true)
		t.expect(approxEqual(partB.Size.X, 4)).toBe(true)
		cleanup(partA, partB)
	end)

	t.test("OuterTouch: works along Y axis", function()
		local partA = makePart(CFrame.new(0, -4, 0), Vector3.new(2, 2, 2))
		local partB = makePart(CFrame.new(0, 4, 0), Vector3.new(2, 2, 2))
		local faceA = makeFace(partA, Enum.NormalId.Top)
		local faceB = makeFace(partB, Enum.NormalId.Bottom)

		doExtend(faceA, faceB, "OuterTouch")

		local topA = partA.CFrame.Position.Y + partA.Size.Y / 2
		local bottomB = partB.CFrame.Position.Y - partB.Size.Y / 2
		t.expect(approxEqual(topA, bottomB)).toBe(true)
		cleanup(partA, partB)
	end)

	t.test("OuterTouch: works along Z axis", function()
		local partA = makePart(CFrame.new(0, 0, -4), Vector3.new(2, 2, 2))
		local partB = makePart(CFrame.new(0, 0, 4), Vector3.new(2, 2, 2))
		local faceA = makeFace(partA, Enum.NormalId.Back)
		local faceB = makeFace(partB, Enum.NormalId.Front)

		doExtend(faceA, faceB, "OuterTouch")

		t.expect(partA.Size.Z > 2).toBe(true)
		cleanup(partA, partB)
	end)

	t.test("OuterTouch: angled parts both extend", function()
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(
			CFrame.new(2, 2, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 2, 2)
		)
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		local origSizeA = partA.Size.X
		local origSizeB = partB.Size.X

		doExtend(faceA, faceB, "OuterTouch")

		t.expect(partA.Size.X > origSizeA).toBe(true)
		t.expect(partB.Size.X > origSizeB).toBe(true)
		cleanup(partA, partB)
	end)

	t.test("WedgeJoin: acute angle creates two wedge fills", function()
		-- Part A face Right (+X), Part B face Bottom rotated 45° → dirB = (0.707, -0.707, 0)
		-- dirA·dirB = 0.707 > 0 (acute outward point)
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 4, 4))
		local partB = makePart(
			CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 4, 4)
		)
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Bottom)

		local origSizeAx = partA.Size.X

		doExtend(faceA, faceB, "WedgeJoin")

		-- Part A should have been resized (inner touch)
		t.expect(partA.Size.X > origSizeAx).toBe(true)

		-- Collect wedge parts
		local wedges = {}
		for _, child in workspace:GetChildren() do
			if child:IsA("WedgePart") then
				table.insert(wedges, child)
			end
		end

		-- Should create 2 wedge fills (one per face)
		t.expect(#wedges).toBe(2)

		-- All wedges should have non-degenerate sizes
		for _, wedge in wedges do
			t.expect(wedge.Size.X > 0.001).toBe(true)
			t.expect(wedge.Size.Y > 0.001).toBe(true)
			t.expect(wedge.Size.Z > 0.001).toBe(true)
		end

		cleanup(partA, partB)
	end)

	t.test("WedgeJoin: acute wedge geometry is correct for face A", function()
		-- Same acute setup, verify wedge A's specific geometry
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 4, 4))
		local partB = makePart(
			CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 4, 4)
		)
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Bottom)

		local dirA = Vector3.new(1, 0, 0)

		doExtend(faceA, faceB, "WedgeJoin")

		-- After resize, face A's right face position
		local faceARight = partA.Position.X + partA.Size.X / 2

		-- Collect wedge parts
		local wedges = {}
		for _, child in workspace:GetChildren() do
			if child:IsA("WedgePart") then
				table.insert(wedges, child)
			end
		end

		-- Find the wedge that belongs to face A (its Up vector should be ~dirA = +X)
		local wedgeA = nil
		for _, wedge in wedges do
			if math.abs(wedge.CFrame.UpVector:Dot(dirA)) > 0.9 then
				wedgeA = wedge
				break
			end
		end

		t.expect(wedgeA ~= nil).toBe(true)
		if wedgeA then
			-- Wedge X should match face A's cross-axis dimension (Z = 4)
			t.expect(approxEqual(wedgeA.Size.X, 4)).toBe(true)
			-- Wedge Z should match face A's perp-axis dimension (Y = 4)
			t.expect(approxEqual(wedgeA.Size.Z, 4)).toBe(true)
			-- Wedge Y (extraLen) should be positive and reasonable
			t.expect(wedgeA.Size.Y > 0.01).toBe(true)
			t.expect(wedgeA.Size.Y < 20).toBe(true)

			-- Wedge should be positioned adjacent to face A's right face
			-- Its center should be at faceARight + extraLen/2 along X
			local expectedCenterX = faceARight + wedgeA.Size.Y / 2
			t.expect(approxEqual(wedgeA.Position.X, expectedCenterX)).toBe(true)
		end

		cleanup(partA, partB)
	end)

	t.test("WedgeJoin: acute wedges meet at outer-touch intersection", function()
		-- The parts should be resized to inner-touch, with wedges filling to outer-touch
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 4, 4))
		local partB = makePart(
			CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 4, 4)
		)

		-- Do an InnerTouch on identical geometry to get the expected inner size
		local partA_inner = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 4, 4))
		local partB_inner = makePart(
			CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 4, 4)
		)
		doExtend(
			makeFace(partA_inner, Enum.NormalId.Right),
			makeFace(partB_inner, Enum.NormalId.Bottom),
			"InnerTouch"
		)
		local innerSizeAx = partA_inner.Size.X

		-- Now do the actual WedgeJoin
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Bottom)
		doExtend(faceA, faceB, "WedgeJoin")

		-- Part A should be resized to inner-touch size (not outer)
		t.expect(approxEqual(partA.Size.X, innerSizeAx)).toBe(true)

		-- Collect wedges
		local wedges = {}
		for _, child in workspace:GetChildren() do
			if child:IsA("WedgePart") then
				table.insert(wedges, child)
			end
		end
		t.expect(#wedges).toBe(2)

		cleanup(partA, partB, partA_inner, partB_inner)
	end)

	t.test("WedgeJoin: parallel faces produce no wedges", function()
		-- Parallel faces hit the isParallel early return, no wedges should be created
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(CFrame.new(3, 0, 0), Vector3.new(2, 2, 2))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		doExtend(faceA, faceB, "WedgeJoin")

		-- Part A should still have been resized (parallel path resizes faceA)
		t.expect(partA.Size.X > 2).toBe(true)

		-- No wedges should be created
		local wedgeCount = 0
		for _, child in workspace:GetChildren() do
			if child:IsA("WedgePart") then
				wedgeCount += 1
			end
		end
		t.expect(wedgeCount).toBe(0)

		cleanup(partA, partB)
	end)

	t.test("WedgeJoin: right-angle faces produce no huge wedges", function()
		-- 90 degree angle: dirA·dirB = 0, wedges should exist but be reasonable
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(CFrame.new(2, 3, 0), Vector3.new(2, 2, 2))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Bottom)

		doExtend(faceA, faceB, "WedgeJoin")

		-- Any wedges created should have reasonable sizes (not infinite)
		for _, child in workspace:GetChildren() do
			if child:IsA("WedgePart") then
				t.expect(child.Size.X < 100).toBe(true)
				t.expect(child.Size.Y < 100).toBe(true)
				t.expect(child.Size.Z < 100).toBe(true)
			end
		end

		cleanup(partA, partB)
	end)

	t.test("OuterTouch: acuteWedgeJoin=true creates wedges on acute angle", function()
		-- Acute angle (dirA·dirB > 0) with flag on should create wedges
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 4, 4))
		local partB = makePart(
			CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 4, 4)
		)
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Bottom)

		doExtend(faceA, faceB, "OuterTouch", true)

		local wedgeCount = 0
		for _, child in workspace:GetChildren() do
			if child:IsA("WedgePart") then
				wedgeCount += 1
			end
		end
		t.expect(wedgeCount).toBe(2)

		cleanup(partA, partB)
	end)

	t.test("OuterTouch: acuteWedgeJoin=false creates no wedges on acute angle", function()
		-- Acute angle with flag off should NOT create wedges
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 4, 4))
		local partB = makePart(
			CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 4, 4)
		)
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Bottom)

		doExtend(faceA, faceB, "OuterTouch", false)

		local wedgeCount = 0
		for _, child in workspace:GetChildren() do
			if child:IsA("WedgePart") then
				wedgeCount += 1
			end
		end
		t.expect(wedgeCount).toBe(0)

		cleanup(partA, partB)
	end)

	t.test("OuterTouch: acuteWedgeJoin=true creates no wedges on obtuse angle", function()
		-- Obtuse angle (dirA·dirB < 0) should NOT trigger wedge fill even with flag on
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(
			CFrame.new(2, 2, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 2, 2)
		)
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		doExtend(faceA, faceB, "OuterTouch", true)

		local wedgeCount = 0
		for _, child in workspace:GetChildren() do
			if child:IsA("WedgePart") then
				wedgeCount += 1
			end
		end
		t.expect(wedgeCount).toBe(0)

		cleanup(partA, partB)
	end)

	t.test("OuterTouch: acuteWedgeJoin=true with parallel faces creates no wedges", function()
		-- Parallel faces should never create wedges regardless of setting
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(CFrame.new(3, 0, 0), Vector3.new(2, 2, 2))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		doExtend(faceA, faceB, "OuterTouch", true)

		local wedgeCount = 0
		for _, child in workspace:GetChildren() do
			if child:IsA("WedgePart") then
				wedgeCount += 1
			end
		end
		t.expect(wedgeCount).toBe(0)

		cleanup(partA, partB)
	end)

	--------------------------------------------------------------------------------
	-- InnerTouch
	--------------------------------------------------------------------------------

	t.test("InnerTouch: parallel faces meet", function()
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(CFrame.new(3, 0, 0), Vector3.new(2, 2, 2))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		doExtend(faceA, faceB, "InnerTouch")

		local rightFaceA = partA.CFrame.Position.X + partA.Size.X / 2
		local leftFaceB = partB.CFrame.Position.X - partB.Size.X / 2
		t.expect(approxEqual(rightFaceA, leftFaceB)).toBe(true)
		cleanup(partA, partB)
	end)

	t.test("InnerTouch: angled parts extend to innermost alignment", function()
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(
			CFrame.new(2, 2, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 2, 2)
		)
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		doExtend(faceA, faceB, "InnerTouch")

		-- Part A should have grown (inner is shorter than outer for angled case)
		t.expect(partA.Size.X > 2).toBe(true)
		cleanup(partA, partB)
	end)

	--------------------------------------------------------------------------------
	-- ExtendUpTo (only Part A moves)
	--------------------------------------------------------------------------------

	t.test("ExtendUpTo: only Part A resizes", function()
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(CFrame.new(3, 0, 0), Vector3.new(2, 2, 2))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		local origSizeB = partB.Size

		doExtend(faceA, faceB, "ExtendUpTo")

		t.expect(partA.Size.X > 2).toBe(true)
		t.expect(partB.Size).toBe(origSizeB)
		cleanup(partA, partB)
	end)

	t.test("ExtendUpTo: face A just touches face B", function()
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(CFrame.new(3, 0, 0), Vector3.new(2, 2, 2))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		doExtend(faceA, faceB, "ExtendUpTo")

		local rightFaceA = partA.CFrame.Position.X + partA.Size.X / 2
		local leftFaceB = partB.CFrame.Position.X - partB.Size.X / 2
		t.expect(approxEqual(rightFaceA, leftFaceB)).toBe(true)
		cleanup(partA, partB)
	end)

	t.test("ExtendUpTo: angled, Part B unchanged", function()
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(
			CFrame.new(2, 2, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 2, 2)
		)
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		local origSizeB = partB.Size

		doExtend(faceA, faceB, "ExtendUpTo")

		t.expect(partA.Size.X > 2).toBe(true)
		t.expect(partB.Size).toBe(origSizeB)
		cleanup(partA, partB)
	end)

	--------------------------------------------------------------------------------
	-- ExtendInto (only Part A moves)
	--------------------------------------------------------------------------------

	t.test("ExtendInto: only Part A resizes", function()
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(CFrame.new(3, 0, 0), Vector3.new(2, 2, 2))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		local origSizeB = partB.Size

		doExtend(faceA, faceB, "ExtendInto")

		t.expect(partA.Size.X > 2).toBe(true)
		t.expect(partB.Size).toBe(origSizeB)
		cleanup(partA, partB)
	end)

	t.test("ExtendInto: extends further than ExtendUpTo for angled parts", function()
		local partA1 = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB1 = makePart(
			CFrame.new(2, 2, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 2, 2)
		)
		doExtend(makeFace(partA1, Enum.NormalId.Right), makeFace(partB1, Enum.NormalId.Left), "ExtendUpTo")
		local upToSize = partA1.Size.X

		local partA2 = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB2 = makePart(
			CFrame.new(2, 2, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 2, 2)
		)
		doExtend(makeFace(partA2, Enum.NormalId.Right), makeFace(partB2, Enum.NormalId.Left), "ExtendInto")
		local intoSize = partA2.Size.X

		t.expect(intoSize > upToSize).toBe(true)
		cleanup(partA1, partB1, partA2, partB2)
	end)

	--------------------------------------------------------------------------------
	-- ButtJoint
	--------------------------------------------------------------------------------

	t.test("ButtJoint: right-angle parts, no overlap", function()
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(CFrame.new(2, 3, 0), Vector3.new(2, 2, 2))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Bottom)

		doExtend(faceA, faceB, "ButtJoint")

		-- Part A right face should butt against Part B's side
		-- Both parts should have been resized
		local rightFaceA = partA.CFrame.Position.X + partA.Size.X / 2
		local leftFaceB = partB.CFrame.Position.X - partB.Size.X / 2
		t.expect(approxEqual(rightFaceA, leftFaceB)).toBe(true)
		cleanup(partA, partB)
	end)

	--------------------------------------------------------------------------------
	-- RoundedJoin
	--------------------------------------------------------------------------------

	t.test("RoundedJoin: creates a filler part", function()
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(
			CFrame.new(2, 2, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2, 2, 2)
		)
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		local childCountBefore = #workspace:GetChildren()

		doExtend(faceA, faceB, "RoundedJoin")

		-- Should have created a filler part
		local childCountAfter = #workspace:GetChildren()
		t.expect(childCountAfter > childCountBefore).toBe(true)
		cleanup(partA, partB)
	end)

	t.test("RoundedJoin: parallel faces degrade to OuterTouch (no filler)", function()
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
		local partB = makePart(CFrame.new(3, 0, 0), Vector3.new(2, 2, 2))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		local childCountBefore = #workspace:GetChildren()

		doExtend(faceA, faceB, "RoundedJoin")

		-- No filler part should be created (parallel => just extends)
		local childCountAfter = #workspace:GetChildren()
		t.expect(childCountAfter).toBe(childCountBefore)

		-- But Part A should still have extended
		t.expect(partA.Size.X > 2).toBe(true)
		cleanup(partA, partB)
	end)

	--------------------------------------------------------------------------------
	-- Edge cases
	--------------------------------------------------------------------------------

	t.test("Does not error with already-touching parts", function()
		local partA = makePart(CFrame.new(-2, 0, 0), Vector3.new(4, 4, 4))
		local partB = makePart(CFrame.new(2, 0, 0), Vector3.new(4, 4, 4))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		doExtend(faceA, faceB, "OuterTouch")
		cleanup(partA, partB)
	end)

	t.test("Parts facing same direction (parallel) get resized", function()
		local partA = makePart(CFrame.new(0, 0, -5), Vector3.new(4, 4, 4))
		local partB = makePart(CFrame.new(0, 0, 5), Vector3.new(4, 4, 4))
		local faceA = makeFace(partA, Enum.NormalId.Back)
		local faceB = makeFace(partB, Enum.NormalId.Front)

		doExtend(faceA, faceB, "OuterTouch")

		t.expect(partA.Size.Z > 4).toBe(true)
		cleanup(partA, partB)
	end)

	t.test("All modes run without error on axis-aligned parts", function()
		local modes: {doExtend.ResizeMode} = {"OuterTouch", "InnerTouch", "WedgeJoin", "RoundedJoin", "ButtJoint", "ExtendUpTo", "ExtendInto"}
		for _, mode in modes do
			local partA = makePart(CFrame.new(-5, 0, 0), Vector3.new(4, 4, 4))
			local partB = makePart(CFrame.new(5, 0, 0), Vector3.new(4, 4, 4))
			local faceA = makeFace(partA, Enum.NormalId.Right)
			local faceB = makeFace(partB, Enum.NormalId.Left)
			doExtend(faceA, faceB, mode)
			cleanup(partA, partB)
		end
	end)

	t.test("All modes run without error on angled parts", function()
		local modes: {doExtend.ResizeMode} = {"OuterTouch", "InnerTouch", "WedgeJoin", "RoundedJoin", "ExtendUpTo", "ExtendInto"}
		for _, mode in modes do
			local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))
			local partB = makePart(
				CFrame.new(2, 2, 0) * CFrame.Angles(0, 0, math.rad(45)),
				Vector3.new(2, 2, 2)
			)
			local faceA = makeFace(partA, Enum.NormalId.Right)
			local faceB = makeFace(partB, Enum.NormalId.Left)
			doExtend(faceA, faceB, mode)
			cleanup(partA, partB)
		end
	end)

	t.test("Asymmetric part sizes work", function()
		local partA = makePart(CFrame.new(-5, 0, 0), Vector3.new(2, 6, 4))
		local partB = makePart(CFrame.new(5, 0, 0), Vector3.new(4, 2, 6))
		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		doExtend(faceA, faceB, "OuterTouch")

		t.expect(partA.Size.X > 2).toBe(true)
		-- Y and Z should be unchanged
		t.expect(approxEqual(partA.Size.Y, 6)).toBe(true)
		t.expect(approxEqual(partA.Size.Z, 4)).toBe(true)
		cleanup(partA, partB)
	end)

	t.test("ExtendUpTo with wedge Face B does not create zero-size part", function()
		-- Regression: resizePart was called with delta=0 on wedge Face B,
		-- which created a new part with zero Y size instead of being a no-op.
		local partA = makePart(CFrame.new(-3, 0, 0), Vector3.new(2, 2, 2))

		local wedge = Instance.new("WedgePart")
		wedge.Size = Vector3.new(2, 2, 2)
		wedge.CFrame = CFrame.new(3, 0, 0)
		wedge.Anchored = true
		wedge.Parent = workspace

		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB: doExtend.Face = {
			Object = wedge,
			Normal = Enum.NormalId.Top,
			IsWedge = true,
		}

		local childCountBefore = #workspace:GetChildren()

		doExtend(faceA, faceB, "ExtendUpTo")

		-- Part A should have extended
		t.expect(partA.Size.X > 2).toBe(true)

		-- No extra part should have been created from the wedge face with zero delta
		local childCountAfter = #workspace:GetChildren()
		t.expect(childCountAfter).toBe(childCountBefore)

		partA:Destroy()
		wedge:Destroy()
		cleanup()
	end)
end
