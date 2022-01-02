OBS         = obslua

-- Script Metadata
SCRIPT_NAME = "Toggle Scene Source"
SCRIPT_AUTHOR = "BillyJBryant"
SCRIPT_AUTHOR_URL = "https://github.com/billyjbryant"
SCRIPT_VERSION = '0.0.1'
SCRIPT_SOURCE_URL = "https://github.com/billyjbryant/obs-artifacts/blob/main/scripts/lua/toggle_scene_source.lua"
SCRIPT_ISSUES_URL = "https://github.com/billyjbryant/obs-artifacts/issues"

-- Establish Default Global Variables
DEFAULT_SETTINGS = {
    scene = '',
    source = '',
    scene_item = '',
    delay = 2000,
    duration = {
        show = 5000,
        hide = 2000
    },
    repeat_ = {
        times = 0,
        reset = true,
        reset_after = 60000
    },
    start_visible = true,
    currently_visible = false
}
MY_SETTINGS = {}
OBS_SETTINGS = nil
SOURCE_LIST_VISIBLE = nil
REPEATED = 0

-- Setup the Script's Primary Functions
function script_properties()
	local props = OBS.obs_properties_create()

	local scene_list = OBS.obs_properties_add_list(props, "scene", "Scene", OBS.OBS_COMBO_TYPE_LIST, OBS.OBS_COMBO_FORMAT_STRING)
    local scenes = OBS.obs_frontend_get_scenes()
	if scenes ~= nil then
        OBS.obs_property_list_add_string(scene_list, "", nil)
		for _, scene in ipairs(scenes) do
			local name = OBS.obs_source_get_name(scene)
			OBS.obs_property_list_add_string(scene_list, name, name)
		end
	end
	OBS.source_list_release(scenes)

	local source_list = OBS.obs_properties_add_list(props, "source_list", "Sources", OBS.OBS_COMBO_TYPE_LIST, OBS.OBS_COMBO_FORMAT_STRING)
    local source_field = OBS.obs_properties_add_text(props, "source", "Source", OBS.OBS_TEXT_DEFAULT)
    local source_button = OBS.obs_properties_add_button(props, "refresh_sources", "Refresh list of Sources in Scene", function() get_sources_from_scene(props, scene_list, OBS_SETTINGS) return true end)
    OBS.obs_property_set_enabled(source_field, false)

    if MY_SETTINGS.source ~= nil and MY_SETTINGS.source ~= '' then
        show_source_list(props, false)
    else 
        show_source_list(props, true)
    end

	OBS.obs_properties_add_int(props, "delay", "Delay after Activating (ms)", 0, 3600000, 1)
	OBS.obs_properties_add_int(props, "duration_show", "Duration to Show (ms)", 1, 3600000, 1)
	OBS.obs_properties_add_int(props, "duration_hide", "Duration to Hide (ms)", 1, 3600000, 1)
	OBS.obs_properties_add_int_slider(props, "repeat_times", "Number of Times to Repeat (0 = Infinite)", 0, 100, 1)
    OBS.obs_properties_add_bool(props, "repeat_reset", "Should we reset the cycle after a certain amount of time?")
    OBS.obs_properties_add_int(props, "repeat_reset_after", "Maximum Duration Elapsed to Reset Repeat (ms)", 1, 3600000, 1)
    OBS.obs_properties_add_bool(props, "start_visible", "Should the source be visible at start?")

	OBS.obs_property_set_modified_callback(scene_list, get_sources_from_scene)
	OBS.obs_property_set_modified_callback(source_list, update_source_from_list)

	return props
end

function script_description()
    local description = [[<center><h2>]] .. SCRIPT_NAME .. [[</h2><p>Allows cycling the visibility of a source within a specific scene at pre-set intervals.</p></center><p><h3>Setup</h3><ol><li>Choose the target <em>Scene</em> from the dropdown list</li><li>Once the <em>Scene</em> has been selected, the <em>Source</em> list will populate, choose the desired <em>Source</em><ul><li>Once a <em>Source</em> has been selected, the dropdown will be replaced by a disabled text field. <br/>If you need to choose a different source, or need to update the sources list, click the <b>Refresh</b> button.</li></ul></li><li>Set the value for <i>Delay after activating</i> [Note: This is the amount of time (in milliseconds) after the scene is enabled to start the toggle]</li><li>Set the value for <i>Duration to Show</i> [This is the amount of time in milliseconds the source is visible]</li><li>Set the value for <i>Duration to Hide</i> [This is the amount of time in milliseconds the source is hidden]</li><li>Set the value for <i>Number of times to Repeat</i> [A value of 0 is infinite, Max is 100]</li><li>If using repeat settings<ol><li>Check whether or not the repeat cycle should be reset after a set amount of time elapses<br/><b>If this is unchecked, the cycle will not restart until the Scene is disabled/enabled or OBS is relaunched</b></li><li>Set the Maximum Duration to wait after the last cycle has finished to reset the repeat counter</li></ol></li><li>Check whether source should be visible when scene becomes enabled (or at OBS Launch)</li></ol></p>]]
    local metadata = [[<p><h3>Metadata</h3><table><tr><td><b>Name:</b><td>]] .. SCRIPT_NAME .. [[<tr><td><b>Version:</b></td><td>]] .. SCRIPT_VERSION .. [[</a></td></tr><tr><td><b>Author:</b></td><td><a href="]] .. SCRIPT_AUTHOR_URL .. [[" target="_blank" rel="noopener nofollow noreferrer">]] .. SCRIPT_AUTHOR .. [[</a></td></tr><tr><td><b>Source:</b></td><td><a href="]] .. SCRIPT_SOURCE_URL .. [[" target="_blank" rel="noopener nofollow noreferrer">]] .. SCRIPT_SOURCE_URL .. [[</a></td></tr></table><em>To Report Issues with this script <a href="]] .. SCRIPT_ISSUES_URL .. [[" target="_blank" rel="noopener nofollow noreferrer">Click Here</a><a</em></p>]]
	return description .. metadata
