local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local createResizeAlignSession = require(script.Parent.createResizeAlignSession)

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

local function makeFace(part: BasePart, normal: Enum.NormalId)
	return {
		Object = part,
		Normal = normal,
		IsWedge = false,
	}
end

return function(t: TestContext)
	t.test("starts in FaceA state", function()
		local session = createResizeAlignSession(t.plugin, makeTestSettings())
		t.expect(session.GetFaceState()).toBe("FaceA")
		session.Destroy()
	end)

	t.test("TestSelectFace transitions to FaceB", function()
		local session = createResizeAlignSession(t.plugin, makeTestSettings())

		local part = Instance.new("Part")
		part.Parent = workspace
		local face = makeFace(part, Enum.NormalId.Top)

		session.TestSelectFace(face)
		t.expect(session.GetFaceState()).toBe("FaceB")

		session.Destroy()
		part:Destroy()
	end)

	t.test("GetSelectedFace returns face data in FaceB state", function()
		local session = createResizeAlignSession(t.plugin, makeTestSettings())

		local part = Instance.new("Part")
		part.Parent = workspace
		local face = makeFace(part, Enum.NormalId.Top)

		session.TestSelectFace(face)
		local selected = session.GetSelectedFace()
		t.expect(selected ~= nil).toBe(true)
		t.expect(selected.Object).toBe(part)
		t.expect(selected.Normal).toBe(Enum.NormalId.Top)

		session.Destroy()
		part:Destroy()
	end)

	t.test("TestResetFace goes back to FaceA", function()
		local session = createResizeAlignSession(t.plugin, makeTestSettings())

		local part = Instance.new("Part")
		part.Parent = workspace
		local face = makeFace(part, Enum.NormalId.Top)

		session.TestSelectFace(face)
		t.expect(session.GetFaceState()).toBe("FaceB")

		session.TestResetFace()
		t.expect(session.GetFaceState()).toBe("FaceA")
		t.expect(session.GetSelectedFace() == nil).toBe(true)

		session.Destroy()
		part:Destroy()
	end)

	t.test("ChangeSignal fires on transitions", function()
		local session = createResizeAlignSession(t.plugin, makeTestSettings())

		local fireCount = 0
		session.ChangeSignal:Connect(function()
			fireCount += 1
		end)

		local part = Instance.new("Part")
		part.Parent = workspace
		local face = makeFace(part, Enum.NormalId.Top)

		session.TestSelectFace(face)
		t.expect(fireCount).toBe(1)

		session.TestResetFace()
		t.expect(fireCount).toBe(2)

		session.Destroy()
		part:Destroy()
	end)

	t.test("Destroy completes without error", function()
		local session = createResizeAlignSession(t.plugin, makeTestSettings())
		session.Destroy()
		t.expect(true).toBe(true)
	end)

	t.test("GetHoverFace returns nil initially", function()
		local session = createResizeAlignSession(t.plugin, makeTestSettings())
		t.expect(session.GetHoverFace() == nil).toBe(true)
		session.Destroy()
	end)

	t.test("Selecting two faces on different parts completes and resets to FaceA", function()
		local session = createResizeAlignSession(t.plugin, makeTestSettings())

		local partA = Instance.new("Part")
		partA.Size = Vector3.new(4, 4, 4)
		partA.CFrame = CFrame.new(-5, 0, 0)
		partA.Parent = workspace

		local partB = Instance.new("Part")
		partB.Size = Vector3.new(4, 4, 4)
		partB.CFrame = CFrame.new(5, 0, 0)
		partB.Parent = workspace

		session.TestSelectFace(makeFace(partA, Enum.NormalId.Right))
		t.expect(session.GetFaceState()).toBe("FaceB")

		session.TestSelectFace(makeFace(partB, Enum.NormalId.Left))
		-- After second face, should reset to FaceA (operation complete)
		t.expect(session.GetFaceState()).toBe("FaceA")
		t.expect(session.GetSelectedFace() == nil).toBe(true)

		session.Destroy()
		partA:Destroy()
		partB:Destroy()
	end)

	t.test("Selecting same part for both faces resets without extending", function()
		local session = createResizeAlignSession(t.plugin, makeTestSettings())

		local part = Instance.new("Part")
		part.Size = Vector3.new(4, 4, 4)
		part.CFrame = CFrame.new(0, 0, 0)
		part.Parent = workspace

		local origSize = part.Size

		session.TestSelectFace(makeFace(part, Enum.NormalId.Right))
		session.TestSelectFace(makeFace(part, Enum.NormalId.Left))

		-- Should not have resized (same object check in selectFace)
		t.expect(part.Size).toBe(origSize)
		t.expect(session.GetFaceState()).toBe("FaceA")

		session.Destroy()
		part:Destroy()
	end)

	t.test("Multiple reset calls don't error", function()
		local session = createResizeAlignSession(t.plugin, makeTestSettings())

		session.TestResetFace()
		session.TestResetFace()
		t.expect(session.GetFaceState()).toBe("FaceA")

		session.Destroy()
	end)

	t.test("ChangeSignal fires twice for full select cycle", function()
		local session = createResizeAlignSession(t.plugin, makeTestSettings())

		local fireCount = 0
		session.ChangeSignal:Connect(function()
			fireCount += 1
		end)

		local partA = Instance.new("Part")
		partA.Size = Vector3.new(4, 4, 4)
		partA.CFrame = CFrame.new(-5, 0, 0)
		partA.Parent = workspace

		local partB = Instance.new("Part")
		partB.Size = Vector3.new(4, 4, 4)
		partB.CFrame = CFrame.new(5, 0, 0)
		partB.Parent = workspace

		session.TestSelectFace(makeFace(partA, Enum.NormalId.Right))
		t.expect(fireCount).toBe(1)

		session.TestSelectFace(makeFace(partB, Enum.NormalId.Left))
		t.expect(fireCount).toBe(2)

		session.Destroy()
		partA:Destroy()
		partB:Destroy()
	end)
end
