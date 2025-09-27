#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <regex>
#include <api_json_settings>
#include <zombie_plague_next_const>

enum _:ePropClasses
{
	eClassTypes:CLASS_PROP_TYPE,
	CLASS_PROP_NAME[64],
	CLASS_PROP_CUSTOM_NAME[64],
	CLASS_PROP_INFO[64],
	CLASS_PROP_MODEL[64],
	CLASS_PROP_MODEL_VIEW[64],
	CLASS_PROP_BODY,
	CLASS_PROP_SKIN,
	Float:CLASS_PROP_HEALTH,
	Float:CLASS_PROP_ARMOR,
	Float:CLASS_PROP_SPEED,
	Float:CLASS_PROP_GRAVITY,
	Float:CLASS_PROP_KNOCKBACK,
	CLASS_PROP_CLAW_WEAPONLIST[64],
	CLASS_PROP_FIND_NAME[32],
	CLASS_PROP_NV_COLOR[9],
	CLASS_PROP_NV_COLOR_CONVERTED[3],
	bool:CLASS_PROP_HIDE_MENU,
	bool:CLASS_PROP_UPDATE_HITBOX,
	CLASS_PROP_BLOOD_COLOR,
	bool:CLASS_PROP_SILENT_FOOTSTEPS,
	CLASS_PROP_MODEL_INDEX,
	CLASS_PROP_LIMIT,
	CLASS_PROP_LEVEL
}

new Array:aDataClass, Array:aIndexClassesZombies, Array:aIndexClassesHumans

public plugin_init()
{
	register_plugin("Zombie Plague Next", "1.0", "Wilian M.")

	get_classes_index()

	// LOG
	new i, text[128]

	server_print("^n")
	server_print("Classes loaded: %d", ArraySize(aDataClass))
	
	new xDataGetClass[ePropClasses]
	for(i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)

		text[0] = EOS
		
		add(text, charsmax(text), fmt("ClassIndex: %d | ", i))
		add(text, charsmax(text), fmt("Name: %s | ", xDataGetClass[CLASS_PROP_NAME]))
		add(text, charsmax(text), fmt("Type: %s | ", (xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_ZOMBIE) ? "zombie" : "human"))
		add(text, charsmax(text), fmt("Model: %s | ", xDataGetClass[CLASS_PROP_MODEL]))
		add(text, charsmax(text), fmt("ModelView: %s | ", xDataGetClass[CLASS_PROP_MODEL_VIEW]))
		add(text, charsmax(text), fmt("BloodColor: %d | ", xDataGetClass[CLASS_PROP_BLOOD_COLOR]))

		server_print(text)
	}
}

public plugin_natives()
{
	register_library("zombie_plague_next_classes")

	register_native("zpn_class_init", "_zpn_class_init")
	register_native("zpn_class_get_prop", "_zpn_class_get_prop")
	register_native("zpn_class_set_prop", "_zpn_class_set_prop")
	register_native("zpn_class_random_class_id", "_zpn_class_random_class_id")
	register_native("zpn_class_find", "_zpn_class_find")
	register_native("zpn_class_array_size", "_zpn_class_array_size")
}

public plugin_precache()
{
	aDataClass = ArrayCreate(ePropClasses, 0)
	aIndexClassesZombies = ArrayCreate(1, 0)
	aIndexClassesHumans = ArrayCreate(1, 0)
}

public plugin_end()
{
	ArrayDestroy(aDataClass)
	ArrayDestroy(aIndexClassesZombies)
	ArrayDestroy(aIndexClassesHumans)
}

public _zpn_class_array_size(plugin_id, param_nums)
{
	return ArraySize(aDataClass)
}

