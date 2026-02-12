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
		AcuteWedgeJoin = true,
		SelectionThreshold = "25",
		ClassicUI = false,
	}
end

local function renderGui(props: {
	ClassicUI: boolean?,
	GuiState: string?,
	FaceState: string?,
	Panelized: boolean?,
	HoverFace: any?,
	SelectedFace: any?,
})
	local settings = makeTestSettings()
	settings.ClassicUI = props.ClassicUI or false

	local screen = Instance.new("ScreenGui")
	screen.Name = "ResizeAlignGuiTest"
	screen.Parent = CoreGui

	local root = ReactRoblox.createRoot(screen)
	ReactRoblox.act(function()
		root:render(e(ResizeAlignGui, {
			GuiState = props.GuiState or "active",
			CurrentSettings = settings,
			UpdatedSettings = function() end,
			HandleAction = function() end,
			Panelized = props.Panelized or false,
			FaceState = props.FaceState or "FaceA",
			HoverFace = props.HoverFace,
			SelectedFace = props.SelectedFace,
		}))
	end)

	ReactRoblox.act(function()
		root:unmount()
	end)
	screen:Destroy()
end

return function(t: TestContext)
	t.test("Modern UI smoke", function()
		renderGui({ ClassicUI = false })
	end)

	t.test("Classic UI smoke", function()
		renderGui({ ClassicUI = true })
	end)

	t.test("Inactive state renders without error", function()
		renderGui({ GuiState = "inactive" })
	end)

	t.test("FaceB state renders without error", function()
		renderGui({ FaceState = "FaceB" })
	end)

	t.test("Panelized mode renders without error", function()
		renderGui({ Panelized = true })
	end)

	t.test("Classic UI inactive state renders without error", function()
		renderGui({ ClassicUI = true, GuiState = "inactive" })
	end)

	t.test("Renders with HoverFace in FaceA state", function()
		local part = Instance.new("Part")
		part.Size = Vector3.new(4, 4, 4)
		part.CFrame = CFrame.new(0, 0, 0)
		part.Parent = workspace

		renderGui({
			FaceState = "FaceA",
			HoverFace = {
				Object = part,
				Normal = Enum.NormalId.Top,
				IsWedge = false,
			},
		})

		part:Destroy()
	end)

	t.test("Renders with SelectedFace and HoverFace in FaceB state", function()
		local partA = Instance.new("Part")
		partA.Size = Vector3.new(4, 4, 4)
		partA.CFrame = CFrame.new(-5, 0, 0)
		partA.Parent = workspace

		local partB = Instance.new("Part")
		partB.Size = Vector3.new(4, 4, 4)
		partB.CFrame = CFrame.new(5, 0, 0)
		partB.Parent = workspace

		renderGui({
			FaceState = "FaceB",
			SelectedFace = {
				Object = partA,
				Normal = Enum.NormalId.Right,
				IsWedge = false,
			},
			HoverFace = {
				Object = partB,
				Normal = Enum.NormalId.Left,
				IsWedge = false,
			},
		})

		partA:Destroy()
		partB:Destroy()
	end)

	t.test("Renders with wedge face highlights", function()
		local wedge = Instance.new("WedgePart")
		wedge.Size = Vector3.new(4, 4, 4)
		wedge.CFrame = CFrame.new(0, 0, 0)
		wedge.Parent = workspace

		renderGui({
			FaceState = "FaceA",
			HoverFace = {
				Object = wedge,
				Normal = Enum.NormalId.Top,
				IsWedge = true,
			},
		})

		wedge:Destroy()
	end)

	t.test("Renders with CornerWedge slope face highlight", function()
		local cornerWedge = Instance.new("CornerWedgePart")
		cornerWedge.Size = Vector3.new(4, 4, 4)
		cornerWedge.CFrame = CFrame.new(0, 0, 0)
		cornerWedge.Parent = workspace

		renderGui({
			FaceState = "FaceA",
			HoverFace = {
				Object = cornerWedge,
				Normal = Enum.NormalId.Right,
				CornerWedgeSide = "Right",
			},
		})

		cornerWedge:Destroy()
	end)

	t.test("All resize modes render in modern UI", function()
		local modes = {"OuterTouch", "InnerTouch", "WedgeJoin", "RoundedJoin", "ButtJoint", "ExtendUpTo", "ExtendInto"}
		for _, mode in modes do
			local settings = makeTestSettings()
			settings.ResizeMode = mode

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
	end)
end
