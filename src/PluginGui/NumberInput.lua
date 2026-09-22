--!strict
local TextService = game:GetService("TextService")

local Plugin = script.Parent.Parent.Parent
local Packages = Plugin.Packages

local React = require(Packages.React)
local e = React.createElement

local Colors = require("./Colors")
local interpretNumberInput = require("./interpretNumberInput")

local function NumberInput(props: {
	Label: string?,
	Value: number,
	Unit: string?,
	ValueEntered: (number) -> number?,
	LayoutOrder: number?,
	ChipColor: Color3?,
	Grow: boolean?,
	-- Show this text in place of a zero value. Entering it (in any case) or
	-- leaving the box empty sets the value to zero.
	ZeroLabel: string?,
	TextBoxWidth: UDim?,
})
	local hasFocus, setHasFocus = React.useState(false)
	local textBoxWidth = props.TextBoxWidth

	local showZeroLabel = props.ZeroLabel ~= nil and props.Value == 0
	local valueText = if showZeroLabel then props.ZeroLabel :: string else string.format("%g", props.Value)
	local unitText = if props.Unit and not showZeroLabel then props.Unit else ""
	-- Numbers are bold, but a whole word in bold is too loud
	local displayText = if showZeroLabel
		then valueText
		else string.format('<b>%s</b><font size="14">%s</font>', valueText, unitText)

	-- Tracked as state so that we re-render once layout gives the box its width,
	-- which isn't known yet on the first render
	local measuredWidth, setMeasuredWidth = React.useState(nil :: number?)
	local numberPartLength = TextService:GetTextSize(valueText, 20, Enum.Font.RobotoMono, Vector2.new(1000, 1000)).X
	local unitPartLength = TextService:GetTextSize(
		unitText,
		14,
		Enum.Font.RobotoMono,
		Vector2.new(1000, 1000)
	).X
	local displayTextSize = numberPartLength + unitPartLength
	local textFitsAtNormalSize = measuredWidth ~= nil and measuredWidth >= displayTextSize + 4

	local onFocusLost = React.useCallback(function(object: TextBox, enterPressed: boolean)
		local newValue = interpretNumberInput(object.Text, props.ZeroLabel)
		if newValue then
			newValue = props.ValueEntered(newValue)
			-- If the value didn't change we need to revert because we won't get rerendered
			if newValue == props.Value then
				object.Text = displayText
			end
		else
			-- Revert to previous value
			object.Text = displayText
		end
		setHasFocus(false)
	end, { props.ValueEntered, displayText, props.ZeroLabel } :: { any })

	local onFocused = React.useCallback(function(object: TextBox)
		-- Start empty rather than making the user delete the zero label
		object.Text = if showZeroLabel then "" else tostring(props.Value)
		object.CursorPosition = #object.Text + 1
		object.SelectionStart = -1
		setHasFocus(true)
	end, { props.Value, showZeroLabel } :: { any })

	return e("Frame", {
		Size = if props.Grow then UDim2.new() else UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		ListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Flex = props.Grow and e("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Grow,
		}),
		Label = props.Label and e("TextLabel", {
			Text = props.Label,
			TextColor3 = Colors.WHITE,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 0, 24),
			AutomaticSize = Enum.AutomaticSize.XY,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		}, {
			Flex = textBoxWidth and e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Grow,
			}),
		}),
		TextBox = e("TextBox", {
			-- Scaled text runs right up to the edges of the box. The space keeps
			-- it off the chip color strip on the left, but without a strip it
			-- would only push centered text off to the right.
			Text = if not textFitsAtNormalSize and props.ChipColor then " " .. displayText else displayText,
			TextColor3 = Colors.WHITE,
			RichText = true,
			BackgroundColor3 = Colors.GREY,
			Size = if textBoxWidth
				then UDim2.new(textBoxWidth.Scale, textBoxWidth.Offset, 0, 24)
				else UDim2.fromOffset(0, 24),
			Font = Enum.Font.RobotoMono,
			TextScaled = not textFitsAtNormalSize,
			TextSize = 20,
			LayoutOrder = 2,
			[React.Event.Focused] = onFocused,
			[React.Event.FocusLost] = onFocusLost :: any,
			[React.Change.AbsoluteSize] = function(object: TextBox)
				setMeasuredWidth(object.AbsoluteSize.X)
			end,
		}, {
			-- Scaled text fills the box's height when it has room to, so cap it
			SizeLimit = not textFitsAtNormalSize and e("UITextSizeConstraint", {
				MaxTextSize = 20,
			}),
			EdgePadding = not textFitsAtNormalSize and not props.ChipColor and e("UIPadding", {
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
			}),
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			Flex = not textBoxWidth and e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Grow,
			}),
			Border = hasFocus and e("UIStroke", {
				Color = Colors.ACTION_BLUE,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			ChipColor = props.ChipColor and not hasFocus and e("CanvasGroup", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, {
				ChipFrame = e("Frame", {
					Size = UDim2.new(0, 2, 1, 0),
					BackgroundColor3 = props.ChipColor,
				}),
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
			}),
		}),
	})
end

return NumberInput
