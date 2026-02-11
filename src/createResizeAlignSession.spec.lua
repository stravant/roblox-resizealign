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
end
