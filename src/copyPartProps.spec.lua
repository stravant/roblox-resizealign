local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local copyPartProps = require(script.Parent.copyPartProps)

return function(t: TestContext)
	t.test("Copies physical properties", function()
		local from = Instance.new("Part")
		from.Anchored = true
		from.Massless = true
		from.RootPriority = 5

		local to = Instance.new("Part")
		copyPartProps(from, to)

		t.expect(to.Anchored).toBe(true)
		t.expect(to.Massless).toBe(true)
		t.expect(to.RootPriority).toBe(5)

		from:Destroy()
		to:Destroy()
	end)

	t.test("Copies collision properties", function()
		local from = Instance.new("Part")
		from.CanCollide = false
		from.CanTouch = false
		from.CanQuery = false

		local to = Instance.new("Part")
		copyPartProps(from, to)

		t.expect(to.CanCollide).toBe(false)
		t.expect(to.CanTouch).toBe(false)
		t.expect(to.CanQuery).toBe(false)

		from:Destroy()
		to:Destroy()
	end)

	t.test("Copies visual properties", function()
		local from = Instance.new("Part")
		from.Color = Color3.fromRGB(255, 0, 128)
		from.Material = Enum.Material.Neon
		from.Reflectance = 0.75
		from.Transparency = 0.5
		from.CastShadow = false

		local to = Instance.new("Part")
		copyPartProps(from, to)

		t.expect(to.Color).toBe(from.Color)
		t.expect(to.Material).toBe(Enum.Material.Neon)
		t.expect(to.Reflectance).toBe(0.75)
		t.expect(to.Transparency).toBe(0.5)
		t.expect(to.CastShadow).toBe(false)

		from:Destroy()
		to:Destroy()
	end)

	t.test("Does not copy Size or CFrame", function()
		local from = Instance.new("Part")
		from.Size = Vector3.new(10, 10, 10)
		from.CFrame = CFrame.new(100, 200, 300)

		local to = Instance.new("Part")
		local origSize = to.Size
		local origCFrame = to.CFrame
		copyPartProps(from, to)

		t.expect(to.Size).toBe(origSize)
		t.expect(to.CFrame).toBe(origCFrame)

		from:Destroy()
		to:Destroy()
	end)

	t.test("Copies CollisionGroup", function()
		local from = Instance.new("Part")
		-- Default CollisionGroup is "Default"
		local to = Instance.new("Part")
		copyPartProps(from, to)

		t.expect(to.CollisionGroup).toBe(from.CollisionGroup)

		from:Destroy()
		to:Destroy()
	end)

	t.test("Sets surfaces to Smooth", function()
		local from = Instance.new("Part")
		from.TopSurface = Enum.SurfaceType.Studs
		from.BottomSurface = Enum.SurfaceType.Inlet

		local to = Instance.new("Part")
		to.TopSurface = Enum.SurfaceType.Weld
		to.BottomSurface = Enum.SurfaceType.Hinge
		copyPartProps(from, to)

		-- Regardless of source, surfaces should be set to Smooth
		t.expect(to.TopSurface).toBe(Enum.SurfaceType.Smooth)
		t.expect(to.BottomSurface).toBe(Enum.SurfaceType.Smooth)

		from:Destroy()
		to:Destroy()
	end)

	t.test("Copies MaterialVariant", function()
		local from = Instance.new("Part")
		from.MaterialVariant = "TestVariant"

		local to = Instance.new("Part")
		copyPartProps(from, to)

		t.expect(to.MaterialVariant).toBe("TestVariant")

		from:Destroy()
		to:Destroy()
	end)

	t.test("Copies CustomPhysicalProperties", function()
		local from = Instance.new("Part")
		from.CustomPhysicalProperties = PhysicalProperties.new(5, 0.3, 0.5, 0.8, 0.2)

		local to = Instance.new("Part")
		copyPartProps(from, to)

		local props = to.CustomPhysicalProperties
		t.expect(props ~= nil).toBe(true)
		if props then
			t.expect(props.Density).toBe(5)
			-- PhysicalProperties uses single-precision floats, so use approximate comparison
			t.expect(math.abs(props.Friction - 0.3) < 0.001).toBe(true)
			t.expect(math.abs(props.Elasticity - 0.5) < 0.001).toBe(true)
		end

		from:Destroy()
		to:Destroy()
	end)

	t.test("Copies CastShadow", function()
		local from = Instance.new("Part")
		from.CastShadow = false

		local to = Instance.new("Part")
		t.expect(to.CastShadow).toBe(true) -- default
		copyPartProps(from, to)

		t.expect(to.CastShadow).toBe(false)

		from:Destroy()
		to:Destroy()
	end)
end
