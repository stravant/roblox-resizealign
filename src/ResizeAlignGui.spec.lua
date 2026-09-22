local CoreGui = game:GetService("CoreGui")

local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local Packages = script.Parent.Parent.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local ResizeAlignGui = require(script.Parent.ResizeAlignGui)
local Settings = require(script.Parent.Settings)

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
		UseCylinderForRoundedJoin = true,
		RoundedJoinRadius = 0,
		SplineJoinSegments = 0,
		SelectionThreshold = "25",
		ClassicUI = false,
	}
end

local function renderGui(props: {
	ClassicUI: boolean?,
	ResizeMode: string?,
	HaveHelp: boolean?,
	Check: ((ScreenGui, Settings.ResizeAlignSettings, () -> ()) -> ())?,
	GuiState: string?,
	FaceState: string?,
	Panelized: boolean?,
	HoverFace: any?,
	SelectedFace: any?,
})
	local settings = makeTestSettings()
	settings.ClassicUI = props.ClassicUI or false
	settings.ResizeMode = props.ResizeMode or "OuterTouch"
	settings.HaveHelp = props.HaveHelp or false

	local screen = Instance.new("ScreenGui")
	screen.Name = "ResizeAlignGuiTest"
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = CoreGui

	local root = ReactRoblox.createRoot(screen)
	local function render()
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
	end
	render()

	local ok, err = pcall(function()
		if props.Check then
			props.Check(screen, settings, render)
		end
	end)
	ReactRoblox.act(function()
		root:unmount()
	end)
	screen:Destroy()
	assert(ok, tostring(err))
end

