#include <amxmodx>
#include <amxmisc>
#include <json>

#define PLUGIN  "AMX JSON Settings API"
#define VERSION "1.3"
#define AUTHOR  "Wilian M."

new dir[128], file_path[256], path_file_name[128], section[128], key[128], sec_key[128]

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
	register_native("json_setting_get_bool", "_setting_get_bool")
	register_native("json_setting_set_bool", "_setting_set_bool")
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

JSON:_load_settings_object(const file_name_path[], file_path_output[], len, bool:create_if_missing = false)
{
	formatex(file_path_output, len, "%s/%s", dir, file_name_path)

	if(!file_exists(file_path_output))
	{
		if(!create_if_missing)
			return Invalid_JSON

		_create_dirs(file_name_path)
		return json_init_object()
	}

	new JSON:object = json_parse(file_path_output, true)

	if(object == Invalid_JSON && create_if_missing)
	{
		_create_dirs(file_name_path)
		object = json_init_object()
	}

	return object
}

bool:_should_update_setting(JSON:object, const setting_key[], JSONType:json_type, bool:replace)
{
	new bool:exists = json_object_has_value(object, setting_key, json_type, true)

	return (!exists || replace)
}

public bool:_setting_remove_section(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path))
	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))

	if(!json_object_has_value(object, section, JSONError, false))
	{
		json_free(object)
		return false
	}

	json_object_remove(object, section, false)
	json_serial_to_file(object, file_path, true)
	json_free(object)

	return true
}

public bool:_setting_remove_key(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path))
	if(object == Invalid_JSON)
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
	json_serial_to_file(object, file_path, true)
	json_free(object)

	return true
}

public bool:_setting_get_int(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_check_type }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path))
	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONNumber : JSONError

	if(!json_object_has_value(object, sec_key, json_type, true))
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
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace, arg_check_type }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path), true)
	if(object == Invalid_JSON)
		return false

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONNumber : JSONError

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new value = get_param(arg_value)
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new bool:updated = _should_update_setting(object, sec_key, json_type, replace)
	if(updated)
	{
		json_object_set_number(object, sec_key, value, true)
		json_serial_to_file(object, file_path, true)
	}

	json_free(object)

	return updated
}

public bool:_setting_get_bool(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_check_type }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path))
	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONBoolean : JSONError

	if(!json_object_has_value(object, sec_key, json_type, true))
	{
		json_free(object)
		return false
	}

	set_param_byref(arg_value, json_object_get_bool(object, sec_key, true))
	json_free(object)

	return true
}

public bool:_setting_set_bool(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace, arg_check_type }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path), true)
	if(object == Invalid_JSON)
		return false

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONBoolean : JSONError

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new bool:value = bool:get_param(arg_value)
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new bool:updated = _should_update_setting(object, sec_key, json_type, replace)
	if(updated)
	{
		json_object_set_bool(object, sec_key, value, true)
		json_serial_to_file(object, file_path, true)
	}

	json_free(object)

	return updated
}

public bool:_setting_get_float(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_check_type}

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path))
	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONNumber : JSONError
	
	if(!json_object_has_value(object, sec_key, json_type, true))
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
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace, arg_check_type }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path), true)
	if(object == Invalid_JSON)
		return false

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONNumber : JSONError

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new Float:value = get_param_f(arg_value)
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new bool:updated = _should_update_setting(object, sec_key, json_type, replace)
	if(updated)
	{
		json_object_set_real(object, sec_key, value, true)
		json_serial_to_file(object, file_path, true)
	}

	json_free(object)

	return updated
}

public bool:_setting_get_string(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_len, arg_check_type }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path))
	if(object == Invalid_JSON)
		return false

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONString : JSONError

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	if(!json_object_has_value(object, sec_key, json_type, true))
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
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace, arg_check_type }

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path), true)
	if(object == Invalid_JSON)
		return false

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONString : JSONError

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new str_value[128]; get_string(arg_value, str_value, charsmax(str_value))

	new bool:updated = _should_update_setting(object, sec_key, json_type, replace)
	if(updated)
	{
		json_object_set_string(object, sec_key, str_value, true)
		json_serial_to_file(object, file_path, true)
	}

	json_free(object)

	return updated
}

public bool:_setting_get_int_arr(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_check_type }

	new Array:array_handle = Array:get_param(arg_value)
	if(array_handle == Invalid_Array)
		return false

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path))
	if(object == Invalid_JSON)
		return false

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONArray : JSONError

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	if(!json_object_has_value(object, sec_key, json_type, true))
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

	for(new i = 0; i < countObjArray; i++)
		ArrayPushCell(array_handle, json_array_get_number(objArray, i))

	json_free(objArray)
	json_free(object)

	return true
}

