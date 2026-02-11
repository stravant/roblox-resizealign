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
end
