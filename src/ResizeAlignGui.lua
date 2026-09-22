--!strict
local CoreGui = game:GetService("CoreGui")

local Src = script.Parent
local Packages = Src.Parent.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local Colors = require("./PluginGui/Colors")
local HelpGui = require("./PluginGui/HelpGui")
local SubPanel = require("./PluginGui/SubPanel")
local PluginGui = require("./PluginGui/PluginGui")
local OperationButton = require("./PluginGui/OperationButton")
local ChipForToggle = require("./PluginGui/ChipForToggle")
local Checkbox = require("./PluginGui/Checkbox")
local Settings = require("./Settings")
local NumberInput = require("./PluginGui/NumberInput")
local ModeDemo = require("./ModeDemo")
local PluginGuiTypes = require("./PluginGui/Types")
local FaceHighlight = require("./FaceHighlight")
local doExtend = require("./doExtend")

type Face = doExtend.Face

local e = React.createElement

local function createNextOrder()
	local order = 0
	return function()
		order += 1
		return order
	end
end

local function ModeButton(props: {
	Text: string,
	IsCurrent: boolean,
	PreviewMode: ModeDemo.PreviewMode,
	HelpText: string,
	OpenBelow: boolean?,
	LayoutOrder: number?,
	OnClick: () -> (),
})
	local HEIGHT = 28
	local openBelow = props.OpenBelow or false
	return e(HelpGui.WithHelpIcon, {
		LayoutOrder = props.LayoutOrder,
		Subject = e("Frame", {
			ZIndex = 2,
			Size = UDim2.new(1, 0, 0, HEIGHT),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Border = props.IsCurrent and not openBelow and e("UIStroke", {
				Color = Colors.WHITE,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Button = e(ChipForToggle, {
				Text = props.Text,
				IsCurrent = props.IsCurrent,
				JoinedRight = true,
				OpenBelow = openBelow,
				HideOutline = true,
				Height = HEIGHT,
				TextSize = 24,
				LayoutOrder = 1,
				OnClick = props.OnClick,
			}),
			Demo = e(ModeDemo, {
				PreviewMode = props.PreviewMode,
				JoinedLeft = true,
				OpenBelow = openBelow,
				Animate = props.IsCurrent,
				Size = UDim2.fromOffset(60, HEIGHT),
				LayoutOrder = 2,
			}),
		}),
		Help = e(HelpGui.BasicTooltip, {
			HelpRichText = props.HelpText,
		}),
	})
end

local function ExpandableModeButton(props: {
	ButtonComponent: any,
	ButtonProps: any,
	ExpandedContent: any,
	OptionsName: string,
	ContentInset: number?,
	LayoutOrder: number?,
})
	local expandedContent = props.ExpandedContent
	local contentInset = props.ContentInset or 0

	return e("Frame", {
		ZIndex = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		OrderedContent = e("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Header = e("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			}, {
				Content = e(props.ButtonComponent, props.ButtonProps),
			}),
			Options = expandedContent and e("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
			}, {
				Panel = e("Frame", {
					Name = props.OptionsName,
					Position = UDim2.fromOffset(contentInset, 0),
					Size = UDim2.new(1, -contentInset, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Color3.fromRGB(18, 18, 18),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", {
						TopLeftRadius = UDim.new(),
						TopRightRadius = UDim.new(),
						BottomLeftRadius = UDim.new(0, 2),
						BottomRightRadius = UDim.new(0, 2),
					}),
					Content = e("Frame", {
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
					}, {
						Layout = e("UIListLayout", {
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 6),
						}),
						PaddingInset = e("UIPadding", {
							PaddingTop = UDim.new(0, 6),
							PaddingBottom = UDim.new(0, 7),
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
						}),
						Options = expandedContent,
					}),
				}),
			}),
		}),
		Outline = expandedContent and e("Frame", {
			ZIndex = 4,
			Position = UDim2.fromOffset(contentInset, 0),
			Size = UDim2.new(1, -contentInset, 1, 0),
			BackgroundTransparency = 1,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			Stroke = e("UIStroke", {
				Color = Colors.WHITE,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Center,
			}),
		}),
	})
end

local function OptionEntry(props: {
	Content: React.ReactElement<any, any>,
	HelpText: string,
	LayoutOrder: number?,
})
	return e(HelpGui.WithHelpIcon, {
		LayoutOrder = props.LayoutOrder,
		Subject = props.Content,
		Help = e(HelpGui.BasicTooltip, {
			HelpRichText = props.HelpText,
		}),
	})
