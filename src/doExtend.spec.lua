local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local doExtend = require(script.Parent.doExtend)

local function makeFace(part: BasePart, normal: Enum.NormalId): doExtend.Face
	return {
		Object = part,
		Normal = normal,
		IsWedge = false,
	}
end

return function(t: TestContext)
	t.test("OuterTouch resizes two axis-aligned parts", function()
		local partA = Instance.new("Part")
		partA.Size = Vector3.new(4, 4, 4)
		partA.CFrame = CFrame.new(-5, 0, 0)
		partA.Anchored = true
		partA.Parent = workspace

		local partB = Instance.new("Part")
		partB.Size = Vector3.new(4, 4, 4)
		partB.CFrame = CFrame.new(5, 0, 0)
		partB.Anchored = true
		partB.Parent = workspace

		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		local origSizeA = partA.Size
		local origSizeB = partB.Size

		doExtend(faceA, faceB, "OuterTouch")

		-- Parts should have been resized (sizes changed)
		local changed = partA.Size ~= origSizeA or partB.Size ~= origSizeB
		t.expect(changed).toBe(true)

		partA:Destroy()
		partB:Destroy()
	end)

	t.test("Parts facing same direction (parallel) get resized", function()
		local partA = Instance.new("Part")
		partA.Size = Vector3.new(4, 4, 4)
		partA.CFrame = CFrame.new(0, 0, -5)
		partA.Anchored = true
		partA.Parent = workspace

		local partB = Instance.new("Part")
		partB.Size = Vector3.new(4, 4, 4)
		partB.CFrame = CFrame.new(0, 0, 5)
		partB.Anchored = true
		partB.Parent = workspace

		local faceA = makeFace(partA, Enum.NormalId.Back)
		local faceB = makeFace(partB, Enum.NormalId.Front)

		doExtend(faceA, faceB, "OuterTouch")

		-- After resize, the front faces should meet
		t.expect(partA.Size.Z > 4).toBe(true)

		partA:Destroy()
		partB:Destroy()
	end)

	t.test("doExtend does not error with touching parts", function()
		local partA = Instance.new("Part")
		partA.Size = Vector3.new(4, 4, 4)
		partA.CFrame = CFrame.new(-2, 0, 0)
		partA.Anchored = true
		partA.Parent = workspace

		local partB = Instance.new("Part")
		partB.Size = Vector3.new(4, 4, 4)
		partB.CFrame = CFrame.new(2, 0, 0)
		partB.Anchored = true
		partB.Parent = workspace

		local faceA = makeFace(partA, Enum.NormalId.Right)
		local faceB = makeFace(partB, Enum.NormalId.Left)

		-- Should not error
		doExtend(faceA, faceB, "OuterTouch")

		partA:Destroy()
		partB:Destroy()
	end)
end
