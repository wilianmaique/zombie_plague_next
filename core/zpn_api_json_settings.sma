#include <amxmodx>
#include <amxmisc>
#include <json>

#define PLUGIN  "AMX JSON Settings API"
#define VERSION "1.2"
#define AUTHOR  "Wilian M."

new dir[128], path_file_name[128], section[128], key[128], sec_key[128]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar("api_json_settings", VERSION, FCVAR_SPONLY|FCVAR_PROTECTED)
}

public plugin_precache()
{
	get_configsdir(dir, charsmax(dir))
}

public plugin_natives()
{
	register_library("api_json_settings")
	register_native("json_setting_remove_section", "_setting_remove_section")
	register_native("json_setting_remove_key", "_setting_remove_key")
	register_native("json_setting_get_int", "_setting_get_int")
	register_native("json_setting_set_int", "_setting_set_int")
	register_native("json_setting_get_float", "_setting_get_float")
	register_native("json_setting_set_float", "_setting_set_float")
	register_native("json_setting_get_string", "_setting_get_string")
	register_native("json_setting_set_string", "_setting_set_string")
	register_native("json_setting_get_int_arr", "_setting_get_int_arr")
	register_native("json_setting_set_int_arr", "_setting_set_int_arr")
	register_native("json_setting_get_float_arr", "_setting_get_float_arr")
	register_native("json_setting_set_float_arr", "_setting_set_float_arr")
	register_native("json_setting_get_string_arr", "_setting_get_string_arr")
	register_native("json_setting_set_string_arr", "_setting_set_string_arr")
}

public bool:_setting_remove_section(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))

	if(!json_object_has_value(object, section, JSONError, false))
	{
		json_free(object)
		return false
	}

	json_object_remove(object, section, false)
	json_serial_to_file(object, fmt("%s/%s", dir, path_file_name), true)
	json_free(object)

	return true
}

public bool:_setting_remove_key(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)
	
	if(!json_object_has_value(object, sec_key, JSONError, true))
	{
		json_free(object)
		return false
	}

	json_object_remove(object, sec_key, true)
	json_serial_to_file(object, fmt("%s/%s", dir, path_file_name), true)
	json_free(object)

	return true
}

public bool:_setting_get_int(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	if(!json_object_has_value(object, sec_key, JSONNumber, true))
	{
		json_free(object)
		return false
	}

	set_param_byref(arg_value, json_object_get_number(object, sec_key, true))
	json_free(object)

	return true
}

public bool:_setting_set_int(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)

	if(object == Invalid_JSON)
	{
		_create_dirs(path_file_name)
		object = json_init_object()
	}

	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new value = get_param(arg_value)
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new bool:updated = false

	if(json_object_has_value(object, sec_key, JSONNumber, true) && replace)
		json_object_set_number(object, sec_key, value, true), updated = true;
	else if(!json_object_has_value(object, sec_key, JSONNumber, true))
		json_object_set_number(object, sec_key, value, true), updated = true;

	if(updated)
		json_serial_to_file(object, fmt("%s/%s", dir, path_file_name), true)

	json_free(object)

	return updated
}

public bool:_setting_get_float(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	if(!json_object_has_value(object, sec_key, JSONNumber, true))
	{
		json_free(object)
		return false
	}

	set_float_byref(arg_value, json_object_get_real(object, sec_key, true))
	json_free(object)

	return true
}

public bool:_setting_set_float(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)

	if(object == Invalid_JSON)
	{
		_create_dirs(path_file_name)
		object = json_init_object()
	}

	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new Float:value = get_param_f(arg_value)
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new bool:updated = false

	if(json_object_has_value(object, sec_key, JSONNumber, true) && replace)
		json_object_set_real(object, sec_key, value, true), updated = true;
	else if(!json_object_has_value(object, sec_key, JSONNumber, true))
		json_object_set_real(object, sec_key, value, true), updated = true;

	if(updated)
		json_serial_to_file(object, fmt("%s/%s", dir, path_file_name), true)

	json_free(object)

	return updated
}

public bool:_setting_get_string(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_len }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	if(!json_object_has_value(object, sec_key, JSONString, true))
	{
		json_free(object)
		return false
	}

	new str_value[128]; json_object_get_string(object, sec_key, str_value, charsmax(str_value), true)
	set_string(arg_value, str_value, get_param(arg_len))
	json_free(object)

	return true
}

public bool:_setting_set_string(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)

	if(object == Invalid_JSON)
	{
		_create_dirs(path_file_name)
		object = json_init_object()
	}

	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new str_value[128]; get_string(arg_value, str_value, charsmax(str_value))

	new bool:updated = false

	if(json_object_has_value(object, sec_key, JSONString, true) && replace)
		json_object_set_string(object, sec_key, str_value, true), updated = true;
	else if(!json_object_has_value(object, sec_key, JSONString, true))
		json_object_set_string(object, sec_key, str_value, true), updated = true;

	if(updated)
		json_serial_to_file(object, fmt("%s/%s", dir, path_file_name), true)

	json_free(object)

	return updated
}

public bool:_setting_get_int_arr(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	if(!json_object_has_value(object, sec_key, JSONArray, true))
	{
		json_free(object)
		return false
	}

	new JSON:objArray = json_object_get_value(object, sec_key, true)
	new countObjArray = json_array_get_count(objArray)

	if(countObjArray <= 0)
	{
		json_free(objArray)
		json_free(object)

		return false
	}

	new Array:array_handle = Array:get_param(arg_value)

	if(array_handle == Invalid_Array)
	{
		json_free(objArray)
		json_free(object)

		return false
	}

	for(new i = 0; i < countObjArray; i++)
		ArrayPushCell(array_handle, json_array_get_number(objArray, i))

	json_free(objArray)
	json_free(object)

	return true
}

