dofile("data/scripts/lib/mod_settings.lua") -- see this file for documentation on some of the features.
local defaults = dofile_once("mods/LocationTracker/settings_defaults.lua")
local mod_id = "LocationTracker"
mod_settings_version = 1

-- This function is called to ensure the correct setting values are visible to the game via ModSettingGet(). your mod's settings don't work if you don't have a function like this defined in settings.lua.
-- This function is called:
--		- when entering the mod settings menu (init_scope will be MOD_SETTINGS_SCOPE_ONLY_SET_DEFAULT)
-- 		- before mod initialization when starting a new game (init_scope will be MOD_SETTING_SCOPE_NEW_GAME)
--		- when entering the game after a restart (init_scope will be MOD_SETTING_SCOPE_RESTART)
--		- at the end of an update when mod settings have been changed via ModSettingsSetNextValue() and the game is unpaused (init_scope will be MOD_SETTINGS_SCOPE_RUNTIME)
function ModSettingsUpdate( init_scope )
	-- local old_version = mod_settings_get_version( mod_id ) -- This can be used to migrate some settings between mod versions.
	-- mod_settings_update( mod_id, mod_settings, init_scope )
end

function ModSettingsGuiCount()
	return 1
end

-- This function is called to display the settings UI for this mod. Your mod's settings wont be visible in the mod settings menu if this function isn't defined correctly.
function ModSettingsGui( gui, in_main_menu )
	if GuiButton(gui, 1, 0, 0, "Reset minimap position and size") then
		local screen_width, screen_height = GuiGetScreenDimensions(EZMouse_gui)
		for setting, default in pairs(defaults) do
			ModSettingRemove(mod_id .. "_" .. setting)
		end
		ModSettingSet(mod_id .. "_was_reset", true)
	end
end