public _zpn_class_init(plugin_id, param_nums)
{
	if(param_nums != 2)
		return -1

	new xDataGetClass[ePropClasses]

	get_string(1, xDataGetClass[CLASS_PROP_NAME], charsmax(xDataGetClass[CLASS_PROP_NAME]))
	xDataGetClass[CLASS_PROP_TYPE] = eClassTypes:get_param(2)

	xDataGetClass[CLASS_PROP_CUSTOM_NAME] = EOS
	xDataGetClass[CLASS_PROP_INFO] = EOS
	xDataGetClass[CLASS_PROP_MODEL] = EOS
	xDataGetClass[CLASS_PROP_MODEL_VIEW] = EOS
	xDataGetClass[CLASS_PROP_BODY] = -1
	xDataGetClass[CLASS_PROP_HEALTH] = 100.0
	xDataGetClass[CLASS_PROP_ARMOR] = 0.0
	xDataGetClass[CLASS_PROP_SPEED] = 240.0
	xDataGetClass[CLASS_PROP_GRAVITY] = 1.0
	xDataGetClass[CLASS_PROP_KNOCKBACK] = 1.0
	xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST] = EOS
	xDataGetClass[CLASS_PROP_FIND_NAME] = EOS
	xDataGetClass[CLASS_PROP_NV_COLOR] = EOS
	xDataGetClass[CLASS_PROP_NV_COLOR_CONVERTED] = { 255, 255, 255 }
	xDataGetClass[CLASS_PROP_HIDE_MENU] = false
	xDataGetClass[CLASS_PROP_UPDATE_HITBOX] = false
	xDataGetClass[CLASS_PROP_BLOOD_COLOR] = -1
	xDataGetClass[CLASS_PROP_LIMIT] = 0
	xDataGetClass[CLASS_PROP_LEVEL] = 0
	xDataGetClass[CLASS_PROP_MODEL_INDEX] = -1

	return ArrayPushArray(aDataClass, xDataGetClass)
}

