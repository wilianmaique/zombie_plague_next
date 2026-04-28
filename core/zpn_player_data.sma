#include <amxmodx>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

enum _:ePropPlayerData
{
	PD_PROP_CURRENT_SELECTED_ZOMBIE_CLASS,
	PD_PROP_CURRENT_SELECTED_HUMAN_CLASS,
	bool:PD_PROP_IS_ZOMBIE,
	bool:PD_PROP_IS_FIRST_ZOMBIE,
	PD_PROP_PRIMARY_WEAPON,
	PD_PROP_SECONDARY_WEAPON,
	Float:PD_PROP_CLASS_TIMEOUT,
	Float:PD_PROP_LAST_LEAP_TIMEOUT,
	bool:PD_PROP_IS_LAST_HUMAN,
	bool:PD_PROP_NV_ON,
	Float:PD_PROP_NV_SPAM,
	PD_PROP_AMMO_PACKS,
	Float:PD_PROP_DMG_DEALT,
	PD_PROP_NEXT_ZOMBIE_CLASS,
	PD_PROP_NEXT_HUMAN_CLASS,
	PD_PROP_CURRENT_TEMP_ZOMBIE_CLASS,
	PD_PROP_CURRENT_TEMP_HUMAN_CLASS,
	PD_PROP_LEVEL,
	bool:PD_PROP_IS_FREEZED,
}

new xPlayerData[33][ePropPlayerData]

public plugin_init()
{
	register_plugin("[ZPN] Core: Player Data", "1.0", "Wilian M.")
}

public plugin_natives()
{
	register_library("zombie_plague_next_player_data")

	register_native("zpn_player_data_get_prop", "_zpn_player_data_get_prop")
	register_native("zpn_player_data_set_prop", "_zpn_player_data_set_prop")
}

public client_putinserver(id)
{
	reset_user_vars(id)
}

public any:_zpn_player_data_get_prop(plugin_id, param_nums)
{
	enum { arg_player = 1, arg_prop }

	new player = get_param(arg_player)
	new prop = get_param(arg_prop)

	switch(ePropPlayerDataRegisters:prop)
	{
		case PROP_PD_REGISTER_CURRENT_SELECTED_ZOMBIE_CLASS: return xPlayerData[player][PD_PROP_CURRENT_SELECTED_ZOMBIE_CLASS]
		case PROP_PD_REGISTER_CURRENT_SELECTED_HUMAN_CLASS: return xPlayerData[player][PD_PROP_CURRENT_SELECTED_HUMAN_CLASS]
		case PROP_PD_REGISTER_IS_ZOMBIE: return xPlayerData[player][PD_PROP_IS_ZOMBIE]
		case PROP_PD_REGISTER_IS_FIRST_ZOMBIE: return xPlayerData[player][PD_PROP_IS_FIRST_ZOMBIE]
		case PROP_PD_REGISTER_PRIMARY_WEAPON: return xPlayerData[player][PD_PROP_PRIMARY_WEAPON]
		case PROP_PD_REGISTER_SECONDARY_WEAPON: return xPlayerData[player][PD_PROP_SECONDARY_WEAPON]
		case PROP_PD_REGISTER_CLASS_TIMEOUT: return xPlayerData[player][PD_PROP_CLASS_TIMEOUT]
		case PROP_PD_REGISTER_LAST_LEAP_TIMEOUT: return xPlayerData[player][PD_PROP_LAST_LEAP_TIMEOUT]
		case PROP_PD_REGISTER_IS_LAST_HUMAN: return xPlayerData[player][PD_PROP_IS_LAST_HUMAN]
		case PROP_PD_REGISTER_NV_ON: return xPlayerData[player][PD_PROP_NV_ON]
		case PROP_PD_REGISTER_NV_SPAM: return xPlayerData[player][PD_PROP_NV_SPAM]
		case PROP_PD_REGISTER_AMMO_PACKS: return xPlayerData[player][PD_PROP_AMMO_PACKS]
		case PROP_PD_REGISTER_DMG_DEALT: return xPlayerData[player][PD_PROP_DMG_DEALT]
		case PROP_PD_REGISTER_NEXT_ZOMBIE_CLASS: return xPlayerData[player][PD_PROP_NEXT_ZOMBIE_CLASS]
		case PROP_PD_REGISTER_NEXT_HUMAN_CLASS: return xPlayerData[player][PD_PROP_NEXT_HUMAN_CLASS]
		case PROP_PD_REGISTER_CURRENT_TEMP_ZOMBIE_CLASS: return xPlayerData[player][PD_PROP_CURRENT_TEMP_ZOMBIE_CLASS]
		case PROP_PD_REGISTER_CURRENT_TEMP_HUMAN_CLASS: return xPlayerData[player][PD_PROP_CURRENT_TEMP_HUMAN_CLASS]
		case PROP_PD_REGISTER_LEVEL: return xPlayerData[player][PD_PROP_LEVEL]
		case PROP_PD_REGISTER_IS_FREEZED: return xPlayerData[player][PD_PROP_IS_FREEZED]
	}

	return true
}

