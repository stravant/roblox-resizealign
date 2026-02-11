--!strict
local CoreGui = game:GetService("CoreGui")

local Packages = script.Parent.Parent.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)
local Signal = require(Packages.Signal)

local createResizeAlignSession = require("./createResizeAlignSession")
local Settings = require("./Settings")
local ResizeAlignGui = require("./ResizeAlignGui")
local PluginGuiTypes = require("./PluginGui/Types")

return function(plugin: Plugin, panel: DockWidgetPluginGui, buttonClicked: Signal.Signal<>, setButtonActive: (active: boolean) -> ())
	local session: createResizeAlignSession.ResizeAlignSession? = nil

	local active = false

	local activeSettings = Settings.Load(plugin)

	local pluginActive = false

	local reactRoot: ReactRoblox.RootType? = nil
	local reactScreenGui: LayerCollector? = nil

	local handleAction: (string) -> () = nil

	local function destroyReactRoot()
		if reactRoot then
			reactRoot:unmount()
			reactRoot = nil
		end
		if reactScreenGui then
			reactScreenGui:Destroy()
			reactScreenGui = nil
		end
	end
	local function createReactRoot()
		if panel.Enabled then
			reactRoot = ReactRoblox.createRoot(panel)
		else
			local screen = Instance.new("ScreenGui")
			screen.Name = "ResizeAlignMainGui"
			screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			screen.Parent = CoreGui
			reactScreenGui = screen
			reactRoot = ReactRoblox.createRoot(screen)
		end
	end

	local function getGuiState(): PluginGuiTypes.PluginGuiMode
		if not active then
			return "inactive"
		else
			return "active"
		end
	end

	local function getFaceState(): "FaceA" | "FaceB"
		if session then
			return session.GetFaceState()
		end
		return "FaceA"
	end

	local function updateUI()
		local needsUI = active or panel.Enabled
		if needsUI then
			if not reactRoot then
				createReactRoot()
			elseif panel.Enabled and reactScreenGui ~= nil then
				destroyReactRoot()
				createReactRoot()
			elseif not panel.Enabled and reactScreenGui == nil then
				destroyReactRoot()
				createReactRoot()
			end

			assert(reactRoot, "We just created it")
			reactRoot:render(React.createElement(ResizeAlignGui, {
				GuiState = getGuiState(),
				CurrentSettings = activeSettings,
				UpdatedSettings = function()
					if session then
						session.Update()
					end
					updateUI()
				end,
				HandleAction = handleAction,
				Panelized = panel.Enabled,
				FaceState = getFaceState(),
				HoverFace = if session then session.GetHoverFace() else nil,
				SelectedFace = if session then session.GetSelectedFace() else nil,
			}))
		elseif reactRoot then
			destroyReactRoot()
		end
	end

	local function destroySession()
		if session then
			session.Destroy()
			session = nil
		end
	end

	local function createSession()
		if not session then
			local newSession = createResizeAlignSession(plugin, activeSettings)
			newSession.ChangeSignal:Connect(updateUI)
			session = newSession
		end
	end

	local function setActive(newActive: boolean)
		if active == newActive then
			return
		end
		setButtonActive(newActive)
		active = newActive
		if newActive then
			if not pluginActive then
				plugin:Activate(true)
				pluginActive = true
			end
			createSession()
		else
			destroySession()
		end
		updateUI()
	end

	local function closeRequested()
		setActive(false)
		plugin:Deactivate()
	end

	local function doReset()
		destroySession()
		setActive(true)
	end

	function handleAction(action: string)
		if action == "cancel" then
			closeRequested()
		elseif action == "reset" then
			doReset()
		elseif action == "togglePanelized" then
			panel.Enabled = not panel.Enabled
			updateUI()
		else
			warn("ResizeAlign: Unknown action: "..action)
		end
	end

	local clickedCn = buttonClicked:Connect(function()
		if active then
			setActive(false)
		else
			doReset()
		end
	end)

	-- Initial UI show in the case where we're in Panelized mode
	updateUI()

	plugin.Deactivation:Connect(function()
		pluginActive = false
		setActive(false)
	end)

	plugin.Unloading:Connect(function()
		destroySession()
		setActive(false)
		destroyReactRoot()
		Settings.Save(plugin, activeSettings)
		clickedCn:Disconnect()
	end)
end
