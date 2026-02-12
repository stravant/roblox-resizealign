local UserInputService = game:GetService("UserInputService")

local Src = script.Parent
local Packages = Src.Parent.Packages

local Signal = require(Packages.Signal)
local DraggerHandler = require(Packages.DraggerHandler)

local doExtend = require(Src.doExtend)
local Settings = require(Src.Settings)

type Face = doExtend.Face

export type ResizeAlignSession = {
	ChangeSignal: Signal.Signal<>,
	GetFaceState: () -> "FaceA" | "FaceB",
	GetHoverFace: () -> Face?,
	GetSelectedFace: () -> Face?,
	Update: () -> (),
	Destroy: () -> (),
	TestSelectFace: (face: Face) -> (),
	TestResetFace: () -> (),
}

local function otherNormalIds(normalId: Enum.NormalId)
	if normalId == Enum.NormalId.Top or normalId == Enum.NormalId.Bottom then
		return Enum.NormalId.Right, Enum.NormalId.Left, Enum.NormalId.Back, Enum.NormalId.Front
	elseif normalId == Enum.NormalId.Right or normalId == Enum.NormalId.Left then
		return Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Back, Enum.NormalId.Front
	elseif normalId == Enum.NormalId.Front or normalId == Enum.NormalId.Back then
		return Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Right, Enum.NormalId.Left
	end
	error("unreachable")
end

local function getFaceSize(part: BasePart, normalId: Enum.NormalId)
	local size = part.Size
	local vec = Vector3.fromNormalId(normalId)
	local x = (1 - math.abs(vec.X)) * size.X
	local y = (1 - math.abs(vec.Y)) * size.Y
	local z = (1 - math.abs(vec.Z)) * size.Z
	return (if x == 0 then 1 else x) * (if y == 0 then 1 else y) * (if z == 0 then 1 else z)
end

local function getFacePolygon(part: BasePart, normalId: Enum.NormalId)
	local halfSize = 0.5 * part.Size
	local cf = part.CFrame
	local basePosition = cf:PointToWorldSpace(Vector3.fromNormalId(normalId) * halfSize)
	local x, _negx, y, _negy = otherNormalIds(normalId)
	local offset_x = cf:VectorToWorldSpace(Vector3.fromNormalId(x) * halfSize)
	local offset_y = cf:VectorToWorldSpace(Vector3.fromNormalId(y) * halfSize)
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
			n = _negx,
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
			n = _negy,
		},
	}
end

local function toVec2(vec3: Vector3): Vector2
	return Vector2.new(vec3.X, vec3.Y)
end

local function edgesToScreen(edges)
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

local function intersectRayRay(r1o, r1d, r2o, r2d)
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

local function directionAndDistanceToEdge(edge, point: Vector2): (Vector2, number)
	local alongEdge = (edge.b - edge.a).Unit
	local toPoint = point - edge.a
	local pointOnEdge = edge.a + alongEdge * toPoint:Dot(alongEdge)
	local toEdge = pointOnEdge - point
	return toEdge.Unit, toEdge.Magnitude
end

local function distanceToOppositeEdge(edge, point: Vector2, direction: Vector2): number?
	local alongEdge = edge.d - edge.c
	local alongEdgeDir = alongEdge.Unit
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

