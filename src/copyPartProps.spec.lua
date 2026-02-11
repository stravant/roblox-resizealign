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
end
