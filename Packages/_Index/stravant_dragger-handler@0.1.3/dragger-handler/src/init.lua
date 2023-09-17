local DraggerHandler = {}
DraggerHandler.__index = DraggerHandler

local Selection = game:GetService("Selection")

local Packages = script.Parent
local DraggerFramework = require(Packages.DraggerFramework)
local Roact = require(Packages.Roact)
local DraggerSchemaCore = require(Packages.DraggerSchemaCore)

local DraggerContext_PluginImpl = require(DraggerFramework.Implementation.DraggerContext_PluginImpl)
local DraggerToolComponent = require(DraggerFramework.DraggerTools.DraggerToolComponent)

function DraggerHandler.new(plugin)
	return setmetatable({
		enabled = false,
		plugin = plugin,
	}, DraggerHandler)
end

function DraggerHandler:isEnabled()
	return self.enabled
end

function DraggerHandler:enable(initialMouseDown)
	if self.enabled then
		return
	end
	self.enabled = true
	
	-- Clear the selection so we have a clean drag
	self.initialSelection = Selection:Get()
	Selection:Set({})
	
	local draggerContext = DraggerContext_PluginImpl.new(
		self.plugin, game, settings(), DraggerSchemaCore.Selection.new())
	
	self.handle = Roact.mount(Roact.createElement(DraggerToolComponent, {
		Mouse = self.plugin:GetMouse(),
		InitialMouseDown = initialMouseDown,
		DraggerContext = draggerContext,
		DraggerSchema = DraggerSchemaCore,
		DraggerSettings = {
			AnalyticsName = "ResizeAlign",
			AllowDragSelect = true,
			AllowFreeformDrag = true,
		},
		WasAutoSelected = false,
	}))
end

local function sameSet(a, b)
	for k, v in a do
		if b[k] ~= v then
			return false
		end
	end
	for k, v in b do
		if a[k] ~= v then
			return false
		end
	end
	return true
end

function DraggerHandler:disable()
	if not self.enabled then
		return
	end
	self.enabled = false
	Roact.unmount(self.handle)
	
	-- Put the selection back
	Selection:Set(self.initialSelection)
end

return DraggerHandler


