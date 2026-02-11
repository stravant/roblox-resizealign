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
	-- Also clean up any children that doExtend may have created (e.g. RoundedJoin filler)
	for _, child in workspace:GetChildren() do
		if child.Name:find("_Extended") or (child:IsA("Part") and child.Shape == Enum.PartType.Cylinder) then
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

		-- Both parts should have grown along X
		t.expect(partA.Size.X > 4).toBe(true)
		t.expect(partB.Size.X > 4).toBe(true)
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
		local modes: {doExtend.ResizeMode} = {"OuterTouch", "InnerTouch", "RoundedJoin", "ButtJoint", "ExtendUpTo", "ExtendInto"}
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
		local modes: {doExtend.ResizeMode} = {"OuterTouch", "InnerTouch", "RoundedJoin", "ExtendUpTo", "ExtendInto"}
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