local function createResizeAlignSession(plugin: Plugin, activeSettings: Settings.ResizeAlignSettings): ResizeAlignSession
	local changeSignal = Signal.new()

	local mState: "FaceA" | "FaceB" = "FaceA"
	local mFaceA: Face? = nil
	local mHoverFace: Face? = nil
	local mDestroyed = false

	local draggerHandler = DraggerHandler.new(plugin)
	local connections: {RBXScriptConnection} = {}

	local function simpleGetTarget()
		local mouseLocation = UserInputService:GetMouseLocation()
		local camera = workspace.CurrentCamera
		if not camera then
			return nil, nil, nil, false
		end
		local ray = camera:ScreenPointToRay(mouseLocation.X, mouseLocation.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local ignoreList = {}
		if mState == "FaceB" and mFaceA then
			table.insert(ignoreList, mFaceA.Object)
		end
		raycastParams.FilterDescendantsInstances = ignoreList

		local result = workspace:Raycast(ray.Origin, ray.Direction * 999, raycastParams)
		if not result then
			return nil, nil, nil, false
		end

		local hit = result.Instance
		if not hit:IsA("BasePart") then
			return nil, nil, nil, false
		end

		local at = result.Position
		local localDisp = hit.CFrame:VectorToObjectSpace(at - hit.Position)
		local halfSize = hit.Size / 2
		local smallest = math.huge
		local targetSurface = Enum.NormalId.Top

		if math.abs(localDisp.X - halfSize.X) < smallest then
			targetSurface = Enum.NormalId.Right
			smallest = math.abs(localDisp.X - halfSize.X)
		end
		if math.abs(localDisp.X + halfSize.X) < smallest then
			targetSurface = Enum.NormalId.Left
			smallest = math.abs(localDisp.X + halfSize.X)
		end
		if math.abs(localDisp.Y - halfSize.Y) < smallest then
			targetSurface = Enum.NormalId.Top
			smallest = math.abs(localDisp.Y - halfSize.Y)
		end
		if math.abs(localDisp.Y + halfSize.Y) < smallest then
			targetSurface = Enum.NormalId.Bottom
			smallest = math.abs(localDisp.Y + halfSize.Y)
		end
		if math.abs(localDisp.Z - halfSize.Z) < smallest then
			targetSurface = Enum.NormalId.Back
			smallest = math.abs(localDisp.Z - halfSize.Z)
		end
		if math.abs(localDisp.Z + halfSize.Z) < smallest then
			targetSurface = Enum.NormalId.Front
			smallest = math.abs(localDisp.Z + halfSize.Z)
		end

		local isWedgeFace = false
		local cornerWedgeSide = nil
		local isWedgeShape = hit:IsA("WedgePart") or (hit:IsA("Part") and hit.Shape == Enum.PartType.Wedge)
		local isCornerWedgeShape = hit:IsA("CornerWedgePart") or (hit:IsA("Part") and hit.Shape == Enum.PartType.CornerWedge)
		local hitNormal = result.Normal
		local cf = hit.CFrame
		if isWedgeShape then
			local slopeNormal = cf.YVector * halfSize.Z - cf.ZVector * halfSize.Y
			if slopeNormal.Magnitude > 0.001 then
				isWedgeFace = hitNormal:Dot(slopeNormal.Unit) > 0.99
			end
		elseif isCornerWedgeShape then
			local rightNormal = cf.YVector * halfSize.X - cf.XVector * halfSize.Y
			local backNormal = cf.YVector * halfSize.Z + cf.ZVector * halfSize.Y
			if rightNormal.Magnitude > 0.001 and hitNormal:Dot(rightNormal.Unit) > 0.99 then
				cornerWedgeSide = "Right"
			elseif backNormal.Magnitude > 0.001 and hitNormal:Dot(backNormal.Unit) > 0.99 then
				cornerWedgeSide = "Back"
			end
		end

		return hit, at, targetSurface, isWedgeFace, cornerWedgeSide
	end

	local function getTarget(): Face?
		local hit, _at, normalId, isWedgeFace, cornerWedgeSide = simpleGetTarget()
		if not hit then
			return nil
		end

		-- If it's a corner wedge slope, return directly (no edge threshold logic)
		if cornerWedgeSide then
			return {
				Object = hit,
				Normal = normalId,
				CornerWedgeSide = cornerWedgeSide,
			}
		end

		local threshold;
		if activeSettings.SelectionThreshold == "25" then
			threshold = 0.25
		elseif activeSettings.SelectionThreshold == "15" then
			threshold = 0.15
		elseif activeSettings.SelectionThreshold == "Exact" then
			threshold = 0
		else
			threshold = 0.25
		end

		local screenEdges = edgesToScreen(getFacePolygon(hit, normalId))
		local mouseLocation = UserInputService:GetMouseLocation()

		local smallestFrac = 1
		local smallestFracEdge = nil

		local hardCutoff = workspace.CurrentCamera.ViewportSize.Magnitude * 0.2

		for _, edge in ipairs(screenEdges) do
			local dir, distToEdge = directionAndDistanceToEdge(edge, mouseLocation)
			local distToOtherEdge = distanceToOppositeEdge(edge, mouseLocation, -dir)
			if distToOtherEdge then
				local totalDist = distToOtherEdge + distToEdge
				local frac = distToEdge / totalDist
				if frac < smallestFrac and frac < threshold and getFaceSize(hit, edge.n) < getFaceSize(hit, normalId) then
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

	local function isCtrlHeld()
		return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	end

	local function updateHover()
		local face = getTarget()
		if face and not face.Object.Locked then
			mHoverFace = face
		else
			mHoverFace = nil
		end
		changeSignal:Fire()
	end

	local function selectFace(face: Face)
		if mState == "FaceA" then
			mFaceA = face
			mState = "FaceB"
			mHoverFace = nil
			changeSignal:Fire()
		else
			local savedFaceA = mFaceA
			mFaceA = nil
			mState = "FaceA"
			mHoverFace = nil
			if savedFaceA and face.Object ~= savedFaceA.Object then
				doExtend(savedFaceA, face, activeSettings.ResizeMode, activeSettings.AcuteWedgeJoin)
			end
			changeSignal:Fire()
		end
	end

	local function resetFace()
		if mState == "FaceB" then
			mFaceA = nil
			mState = "FaceA"
			mHoverFace = nil
			changeSignal:Fire()
		end
	end

	-- Input handling
	table.insert(connections, UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if mDestroyed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if draggerHandler:isEnabled() then
				return
			end
			local face = getTarget()
			if face and not face.Object.Locked then
				selectFace(face)
			else
				resetFace()
			end
		end
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean)
		if mDestroyed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if draggerHandler:isEnabled() and not isCtrlHeld() then
				draggerHandler:disable()
				updateHover()
			end
		end
	end))

	table.insert(connections, UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
		if mDestroyed then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if not draggerHandler:isEnabled() then
				updateHover()
			end
		end
	end))

	-- Idle loop for Ctrl detection
	local idleThread = task.spawn(function()
		while not mDestroyed do
			if isCtrlHeld() then
				if not draggerHandler:isEnabled() then
					mHoverFace = nil
					if mState == "FaceB" then
						mFaceA = nil
						mState = "FaceA"
					end
					draggerHandler:enable()
					changeSignal:Fire()
				end
			else
				if draggerHandler:isEnabled() then
					if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
						draggerHandler:disable()
						updateHover()
					end
				end
			end
			task.wait()
		end
	end)

	local session: ResizeAlignSession = {
		ChangeSignal = changeSignal,
		GetFaceState = function()
			return mState
		end,
		GetHoverFace = function()
			return mHoverFace
		end,
		GetSelectedFace = function()
			return mFaceA
		end,
		Update = function()
			-- Called when settings change, nothing to do currently
		end,
		Destroy = function()
			mDestroyed = true
			for _, cn in connections do
				cn:Disconnect()
			end
			table.clear(connections)
			task.cancel(idleThread)
			draggerHandler:disable()
			mHoverFace = nil
			mFaceA = nil
		end,
		TestSelectFace = function(face: Face)
			selectFace(face)
		end,
		TestResetFace = function()
			resetFace()
		end,
	}
	return session
end

return createResizeAlignSession