end

local function SplineJoinOptions(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
})
	return React.createElement(React.Fragment, nil, {
		Segments = e(OptionEntry, {
			LayoutOrder = 2,
			HelpText = "Number of clones making up the spline. More segments produce a smoother curve. Leave empty or enter \"automatic\" to choose the count from the spline length and curvature.",
			Content = e(NumberInput, {
				Label = "Segments",
				Value = props.Settings.SplineJoinSegments,
				ZeroLabel = "Automatic",
				TextBoxWidth = UDim.new(0.5, -3),
				ValueEntered = function(value: number): number
					if value % 1 == 0 and value >= 0 then
						props.Settings.SplineJoinSegments = value
						props.UpdatedSettings()
					end
					return props.Settings.SplineJoinSegments
				end,
			}),
		}),
	})
end

local function OuterTouchOptions(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
})
	return React.createElement(React.Fragment, nil, {
		AcuteWedgeJoin = e(OptionEntry, {
			HelpText = "Automatically use Wedge Join instead of Outer Touch when the angle between faces is small to allow the formation of a sharp point for tight corners.",
			Content = e(Checkbox, {
				Label = "Wedge Join if needed",
				Checked = props.Settings.AcuteWedgeJoin,
				Changed = function(value: boolean)
					props.Settings.AcuteWedgeJoin = value
					props.UpdatedSettings()
				end,
			}),
		}),
	})
end

local function RoundedJoinOptions(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
})
	local useCylinder = props.Settings.UseCylinderForRoundedJoin
	local function fillerChip(text: string, cylinder: boolean, layoutOrder: number)
		return e(ChipForToggle, {
			Text = text,
			IsCurrent = useCylinder == cylinder,
			LayoutOrder = layoutOrder,
			OnClick = function()
				props.Settings.UseCylinderForRoundedJoin = cylinder
				props.UpdatedSettings()
			end,
		})
	end
	return React.createElement(React.Fragment, nil, {
		Radius = e(OptionEntry, {
			LayoutOrder = 1,
			HelpText = "Radius of the rounded outside of the join. A larger radius makes a wider Cylinder, moved inwards to stay flush with the outside of both parts, or a more gradual Spline bend. Leave empty or enter \"automatic\" to use the radius the joined faces need, which is also the smallest radius that can be used. Joining two cylinders ignores this.",
			Content = e(NumberInput, {
				Label = "Radius",
				Value = props.Settings.RoundedJoinRadius,
				ZeroLabel = "Automatic",
				Unit = " studs",
				TextBoxWidth = UDim.new(0.5, -3),
				ValueEntered = function(value: number): number
					if value >= 0 and value <= 1024 then
						props.Settings.RoundedJoinRadius = value
						props.UpdatedSettings()
					end
					return props.Settings.RoundedJoinRadius
				end,
			}),
		}),
		FillerType = e(OptionEntry, {
			LayoutOrder = 2,
			HelpText = "What to fill the gap between the parts with.\n"
				.. "<b>•Cylinder</b> — A single Cylinder part.\n"
				.. "<b>•Spline</b> — A Spline Join made of copies of the first part, which keeps the shape of non-block parts.\n"
				.. "Joining two cylinders always uses a sphere.",
			Content = e("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			}, {
				ListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Cylinder = fillerChip("Cylinder", true, 1),
				Spline = fillerChip("Spline", false, 2),
			}),
		}),
	})
end