public any:_zpn_player_data_set_prop(plugin_id, param_nums)
{
	enum { arg_player = 1, arg_prop, arg_value }

	new player = get_param(arg_player)
	new prop = get_param(arg_prop)

	switch(ePropPlayerDataRegisters:prop)
	{
		case PROP_PD_REGISTER_CURRENT_SELECTED_ZOMBIE_CLASS: xPlayerData[player][PD_PROP_CURRENT_SELECTED_ZOMBIE_CLASS] = get_param_byref(arg_value)
		case PROP_PD_REGISTER_CURRENT_SELECTED_HUMAN_CLASS: xPlayerData[player][PD_PROP_CURRENT_SELECTED_HUMAN_CLASS] = get_param_byref(arg_value)
		case PROP_PD_REGISTER_IS_ZOMBIE: xPlayerData[player][PD_PROP_IS_ZOMBIE] = bool:get_param_byref(arg_value)
		case PROP_PD_REGISTER_IS_FIRST_ZOMBIE: xPlayerData[player][PD_PROP_IS_FIRST_ZOMBIE] = bool:get_param_byref(arg_value)
		case PROP_PD_REGISTER_PRIMARY_WEAPON: xPlayerData[player][PD_PROP_PRIMARY_WEAPON] = get_param_byref(arg_value)
		case PROP_PD_REGISTER_SECONDARY_WEAPON: xPlayerData[player][PD_PROP_SECONDARY_WEAPON] = get_param_byref(arg_value)
		case PROP_PD_REGISTER_CLASS_TIMEOUT: xPlayerData[player][PD_PROP_CLASS_TIMEOUT] = get_float_byref(arg_value)
		case PROP_PD_REGISTER_LAST_LEAP_TIMEOUT: xPlayerData[player][PD_PROP_LAST_LEAP_TIMEOUT] = get_float_byref(arg_value)
		case PROP_PD_REGISTER_IS_LAST_HUMAN: xPlayerData[player][PD_PROP_IS_LAST_HUMAN] = bool:get_param_byref(arg_value)
		case PROP_PD_REGISTER_NV_ON: xPlayerData[player][PD_PROP_NV_ON] = bool:get_param_byref(arg_value)
		case PROP_PD_REGISTER_NV_SPAM: xPlayerData[player][PD_PROP_NV_SPAM] = get_float_byref(arg_value)
		case PROP_PD_REGISTER_AMMO_PACKS: xPlayerData[player][PD_PROP_AMMO_PACKS] = get_param_byref(arg_value)
		case PROP_PD_REGISTER_DMG_DEALT: xPlayerData[player][PD_PROP_DMG_DEALT] = get_float_byref(arg_value)
		case PROP_PD_REGISTER_NEXT_ZOMBIE_CLASS: xPlayerData[player][PD_PROP_NEXT_ZOMBIE_CLASS] = get_param_byref(arg_value)
		case PROP_PD_REGISTER_NEXT_HUMAN_CLASS: xPlayerData[player][PD_PROP_NEXT_HUMAN_CLASS] = get_param_byref(arg_value)
		case PROP_PD_REGISTER_CURRENT_TEMP_ZOMBIE_CLASS: xPlayerData[player][PD_PROP_CURRENT_TEMP_ZOMBIE_CLASS] = get_param_byref(arg_value)
		case PROP_PD_REGISTER_CURRENT_TEMP_HUMAN_CLASS: xPlayerData[player][PD_PROP_CURRENT_TEMP_HUMAN_CLASS] = get_param_byref(arg_value)
		case PROP_PD_REGISTER_LEVEL: xPlayerData[player][PD_PROP_LEVEL] = get_param_byref(arg_value)
		case PROP_PD_REGISTER_IS_FREEZED: xPlayerData[player][PD_PROP_IS_FREEZED] = bool:get_param_byref(arg_value)
	}

	return true
}

public reset_user_vars(id)
{
	new zombie_class = get_first_class(CLASS_TEAM_TYPE_ZOMBIE)
	new human_class = get_first_class(CLASS_TEAM_TYPE_HUMAN)

	xPlayerData[id][PD_PROP_CURRENT_SELECTED_ZOMBIE_CLASS] = zombie_class != -1 ? zombie_class : 0
	xPlayerData[id][PD_PROP_CURRENT_SELECTED_HUMAN_CLASS] = human_class != -1 ? human_class : 0
	xPlayerData[id][PD_PROP_IS_ZOMBIE] = false
	xPlayerData[id][PD_PROP_IS_FIRST_ZOMBIE] = false
	xPlayerData[id][PD_PROP_CURRENT_TEMP_ZOMBIE_CLASS] = -1
	xPlayerData[id][PD_PROP_CURRENT_TEMP_HUMAN_CLASS] = -1
	xPlayerData[id][PD_PROP_PRIMARY_WEAPON] = -1
	xPlayerData[id][PD_PROP_SECONDARY_WEAPON] = -1
	xPlayerData[id][PD_PROP_NEXT_ZOMBIE_CLASS] = -1
	xPlayerData[id][PD_PROP_NEXT_HUMAN_CLASS] = -1
	xPlayerData[id][PD_PROP_CLASS_TIMEOUT] = get_gametime()
	xPlayerData[id][PD_PROP_LAST_LEAP_TIMEOUT] = get_gametime()
	xPlayerData[id][PD_PROP_LEVEL] = 1
	xPlayerData[id][PD_PROP_IS_FREEZED] = false
}

get_first_class(eClassTypes:class_type)
{
	for(new i = 0; i < zpn_class_array_size(); i++)
	{
		if(zpn_class_get_prop(i, PROP_CLASS_REGISTER_TYPE) == class_type)
			return i
	}

	return -1
}
