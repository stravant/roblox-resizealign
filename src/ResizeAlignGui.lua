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

local RESIZE_MODE_INFO = {
	{ key = "OuterTouch", label = "Outer Touch", detail = "The parts are extended until the last point where the selected faces line up. (Good for sealing up non-right angle joints in walls and other things.)", icon = "rbxassetid://9756984675" },
	{ key = "InnerTouch", label = "Inner Touch", detail = "The parts are extended until the first point where the selected faces line up.", icon = "rbxassetid://9756984928" },
	{ key = "WedgeJoin", label = "Wedge Join", detail = "The parts are extended to inner touch and the remaining gap is filled with wedge parts to form a sharp point. (Good for acute angle joints.)", icon = "rbxassetid://9756984675" },
	{ key = "RoundedJoin", label = "Rounded Join", detail = "The parts meet at the middle and any exposed gap is filled with a sphere or cylinder part. (Works best on faces which are the same size)", icon = "rbxassetid://9834555074" },
	{ key = "ButtJoint", label = "Butt Joint", detail = "The parts are extended out such that the first face butts up against the side of the second face, with no overlap. (Only works for right-angle intersections)", icon = "rbxassetid://9756985700" },
	{ key = "ExtendUpTo", label = "Extend Up To", detail = "The first face is extended out until the first point where it touches the second face. (The first face will be just touching the second face)", icon = "rbxassetid://9756985017" },
	{ key = "ExtendInto", label = "Extend Into", detail = "The first face is extended out until the last point where it touches the second face. (The first face will be extended just far enough to be completely sunk into the second)", icon = "rbxassetid://9756985126" },
}

local THRESHOLD_INFO = {
	{ key = "25", label = "25% Threshold", detail = "A 25% threshold around the edge of the hovered face will instead select the adjacent face allowing you to select backfaces without moving your camera.", icon = "rbxassetid://9758180727" },
	{ key = "15", label = "15% Threshold", detail = "Same as above but with a 15% threshold.", icon = "rbxassetid://9758180952" },
	{ key = "Exact", label = "Exact Target", detail = "Exactly the hovered face will be selected. Greater precision but requires a lot more camera movement to select what you want.", icon = "rbxassetid://9758180541" },
}

local function ResizeMethodPanel(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local current = props.Settings.ResizeMode

	local function makeButton(text: string, mode: Settings.ResizeMode, helpText: string, layoutOrder: number)
		local HEIGHT = 28
		return e(HelpGui.WithHelpIcon, {
			LayoutOrder = layoutOrder,
			Subject = e("Frame", {
				Size = UDim2.new(1, 0, 0, HEIGHT),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Button = e(ChipForToggle, {
					Text = text,
					IsCurrent = current == mode,
					Height = HEIGHT,
					TextSize = 24,
					LayoutOrder = 1,
					OnClick = function()
						props.Settings.ResizeMode = mode
						props.UpdatedSettings()
					end,
				}),
				Demo = e(ModeDemo, {
					ResizeMode = mode,
					Animate = current == mode,
					Size = UDim2.fromOffset(60, HEIGHT),
					LayoutOrder = 2,
				}),
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = helpText,
			}),
		})
	end

	return e(SubPanel, {
		Title = "Resize Method",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		OuterTouch = makeButton("Outer Touch", "OuterTouch",
			"Extend both parts until their faces align at the outermost points. Good for sealing up non-right-angle joints.", 1),
		InnerTouch = makeButton("Inner Touch", "InnerTouch",
			"Extend both parts until their faces align at the innermost points.", 3),
		WedgeJoin = makeButton("Wedge Join", "WedgeJoin",
			"Extend to inner touch and fill the remaining gap with wedge parts to form a sharp point. Good for acute angle joints.", 4),
		RoundedJoin = makeButton("Rounded Join", "RoundedJoin",
			"Both parts meet at the middle and any exposed gap is filled with a sphere or cylinder. Works best on faces which are the same size.", 5),
		ButtJoint = makeButton("Butt Joint", "ButtJoint",
			"The first face butts up against the side of the second, with no overlap. Only works for right-angle intersections.", 6),
		ExtendUpTo = makeButton("Extend Up To", "ExtendUpTo",
			"Only the first face is extended out until it just touches the second face.", 7),
		ExtendInto = makeButton("Extend Into", "ExtendInto",
			"Only the first face is extended out until it fully penetrates the second face.", 8),
		AcuteWedgeJoin = current == "OuterTouch" and e(HelpGui.WithHelpIcon, {
			LayoutOrder = 9,
			Subject = e(Checkbox, {
				Label = "Wedge Join tight corners",
				Checked = props.Settings.AcuteWedgeJoin,
				LayoutOrder = 9,
				Changed = function(newValue: boolean)
					props.Settings.AcuteWedgeJoin = newValue
					props.UpdatedSettings()
				end,
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Automatically use Wedge Join instead of Outer Touch when the angle between faces is small to allow the formation of a sharp point for tight corners.",
			}),
		})
	})
end

local function SelectionBehaviorPanel(props: {
	Settings: Settings.ResizeAlignSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local current = props.Settings.SelectionThreshold
	return e(SubPanel, {
		Title = "Selection Reach Around Edges",
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
				HelpRichText =
					"Edge threshold for selecting adjacent faces:\n" ..
					"<b>•25%</b> — A large threshold; easier to select backfaces.\n" ..
					"<b>•15%</b> — Same behavior but with a smaller threshold.\n" ..
					"<b>•Exact</b> — Only the directly hovered face is selected.",
			}),
		}),
	})
end

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
	local fullText = string.format(
		'%s\n<i><font size="12" color="#AAA">%s</font></i>',
		props.Text, props.SubText
	)
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
	return e(SubPanel, {
		Title = "Resize Method",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		OuterTouch = makeButton("OuterTouch", "Outer Touch", "extend to outermost alignment", 1),
		AcuteWedgeJoin = current == "OuterTouch" and e(Checkbox, {
			Label = "Wedge fill acute angles",
			Checked = props.Settings.AcuteWedgeJoin,
			LayoutOrder = 2,
			Changed = function(newValue: boolean)
				props.Settings.AcuteWedgeJoin = newValue
				props.UpdatedSettings()
			end,
		}),
		InnerTouch = makeButton("InnerTouch", "Inner Touch", "extend to innermost alignment", 3),
		WedgeJoin = makeButton("WedgeJoin", "Wedge Join", "inner touch + wedge fill for sharp point", 4),
		RoundedJoin = makeButton("RoundedJoin", "Rounded Join", "meet in the middle with filler", 5),
		ButtJoint = makeButton("ButtJoint", "Butt Joint", "butt up against second face", 6),
		ExtendUpTo = makeButton("ExtendUpTo", "Extend Up To", "extend to first contact", 7),
		ExtendInto = makeButton("ExtendInto", "Extend Into", "extend to full penetration", 8),
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
	local function makeButton(threshold: Settings.SelectionThreshold, label: string, subText: string, layoutOrder: number)
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

	return ReactRoblox.createPortal(e("Folder", {
		Name = "$ResizeAlignAdornments",
		Archivable = false,
	}, children), CoreGui)
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
		OptionsPanel = e(OptionsPanel, {
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