public bool:_setting_set_int_arr(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)

	if(object == Invalid_JSON)
	{
		_create_dirs(path_file_name)
		object = json_init_object()
	}

	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new Array:value = Array:get_param(arg_value)
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	if(value == Invalid_Array)
	{
		json_free(object)
		return false
	}

	new countArr = ArraySize(value)
	new JSON:newArray = json_init_array()

	for(new i = 0; i < countArr; i++)
		json_array_append_number(newArray, ArrayGetCell(value, i))

	new bool:updated = false

	if(json_object_has_value(object, sec_key, JSONArray, true) && replace)
		json_object_set_value(object, sec_key, newArray, true), updated = true;
	else if(!json_object_has_value(object, sec_key, JSONArray, true))
		json_object_set_value(object, sec_key, newArray, true), updated = true;

	if(updated)
		json_serial_to_file(object, fmt("%s/%s", dir, path_file_name), true)

	json_free(newArray)
	json_free(object)

	return updated
}

public bool:_setting_get_string_arr(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	if(!json_object_has_value(object, sec_key, JSONArray, true))
	{
		json_free(object)
		return false
	}

	new JSON:objArray = json_object_get_value(object, sec_key, true)
	new countObjArray = json_array_get_count(objArray)

	if(countObjArray <= 0)
	{
		json_free(objArray)
		json_free(object)

		return false
	}

	new Array:array_handle = Array:get_param(arg_value)

	if(array_handle == Invalid_Array)
	{
		json_free(objArray)
		json_free(object)

		return false
	}

	static str_value[128]

	for(new i = 0; i < countObjArray; i++)
	{
		json_array_get_string(objArray, i, str_value, charsmax(str_value))
		ArrayPushString(array_handle, str_value)
	}

	json_free(objArray)
	json_free(object)

	return true
}

public bool:_setting_set_string_arr(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)

	if(object == Invalid_JSON)
	{
		_create_dirs(path_file_name)
		object = json_init_object()
	}

	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new Array:value = Array:get_param(arg_value)
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	if(value == Invalid_Array)
	{
		json_free(object)
		return false
	}

	new countArr = ArraySize(value)
	new JSON:newArray = json_init_array()

	static str_value[128]

	for(new i = 0; i < countArr; i++)
	{
		ArrayGetString(value, i, str_value, charsmax(str_value))
		json_array_append_string(newArray, str_value)
	}

	new bool:updated = false

	if(json_object_has_value(object, sec_key, JSONArray, true) && replace)
		json_object_set_value(object, sec_key, newArray, true), updated = true;
	else if(!json_object_has_value(object, sec_key, JSONArray, true))
		json_object_set_value(object, sec_key, newArray, true), updated = true;

	if(updated)
		json_serial_to_file(object, fmt("%s/%s", dir, path_file_name), true)

	json_free(newArray)
	json_free(object)

	return updated
}

public bool:_setting_get_float_arr(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	if(!json_object_has_value(object, sec_key, JSONArray, true))
	{
		json_free(object)
		return false
	}

	new JSON:objArray = json_object_get_value(object, sec_key, true)
	new countObjArray = json_array_get_count(objArray)

	if(countObjArray <= 0)
	{
		json_free(objArray)
		json_free(object)

		return false
	}

	new Array:array_handle = Array:get_param(arg_value)

	if(array_handle == Invalid_Array)
	{
		json_free(objArray)
		json_free(object)

		return false
	}

	for(new i = 0; i < countObjArray; i++)
		ArrayPushCell(array_handle, json_array_get_real(objArray, i))

	json_free(objArray)
	json_free(object)

	return true
}

public bool:_setting_set_float_arr(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object

	if((object = json_parse(fmt("%s/%s", dir, path_file_name), true)) == Invalid_JSON)

	if(object == Invalid_JSON)
	{
		_create_dirs(path_file_name)
		object = json_init_object()
	}

	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new Array:value = Array:get_param(arg_value)
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	if(value == Invalid_Array)
	{
		json_free(object)
		return false
	}

	new countArr = ArraySize(value)
	new JSON:newArray = json_init_array()

	for(new i = 0; i < countArr; i++)
		json_array_append_real(newArray, ArrayGetCell(value, i))

	new bool:updated = false

	if(json_object_has_value(object, sec_key, JSONArray, true) && replace)
		json_object_set_value(object, sec_key, newArray, true), updated = true;
	else if(!json_object_has_value(object, sec_key, JSONArray, true))
		json_object_set_value(object, sec_key, newArray, true), updated = true;

	if(updated)
		json_serial_to_file(object, fmt("%s/%s", dir, path_file_name), true)

	json_free(newArray)
	json_free(object)

	return updated
}

_create_dirs(const original_path[])
{
	new find = 0
	new paths[128]
	new cpath_file_name[128]; copy(cpath_file_name, charsmax(cpath_file_name), original_path)

	while((find = contain(cpath_file_name, "/")) != -1)
	{
		copy(cpath_file_name, find, cpath_file_name)
		strcat(paths, fmt("%s/", cpath_file_name), charsmax(cpath_file_name))
		
		if(!dir_exists(fmt("%s/%s", dir, paths)))
			mkdir(fmt("%s/%s", dir, paths))
		
		formatex(cpath_file_name, charsmax(cpath_file_name), "%s", cpath_file_name[find + 1])
	}
}