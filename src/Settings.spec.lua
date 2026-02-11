local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local Settings = require(script.Parent.Settings)

return function(t: TestContext)
	t.test("Load returns valid settings with defaults", function()
		local settings = Settings.Load(t.plugin)
		t.expect(settings.ResizeMode).toBe("OuterTouch")
		t.expect(settings.SelectionThreshold).toBe("25")
		t.expect(settings.ClassicUI).toBe(false)
		t.expect(settings.WindowPosition ~= nil).toBe(true)
		t.expect(settings.WindowAnchor ~= nil).toBe(true)
	end)

	t.test("Save and Load round-trips", function()
		local settings = Settings.Load(t.plugin)
		settings.ResizeMode = "ButtJoint"
		settings.SelectionThreshold = "15"
		Settings.Save(t.plugin, settings)

		local reloaded = Settings.Load(t.plugin)
		t.expect(reloaded.ResizeMode).toBe("ButtJoint")
		t.expect(reloaded.SelectionThreshold).toBe("15")

		-- Restore defaults
		settings.ResizeMode = "OuterTouch"
		settings.SelectionThreshold = "25"
		Settings.Save(t.plugin, settings)
	end)

	t.test("ClassicUI round-trips", function()
		local settings = Settings.Load(t.plugin)
		settings.ClassicUI = true
		Settings.Save(t.plugin, settings)

		local reloaded = Settings.Load(t.plugin)
		t.expect(reloaded.ClassicUI).toBe(true)

		-- Restore
		settings.ClassicUI = false
		Settings.Save(t.plugin, settings)
	end)

	t.test("All resize modes round-trip", function()
		local modes = {"OuterTouch", "InnerTouch", "WedgeJoin", "RoundedJoin", "ButtJoint", "ExtendUpTo", "ExtendInto"}
		for _, mode in modes do
			local settings = Settings.Load(t.plugin)
			settings.ResizeMode = mode
			Settings.Save(t.plugin, settings)

			local reloaded = Settings.Load(t.plugin)
			t.expect(reloaded.ResizeMode).toBe(mode)
		end

		-- Restore
		local settings = Settings.Load(t.plugin)
		settings.ResizeMode = "OuterTouch"
		Settings.Save(t.plugin, settings)
	end)

	t.test("All threshold values round-trip", function()
		local thresholds = {"25", "15", "Exact"}
		for _, threshold in thresholds do
			local settings = Settings.Load(t.plugin)
			settings.SelectionThreshold = threshold
			Settings.Save(t.plugin, settings)

			local reloaded = Settings.Load(t.plugin)
			t.expect(reloaded.SelectionThreshold).toBe(threshold)
		end

		-- Restore
		local settings = Settings.Load(t.plugin)
		settings.SelectionThreshold = "25"
		Settings.Save(t.plugin, settings)
	end)

	t.test("WindowPosition round-trips", function()
		local settings = Settings.Load(t.plugin)
		settings.WindowPosition = Vector2.new(100, 200)
		settings.WindowAnchor = Vector2.new(0.5, 0.5)
		Settings.Save(t.plugin, settings)

		local reloaded = Settings.Load(t.plugin)
		t.expect(reloaded.WindowPosition.X).toBe(100)
		t.expect(reloaded.WindowPosition.Y).toBe(200)
		t.expect(reloaded.WindowAnchor.X).toBe(0.5)
		t.expect(reloaded.WindowAnchor.Y).toBe(0.5)

		-- Restore
		settings.WindowPosition = Vector2.new(24, 24)
		settings.WindowAnchor = Vector2.new(0, 0)
		Settings.Save(t.plugin, settings)
	end)

	t.test("HaveHelp and DoneTutorial round-trip", function()
		local settings = Settings.Load(t.plugin)
		settings.HaveHelp = false
		settings.DoneTutorial = true
		Settings.Save(t.plugin, settings)

		local reloaded = Settings.Load(t.plugin)
		t.expect(reloaded.HaveHelp).toBe(false)
		t.expect(reloaded.DoneTutorial).toBe(true)

		-- Restore
		settings.HaveHelp = true
		settings.DoneTutorial = false
		Settings.Save(t.plugin, settings)
	end)
end
