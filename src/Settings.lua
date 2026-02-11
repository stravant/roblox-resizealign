local InitialPosition = Vector2.new(24, 24)
local kSettingsKey = "resizeAlignState"

local PluginGuiTypes = require("./PluginGui/Types")

export type ResizeMode = "OuterTouch" | "InnerTouch" | "WedgeJoin" | "RoundedJoin" | "ButtJoint" | "ExtendUpTo" | "ExtendInto"
export type SelectionThreshold = "25" | "15" | "Exact"

export type ResizeAlignSettings = PluginGuiTypes.PluginGuiSettings & {
	ResizeMode: ResizeMode,
	AcuteWedgeJoin: boolean,
	SelectionThreshold: SelectionThreshold,
	ClassicUI: boolean,
}

local function loadSettings(plugin: Plugin): ResizeAlignSettings
	local raw = plugin:GetSetting(kSettingsKey) or {}
	return {
		WindowPosition = Vector2.new(
			raw.WindowPositionX or InitialPosition.X,
			raw.WindowPositionY or InitialPosition.Y
		),
		WindowAnchor = Vector2.new(
			raw.WindowAnchorX or 0,
			raw.WindowAnchorY or 0
		),
		WindowHeightDelta = if raw.WindowHeightDelta ~= nil then raw.WindowHeightDelta else 0,
		DoneTutorial = if raw.DoneTutorial ~= nil then raw.DoneTutorial else false,
		HaveHelp = if raw.HaveHelp ~= nil then raw.HaveHelp else true,

		----

		ResizeMode = if raw.ResizeMode ~= nil then raw.ResizeMode else "OuterTouch",
		AcuteWedgeJoin = if raw.AcuteWedgeJoin ~= nil then raw.AcuteWedgeJoin else true,
		SelectionThreshold = if raw.SelectionThreshold ~= nil then raw.SelectionThreshold else "25",
		ClassicUI = if raw.ClassicUI ~= nil then raw.ClassicUI else false,
	}
end
local function saveSettings(plugin: Plugin, settings: ResizeAlignSettings)
	plugin:SetSetting(kSettingsKey, {
		WindowPositionX = settings.WindowPosition.X,
		WindowPositionY = settings.WindowPosition.Y,
		WindowAnchorX = settings.WindowAnchor.X,
		WindowAnchorY = settings.WindowAnchor.Y,
		WindowHeightDelta = settings.WindowHeightDelta,
		DoneTutorial = settings.DoneTutorial,
		HaveHelp = settings.HaveHelp,

		----

		ResizeMode = settings.ResizeMode,
		AcuteWedgeJoin = settings.AcuteWedgeJoin,
		SelectionThreshold = settings.SelectionThreshold,
		ClassicUI = settings.ClassicUI,
	})
end

return {
	Load = loadSettings,
	Save = saveSettings,
}