end

function script_update(settings)
    MY_SETTINGS.scene = OBS.obs_data_get_string(settings, "scene")
    MY_SETTINGS.delay = OBS.obs_data_get_int(settings, "delay")
    MY_SETTINGS.duration.show = OBS.obs_data_get_int(settings, "duration_show")
    MY_SETTINGS.duration.hide = OBS.obs_data_get_int(settings, "duration_hide")
    MY_SETTINGS.repeat_.times = OBS.obs_data_get_int(settings, "repeat_times")
    MY_SETTINGS.repeat_.reset = OBS.obs_data_get_bool(settings, "repeat_reset")
    MY_SETTINGS.repeat_.reset_after = OBS.obs_data_get_int(settings, "repeat_reset_after")
    MY_SETTINGS.start_visible = OBS.obs_data_get_bool(settings, "start_visible")

    OBS_SETTINGS = settings
	activate(true)
end

function script_defaults(settings)
	OBS.obs_data_set_default_string(settings, "source", DEFAULT_SETTINGS.source)
	OBS.obs_data_set_default_int(settings, "delay", DEFAULT_SETTINGS.delay)
	OBS.obs_data_set_default_int(settings, "duration_show", DEFAULT_SETTINGS.duration.show) 
	OBS.obs_data_set_default_int(settings, "duration_hide", DEFAULT_SETTINGS.duration.hide)
	OBS.obs_data_set_default_int(settings, "repeat_times", DEFAULT_SETTINGS.repeat_.times)
	OBS.obs_data_set_default_bool(settings, "repeat_reset", DEFAULT_SETTINGS.repeat_.reset)
	OBS.obs_data_set_default_int(settings, "repeat_reset_after", DEFAULT_SETTINGS.repeat_.reset_after)
	OBS.obs_data_set_default_bool(settings, "start_visible", DEFAULT_SETTINGS.start_visible)
	OBS_SETTINGS = settings
end

function script_save(settings)

end

function script_load(settings)
    MY_SETTINGS = DEFAULT_SETTINGS
	OBS_SETTINGS = settings
end

function script_unload()
    activate(false)
end

-- CORE FUNCTIONS [All of the functions defined to "do things" other than script management]

--[[ Updates the Sources list from the Sources in the selected Scene
    callback_method
    param *props obs_properties_t
    param *prop obs_property_t
    param *settings obs_data_t

    returns boolean
]]
function get_sources_from_scene(props, prop, settings)
    local scene_name = OBS.obs_data_get_string(settings, "scene")
    local source_list = OBS.obs_properties_get(props, "source_list")
    OBS.obs_property_list_clear(source_list)
    
    if scene_name ~= "" and scene_name ~= nil then
        local scene = get_scene_by_name(scene_name)
        local scene_items = OBS.obs_scene_enum_items(scene)
        if scene_items ~= nil then
            OBS.obs_property_list_add_string(source_list, "", nil)
            for _, scene_item in ipairs(scene_items) do
                local source = OBS.obs_sceneitem_get_source(scene_item)
                local name = OBS.obs_source_get_name(source)
                OBS.obs_property_list_add_string(source_list, name, name)
            end
            show_source_list(props, true)
        end
        OBS.sceneitem_list_release(scene_items)
    end
    return true
end

--[[ Updates the source to the selected source in the sources list
    callback_method
    param *props obs_properties_t
    param *prop obs_property_t
    param *settings obs_data_t

    returns boolean
]]
function update_source_from_list(props, prop, settings)
    local stored_source = MY_SETTINGS.source
    local source_updated_to = OBS.obs_data_get_string(settings, "source_list")
    local source_list = OBS.obs_properties_get(props, "source_list")
    if source_updated_to ~= nil and source_updated_to ~= "" then
        if (stored_source == source_updated_to) and (stored_source ~= "" and stored_source ~= nil) then
            show_source_list(props, false)
            activate(true)
            return true
        else
            local scene_name = OBS.obs_data_get_string(settings, "scene")
            local scene_item = get_sceneitem_by_name(scene_name, source_updated_to)
            OBS.obs_data_set_string(settings, "source", source_updated_to)
            show_source_list(props, false)
            MY_SETTINGS.source = source_updated_to
            MY_SETTINGS.scene_item = scene_item
            activate(true)
            return true
        end
        print("Something happened, we shouldn't be here, RUN AWAY!")
        return false
    else
        return false
    end