public any:_zpn_class_get_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataClass))
		return false

	enum { arg_class_id = 1, arg_prop, arg_value, arg_len }

	new class_id = get_param(arg_class_id)
	new prop = get_param(arg_prop)

	new xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	switch(ePropClassRegisters:prop)
	{
		case CLASS_PROP_REGISTER_TYPE: return xDataGetClass[CLASS_PROP_TYPE]
		case CLASS_PROP_REGISTER_NAME: set_string(arg_value, xDataGetClass[CLASS_PROP_NAME], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_INFO: set_string(arg_value, xDataGetClass[CLASS_PROP_INFO], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_MODEL: set_string(arg_value, xDataGetClass[CLASS_PROP_MODEL], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_MODEL_VIEW: set_string(arg_value, xDataGetClass[CLASS_PROP_MODEL_VIEW], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_BODY: return xDataGetClass[CLASS_PROP_BODY]
		case CLASS_PROP_REGISTER_HEALTH: return xDataGetClass[CLASS_PROP_HEALTH]
		case CLASS_PROP_REGISTER_ARMOR: return xDataGetClass[CLASS_PROP_ARMOR]
		case CLASS_PROP_REGISTER_SPEED: return xDataGetClass[CLASS_PROP_SPEED]
		case CLASS_PROP_REGISTER_GRAVITY: return xDataGetClass[CLASS_PROP_GRAVITY]
		case CLASS_PROP_REGISTER_KNOCKBACK: return xDataGetClass[CLASS_PROP_KNOCKBACK]
		case CLASS_PROP_REGISTER_CLAW_WEAPONLIST: set_string(arg_value, xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_SKIN: return xDataGetClass[CLASS_PROP_SKIN]
		case CLASS_PROP_REGISTER_FIND_NAME: set_string(arg_value, xDataGetClass[CLASS_PROP_FIND_NAME], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_NV_COLOR: set_string(arg_value, xDataGetClass[CLASS_PROP_NV_COLOR], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_NV_COLOR_CONVERTED: set_array(arg_value, xDataGetClass[CLASS_PROP_NV_COLOR_CONVERTED], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_HIDE_MENU: return bool:xDataGetClass[CLASS_PROP_HIDE_MENU]
		case CLASS_PROP_REGISTER_UPDATE_HITBOX: return bool:xDataGetClass[CLASS_PROP_UPDATE_HITBOX]
		case CLASS_PROP_REGISTER_BLOOD_COLOR: return xDataGetClass[CLASS_PROP_BLOOD_COLOR]
		case CLASS_PROP_REGISTER_SILENT_FOOTSTEPS: return bool:xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS]
		case CLASS_PROP_REGISTER_MODEL_INDEX: return xDataGetClass[CLASS_PROP_MODEL_INDEX]
		case CLASS_PROP_REGISTER_LIMIT: return xDataGetClass[CLASS_PROP_LIMIT]
		case CLASS_PROP_REGISTER_LEVEL: return xDataGetClass[CLASS_PROP_LEVEL]
		default: return false
	}

	return true
}

public any:_zpn_class_set_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataClass))
		return false

	enum { arg_class_id = 1, arg_prop, arg_value }

	new class_id = get_param(arg_class_id)
	new prop = get_param(arg_prop)

	new xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	new class_section[64]; class_section[0] = EOS
	new class_section_final[64]; class_section_final[0] = EOS

	copy(xDataGetClass[CLASS_PROP_CUSTOM_NAME], charsmax(xDataGetClass[CLASS_PROP_CUSTOM_NAME]), xDataGetClass[CLASS_PROP_NAME])
	create_slug(xDataGetClass[CLASS_PROP_NAME], class_section, charsmax(class_section))
	formatex(class_section_final, charsmax(class_section_final), "%s.%s", get_section_class(xDataGetClass[CLASS_PROP_TYPE]), class_section)

	if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "name", xDataGetClass[CLASS_PROP_CUSTOM_NAME], charsmax(xDataGetClass[CLASS_PROP_CUSTOM_NAME])))
		json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "name", xDataGetClass[CLASS_PROP_CUSTOM_NAME])

	switch(ePropClassRegisters:prop)
	{
		case CLASS_PROP_REGISTER_INFO:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_INFO], charsmax(xDataGetClass[CLASS_PROP_INFO]))

			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "description", xDataGetClass[CLASS_PROP_INFO], charsmax(xDataGetClass[CLASS_PROP_INFO])))
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "description", xDataGetClass[CLASS_PROP_INFO])
		}
		case CLASS_PROP_REGISTER_MODEL:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_MODEL], charsmax(xDataGetClass[CLASS_PROP_MODEL]))

			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "model", xDataGetClass[CLASS_PROP_MODEL], charsmax(xDataGetClass[CLASS_PROP_MODEL])))
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "model", xDataGetClass[CLASS_PROP_MODEL])

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_MODEL]))
				xDataGetClass[CLASS_PROP_MODEL_INDEX] = precache_player_model(xDataGetClass[CLASS_PROP_MODEL])
		}
		case CLASS_PROP_REGISTER_MODEL_VIEW:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_MODEL_VIEW], charsmax(xDataGetClass[CLASS_PROP_MODEL_VIEW]))

			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "model_view", xDataGetClass[CLASS_PROP_MODEL_VIEW], charsmax(xDataGetClass[CLASS_PROP_MODEL_VIEW])))
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "model_view", xDataGetClass[CLASS_PROP_MODEL_VIEW])

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_MODEL_VIEW]))
				precache_model(xDataGetClass[CLASS_PROP_MODEL_VIEW])
		}
		case CLASS_PROP_REGISTER_BODY:
		{
			xDataGetClass[CLASS_PROP_BODY] = get_param_byref(arg_value)

			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "body", xDataGetClass[CLASS_PROP_BODY], false))
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "body", xDataGetClass[CLASS_PROP_BODY], false)
		}
		case CLASS_PROP_REGISTER_SKIN:
		{
			xDataGetClass[CLASS_PROP_SKIN] = get_param_byref(arg_value)

			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "skin", xDataGetClass[CLASS_PROP_SKIN], false))
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "skin", xDataGetClass[CLASS_PROP_SKIN], false)
		}
		case CLASS_PROP_REGISTER_HEALTH:
		{
			xDataGetClass[CLASS_PROP_HEALTH] = get_float_byref(arg_value)
	
			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "health", xDataGetClass[CLASS_PROP_HEALTH]))
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "health", xDataGetClass[CLASS_PROP_HEALTH])
		}
		case CLASS_PROP_REGISTER_SPEED:
		{
			xDataGetClass[CLASS_PROP_SPEED] = get_float_byref(arg_value)

			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "speed", xDataGetClass[CLASS_PROP_SPEED]))
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "speed", xDataGetClass[CLASS_PROP_SPEED])
		}
		case CLASS_PROP_REGISTER_ARMOR:
		{
			xDataGetClass[CLASS_PROP_ARMOR] = get_float_byref(arg_value)

			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "armor", xDataGetClass[CLASS_PROP_ARMOR]))
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "armor", xDataGetClass[CLASS_PROP_ARMOR])
		}
		case CLASS_PROP_REGISTER_GRAVITY:
		{
			xDataGetClass[CLASS_PROP_GRAVITY] = get_float_byref(arg_value)

			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "gravity", xDataGetClass[CLASS_PROP_GRAVITY]))
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "gravity", xDataGetClass[CLASS_PROP_GRAVITY])
		}
		case CLASS_PROP_REGISTER_KNOCKBACK:
		{
			xDataGetClass[CLASS_PROP_KNOCKBACK] = get_float_byref(arg_value)

			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "knockback", xDataGetClass[CLASS_PROP_KNOCKBACK]))
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "knockback", xDataGetClass[CLASS_PROP_KNOCKBACK])
		}
		case CLASS_PROP_REGISTER_CLAW_WEAPONLIST:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST], charsmax(xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST]))

			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "claw_weapon_list", xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST], charsmax(xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST])))
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "claw_weapon_list", xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST])
		}
		case CLASS_PROP_REGISTER_FIND_NAME:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_FIND_NAME], charsmax(xDataGetClass[CLASS_PROP_FIND_NAME]))

			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "find_name", xDataGetClass[CLASS_PROP_FIND_NAME], charsmax(xDataGetClass[CLASS_PROP_FIND_NAME])))
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "find_name", xDataGetClass[CLASS_PROP_FIND_NAME])
		}
		case CLASS_PROP_REGISTER_NV_COLOR:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_NV_COLOR], charsmax(xDataGetClass[CLASS_PROP_NV_COLOR]))

			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "nv_color", xDataGetClass[CLASS_PROP_NV_COLOR], charsmax(xDataGetClass[CLASS_PROP_NV_COLOR])))
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "nv_color", xDataGetClass[CLASS_PROP_NV_COLOR])

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_NV_COLOR]))
			{
				if(!parse_hex_color(xDataGetClass[CLASS_PROP_NV_COLOR], xDataGetClass[CLASS_PROP_NV_COLOR_CONVERTED]))
				{
					server_print("^n")
					server_print("Falha ao converter HEX COLOR: %s - %s", xDataGetClass[CLASS_PROP_CUSTOM_NAME], xDataGetClass[CLASS_PROP_NV_COLOR])
					server_print("^n")
				}
			}
		}
		case CLASS_PROP_REGISTER_HIDE_MENU:
		{
			xDataGetClass[CLASS_PROP_HIDE_MENU] = bool:get_param_byref(arg_value)

			if(!json_setting_get_bool(PATH_SETTINGS_CLASSES, class_section_final, "hide_class_in_menu", xDataGetClass[CLASS_PROP_HIDE_MENU]))
				json_setting_set_bool(PATH_SETTINGS_CLASSES, class_section_final, "hide_class_in_menu", xDataGetClass[CLASS_PROP_HIDE_MENU])
		}
		case CLASS_PROP_REGISTER_UPDATE_HITBOX:
		{
			xDataGetClass[CLASS_PROP_UPDATE_HITBOX] = bool:get_param_byref(arg_value)

			if(!json_setting_get_bool(PATH_SETTINGS_CLASSES, class_section_final, "update_hitbox", xDataGetClass[CLASS_PROP_UPDATE_HITBOX]))
				json_setting_set_bool(PATH_SETTINGS_CLASSES, class_section_final, "update_hitbox", xDataGetClass[CLASS_PROP_UPDATE_HITBOX])
		}
		case CLASS_PROP_REGISTER_BLOOD_COLOR:
		{
			xDataGetClass[CLASS_PROP_BLOOD_COLOR] = get_param_byref(arg_value)

			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "blood_color", xDataGetClass[CLASS_PROP_BLOOD_COLOR], false))
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "blood_color", xDataGetClass[CLASS_PROP_BLOOD_COLOR], false)
		}
		case CLASS_PROP_REGISTER_SILENT_FOOTSTEPS:
		{
			xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS] = bool:get_param_byref(arg_value)

			if(!json_setting_get_bool(PATH_SETTINGS_CLASSES, class_section_final, "silent_footsteps", xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS]))
				json_setting_set_bool(PATH_SETTINGS_CLASSES, class_section_final, "silent_footsteps", xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS])
		}
		case CLASS_PROP_REGISTER_LIMIT:
		{
			xDataGetClass[CLASS_PROP_LIMIT] = clamp(get_param_byref(arg_value), 0, MAX_LEVEL)

			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "limit", xDataGetClass[CLASS_PROP_LIMIT], false))
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "limit", xDataGetClass[CLASS_PROP_LIMIT], false)
		}
		case CLASS_PROP_REGISTER_LEVEL:
		{
			xDataGetClass[CLASS_PROP_LEVEL] = clamp(get_param_byref(arg_value), 0, MAX_LEVEL)

			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "level", xDataGetClass[CLASS_PROP_LEVEL], false))
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "level", xDataGetClass[CLASS_PROP_LEVEL], false)
		}
		default: return false
	}

	ArraySetArray(aDataClass, class_id, xDataGetClass)

	return true
}

