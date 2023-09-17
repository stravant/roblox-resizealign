-- Debugging stub to temporarily turn off the plugin easily with Ctrl+Shift+L
if false then
	return
end

--Updated May 2022:
-- * Improve face selection mechanics to allow selecting backfaces.

--Updated June 2022:
-- * Allow selection and extension of the sloped face of WedgeParts (a new part
--   is created in that case)
-- * Introduce "Rounded" join mode for creating smooth corners and joining
--   pipe sections.

--Updated June 2022:
-- * Fix minor bug where ExtendUpto / ExtendInto failed in the exactly
--   perpendicular case.
-- * Eliminate an error that can come up when reloading the plugin.

--Updated August 2022:
-- * ResizeAlign now resepects the "Join Surfaces" toggle by taking advantage
--   of the JointMaker class from the DraggerFramework.
-- * Holding Ctrl now enables "Dragger Mode" where the Select dragger can be
--   used while Ctrl is held down.

----[=[
------------------
--DEFAULT VALUES--
------------------
-- has the plugin been loaded?
local loaded = false

-- is the plugin currently active?
local on = false

local mouse;

----------------
--PLUGIN SETUP--
----------------
-- an event that is fired before the plugin deactivates
local UserInputService = game:GetService("UserInputService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local DraggerService = game:GetService("DraggerService")

local Src = script.Parent
local Packages = Src.Parent.Packages

local DraggerHandler = require(Packages.DraggerHandler)
local createSharedToolbar = require(Packages.createSharedToolbar)
local DraggerFramework = require(Packages.DraggerFramework)
local JointMaker = require(DraggerFramework.Utility.JointMaker)

local FaceDisplay = require(Src.FaceDisplay)
local copyPartProps = require(Src.copyPartProps)

local mouseCnList = {}

local draggerHandler = DraggerHandler.new(plugin)

local addDraggerSidebar;

-- create the plugin and toolbar, and connect them to the On/Off activation functions
plugin.Deactivation:connect(function()
	Off()
end)

local sharedToolbarSettings = {} :: createSharedToolbar.SharedToolbarSettings
sharedToolbarSettings.CombinerName = "GeomToolsToolbar"
sharedToolbarSettings.ToolbarName = "GeomTools"
sharedToolbarSettings.ButtonName = "ResizeAlign"
sharedToolbarSettings.ButtonIcon = "rbxassetid://4524348910"
sharedToolbarSettings.ButtonTooltip = "Resize pairs of parts up to the point where they intersect."
sharedToolbarSettings.ClickedFn = function()
	if on then
		Off()
	elseif loaded then
		On()
	end
end
createSharedToolbar(plugin, sharedToolbarSettings)

-- Run when the popup is activated.
function On()
	plugin:Activate(true)
	sharedToolbarSettings.Button:SetActive(true)
	on = true
	mouse = plugin:GetMouse(true)
	table.insert(mouseCnList, mouse.Button1Down:connect(function()
		MouseDown()
	end))
	table.insert(mouseCnList, mouse.Button1Up:connect(function()
		MouseUp()
	end))
	table.insert(mouseCnList, mouse.Move:connect(function()
		MouseMove()
	end))
	table.insert(mouseCnList, mouse.Idle:connect(function()
		MouseIdle()
	end))
	--
	Selected()
end

-- Run when the popup is deactivated.
function Off()
	draggerHandler:disable()
	sharedToolbarSettings.Button:SetActive(false)
	on = false
	for i, cn in pairs(mouseCnList) do
		cn:Disconnect()
		mouseCnList[i] = nil
	end
	--
	Deselected()
end

local PLUGIN_NAME = 'ResizeAlign'
function SetSetting(setting, value)
	plugin:SetSetting(PLUGIN_NAME..setting, value)
end
function GetSetting(setting)
	return plugin:GetSetting(PLUGIN_NAME..setting)
end

local USED_TOOL = 'UsedToolSetting'
local CLOSED_SIDEBAR = 'ClosedSidebarSetting'

-------------
--UTILITIES--
-------------

type Face = {
	Object: BasePart,
	Normal: Enum.NormalId,
	IsWedge: boolean?,
}

local function otherNormals(dir: Vector3)
	if math.abs(dir.X) > 0 then
		return Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
	elseif math.abs(dir.Y) > 0 then
		return Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
	else
		return Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
	end
end

local function extend(v: Vector3, amount: number)
	return v.Unit * (v.Magnitude + amount) 
end

local function getFacePoints(face: Face)
	local hsize = face.Object.Size / 2
	local cf = face.Object.CFrame
	if face.IsWedge then
		return {
			cf:PointToWorldSpace((Vector3.xAxis + Vector3.yAxis + Vector3.zAxis) * hsize),
			cf:PointToWorldSpace((Vector3.xAxis + Vector3.yAxis + Vector3.zAxis) * hsize),
			cf:PointToWorldSpace((-Vector3.xAxis - Vector3.yAxis - Vector3.zAxis) * hsize),
			cf:PointToWorldSpace((-Vector3.xAxis - Vector3.yAxis - Vector3.zAxis) * hsize),
		}
	else
		local faceDir = Vector3.fromNormalId(face.Normal)
		local faceA, faceB = otherNormals(faceDir)
		faceDir, faceA, faceB = faceDir*hsize, faceA*hsize, faceB*hsize
		--
		return {
			cf:PointToWorldSpace(faceDir + faceA + faceB);
			cf:PointToWorldSpace(faceDir + faceA - faceB);
			cf:PointToWorldSpace(faceDir - faceA - faceB);
			cf:PointToWorldSpace(faceDir - faceA + faceB);
		}
	end
end

local function getPoints(part: BasePart): {Vector3}
	local hsize = part.Size / 2
	local cf = part.CFrame
	local points = {}
	for i = -1, 1, 2 do
		for j = -1, 1, 2 do
			for k = -1, 1, 2 do
				table.insert(points, cf:PointToWorldSpace(Vector3.new(i, j, k) * hsize))
			end
		end
	end
	return points
end

local function getNormal(face: Face)
	if face.IsWedge then
		local hsize = face.Object.Size / 2
		local cf = face.Object.CFrame
		return (cf.YVector * hsize.Z - cf.ZVector * hsize.Y).Unit
	else
		return face.Object.CFrame:VectorToWorldSpace(Vector3.fromNormalId(face.Normal))
	end
end

local function getDimension(face: Face)
	if face.IsWedge then
		-- Can't subtract from a wedge face, only extend
		return Vector3.zero
	else
		local dir = Vector3.fromNormalId(face.Normal)
		return Vector3.new(math.abs(dir.X), math.abs(dir.Y), math.abs(dir.Z))
	end
end

function cl0(n)
	return (n > 0) and n or 0
end
function realDistanceFrom(point: Vector3, part: BasePart)
	local p = part.CFrame:PointToObjectSpace(part.Position)
	local hz = part.Size/2
	local sep = Vector3.new(cl0(math.abs(p.x)-hz.x), cl0(math.abs(p.y)-hz.y), cl0(math.abs(p.z)-hz.z))
	return sep.magnitude
end

function getClosestPointTo(part: BasePart, points: {Vector3}): Vector3
	local closestDistance = math.huge
	local closestPoint = nil
	for _, point in points do
		local dist = realDistanceFrom(point, part)
		if dist < closestDistance then
			closestDistance = dist
			closestPoint = point
		end
	end
	return closestPoint
end

function getFurthestPointTo(part: BasePart, points: {Vector3}): Vector3
	local furthestDistance = -math.huge
	local furthestPoint = nil
	for _, point in points do
		local dist = realDistanceFrom(point, part)
		if dist > furthestDistance then
			furthestDistance = dist
			furthestPoint = point
		end
	end
	return furthestPoint
end

local function getBasis(face: Face)
	if face.IsWedge then
		return face.Object.Position, getNormal(face)
	else
		local hsize = face.Object.Size / 2
		local faceDir = Vector3.fromNormalId(face.Normal)
		local faceNormal = face.Object.CFrame:VectorToWorldSpace(faceDir)
		local facePoint = face.Object.CFrame:PointToWorldSpace(faceDir * hsize)
		return facePoint, faceNormal
	end
end

-- Get the point in the list most "out" of the face
function getPositivePointToFace(face, points: {Vector3}): Vector3
	local basePoint, normal = getBasis(face)
	local maxDist = -math.huge
	local maxPoint = nil
	for _, point in points do
		local dist = (point - basePoint):Dot(normal)
		if dist > maxDist then
			maxDist = dist
			maxPoint = point
		end
	end
	return maxPoint
end

function getNegativePointToFace(face, points: {Vector3}): Vector3
	local basePoint, normal = getBasis(face)
	local minDist = math.huge
	local minPoint = nil
	for _, point in pairs(points) do
		local dist = (point - basePoint):Dot(normal)
		if dist < minDist then
			minDist = dist
			minPoint = point
		end
	end
	return minPoint
end

function resizePart(face: Face, delta: number)
	if face.IsWedge then
		-- Create a new part extruding wedge face
		local point, normal = getBasis(face)
		local part = Instance.new("Part")
		copyPartProps(face.Object, part)
		part.CFrame = CFrame.fromMatrix(point + normal * 0.5 * delta, face.Object.CFrame.XVector, normal)
		local size = face.Object.Size
		part.Size = Vector3.new(size.X, delta, math.sqrt(size.Y^2 + size.Z^2))
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = face.Object.Parent
		part.Name = face.Object.Name.."_Extended"
	else
		-- Extend existing part
		
		-- Handle existing joints (disable WeldConstraints, destroy Welds, etc)
		local joiner = JointMaker.new(false)
		joiner:pickUpParts({face.Object})
		joiner:breakJointsToOutsiders()
		
		local axis = Vector3.fromNormalId(face.Normal)
		face.Object.Size += Vector3.new(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z)) * delta
		face.Object.CFrame *= CFrame.new(axis * (delta / 2))
		
		-- Restore / create joints post resize
		if DraggerService.JointsEnabled then
			joiner:computeJointPairs():createJoints()
		end
		joiner:putDownParts()
	end
	
	-- Show the sidebar once we've successfully used the plugin
	addDraggerSidebar(true)
end

------------------
--IMPLEMENTATION--
------------------

local mGuiContainer = Instance.new('Folder')
mGuiContainer.Name = 'ResizeAlignGui'
mGuiContainer.Archivable = false

local mState = 'FaceA' -- | 'FaceB'
local mFaceA = nil
local mFaceADrawn = nil

local mModeScreenGui = Instance.new('ScreenGui')
local DARK_RED = Color3.new(0.705882, 0, 0)

local function MakeModeGui(ident, pos, topText, options, optionText, optionDetails, optionIcons)
	optionDetails = optionDetails or {}
	optionIcons = optionIcons or {}
	topText = topText or ""
	local H = 30
	local optCount = #options

	local this = {}

	local mHintOn = false

	local mContainer = Instance.new('ImageButton', mModeScreenGui)
	mContainer.BackgroundTransparency = 1
	mContainer.Size = UDim2.new(0, 212, 0, 6+(H+6)*optCount + 20)
	mContainer.Position = pos
	--
	local mDragConnection;
	mContainer.InputBegan:Connect(function(inputObject: InputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			local initialX = mContainer.Position.X.Offset
			local initialY = mContainer.Position.Y.Offset
			local dragStart = inputObject.Position
			mDragConnection = UserInputService.InputChanged:Connect(function(inputObject: InputObject)
				if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
					local delta = inputObject.Position - dragStart
					mContainer.Position = UDim2.fromOffset(initialX + delta.X, initialY + delta.Y)
				end
			end)
		end
	end)
	mContainer.InputEnded:Connect(function(inputObject: InputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			if mDragConnection then
				mDragConnection:Disconnect()
				mDragConnection = nil
			end
			SetSetting('WindowPos_'..ident, {mContainer.AbsolutePosition.X, mContainer.AbsolutePosition.Y})
		end
	end)
	do
		local setting = GetSetting('WindowPos_'..ident)
		if setting then
			local tempWnd = Instance.new('ScreenGui', game:GetService('CoreGui'))
			local w = mContainer.Size.X.Offset
			local h = mContainer.Size.Y.Offset
			local fullw = tempWnd.AbsoluteSize.X
			local fullh = tempWnd.AbsoluteSize.Y
			tempWnd:Destroy()
			mContainer.Position = UDim2.new(0, math.min((setting[1] or setting['1'] or 0) + w, fullw) - w, 0, math.min((setting['2'] or setting[2] or 0) + h, fullh) - h)
		end
	end

	local mModeGui = Instance.new('Frame', mContainer)
	mModeGui.Name = "ModeGui"
	mModeGui.Position = UDim2.new(0, 0, 0, 20)
	mModeGui.Size = UDim2.new(0, 222, 0, 6+(H+6)*optCount)
	mModeGui.BackgroundTransparency = 1
	--
	local CONTENT_PADDING = UDim.new(0, 4)
	local mContent = Instance.new("Frame", mModeGui)
	mContent.AutomaticSize = Enum.AutomaticSize.Y
	mContent.Size = UDim2.new(1, 0, 0, 0)
	mContent.BackgroundColor3 = Color3.new(0, 0, 0)
	mContent.BorderSizePixel = 0
	mContent.BackgroundTransparency = 0.2
	local padding = Instance.new("UIPadding", mContent)
	padding.PaddingTop = CONTENT_PADDING
	padding.PaddingBottom = CONTENT_PADDING
	padding.PaddingRight = CONTENT_PADDING
	padding.PaddingLeft = CONTENT_PADDING
	local mLayout = Instance.new("UIListLayout", mContent)
	mLayout.Padding = UDim.new(0, 5)
	mLayout.SortOrder = Enum.SortOrder.LayoutOrder
	--
	local mTopText = Instance.new('TextLabel', mModeGui)
	mTopText.Name = "TopText"
	mTopText.Size = UDim2.new(0.8, 0, 0, 20)
	mTopText.Position = UDim2.new(0, 0, 0, -20)
	mTopText.BorderSizePixel = 0
	mTopText.Font = Enum.Font.SourceSansBold
	mTopText.TextSize = 16
	mTopText.TextXAlignment = Enum.TextXAlignment.Left
	mTopText.Text = " :: " .. topText
	mTopText.TextColor3 = Color3.new(1, 1, 1)
	mTopText.BackgroundColor3 = Color3.new(0, 0, 0)
	mTopText.BackgroundTransparency = 0.2
	--
	local mBottomText = Instance.new('TextLabel', mContent)
	mBottomText.Name = "BottomText"
	mBottomText.Size = UDim2.new(1, 0, 0, 0)
	mBottomText.Font = Enum.Font.SourceSans
	mBottomText.TextSize = 16
	mBottomText.TextXAlignment = Enum.TextXAlignment.Left
	mBottomText.TextYAlignment = Enum.TextYAlignment.Top
	mBottomText.Text = ""
	mBottomText.TextColor3 = Color3.new(1, 1, 1)
	mBottomText.BackgroundColor3 = Color3.new(0, 0, 0)
	mBottomText.BackgroundTransparency = 0.2
	mBottomText.BorderSizePixel = 0
	mBottomText.Visible = false
	mBottomText.TextWrapped = true
	mBottomText.LayoutOrder = 100
	mBottomText.AutomaticSize = Enum.AutomaticSize.Y
	--
	local mTopQ = Instance.new('TextButton', mModeGui)
	mTopQ.Size = UDim2.new(0, 20, 0, 20)
	mTopQ.Position = UDim2.new(1, -20, 0, -20)
	mTopQ.BorderSizePixel = 0
	mTopQ.BorderColor3 = Color3.new(1, 1, 1)
	mTopQ.TextSize = 20
	mTopQ.Font = Enum.Font.SourceSansBold
	mTopQ.TextColor3 = Color3.new(1, 1, 1)
	mTopQ.BackgroundColor3 = Color3.new(0, 0, 0)
	mTopQ.BackgroundTransparency = 0.2
	mTopQ.Text = "?"
	mTopQ.MouseButton1Down:Connect(function()
		mHintOn = not mHintOn
		if mHintOn then
			mTopQ.BorderColor3 = Color3.new(1, 0, 0)
			mTopQ.BorderSizePixel = 2
			mBottomText.Visible = true
			mBottomText.Text = "General Usage: Select two faces of parts to resize them such that they are aligned in some way.\nMouse over the options to get a description of them."
		else
			mTopQ.BorderColor3 = Color3.new(1, 1, 1)
			mTopQ.BorderSizePixel = 0
			mBottomText.Visible = false
		end
	end)
	mTopQ.MouseEnter:Connect(function()
		if not mHintOn then
			mTopQ.BorderColor3 = Color3.new(1, 1, 1)
			mTopQ.BorderSizePixel = 1
		end
	end)
	mTopQ.MouseLeave:Connect(function()
		if not mHintOn then
			mTopQ.BorderSizePixel = 0
		end
	end)
	local mTopQOutline = Instance.new("UIStroke", mTopQ)
	mTopQOutline.Color = DARK_RED
	--
	local optionGuis = {}
	local function resetOptionGuis()
		for _, gui in pairs(optionGuis) do
			gui.Border.Enabled = false
			gui.ZIndex = 1
		end
	end
	local function selectOption(option, gui)
		resetOptionGuis()
		gui.Border.Enabled = true
		gui.ZIndex = 2
		this.Mode = option
		SetSetting('Current_'..ident, option)
	end
	--
	for index, option in pairs(options) do
		local modeGui = Instance.new('TextButton', mContent)
		modeGui.RichText = true
		modeGui.Text = optionText[index]
		modeGui.BackgroundColor3 = Color3.new(0, 0, 0)
		modeGui.TextColor3 = Color3.new(1, 1, 1)
		modeGui.BorderColor3 = Color3.new(0.203922, 0.203922, 0.203922)
		modeGui.TextXAlignment = Enum.TextXAlignment.Left
		modeGui.Font = Enum.Font.SourceSansBold
		modeGui.TextSize = 24
		modeGui.Size = UDim2.new(1, 0, 0, H)
		modeGui.BackgroundTransparency = 0 --1 --0.3
		modeGui.LayoutOrder = index
		modeGui.AutomaticSize = Enum.AutomaticSize.Y
		modeGui.MouseEnter:connect(function()
			if mHintOn then
				mBottomText.Text = optionDetails[index] or ""
				mBottomText.Visible = true
			end
		end)
		local padding = Instance.new("UIPadding", modeGui)
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingTop = UDim.new(0, 2)
		padding.PaddingBottom = UDim.new(0, 2)
		padding.PaddingRight = UDim.new(0, 2)
		if optionIcons[index] then
			local icon = Instance.new("ImageLabel", modeGui)
			icon.AnchorPoint = Vector2.new(1, 0)
			icon.Position = UDim2.new(1, 0, 0, 0.5)
			icon.Size = UDim2.fromOffset(64, 32)
			icon.Image = optionIcons[index]
			icon.Name = "Icon"
			icon.ZIndex = 2
		end
		local border = Instance.new("UIStroke", modeGui)
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		border.LineJoinMode = Enum.LineJoinMode.Round
		border.Color = DARK_RED
		border.Thickness = 5
		border.Enabled = false
		border.Name = "Border"
		--
		modeGui.MouseButton1Down:connect(function()
			selectOption(option, modeGui)
		end)
		table.insert(optionGuis, modeGui)
	end
	--
	local previousOption = GetSetting('Current_'..ident)
	local hadPreviousValue = false
	if previousOption then
		for i, option in ipairs(options) do
			if option == previousOption then
				selectOption(options[i], optionGuis[i])
				hadPreviousValue = true
				break
			end
		end
	end
	-- Didn't manage to load previous choice
	if not hadPreviousValue then
		selectOption(options[1], optionGuis[1])
	end
	--
	local sidebar;
	function this:AddSidebar(str, animate, closedSetting)
		local frame = Instance.new("Frame")
		frame.Parent = mModeGui
		frame.Position = UDim2.new(1, 10, 0, 0)
		frame.Size = UDim2.fromOffset(26, 188)
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderColor3 = Color3.new(1, 1, 1)
		sidebar = frame
		local text = Instance.new("TextLabel", frame)
		text.BackgroundTransparency = 1
		text.Rotation = 90
		text.Position = UDim2.fromScale(0.5, 0.5)
		text.Text = str
		text.Font = Enum.Font.SourceSansBold
		text.TextSize = 18
		text.TextColor3 = Color3.new(1, 1, 1)
		local xButton = Instance.new("TextButton", frame)
		xButton.Text = "❌"
		xButton.TextColor3 = DARK_RED
		xButton.Position = UDim2.new(1, 0, 1, 0)
		xButton.AnchorPoint = Vector2.new(0.5, 0.5)
		xButton.Size = UDim2.fromOffset(16, 16)
		xButton.Font = Enum.Font.Arial
		xButton.BorderColor3 = DARK_RED
		xButton.BackgroundColor3 = Color3.new(0, 0, 0)
		xButton.MouseButton1Click:Connect(function()
			this:RemoveSidebar(closedSetting)
		end)
		local corner = Instance.new("UICorner", xButton)
		corner.CornerRadius = UDim.new(0, 2)
		local stroke = Instance.new("UIStroke", xButton)
		stroke.Thickness = 1
		stroke.Color = DARK_RED
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		--
		if animate then
			task.spawn(function()
				for i = 50, 0, -1 do
					local frac = i / 50
					frame.BackgroundTransparency = frac
					text.TextTransparency = frac
					stroke.Transparency = frac
					xButton.BackgroundTransparency = frac
					xButton.TextTransparency = frac
					task.wait()
				end
			end)
		end
	end
	function this:RemoveSidebar(closedSetting)
		SetSetting(closedSetting, true)
		if sidebar then
			sidebar:Destroy()
		end
	end
	function this:SetSidebarActive(state)
		if sidebar then
			if state then
				sidebar.BorderColor3 = DARK_RED
			else
				sidebar.BorderColor3 = Color3.new(1, 1, 1)
			end
		end
	end
	--
	return this
end

local OUTER_TOUCH = "Outer Touch"
local INNER_TOUCH = "Inner Touch"
local MIDDLE_JOIN = "Rounded Join"
local BUTT_JOINT = "Butt Joint"
local EXTEND_UP_TO = "Extend Up To"
local EXTEND_INTO = "Extend Into"

local mModeOption = MakeModeGui('Mode', UDim2.new(0, 20, 0, 20), "Resize Method", 
	{
		OUTER_TOUCH,
		INNER_TOUCH,
		MIDDLE_JOIN,
		BUTT_JOINT,
		EXTEND_UP_TO,
		EXTEND_INTO,
	},
	{
		"Outer Touch",
		"Inner Touch",
		"Rounded Join",
		"Butt Joint",
		"Extend Up To",
		"Extend Into",
	},
	{
		"The parts are extended until the last point where the selected faces line up. (Good sealing up non-right angle joints in walls and other things.)",
		"The parts are extended until the first point where the selected faces line up.",
		"The parts meet at the middle and any exposed gap is filled with a sphere or cylinder part. (Works best on faces which are the same size)",
	 	"The parts are extended out such that the first face butts up against the side of the second face, with no overlap. (Only works for right-angle intersections)",
	 	"The first face is extended out until the first point where it touches the second face. (The first face will be just touching the second face)",
		"The first face is extended out until the last point where it touches the second face. (The first face will be extended just far enough to be completely sunk into the second)",
	},
	{
		"rbxassetid://9756984675",
		"rbxassetid://9756984928",
		"rbxassetid://9834555074",
		"rbxassetid://9756985700",
		"rbxassetid://9756985017",
		"rbxassetid://9756985126",
	})

-- For debugging, uncomment to clear the setting state
--SetSetting(USED_TOOL, nil) SetSetting(CLOSED_SIDEBAR, nil)

-- Note on the logic here: We show the sidebar if the user hasn't closed it
-- yet. However we don't want to overwhealm them at first, so we only show
-- it after the first time they actually use the tool to resize something.
local hasClosedSidebar = GetSetting(CLOSED_SIDEBAR)
local addedDraggerSidebar = false
function addDraggerSidebar(setSetting)
	if hasClosedSidebar or addedDraggerSidebar then
		return
	end
	addedDraggerSidebar = true
	mModeOption:AddSidebar("Hold Ctrl: Activate Dragger", setSetting, CLOSED_SIDEBAR)
	if setSetting then
		SetSetting(USED_TOOL, true)
	end
end
if not hasClosedSidebar and GetSetting(USED_TOOL) then
	addDraggerSidebar(false)
end

local THRESHOLD_25 = "Threshold: 25%"
local THRESHOLD_15 = "Threshold: 15%"
local THRESHOLD_EXACT = "Exact Target"

local mSelectionOption = MakeModeGui('Threshold', UDim2.new(0, 20, 0, 350), "Selection Behavior",
	{
		THRESHOLD_25,
		THRESHOLD_15,
		THRESHOLD_EXACT,
	},
	{
		"25% Threshold",
		"15% Threshold",
		"Exact Target",
	},
	{
		"A 25% threshold around the edge of the hovered face will instead select the adjacent face allowing you to select backfaces without moving your camera.",
		"Same as above but with a 15% threshold.",
		"Exactly the hovered face will be selected. Greater precision but requires a lot more camera movement to select what you want.",
	},
	{
		"rbxassetid://9758180727",
		"rbxassetid://9758180952",
		"rbxassetid://9758180541",
	})

-- Target finding (Taking into account currently selected faces / target filter
function simpleGetTarget()
	local ray = Ray.new(mouse.UnitRay.Origin, mouse.UnitRay.Direction*999)
	local ignore = {mGuiContainer}
	if mState == 'FaceB' then
		table.insert(ignore, mFaceA.Object)
	end
	local hit, at = workspace:FindPartOnRayWithIgnoreList(ray, ignore)
	local targetSurface;
	local isWedgeFace = false
	if hit then
		local localDisp = hit.CFrame:VectorToObjectSpace(at - hit.Position)
		local halfSize = hit.Size / 2
		local smallest = math.huge
		if math.abs(localDisp.x - halfSize.x) < smallest then
			targetSurface = Enum.NormalId.Right
			smallest = math.abs(localDisp.x - halfSize.x)
		end
		if math.abs(localDisp.x + halfSize.x) < smallest then
			targetSurface = Enum.NormalId.Left
			smallest = math.abs(localDisp.x + halfSize.x)
		end
		if math.abs(localDisp.y - halfSize.y) < smallest then
			targetSurface = Enum.NormalId.Top
			smallest = math.abs(localDisp.y - halfSize.y)
		end
		if math.abs(localDisp.y + halfSize.y) < smallest then
			targetSurface = Enum.NormalId.Bottom
			smallest = math.abs(localDisp.y + halfSize.y)
		end
		if math.abs(localDisp.z - halfSize.z) < smallest then
			targetSurface = Enum.NormalId.Back
			smallest = math.abs(localDisp.z - halfSize.z)
		end
		if math.abs(localDisp.z + halfSize.z) < smallest then
			targetSurface = Enum.NormalId.Front
			smallest = math.abs(localDisp.z + halfSize.z)
		end
		local offsetFrac = localDisp / halfSize
		local wedgeFace = offsetFrac.Y / offsetFrac.Z
		if math.abs(1 - wedgeFace) < 0.0001 then
			isWedgeFace = true
		end
	end
	return hit, at, targetSurface, isWedgeFace
end
function otherNormalIds(normalId: Enum.NormalId)
	if normalId == Enum.NormalId.Top or normalId == Enum.NormalId.Bottom then
		return Enum.NormalId.Right, Enum.NormalId.Left, Enum.NormalId.Back, Enum.NormalId.Front
	elseif normalId == Enum.NormalId.Right or normalId == Enum.NormalId.Left then
		return Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Back, Enum.NormalId.Front
	elseif normalId == Enum.NormalId.Front or normalId == Enum.NormalId.Back then
		return Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Right, Enum.NormalId.Left
	end
end
function getFaceSize(part: BasePart, normalId: Enum.NormalId)
	local size = part.Size
	local vec = Vector3.fromNormalId(normalId)
	local x = (1 - math.abs(vec.X)) * size.X
	local y = (1 - math.abs(vec.Y)) * size.Y
	local z = (1 - math.abs(vec.Z)) * size.Z
	return (if x == 0 then 1 else x) * (if y == 0 then 1 else y) * (if z == 0 then 1 else z)
end
function getFacePolygon(part: BasePart, normalId: Enum.NormalId)
	local halfSize = 0.5 * part.Size
	local cf = part.CFrame
	local basePosition = cf:PointToWorldSpace(Vector3.fromNormalId(normalId) * halfSize)
	--
	local x, negx, y, negy = otherNormalIds(normalId)
	local offset_x = cf:VectorToWorldSpace(Vector3.fromNormalId(x) * halfSize)
	local offset_y = cf:VectorToWorldSpace(Vector3.fromNormalId(y) * halfSize)
	--
	return {
		{
			a = basePosition + offset_x + offset_y,
			b = basePosition + offset_x - offset_y,
			c = basePosition - offset_x + offset_y,
			d = basePosition - offset_x - offset_y,
			n = x,
		},
		{
			a = basePosition - offset_x + offset_y,
			b = basePosition - offset_x - offset_y,
			c = basePosition + offset_x + offset_y,
			d = basePosition + offset_x - offset_y,
			n = negx,
		},
		{
			a = basePosition + offset_y + offset_x,
			b = basePosition + offset_y - offset_x,
			c = basePosition - offset_y + offset_x,
			d = basePosition - offset_y - offset_x,
			n = y,
		},
		{
			a = basePosition - offset_y + offset_x,
			b = basePosition - offset_y - offset_x,
			c = basePosition + offset_y + offset_x,
			d = basePosition + offset_y - offset_x,
			n = negy,
		},
	}
end
local function toVec2(vec3: Vector3): Vector2
	return Vector2.new(vec3.X, vec3.Y)
end
function edgesToScreen(edges)
	local camera = workspace.CurrentCamera
	local screenEdges = {}
	for _, edge in pairs(edges) do
		table.insert(screenEdges, {
			a = toVec2(camera:WorldToScreenPoint(edge.a)),
			b = toVec2(camera:WorldToScreenPoint(edge.b)),
			c = toVec2(camera:WorldToScreenPoint(edge.c)),
			d = toVec2(camera:WorldToScreenPoint(edge.d)),
			n = edge.n,
		})
	end
	return screenEdges
end
--[[
	The return value `t` is a number such that `r1o + t * r1d` is the point of
	closest approach on the first ray between the two rays specified by the
	arguments.
]]
function intersectRayRay(r1o, r1d, r2o, r2d)
	local n =
		(r2o - r1o):Dot(r1d) * r2d:Dot(r2d) +
		(r1o - r2o):Dot(r2d) * r1d:Dot(r2d)
	local d =
		r1d:Dot(r1d) * r2d:Dot(r2d) -
		r1d:Dot(r2d) * r1d:Dot(r2d)
	if d == 0 then
		return false
	else
		return true, n / d
	end
end
function directionAndDistanceToEdge(edge, point: Vector2): (Vector2, number)
	local alongEdge = (edge.b - edge.a).Unit
	local toPoint = point - edge.a
	local pointOnEdge = edge.a + alongEdge * toPoint:Dot(alongEdge)
	local toEdge = pointOnEdge - point
	return toEdge.Unit, toEdge.Magnitude
end
function distanceToOppositeEdge(edge, point: Vector2, direction: Vector2): number?
	local alongEdge = edge.d - edge.c
	local alongEdgeDir = alongEdge.Unit
	local edgeLength = alongEdge.Magnitude
	local intersect, t = intersectRayRay(edge.c, alongEdgeDir, point, direction)
	if intersect then
		local intersectPoint = edge.c + alongEdgeDir * t
		local firstTry = (intersectPoint - point).Magnitude
		local clampC = (point - edge.c).Magnitude
		local clampD = (point - edge.d).Magnitude
		return math.min(firstTry, clampC, clampD)
	else
		return nil
	end
end
function GetTarget(): Face?
	-- First, get a base face
	local hit, at, normalId, isWedgeFace = simpleGetTarget()
	if not hit then
		return nil
	end
	
	-- Get the face edges in screen space
	local screenEdges = edgesToScreen(getFacePolygon(hit, normalId))
	local mouseLocation = UserInputService:GetMouseLocation()
	
	local smallestFrac = 1
	local smallestFracEdge = nil
	
	local threshold;
	if mSelectionOption.Mode == THRESHOLD_25 then
		threshold = 0.25
	elseif mSelectionOption.Mode == THRESHOLD_15 then
		threshold = 0.15
	elseif mSelectionOption.Mode == THRESHOLD_EXACT then
		threshold = 0
	else
		assert(false, "Unreachable")
	end
	
	local hardCutoff = workspace.CurrentCamera.ViewportSize.Magnitude * 0.2
	
	for i, edge in ipairs(screenEdges) do
		local dir, distToEdge = directionAndDistanceToEdge(edge, mouseLocation)
		local distToOtherEdge = distanceToOppositeEdge(edge, mouseLocation, -dir)
		if distToOtherEdge then
			local totalDist = distToOtherEdge + distToEdge
			local frac = distToEdge / totalDist
			if frac < smallestFrac and frac < threshold and getFaceSize(hit, edge.n) < getFaceSize(hit, normalId) then
				-- Hard cutoff at a certain fraction of the total viewport size
				if distToEdge < hardCutoff then
					smallestFrac = frac
					smallestFracEdge = edge
				end
			end
		end
	end
	
	return {
		Object = hit,
		Normal = if smallestFracEdge then smallestFracEdge.n else normalId,
		IsWedge = not smallestFracEdge and isWedgeFace,
	}
end

-- Hover Face
local mCurrentHoverFace: FaceDisplay.T
function HideHoverFace()
	if mCurrentHoverFace then
		mCurrentHoverFace:destroy()
		mCurrentHoverFace = nil
	end
end
function ShowHoverFace(face: Face)
	HideHoverFace()
	local color = if mState == 'FaceA' then Color3.new(1, 0, 0) else Color3.new(0, 0, 1)
	mCurrentHoverFace = FaceDisplay.new(mGuiContainer, face, color, 0.5, 2)
end

local function isCylinder(part: BasePart)
	return part:IsA("Part") and part.Shape == Enum.PartType.Cylinder
end

local function fillJoint(faceA: Face, faceB: Face, fillPoint, fillAxis: Vector3, pointsA, pointsB, offsetA, offsetB)
	local maxProj = -math.huge
	local minProj = math.huge
	local maxRadius = -math.huge
	for _, point in pointsA do
		local modPoint = point + offsetA
		local proj = (modPoint - fillPoint):Dot(fillAxis)
		maxProj = math.max(maxProj, proj)
		minProj = math.min(minProj, proj)
		
		-- Take the radius from the first face selected
		local toAxis = (modPoint - (fillPoint + fillAxis * proj)).Magnitude
		maxRadius = math.max(maxRadius, toAxis)
	end
	for _, point in pointsB do
		local modPoint = point + offsetB
		local proj = (modPoint - fillPoint):Dot(fillAxis)
		maxProj = math.max(maxProj, proj)
		minProj = math.min(minProj, proj)
	end
	--
	local centerPoint = fillPoint + fillAxis * (0.5 * (minProj + maxProj))
	local length = (maxProj - minProj)
	local radius = maxRadius
	--
	local cyl = Instance.new("Part")
	if isCylinder(faceA.Object) and isCylinder(faceB.Object) then
		cyl.Shape = Enum.PartType.Ball
	else
		cyl.Shape = Enum.PartType.Cylinder
	end
	cyl.TopSurface = Enum.SurfaceType.Smooth
	cyl.BottomSurface = Enum.SurfaceType.Smooth
	copyPartProps(faceB.Object, cyl)
	cyl.Size = Vector3.new(length, 2 * radius, 2 * radius)
	cyl.CFrame = CFrame.fromMatrix(centerPoint, fillAxis, getNormal(faceB))
	cyl.Parent = faceB.Object.Parent
end

-- Calculate the result
function doExtend(faceA, faceB)
	local pointsA = getFacePoints(faceA)
	local pointsB = getFacePoints(faceB)
	local localDimensionA = getDimension(faceA)
	local localDimensionB = getDimension(faceB)
	local dirA = getNormal(faceA)
	local dirB = getNormal(faceB)
	
	-- Compare the directions
	local a, b, c = dirA:Dot(dirA), dirA:Dot(dirB), dirB:Dot(dirB)
	local denom = a*c - b*b
	local isParallel = math.abs(denom) < 0.001
	
	-- Find the points to extend out to meet
	local extendPointA, extendPointB;
	if mModeOption.Mode == EXTEND_INTO or mModeOption.Mode == OUTER_TOUCH or mModeOption.Mode == BUTT_JOINT or (isParallel and mModeOption.Mode == MIDDLE_JOIN) then
		extendPointA = getPositivePointToFace(faceB, pointsA)
		extendPointB = getPositivePointToFace(faceA, pointsB)
	elseif mModeOption.Mode == EXTEND_UP_TO or mModeOption.Mode == INNER_TOUCH then
		extendPointA = getNegativePointToFace(faceB, pointsA)
		extendPointB = getNegativePointToFace(faceA, pointsB)
	elseif mModeOption.Mode == MIDDLE_JOIN then
		-- First pick a point and radius based on A
		extendPointA = getBasis(faceA)
		local fillAxis = dirA:Cross(dirB).Unit
		local radiusA = -math.huge
		for _, point in pointsA do
			local projPoint = extendPointA + fillAxis * (point - extendPointA):Dot(fillAxis)
			radiusA = math.max(radiusA, (point - projPoint).Magnitude)
		end
		
		-- Next extend out as far as possible in B but then pull back by the A radius
		local centerPointB = getBasis(faceB)
		extendPointB = getPositivePointToFace(faceA, pointsB)
		local proj = (extendPointB - centerPointB):Dot(fillAxis)
		local projPoint = centerPointB + fillAxis * proj
		local distanceToAxis = (extendPointB - projPoint).Magnitude
		local frac = radiusA / distanceToAxis
		extendPointB = extendPointB:Lerp(projPoint, frac)
	else
		assert(false, "unreachable")
	end
	
	-- Find the closest distance between the rays (extendPointA, dirA) and (extendPointB, dirB):
	-- See: http://geomalgorithms.com/a07-_distance.html#dist3D_Segment_to_Segment
	local startSep = extendPointB - extendPointA
	local d, e = dirA:Dot(startSep), dirB:Dot(startSep)

	-- Is this a degenerate case?
	if isParallel then
		-- Parts are parallel, extend faceA to faceB
		local lenA = (extendPointA - extendPointB):Dot(getNormal(faceB))
		if faceA.IsWedge then
			if lenA < 0 then
				return
			end
		else
			local extendableA = (localDimensionA * faceA.Object.Size).magnitude
			if getNormal(faceA):Dot(getNormal(faceB)) > 0 then
				lenA = -lenA
			end
			if lenA < -extendableA then
				return
			end
		end
		resizePart(faceA, lenA)
		ChangeHistoryService:SetWaypoint('ResizeAlign')
		return
	end

	-- Get the distances to extend by
	local lenA = -(b*e - c*d) / denom
	local lenB = -(a*e - b*d) / denom

	if mModeOption.Mode == EXTEND_INTO or mModeOption.Mode == EXTEND_UP_TO then
		-- We need to find a different lenA, which is the intersection of
		-- extendPointA to the plane faceB:
		-- dist to plane (point, normal) = - (ray_dir . normal) / ((ray_origin - point) . normal)
		local denom2 = dirA:Dot(dirB)
		if math.abs(denom2) > 0.0001 then
			lenA = - (extendPointA - extendPointB):Dot(dirB) / denom2
			lenB = 0
		else
			-- Perpendicular
			-- Project all points of faceB onto faceA and extend by that much
			local points = getPoints(faceB.Object)
			if mModeOption.Mode == EXTEND_UP_TO then
				local smallestLen = math.huge
				for _, v in pairs(points) do
					local dist = (v - extendPointA):Dot(getNormal(faceA))
					if dist < smallestLen then
						smallestLen = dist
					end
				end
				lenA = smallestLen
			elseif mModeOption.Mode == EXTEND_INTO then
				local largestLen = -math.huge
				for _, v in pairs(points) do
					local dist = (v - extendPointA):Dot(getNormal(faceA))
					if dist > largestLen then
						largestLen = dist
					end
				end
				lenA = largestLen
			else
				assert(false, "Unreachable")
			end
			lenB = 0
		end
	end

	-- Are both extents doable?
	-- Note: Negative amounts to extend by *are* allowed, but only
	-- up to the size of the part on the dimension being extended on.
	local extendableA = (localDimensionA * faceA.Object.Size).magnitude
	local extendableB = (localDimensionB * faceB.Object.Size).magnitude
	if lenA < -extendableA then
		return
	end
	if lenB < -extendableB then
		return
	end

	-- Both are doable, execute:
	resizePart(faceA, lenA)
	resizePart(faceB, lenB)
	
	-- Handle filling a joint
	if mModeOption.Mode == MIDDLE_JOIN then
		local fillAxis = dirA:Cross(dirB).Unit
		fillJoint(faceA, faceB, extendPointA + dirA * lenA, fillAxis, pointsA, pointsB, dirA * lenA, dirB * lenB)
	end

	-- For a butt joint, we want to resize back one of the parts by the thickness 
	-- of the other part on that axis. Renize the first part (A), such that it
	-- "butts up against" the second part (B).
	if mModeOption.Mode == BUTT_JOINT then
		-- Find the width of B on the axis A, which is the amount to resize by
		local points = getFacePoints(faceB)
		local minV =  math.huge
		local maxV = -math.huge
		for _, v in pairs(points) do
			local proj = (v - extendPointA):Dot(dirA)
			if proj < minV then minV = proj end
			if proj > maxV then maxV = proj end
		end
		resizePart(faceA, -(maxV - minV))
	end

	ChangeHistoryService:SetWaypoint('ResizeAlign')
end


function UpdateHover()
	local face = GetTarget()
	if face and not face.Object.Locked then
		ShowHoverFace(face)
	else
		HideHoverFace()
	end
end

function Selected()
	mModeScreenGui.Parent = game:GetService('CoreGui')
	mGuiContainer.Parent = game:GetService('CoreGui')
	mState = 'FaceA'
end

function Deselected()
	mModeScreenGui.Parent = nil
	mGuiContainer.Parent = nil
	mModeOption:SetSidebarActive(false)
	HideHoverFace()
	if mFaceADrawn then
		mFaceADrawn:destroy()
		mFaceADrawn = nil
	end
end

local function isCtrlHeld()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

function MouseDown()
	if draggerHandler:isEnabled() then
		-- Let the DraggerFramework handle it
		return
	end
	
	local face = GetTarget()
	if face and not face.Object.Locked then
		if mState == 'FaceA' then
			-- Set face A
			mFaceA = face
			mFaceADrawn = FaceDisplay.new(mGuiContainer, face, Color3.new(1, 0, 0), 0, 0)
			mState = 'FaceB'
		else
			-- Remove FaceA
			mFaceADrawn:destroy()
			mFaceADrawn = nil
			mState = 'FaceA'
			--
			if face.Object == mFaceA.Object then
				-- Nothing to do, same face
			else
				-- Act
				doExtend(mFaceA, face)
			end
			--
			mFaceA = nil
			HideHoverFace()
		end
	else
		if mState == 'FaceB' then
			-- Remove FaceA
			mFaceADrawn:destroy()
			mFaceADrawn = nil
			mState = 'FaceA'
			--
			mFaceA = nil
			HideHoverFace()
		end
	end
end

function MouseUp()
	if draggerHandler:isEnabled() and not isCtrlHeld() then
		draggerHandler:disable()
		mModeOption:SetSidebarActive(false)
		mouse.Icon = "" -- Disabling DraggerFramework does not reset Icon
		UpdateHover()
	end
end

function MouseMove()
	if not draggerHandler:isEnabled() then
		UpdateHover()
	end
end

function MouseIdle()
	if isCtrlHeld() then
		if not draggerHandler:isEnabled() then
			HideHoverFace()
			if mFaceADrawn then
				mFaceADrawn:destroy()
				mFaceADrawn = nil
			end
			mState = 'FaceA'
			draggerHandler:enable()
			mModeOption:SetSidebarActive(true)
		end
	else
		if draggerHandler:isEnabled() then
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				draggerHandler:disable()
				mModeOption:SetSidebarActive(false)
				mouse.Icon = "" -- Disabling DraggerFramework does not reset Icon
				UpdateHover()
			end
		else
			UpdateHover()
		end
	end
end

-- and we're finally done loading
loaded = true
--]=]