local function ResizeMethodPanel(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local current = props.Settings.ResizeMode
	local function makeButton(text: string, mode: Settings.ResizeMode, helpText: string, layoutOrder: number)
		return e(ModeButton, {
			Text = text,
			IsCurrent = current == mode,
			PreviewMode = if mode == "RoundedJoin" and props.Settings.UseCylinderForRoundedJoin
				then "RoundedJoinCylinder"
				else mode,
			HelpText = helpText,
			LayoutOrder = layoutOrder,
			OnClick = function()
				props.Settings.ResizeMode = mode
				props.UpdatedSettings()
			end,
		})
	end

	local function makeExpandableButton(
		text: string,
		mode: Settings.ResizeMode,
		helpText: string,
		layoutOrder: number,
		expandedContent: any
	)
		local isCurrent = current == mode
		return e(ExpandableModeButton, {
			ButtonComponent = ModeButton,
			ButtonProps = {
				Text = text,
				IsCurrent = isCurrent,
				PreviewMode = if mode == "RoundedJoin" and props.Settings.UseCylinderForRoundedJoin
					then "RoundedJoinCylinder"
					else mode,
				HelpText = helpText,
				OpenBelow = isCurrent,
				OnClick = function()
					props.Settings.ResizeMode = mode
					props.UpdatedSettings()
				end,
			},
			LayoutOrder = layoutOrder,
			OptionsName = mode .. "Options",
			ContentInset = if props.Settings.HaveHelp then 20 else 0,
			ExpandedContent = if isCurrent then expandedContent else nil,
		})
	end

	return e(SubPanel, {
		Title = "Resize Method",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		OuterTouch = makeExpandableButton(
			"Outer Touch",
			"OuterTouch",
			"Extend both parts until their faces align at the outermost points. Good for sealing up non-right-angle joints.",
			1,
			e(OuterTouchOptions, {
				Settings = props.Settings,
				UpdatedSettings = props.UpdatedSettings,
			})
		),
		InnerTouch = makeButton(
			"Inner Touch",
			"InnerTouch",
			"Extend both parts until their faces align at the innermost points.",
			3
		),
		WedgeJoin = makeButton(
			"Wedge Join",
			"WedgeJoin",
			"Extend to inner touch and fill the remaining gap with wedge parts to form a sharp point. This mode always avoids Z-fighting.",
			4
		),
		RoundedJoin = makeExpandableButton(
			"Rounded Join",
			"RoundedJoin",
			"Both parts meet at the middle and any exposed gap is filled with a sphere or cylinder, or with a Spline Join. Works best on faces which are the same size.",
			5,
			e(RoundedJoinOptions, {
				Settings = props.Settings,
				UpdatedSettings = props.UpdatedSettings,
			})
		),
		SplineJoin = makeExpandableButton(
			"Spline Join",
			"SplineJoin",
			"Connect the selected faces with clones of the first part along a spline that matches both face orientations.",
			7,
			e(SplineJoinOptions, {
				Settings = props.Settings,
				UpdatedSettings = props.UpdatedSettings,
			})
		),
		ButtJoint = makeButton(
			"Butt Joint",
			"ButtJoint",
			"The first face butts up against the side of the second, with no overlap. Only works for right-angle intersections.",
			9
		),
		ExtendUpTo = makeButton(
			"Extend Up To",
			"ExtendUpTo",
			"Only the first face is extended out until it just touches the second face.",
			10
		),
		ExtendInto = makeButton(
			"Extend Into",
			"ExtendInto",
			"Only the first face is extended out until it fully penetrates the second face.",
			11
		),
	})
end

local function SelectionBehaviorPanel(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local current = props.Settings.SelectionThreshold
	return e(SubPanel, {
		Title = "Reach Around Edge Threshold",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		Buttons = e(HelpGui.WithHelpIcon, {
			LayoutOrder = 1,
			Subject = e("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			}, {
				ListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Threshold25 = e(ChipForToggle, {
					Text = "25%",
					IsCurrent = current == "25",
					LayoutOrder = 1,
					OnClick = function()
						props.Settings.SelectionThreshold = "25"
						props.UpdatedSettings()
					end,
				}),
				Threshold15 = e(ChipForToggle, {
					Text = "15%",
					IsCurrent = current == "15",
					LayoutOrder = 2,
					OnClick = function()
						props.Settings.SelectionThreshold = "15"
						props.UpdatedSettings()
					end,
				}),
				ThresholdExact = e(ChipForToggle, {
					Text = "Exact",
					IsCurrent = current == "Exact",
					LayoutOrder = 3,
					OnClick = function()
						props.Settings.SelectionThreshold = "Exact"
						props.UpdatedSettings()
					end,
				}),
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = 'How much margin near an edge should "Reach Around" for the back face to allow selection without camera movement.\n'
					.. "<b>•25%</b> — A large threshold; easier to select backfaces.\n"
					.. "<b>•15%</b> — Same behavior but with a smaller threshold.\n"
					.. "<b>•Exact</b> — Only the directly hovered face is selected; More precision.",
			}),
		}),
	})
end

local MODES_WITHOUT_CLASSIC_UI: { [Settings.ResizeMode]: boolean } = {
	WedgeJoin = true,
	RoundedJoin = true,
	SplineJoin = true,
}

local function OptionsPanel(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Advanced Options",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		ClassicUI = e(HelpGui.WithHelpIcon, {
			LayoutOrder = 1,
			Subject = e(Checkbox, {
				Label = "Classic UI style",
				Checked = props.Settings.ClassicUI,
				Changed = function(newValue: boolean)
					props.Settings.ClassicUI = newValue
					props.UpdatedSettings()
				end,
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Switch to something more similar to the classic ResizeAlign UI.",
			}),
		}),
	})