public bool:_setting_set_int_arr(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace, arg_check_type }

	new Array:value = Array:get_param(arg_value)
	if(value == Invalid_Array)
		return false

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path), true)
	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONArray : JSONError
	new bool:updated = _should_update_setting(object, sec_key, json_type, replace)

	if(!updated)
	{
		json_free(object)
		return false
	}

	new countArr = ArraySize(value)
	new JSON:newArray = json_init_array()
	if(newArray == Invalid_JSON)
	{
		json_free(object)
		return false
	}

	for(new i = 0; i < countArr; i++)
		json_array_append_number(newArray, ArrayGetCell(value, i))

	json_object_set_value(object, sec_key, newArray, true)
	json_serial_to_file(object, file_path, true)

	json_free(newArray)
	json_free(object)

	return updated
}

public bool:_setting_get_string_arr(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_check_type }

	new Array:array_handle = Array:get_param(arg_value)
	if(array_handle == Invalid_Array)
		return false

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path))
	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONArray : JSONError

	if(!json_object_has_value(object, sec_key, json_type, true))
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
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace, arg_check_type }

	new Array:value = Array:get_param(arg_value)
	if(value == Invalid_Array)
		return false

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path), true)
	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONArray : JSONError
	new bool:updated = _should_update_setting(object, sec_key, json_type, replace)

	if(!updated)
	{
		json_free(object)
		return false
	}

	new countArr = ArraySize(value)
	new JSON:newArray = json_init_array()
	if(newArray == Invalid_JSON)
	{
		json_free(object)
		return false
	}

	static str_value[128]

	for(new i = 0; i < countArr; i++)
	{
		ArrayGetString(value, i, str_value, charsmax(str_value))
		json_array_append_string(newArray, str_value)
	}

	json_object_set_value(object, sec_key, newArray, true)
	json_serial_to_file(object, file_path, true)

	json_free(newArray)
	json_free(object)

	return updated
}

public bool:_setting_get_float_arr(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_check_type }

	new Array:array_handle = Array:get_param(arg_value)
	if(array_handle == Invalid_Array)
		return false

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path))
	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONArray : JSONError

	if(!json_object_has_value(object, sec_key, json_type, true))
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

	for(new i = 0; i < countObjArray; i++)
		ArrayPushCell(array_handle, json_array_get_real(objArray, i))

	json_free(objArray)
	json_free(object)

	return true
}

public bool:_setting_set_float_arr(plugin_id, param_nums)
{
	enum { arg_file_name_path = 1, arg_section, arg_key, arg_value, arg_replace, arg_check_type }

	new Array:value = Array:get_param(arg_value)
	if(value == Invalid_Array)
		return false

	get_string(arg_file_name_path, path_file_name, charsmax(path_file_name))

	new JSON:object = _load_settings_object(path_file_name, file_path, charsmax(file_path), true)
	if(object == Invalid_JSON)
		return false

	get_string(arg_section, section, charsmax(section))
	get_string(arg_key, key, charsmax(key))
	new bool:replace = bool:get_param(arg_replace)
	formatex(sec_key, charsmax(sec_key), "%s.%s", section, key)

	new JSONType:json_type = bool:get_param(arg_check_type) ? JSONArray : JSONError
	new bool:updated = _should_update_setting(object, sec_key, json_type, replace)

	if(!updated)
	{
		json_free(object)
		return false
	}

	new countArr = ArraySize(value)
	new JSON:newArray = json_init_array()
	if(newArray == Invalid_JSON)
	{
		json_free(object)
		return false
	}

	for(new i = 0; i < countArr; i++)
		json_array_append_real(newArray, ArrayGetCell(value, i))

	json_object_set_value(object, sec_key, newArray, true)
	json_serial_to_file(object, file_path, true)

	json_free(newArray)
	json_free(object)

	return updated
}

_create_dirs(const original_path[])
{
	new full_path[256], partial_path[128]
	copy(partial_path, charsmax(partial_path), original_path)

	for(new i = 0; partial_path[i] != EOS; i++)
	{
		if(partial_path[i] != '/')
			continue

		partial_path[i] = EOS
		formatex(full_path, charsmax(full_path), "%s/%s", dir, partial_path)

		if(!dir_exists(full_path))
			mkdir(full_path)

		partial_path[i] = '/'
	}
}