return function(t: TestContext)
	t.test("Attached menus follow selection", function()
		for _, mode in { "SplineJoin", "OuterTouch", "InnerTouch", "RoundedJoin" } do
			renderGui({
				ResizeMode = mode,
				HaveHelp = true,
				Check = function(screen)
					local spline = screen:FindFirstChild("SplineJoinOptions", true)
					local outer = screen:FindFirstChild("OuterTouchOptions", true)
					t.expect(spline ~= nil).toBe(mode == "SplineJoin")
					t.expect(outer ~= nil).toBe(mode == "OuterTouch")
					local rounded = screen:FindFirstChild("RoundedJoinOptions", true)
					local panel = spline or outer or rounded
					if panel then
						local row = screen:FindFirstChild(if spline then "SplineJoin" elseif rounded then "RoundedJoin" else "OuterTouch", true)
						t.expect(row.LayoutOrder).toBe(
							if spline then 7 elseif rounded then 5 else 1
						)
						t.expect(panel.Position.X.Offset).toBe(20)
						local outline = row.Outline
						t.expect(outline.Stroke.Color).toBe(Color3.new(1, 1, 1))
						t.expect(outline.BackgroundTransparency).toBe(1)
					end
					if outer then
						local label = outer.Content.AcuteWedgeJoin:FindFirstChild("Label", true)
						t.expect(label.TextWrapped).toBe(true)
						-- The label must wrap rather than push the checkbox out of the panel
						local checkBox = outer.Content.AcuteWedgeJoin:FindFirstChild("CheckBox", true)
						t.expect(
							checkBox.AbsolutePosition.X + checkBox.AbsoluteSize.X <= outer.AbsolutePosition.X + outer.AbsoluteSize.X
						).toBe(true)
					end
					if spline then
						local preview = screen:FindFirstChild("SplineJoin", true):FindFirstChild("Filler", true)
						t.expect(preview:IsA("Model")).toBe(true)
						t.expect(preview:FindFirstChildWhichIsA("BasePart") ~= nil).toBe(true)
						t.expect(spline.Content:FindFirstChild("AutomaticSegments") == nil).toBe(true)
						local segments = spline.Content.Segments:FindFirstChild("TextBox", true)
						t.expect(segments.Text:find("Automatic", 1, true) ~= nil).toBe(true)
						t.expect(panel.BackgroundColor3).toBe(Color3.fromRGB(18, 18, 18))
						t.expect(spline.Content:FindFirstChild("Padding")).toBe(nil)
						t.expect(spline.Content:FindFirstChild("AdvancedPadding")).toBe(nil)
					end
				end,
			})
		end
	end)

	t.test("Classic UI offers only the original modes, without sub-options", function()
		for _, mode in { "OuterTouch", "InnerTouch", "RoundedJoin", "SplineJoin" } do
			renderGui({
				ClassicUI = true,
				ResizeMode = mode,
				HaveHelp = true,
				Check = function(screen)
					local panel = screen:FindFirstChild("ClassicResizeMethod", true)
					for _, name in { "OuterTouch", "InnerTouch", "RoundedJoin", "ButtJoint", "ExtendUpTo", "ExtendInto" } do
						t.expect(panel:FindFirstChild(name, true) ~= nil).toBe(true)
					end
					for _, name in { "WedgeJoin", "SplineJoin" } do
						t.expect(panel:FindFirstChild(name, true)).toBe(nil)
					end
					for _, name in { "OuterTouchOptions", "RoundedJoinOptions", "SplineJoinOptions" } do
						t.expect(screen:FindFirstChild(name, true)).toBe(nil)
					end
				end,
			})
		end
	end)

	t.test("Spline menu opens with the same outline and height as reselection", function()
		renderGui({
			ResizeMode = "SplineJoin",
			HaveHelp = true,
			Check = function(screen, settings, render)
				local panel = screen:FindFirstChild("SplineJoinOptions", true)
				local header = screen:FindFirstChild("SplineJoin", true)
				local height = panel.AbsoluteSize.Y
				t.expect(height > 0).toBe(true)
				t.expect(header.Outline.ZIndex > header.ZIndex).toBe(true)
				t.expect(header.Outline.AbsolutePosition.Y).toBe(header.AbsolutePosition.Y)
				settings.ResizeMode = "InnerTouch"
				render()
				settings.ResizeMode = "SplineJoin"
				render()
				panel = screen:FindFirstChild("SplineJoinOptions", true)
				header = screen:FindFirstChild("SplineJoin", true)
				t.expect(panel.AbsoluteSize.Y).toBe(height)
				t.expect(header.Outline.AbsolutePosition.Y).toBe(header.AbsolutePosition.Y)
				settings.SplineJoinSegments = 12
				render()
				t.expect(panel.AbsoluteSize.Y).toBe(height)
				local content = panel.Content
				local segments = content.Segments
				local segmentLabel = segments:FindFirstChild("Label", true)
				local segmentTextBox = segments:FindFirstChild("TextBox", true)
				t.expect(segmentLabel.TextXAlignment).toBe(Enum.TextXAlignment.Left)
				t.expect(segmentTextBox.AbsolutePosition.X > segmentLabel.AbsolutePosition.X + segmentLabel.AbsoluteSize.X).toBe(true)
			end,
		})
	end)

	t.test("Spline segments input shows Automatic for zero", function()
		renderGui({
			ResizeMode = "SplineJoin",
			Check = function(screen, settings, render)
				local function textBox(): TextBox
					return screen:FindFirstChild("SplineJoinOptions", true).Content.Segments:FindFirstChild("TextBox", true)
				end
				t.expect(settings.SplineJoinSegments).toBe(0)
				-- The label is plain, only numbers are bold
				t.expect(textBox().Text:find("Automatic", 1, true) ~= nil).toBe(true)
				t.expect(textBox().Text:find("<b>", 1, true)).toBe(nil)
				settings.SplineJoinSegments = 12
				render()
				t.expect(textBox().Text:find("Automatic", 1, true)).toBe(nil)
				t.expect(textBox().Text:find("<b>12</b>", 1, true) ~= nil).toBe(true)
			end,
		})
	end)

	t.test("Automatic labels fit their text boxes as soon as a menu opens", function()
		local menus = { SplineJoin = "Segments", RoundedJoin = "Radius" }
		for mode, option in menus do
			renderGui({
				ResizeMode = mode,
				HaveHelp = true,
				Check = function(screen)
					-- No re-render here: the first render has to get it right by itself
					task.wait(0.1)
					local textBox = screen:FindFirstChild(mode .. "Options", true).Content[option]:FindFirstChild("TextBox", true)
					t.expect(textBox.Text:find("Automatic", 1, true) ~= nil).toBe(true)
					t.expect(textBox.TextFits).toBe(true)
					-- Centered text must not be padded on one side only
					t.expect(textBox.Text:sub(1, 1) ~= " ").toBe(true)
					local padding = textBox:FindFirstChildWhichIsA("UIPadding")
					t.expect(padding == nil or padding.PaddingLeft == padding.PaddingRight).toBe(true)
					t.expect(textBox.TextBounds.X <= textBox.AbsoluteSize.X).toBe(true)
				end,
			})
		end
	end)

	t.test("Rounded Join menu switches between segmented and original cylinder previews", function()
		for _, classic in { false, true } do
			renderGui({
				ClassicUI = classic,
				ResizeMode = "RoundedJoin",
				Check = function(screen, settings, render)
					local menu = screen:FindFirstChild("RoundedJoinOptions", true)
					t.expect(menu ~= nil).toBe(not classic)
					for _, cylinder in { false, true, false } do
						settings.UseCylinderForRoundedJoin = cylinder
						render()
						local row = screen:FindFirstChild("RoundedJoin", true)
						if classic then
							local icon = row:FindFirstChild("Icon", true)
							t.expect(icon:IsA("ImageLabel")).toBe(true)
							t.expect(icon.Image).toBe("rbxassetid://9834555074")
							continue
						end
						local options = screen:FindFirstChild("RoundedJoinOptions", true).Content
						local radius = options.Radius:FindFirstChild("TextBox", true)
						t.expect(radius.Text:find("Automatic", 1, true) ~= nil).toBe(true)
						t.expect(options.Radius.LayoutOrder < options.FillerType.LayoutOrder).toBe(true)
						local chips = options.FillerType
						t.expect(chips:FindFirstChild("Cylinder", true).Font == Enum.Font.SourceSansBold).toBe(cylinder)
						t.expect(chips:FindFirstChild("Spline", true).Font == Enum.Font.SourceSansBold).toBe(not cylinder)
						local filler = row:FindFirstChild("Filler", true)
						t.expect(filler:IsA("Part")).toBe(cylinder)
						if cylinder then
							t.expect(filler.Shape).toBe(Enum.PartType.Cylinder)
							local sawFade = false
							for _ = 1, 24 do
								task.wait(0.05)
								if filler.Transparency > 0 and filler.Transparency < 1 then
									sawFade = true
								end
							end
							t.expect(sawFade).toBe(true)
						else
							t.expect(filler:IsA("Model")).toBe(true)
						end
					end
				end,
			})
		end
	end)

	t.test("Classic UI style option is hidden while a new mode is selected", function()
		renderGui({
			Check = function(screen, settings, render)
				local hiddenModes = { WedgeJoin = true, RoundedJoin = true, SplineJoin = true }
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
					settings.ResizeMode = mode
					render()
					t.expect(screen:FindFirstChild("ClassicUI", true) == nil).toBe(hiddenModes[mode] == true)
					t.expect(screen:FindFirstChild("OptionsPanel", true) == nil).toBe(hiddenModes[mode] == true)
				end
				-- Someone already in the classic UI can always switch back
				settings.ClassicUI = true
				settings.ResizeMode = "RoundedJoin"
				render()
				t.expect(screen:FindFirstChild("ReturnToNewUI", true) ~= nil).toBe(true)
			end,
		})
	end)

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
			local settings = makeTestSettings()
			settings.ResizeMode = mode

			local screen = Instance.new("ScreenGui")
			screen.Name = "ResizeAlignGuiTest"
			screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
