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
	FaceState: "FaceA" | "FaceB",
	LayoutOrder: number?,
})
	local current = props.Settings.ResizeMode
	return e(SubPanel, {
		Title = "Resize Method",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		Buttons = e(HelpGui.WithHelpIcon, {
			LayoutOrder = 2,
			Subject = e("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			}, {
				ListLayout = e("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Row1 = e("Frame", {
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				}, {
					ListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					OuterTouch = e(ChipForToggle, {
						Text = "Outer Touch",
						IsCurrent = current == "OuterTouch",
						LayoutOrder = 1,
						OnClick = function()
							props.Settings.ResizeMode = "OuterTouch"
							props.UpdatedSettings()
						end,
					}),
					InnerTouch = e(ChipForToggle, {
						Text = "Inner Touch",
						IsCurrent = current == "InnerTouch",
						LayoutOrder = 2,
						OnClick = function()
							props.Settings.ResizeMode = "InnerTouch"
							props.UpdatedSettings()
						end,
					}),
				}),
				Row2 = e("Frame", {
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
				}, {
					ListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					RoundedJoin = e(ChipForToggle, {
						Text = "Rounded Join",
						IsCurrent = current == "RoundedJoin",
						LayoutOrder = 1,
						OnClick = function()
							props.Settings.ResizeMode = "RoundedJoin"
							props.UpdatedSettings()
						end,
					}),
					ButtJoint = e(ChipForToggle, {
						Text = "Butt Joint",
						IsCurrent = current == "ButtJoint",
						LayoutOrder = 2,
						OnClick = function()
							props.Settings.ResizeMode = "ButtJoint"
							props.UpdatedSettings()
						end,
					}),
				}),
				Row3 = e("Frame", {
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 3,
				}, {
					ListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					ExtendUpTo = e(ChipForToggle, {
						Text = "Extend Up To",
						IsCurrent = current == "ExtendUpTo",
						LayoutOrder = 1,
						OnClick = function()
							props.Settings.ResizeMode = "ExtendUpTo"
							props.UpdatedSettings()
						end,
					}),
					ExtendInto = e(ChipForToggle, {
						Text = "Extend Into",
						IsCurrent = current == "ExtendInto",
						LayoutOrder = 2,
						OnClick = function()
							props.Settings.ResizeMode = "ExtendInto"
							props.UpdatedSettings()
						end,
					}),
				}),
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText =
					"How to resize the parts:\n" ..
					"<b>•Outer Touch</b> — Extend until faces align at their outermost points.\n" ..
					"<b>•Inner Touch</b> — Extend until faces align at their innermost points.\n" ..
					"<b>•Rounded Join</b> — Meet at the middle with a rounded filler.\n" ..
					"<b>•Butt Joint</b> — First face butts up against the second (right angles only).\n" ..
					"<b>•Extend Up To</b> — First face extended to just touch the second.\n" ..
					"<b>•Extend Into</b> — First face extended to fully penetrate the second.",
			}),
		}),
		Status = props.Settings.HaveHelp and e("TextLabel", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 0,
			BackgroundColor3 = Colors.GREY,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			TextColor3 = Colors.WHITE,
			RichText = true,
			Text = if props.FaceState == "FaceA"
				then "<i>Select the first face to resize.</i>"
				else "<i>Select the second face, or click empty space to cancel.</i>",
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 1,
		}, {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 2),
				PaddingBottom = UDim.new(0, 2),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
		}),
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
	FaceState: "FaceA" | "FaceB",
})
	local currentSettings = props.CurrentSettings
	local nextOrder = createNextOrder()
	return React.createElement(React.Fragment, nil, {
		ResizeMethodPanel = e(ResizeMethodPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			FaceState = props.FaceState,
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
				FaceState = props.FaceState,
			}),
	})
end

return ResizeAlignGui