public _zpn_class_random_class_id(plugin_id, param_nums)
{
	if(param_nums != 1)
		return 0

	new eClassTypes:type = eClassTypes:get_param(1)
	new random_index

	switch(type)
	{
		case CLASS_TEAM_TYPE_ZOMBIE: random_index = ArrayGetCell(aIndexClassesZombies, random_num(0, ArraySize(aIndexClassesZombies) -1))
		case CLASS_TEAM_TYPE_HUMAN: random_index = ArrayGetCell(aIndexClassesHumans, random_num(0, ArraySize(aIndexClassesHumans) -1))
		default: random_index =  ArrayGetCell(aIndexClassesZombies, 0)
	}

	return random_index
}

public _zpn_class_find(plugin_id, param_nums)
{
	if(param_nums != 1)
		return -1

	static findName[32]; findName[0] = EOS;
	get_string(1, findName, charsmax(findName))

	new find = -1
	new xDataGetClass[ePropClasses]

	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)
		
		if(zpn_is_null_string(xDataGetClass[CLASS_PROP_FIND_NAME]))
			continue

		if(equal(xDataGetClass[CLASS_PROP_FIND_NAME], findName))
			find = i

		if(find != -1)
			break
	}

	return find
}

get_section_class(eClassTypes:type)
{
	static section[64]; section[0] = EOS

	switch(type)
	{
		case CLASS_TEAM_TYPE_ZOMBIE: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_ZOMBIE)
		case CLASS_TEAM_TYPE_ZOMBIE_SPECIAL: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_ZOMBIE_SP)
		case CLASS_TEAM_TYPE_HUMAN: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_HUMAN)
		case CLASS_TEAM_TYPE_HUMAN_SPECIAL: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_HUMAN_SP)
		default:
		{
			copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_ZOMBIE)
		}
	}

	return section
}

get_classes_index()
{
	new xDataGetClass[ePropClasses]
	
	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)

		if(xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_ZOMBIE)
			ArrayPushCell(aIndexClassesZombies, i)
		else if(xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_HUMAN)
			ArrayPushCell(aIndexClassesHumans, i)
	}
}