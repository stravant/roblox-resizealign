local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local ShapeUtils = require(script.Parent.ShapeUtils)

return function(t: TestContext)
	--------------------------------------------------------------------------------
	-- otherNormals
	--------------------------------------------------------------------------------

	t.test("otherNormals: X axis returns Y and Z", function()
		local a, b = ShapeUtils.otherNormals(Vector3.new(1, 0, 0))
		t.expect(a).toBe(Vector3.new(0, 1, 0))
		t.expect(b).toBe(Vector3.new(0, 0, 1))
	end)

	t.test("otherNormals: negative X axis returns Y and Z", function()
		local a, b = ShapeUtils.otherNormals(Vector3.new(-1, 0, 0))
		t.expect(a).toBe(Vector3.new(0, 1, 0))
		t.expect(b).toBe(Vector3.new(0, 0, 1))
	end)

	t.test("otherNormals: Y axis returns X and Z", function()
		local a, b = ShapeUtils.otherNormals(Vector3.new(0, 1, 0))
		t.expect(a).toBe(Vector3.new(1, 0, 0))
		t.expect(b).toBe(Vector3.new(0, 0, 1))
	end)

	t.test("otherNormals: negative Y axis returns X and Z", function()
		local a, b = ShapeUtils.otherNormals(Vector3.new(0, -1, 0))
		t.expect(a).toBe(Vector3.new(1, 0, 0))
		t.expect(b).toBe(Vector3.new(0, 0, 1))
	end)

	t.test("otherNormals: Z axis returns X and Y", function()
		local a, b = ShapeUtils.otherNormals(Vector3.new(0, 0, 1))
		t.expect(a).toBe(Vector3.new(1, 0, 0))
		t.expect(b).toBe(Vector3.new(0, 1, 0))
	end)

	t.test("otherNormals: negative Z axis returns X and Y", function()
		local a, b = ShapeUtils.otherNormals(Vector3.new(0, 0, -1))
		t.expect(a).toBe(Vector3.new(1, 0, 0))
		t.expect(b).toBe(Vector3.new(0, 1, 0))
	end)

	--------------------------------------------------------------------------------
	-- isWedgeShape
	--------------------------------------------------------------------------------

	t.test("isWedgeShape: WedgePart returns true", function()
		local part = Instance.new("WedgePart")
		t.expect(ShapeUtils.isWedgeShape(part)).toBe(true)
		part:Destroy()
	end)

	t.test("isWedgeShape: Part with Wedge shape returns true", function()
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Wedge
		t.expect(ShapeUtils.isWedgeShape(part)).toBe(true)
		part:Destroy()
	end)

	t.test("isWedgeShape: regular Part returns false", function()
		local part = Instance.new("Part")
		t.expect(ShapeUtils.isWedgeShape(part)).toBe(false)
		part:Destroy()
	end)

	t.test("isWedgeShape: CornerWedgePart returns false", function()
		local part = Instance.new("CornerWedgePart")
		t.expect(ShapeUtils.isWedgeShape(part)).toBe(false)
		part:Destroy()
	end)

	t.test("isWedgeShape: cylinder Part returns false", function()
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		t.expect(ShapeUtils.isWedgeShape(part)).toBe(false)
		part:Destroy()
	end)

	--------------------------------------------------------------------------------
	-- isCornerWedgeShape
	--------------------------------------------------------------------------------

	t.test("isCornerWedgeShape: CornerWedgePart returns true", function()
		local part = Instance.new("CornerWedgePart")
		t.expect(ShapeUtils.isCornerWedgeShape(part)).toBe(true)
		part:Destroy()
	end)

	t.test("isCornerWedgeShape: Part with CornerWedge shape returns true", function()
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.CornerWedge
		t.expect(ShapeUtils.isCornerWedgeShape(part)).toBe(true)
		part:Destroy()
	end)

	t.test("isCornerWedgeShape: regular Part returns false", function()
		local part = Instance.new("Part")
		t.expect(ShapeUtils.isCornerWedgeShape(part)).toBe(false)
		part:Destroy()
	end)

	t.test("isCornerWedgeShape: WedgePart returns false", function()
		local part = Instance.new("WedgePart")
		t.expect(ShapeUtils.isCornerWedgeShape(part)).toBe(false)
		part:Destroy()
	end)

	--------------------------------------------------------------------------------
	-- isCylinder
	--------------------------------------------------------------------------------

	t.test("isCylinder: Part with Cylinder shape returns true", function()
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		t.expect(ShapeUtils.isCylinder(part)).toBe(true)
		part:Destroy()
	end)

	t.test("isCylinder: regular Part returns false", function()
		local part = Instance.new("Part")
		t.expect(ShapeUtils.isCylinder(part)).toBe(false)
		part:Destroy()
	end)

	t.test("isCylinder: ball Part returns false", function()
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball
		t.expect(ShapeUtils.isCylinder(part)).toBe(false)
		part:Destroy()
	end)

	t.test("isCylinder: WedgePart returns false", function()
		local part = Instance.new("WedgePart")
		t.expect(ShapeUtils.isCylinder(part)).toBe(false)
		part:Destroy()
	end)
end
