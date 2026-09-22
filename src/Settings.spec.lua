local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local Settings = require(script.Parent.Settings)

return function(t: TestContext)
	-- Run with nothing saved so that defaults don't depend on what earlier
	-- runs left behind in the test plugin's settings
	local function withoutSavedSettings(body: () -> ())
		local previous = t.plugin:GetSetting("resizeAlignState")
		t.plugin:SetSetting("resizeAlignState", nil)
		local ok, err = pcall(body)
		t.plugin:SetSetting("resizeAlignState", previous)
		assert(ok, err)
	end

	t.test("Load returns valid settings with defaults", function()
		withoutSavedSettings(function()
			local settings = Settings.Load(t.plugin)
			t.expect(settings.ResizeMode).toBe("OuterTouch")
			t.expect(settings.SelectionThreshold).toBe("25")
			t.expect(settings.ClassicUI).toBe(false)
			t.expect(settings.WindowPosition ~= nil).toBe(true)
			t.expect(settings.WindowAnchor ~= nil).toBe(true)
		end)
	end)

	t.test("SplineJoin segments default to automatic and round-trip", function()
		withoutSavedSettings(function()
			local settings = Settings.Load(t.plugin)
			t.expect(settings.SplineJoinSegments).toBe(0)
			settings.SplineJoinSegments = 24
			Settings.Save(t.plugin, settings)
			t.expect(Settings.Load(t.plugin).SplineJoinSegments).toBe(24)
		end)
	end)

	t.test("Settings are a flat table of plain values", function()
		withoutSavedSettings(function()
			Settings.Save(t.plugin, Settings.Load(t.plugin))
			for key, value in t.plugin:GetSetting("resizeAlignState") do
				t.expect(typeof(value) ~= "table").toBe(true)
			end
		end)
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

	t.test("AcuteWedgeJoin round-trips", function()
		local settings = Settings.Load(t.plugin)
		settings.AcuteWedgeJoin = false
		Settings.Save(t.plugin, settings)

		local reloaded = Settings.Load(t.plugin)
		t.expect(reloaded.AcuteWedgeJoin).toBe(false)

		-- Restore
		settings.AcuteWedgeJoin = true
		Settings.Save(t.plugin, settings)
	end)

	t.test("RoundedJoin cylinder defaults on and round-trips", function()
		withoutSavedSettings(function()
			local settings = Settings.Load(t.plugin)
			t.expect(settings.UseCylinderForRoundedJoin).toBe(true)
			settings.UseCylinderForRoundedJoin = false
			Settings.Save(t.plugin, settings)
			t.expect(Settings.Load(t.plugin).UseCylinderForRoundedJoin).toBe(false)
			settings.UseCylinderForRoundedJoin = true
			Settings.Save(t.plugin, settings)
		end)
	end)

	t.test("RoundedJoin radius defaults to automatic and round-trips", function()
		withoutSavedSettings(function()
			local settings = Settings.Load(t.plugin)
			t.expect(settings.RoundedJoinRadius).toBe(0)
			settings.RoundedJoinRadius = 2.5
			Settings.Save(t.plugin, settings)
			t.expect(Settings.Load(t.plugin).RoundedJoinRadius).toBe(2.5)
		end)
	end)

	t.test("All resize modes round-trip", function()
		local modes = {
			"OuterTouch",
			"InnerTouch",
			"WedgeJoin",
			"RoundedJoin",
			"SplineJoin",
			"ButtJoint",
			"ExtendUpTo",
			"ExtendInto",
		}
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
		local thresholds = { "25", "15", "Exact" }
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
