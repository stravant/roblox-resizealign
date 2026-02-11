local CoreGui = game:GetService("CoreGui")

local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local Packages = script.Parent.Parent.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local ResizeAlignGui = require(script.Parent.ResizeAlignGui)

local e = React.createElement

local function makeTestSettings()
	return {
		WindowPosition = Vector2.zero,
		WindowAnchor = Vector2.zero,
		WindowHeightDelta = 0,
		DoneTutorial = false,
		HaveHelp = false,
		ResizeMode = "OuterTouch",
		SelectionThreshold = "25",
		ClassicUI = false,
	}
end

local function mountAndUnmount(classicUI: boolean)
	local settings = makeTestSettings()
	settings.ClassicUI = classicUI

	local screen = Instance.new("ScreenGui")
	screen.Name = "ResizeAlignGuiTest"
	screen.Parent = CoreGui

	local root = ReactRoblox.createRoot(screen)
	ReactRoblox.act(function()
		root:render(e(ResizeAlignGui, {
			GuiState = "active",
			CurrentSettings = settings,
			UpdatedSettings = function() end,
			HandleAction = function() end,
			Panelized = false,
			FaceState = "FaceA",
			HoverFace = nil,
			SelectedFace = nil,
		}))
	end)

	ReactRoblox.act(function()
		root:unmount()
	end)
	screen:Destroy()
end

return function(t: TestContext)
	t.test("Modern UI smoke", function()
		mountAndUnmount(false)
	end)
	t.test("Classic UI smoke", function()
		mountAndUnmount(true)
	end)
end