end

local function CloseButton(props: {
	HandleAction: (string) -> (),
	LayoutOrder: number?,
})
	return e("Frame", {
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		CancelButton = e(OperationButton, {
			Text = "Close <i>ResizeAlign</i>",
			Color = Colors.DARK_RED,
			Disabled = false,
			Height = 30,
			OnClick = function()
				props.HandleAction("cancel")
			end,
		}),
	})
end

-- Classic UI: OperationButton with icon
local function IconOperationButton(props: {
	Text: string,
	SubText: string,
	IsCurrent: boolean,
	Icon: string,
	LayoutOrder: number?,
	OnClick: () -> (),
})
	local fullText = string.format('%s\n<i><font size="12" color="#AAA">%s</font></i>', props.Text, props.SubText)
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Button = e("Frame", {
			Size = UDim2.new(1, -68, 0, 32),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		}, {
			Inner = e(OperationButton, {
				Text = fullText,
				Color = if props.IsCurrent then Colors.DARK_RED else Colors.GREY,
				Disabled = false,
				Height = 32,
				OnClick = props.OnClick,
			}),
		}),
		Icon = e("ImageLabel", {
			Size = UDim2.fromOffset(64, 32),
			BackgroundTransparency = 1,
			Image = props.Icon,
			LayoutOrder = 2,
		}),
	})
end

local RESIZE_MODE_ICONS: { [Settings.ResizeMode]: string } = {
	OuterTouch = "rbxassetid://9756984675",
	InnerTouch = "rbxassetid://9756984928",
	WedgeJoin = "rbxassetid://9756984675",
	RoundedJoin = "rbxassetid://9834555074",
	ButtJoint = "rbxassetid://9756985700",
	ExtendUpTo = "rbxassetid://9756985017",
	ExtendInto = "rbxassetid://9756985126",
}