end

--[[ Toggles the configured source with an optional parameter to force visibility

    param *hidden bool

    returns boolean
]]
function toggle_source(hidden)
        local scene_item = get_sceneitem_by_name(MY_SETTINGS.scene, MY_SETTINGS.source)
    if scene_item ~= nil then
        local is_visible = OBS.obs_sceneitem_visible(scene_item)
        if hidden ~= nil then is_visible = not hidden end
        OBS.obs_sceneitem_set_visible(scene_item, not is_visible)
        return not is_visible
    end
    return nil
end


-- Handles the repeat cycles
function repeat_source()
    local scene_item = get_sceneitem_by_name(MY_SETTINGS.scene, MY_SETTINGS.source)
    local is_visible
    if scene_item ~= nil then
        is_visible = toggle_source()
    end

	if MY_SETTINGS.repeat_.times == 0 or REPEATED < MY_SETTINGS.repeat_.times then
        OBS.timer_remove(repeat_source)
        if is_visible then timer = MY_SETTINGS.duration.show else timer = MY_SETTINGS.duration.hide end
        OBS.timer_add(repeat_source, timer)
        REPEATED = REPEATED + 1
    else
        OBS.timer_remove(repeat_source)
        toggle_source(false)
        if MY_SETTINGS.repeat_.reset then
            OBS.timer_add(reset_repeats, MY_SETTINGS.repeat_.reset_after)
        end
    end
end

-- Resets the number of times we have repeated
function reset_repeats()
    if MY_SETTINGS.repeat_.reset then
        local REPEATED_old = REPEATED
        REPEATED = 0
        OBS.timer_remove(reset_repeats)
        repeat_source()
    end
end

-- This is the first event, sets up the repeat timer and does the first toggle
function start_timer()
    local scene_item = get_sceneitem_by_name(MY_SETTINGS.scene, MY_SETTINGS.source)
    local is_visible = MY_SETTINGS.start_visible
    local timer = nil
    if scene_item ~= nil then
        toggle_source(is_visible)
        if is_visible then timer = MY_SETTINGS.duration.show else timer = MY_SETTINGS.duration.hide end
        OBS.timer_add(repeat_source, timer)
    end
    OBS.timer_remove(start_timer)
end

-- Activates the script after a settings update, takes a boolean of true/false
function activate(activating)
    OBS.timer_remove(start_timer)
	OBS.timer_remove(repeat_source)
	OBS.timer_remove(reset_repeats)

	if activating then
        local scene_item = get_sceneitem_by_name(MY_SETTINGS.scene, MY_SETTINGS.source)
        if scene_item ~= nil then
            if MY_SETTINGS.delay ~= 0 then
                 OBS.timer_add(start_timer, MY_SETTINGS.delay)
            else
                start_timer()
            end
        else
            toggle_source(MY_SETTINGS.start_visible)
            return nil
        end
	end
end

-- HELPER FUNCTIONS [Functions which are used to supliment the Core functions]

--[[ Toggles to show the Source List, Source Field and Refresh Button

    param *props obs_properties_t
    param *visible bool

    returns boolean
]]
function show_source_list(props, visible)
    local source_list = OBS.obs_properties_get(props, "source_list")
    local source_field = OBS.obs_properties_get(props, "source")
    local source_button = OBS.obs_properties_get(props, "refresh_sources")

    if visible then
        OBS.obs_property_set_visible(source_list, true)
        OBS.obs_property_set_visible(source_field, false)
        OBS.obs_property_set_visible(source_button, false)
        return true
    else
        OBS.obs_property_set_visible(source_list, false)
        OBS.obs_property_set_visible(source_field, true)
        OBS.obs_property_set_visible(source_button, true)
        return true
    end
    return false
end

--[[ Returns obs_scene_t from given Scene Name

    param *scene_name string

    returns obs_scene_t
]]
function get_scene_by_name(scene_name)
    local scene_source = OBS.obs_get_source_by_name(scene_name)
    local scene_context = OBS.obs_scene_from_source(scene_source)
    OBS.obs_source_release(scene_source)
    return scene_context
end

--[[ Returns obs_sceneitem_t from given Scene Name & Source Name

    param *scene_name string
    param *source_name string

    returns obs_sceneitem_t
]]
function get_sceneitem_by_name(scene_name, source_name)
    local scene = get_scene_by_name(scene_name)
    local source = OBS.obs_get_source_by_name(source_name)
    local scene_item = OBS.obs_scene_sceneitem_from_source(scene, source)
    OBS.obs_source_release(source)
    return scene_item
end

-- Dumps Input to String, if input is a table it returns the expanded table
function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
                if type(k) ~= 'number' then k = '"'..k..'"' end
                s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end