local function ClassicResizeMethodPanel(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local current = props.Settings.ResizeMode
	local function makeButton(mode: Settings.ResizeMode, label: string, subText: string, layoutOrder: number)
		return e(IconOperationButton, {
			Text = label,
			SubText = subText,
			IsCurrent = current == mode,
			Icon = RESIZE_MODE_ICONS[mode],
			LayoutOrder = layoutOrder,
			OnClick = function()
				props.Settings.ResizeMode = mode
				props.UpdatedSettings()
			end,
		})
	end

	-- The classic UI only offers the original plugin's modes, without sub-options
	return e(SubPanel, {
		Title = "Resize Method",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		OuterTouch = makeButton("OuterTouch", "Outer Touch", "extend to outermost alignment", 1),
		InnerTouch = makeButton("InnerTouch", "Inner Touch", "extend to innermost alignment", 2),
		RoundedJoin = makeButton("RoundedJoin", "Rounded Join", "meet in the middle with filler", 3),
		ButtJoint = makeButton("ButtJoint", "Butt Joint", "butt up against second face", 4),
		ExtendUpTo = makeButton("ExtendUpTo", "Extend Up To", "extend to first contact", 5),
		ExtendInto = makeButton("ExtendInto", "Extend Into", "extend to full penetration", 6),
	})
end

local THRESHOLD_ICONS: { [Settings.SelectionThreshold]: string } = {
	["25"] = "rbxassetid://9758180727",
	["15"] = "rbxassetid://9758180952",
	Exact = "rbxassetid://9758180541",
}

local function ClassicSelectionBehaviorPanel(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local current = props.Settings.SelectionThreshold
	local function makeButton(
		threshold: Settings.SelectionThreshold,
		label: string,
		subText: string,
		layoutOrder: number
	)
		return e(IconOperationButton, {
			Text = label,
			SubText = subText,
			IsCurrent = current == threshold,
			Icon = THRESHOLD_ICONS[threshold],
			LayoutOrder = layoutOrder,
			OnClick = function()
				props.Settings.SelectionThreshold = threshold
				props.UpdatedSettings()
			end,
		})
	end
	return e(SubPanel, {
		Title = "Selection Behavior",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		Threshold25 = makeButton("25", "25% Threshold", "large edge threshold", 1),
		Threshold15 = makeButton("15", "15% Threshold", "small edge threshold", 2),
		ThresholdExact = makeButton("Exact", "Exact Target", "no threshold", 3),
	})
end

local function AdornmentOverlay(props: {
	HoverFace: Face?,
	SelectedFace: Face?,
	FaceState: "FaceA" | "FaceB",
})
	local children: { [string]: any } = {}

	if props.SelectedFace then
		children.SelectedFace = e(FaceHighlight, {
			Face = props.SelectedFace,
			Color = Color3.new(1, 0, 0),
			Transparency = 0,
			ZIndexOffset = 0,
		})
	end

	if props.HoverFace then
		local hoverColor = if props.FaceState == "FaceA" then Color3.new(1, 0, 0) else Color3.new(0, 0, 1)
		children.HoverFace = e(FaceHighlight, {
			Face = props.HoverFace,
			Color = hoverColor,
			Transparency = 0.5,
			ZIndexOffset = 2,
		})
	end

	return ReactRoblox.createPortal(
		e("Folder", {
			Name = "$ResizeAlignAdornments",
			Archivable = false,
		}, children),
		CoreGui
	)
end

local function ClassicContent(props: {
	CurrentSettings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
})
	local currentSettings = props.CurrentSettings
	local nextOrder = createNextOrder()
	return React.createElement(React.Fragment, nil, {
		ClassicResizeMethod = e(ClassicResizeMethodPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		ClassicSelectionBehavior = e(ClassicSelectionBehaviorPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		OptionsPanel = e(SubPanel, {
			Title = "Advanced Options",
			LayoutOrder = nextOrder(),
			Padding = UDim.new(0, 4),
		}, {
			ReturnToNewUI = e(Checkbox, {
				LayoutOrder = 1,
				Label = "Classic UI style",
				Checked = currentSettings.ClassicUI,
				Changed = function(newValue: boolean)
					currentSettings.ClassicUI = newValue
					props.UpdatedSettings()
				end,
			}),
		}),
	})
end

local function ModernContent(props: {
	CurrentSettings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
})
	local currentSettings = props.CurrentSettings
	local nextOrder = createNextOrder()
	return React.createElement(React.Fragment, nil, {
		ResizeMethodPanel = e(ResizeMethodPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		SelectionBehaviorPanel = e(SelectionBehaviorPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		-- The classic UI is only offered for the modes the original plugin had.
		-- It is the panel's only option, so the whole panel goes with it.
		OptionsPanel = not MODES_WITHOUT_CLASSIC_UI[currentSettings.ResizeMode] and e(OptionsPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		CloseButton = e(CloseButton, {
			HandleAction = props.HandleAction,
			LayoutOrder = nextOrder(),
		}),
	})
end

local RESIZEALIGN_CONFIG: PluginGuiTypes.PluginGuiConfig = {
	PluginName = "ResizeAlign",
	PendingText = "...",
	TutorialElement = nil,
}

local function ResizeAlignGui(props: {
	GuiState: PluginGuiTypes.PluginGuiMode,
	CurrentSettings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
	FaceState: "FaceA" | "FaceB",
	HoverFace: Face?,
	SelectedFace: Face?,
})
	local currentSettings = props.CurrentSettings
	return e(PluginGui, {
		Config = RESIZEALIGN_CONFIG,
		State = {
			Mode = props.GuiState,
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			HandleAction = props.HandleAction,
			Panelized = props.Panelized,
		},
	}, {
		AdornmentOverlay = e(AdornmentOverlay, {
			HoverFace = props.HoverFace,
			SelectedFace = props.SelectedFace,
			FaceState = props.FaceState,
		}),
		Content = if currentSettings.ClassicUI
			then e(ClassicContent, {
				CurrentSettings = currentSettings,
				UpdatedSettings = props.UpdatedSettings,
			})
			else e(ModernContent, {
				CurrentSettings = currentSettings,
				UpdatedSettings = props.UpdatedSettings,
				HandleAction = props.HandleAction,
			}),
	})
end

return ResizeAlignGui
