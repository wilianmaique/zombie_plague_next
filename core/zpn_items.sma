#include <amxmodx>
#include <regex>
#include <api_json_settings>
#include <zombie_plague_next_const>

enum _:ePropItems
{
	ITEM_PROP_NAME[32],
	ITEM_PROP_FIND_NAME[32],
	ITEM_PROP_CMD_BUY[32],
	ITEM_PROP_COST,
	eItemTeams:ITEM_PROP_TEAM,
	ITEM_PROP_LIMIT_PLAYER_PER_ROUND,
	ITEM_PROP_LIMIT_MAX_PER_ROUND,
	ITEM_PROP_LIMIT_PER_MAP,
	ITEM_PROP_MIN_ZOMBIES,
	bool:ITEM_PROP_ALLOW_BUY_SPECIAL_MODS,
	ITEM_PROP_FLAG,
}

new Array:aDataItem

public plugin_init()
{
	register_plugin("[ZPN] Core: Items", "1.0", "Wilian M.")

	// LOG
	new i, text[256]

	server_print("^n")
	server_print("Items loaded: %d", ArraySize(aDataItem))
	
	new xDataGetItem[ePropItems]
	for(i = 0; i < ArraySize(aDataItem); i++)
	{
		ArrayGetArray(aDataItem, i, xDataGetItem)

		text[0] = EOS
		
		add(text, charsmax(text), fmt("ItemIndex: %d | ", i))
		add(text, charsmax(text), fmt("Name: %s | ", xDataGetItem[ITEM_PROP_NAME]))
		add(text, charsmax(text), fmt("Find Name: %s | ", xDataGetItem[ITEM_PROP_FIND_NAME]))
		add(text, charsmax(text), fmt("Cost: %d | ", xDataGetItem[ITEM_PROP_COST]))
		server_print(text)
	}
	
	server_print("^n")
}

public plugin_precache()
{
	aDataItem = ArrayCreate(ePropItems, 0)
}

public plugin_end()
{
	ArrayDestroy(aDataItem)
}

public plugin_natives()
{
	register_library("zombie_plague_next_items")

	register_native("zpn_item_init", "_zpn_item_init")
	register_native("zpn_item_get_prop", "_zpn_item_get_prop")
	register_native("zpn_item_set_prop", "_zpn_item_set_prop")
	register_native("zpn_item_find", "_zpn_item_find")
	register_native("zpn_item_array_size", "_zpn_item_array_size")
}

public _zpn_item_init(plugin_id, param_nums)
{
	new xDataGetItem[ePropItems]

	xDataGetItem[ITEM_PROP_NAME] = EOS
	xDataGetItem[ITEM_PROP_FIND_NAME] = EOS
	xDataGetItem[ITEM_PROP_CMD_BUY] = EOS
	xDataGetItem[ITEM_PROP_COST] = 0
	xDataGetItem[ITEM_PROP_TEAM] = ITEM_TEAM_HUMAN
	xDataGetItem[ITEM_PROP_LIMIT_PLAYER_PER_ROUND] = 0
	xDataGetItem[ITEM_PROP_LIMIT_MAX_PER_ROUND] = 0
	xDataGetItem[ITEM_PROP_LIMIT_PER_MAP] = 0
	xDataGetItem[ITEM_PROP_MIN_ZOMBIES] = 0
	xDataGetItem[ITEM_PROP_ALLOW_BUY_SPECIAL_MODS] = false
	xDataGetItem[ITEM_PROP_FLAG] = ADMIN_ALL

	return ArrayPushArray(aDataItem, xDataGetItem)
}

public any:_zpn_item_get_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataItem))
		return false

	enum { arg_item_id = 1, arg_prop, arg_value, arg_len }

	new item_id = get_param(arg_item_id)
	new prop = get_param(arg_prop)

	new xDataGetItem[ePropItems]
	ArrayGetArray(aDataItem, item_id, xDataGetItem)

	switch(ePropItemRegisters:prop)
	{
		case PROP_ITEM_REGISTER_NAME: set_string(arg_value, xDataGetItem[ITEM_PROP_NAME], get_param_byref(arg_len))
		case PROP_ITEM_REGISTER_FIND_NAME: set_string(arg_value, xDataGetItem[ITEM_PROP_FIND_NAME], get_param_byref(arg_len))
		case PROP_ITEM_REGISTER_CMD_BUY: set_string(arg_value, xDataGetItem[ITEM_PROP_CMD_BUY], get_param_byref(arg_len))
		case PROP_ITEM_REGISTER_COST: return xDataGetItem[ITEM_PROP_COST]
		case PROP_ITEM_REGISTER_TEAM: return xDataGetItem[ITEM_PROP_TEAM]
		case PROP_ITEM_REGISTER_LIMIT_PLAYER_PER_ROUND: return xDataGetItem[ITEM_PROP_LIMIT_PLAYER_PER_ROUND]
		case PROP_ITEM_REGISTER_LIMIT_MAX_PER_ROUND: return xDataGetItem[ITEM_PROP_LIMIT_MAX_PER_ROUND]
		case PROP_ITEM_REGISTER_LIMIT_PER_MAP: return xDataGetItem[ITEM_PROP_LIMIT_PER_MAP]
		case PROP_ITEM_REGISTER_MIN_ZOMBIES: return xDataGetItem[ITEM_PROP_MIN_ZOMBIES]
		case PROP_ITEM_REGISTER_ALLOW_BUY_SPECIAL_MODS: return xDataGetItem[ITEM_PROP_ALLOW_BUY_SPECIAL_MODS]
		case PROP_ITEM_REGISTER_FLAG: return xDataGetItem[ITEM_PROP_FLAG]
		default: return false
	}

	return true
}

public any:_zpn_item_set_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataItem))
		return false

	enum { arg_item_id = 1, arg_prop, arg_value }

	new item_id = get_param(arg_item_id)
	new prop = get_param(arg_prop)

	new xDataGetItem[ePropItems]
	ArrayGetArray(aDataItem, item_id, xDataGetItem)

	switch(ePropItemRegisters:prop)
	{
		case PROP_ITEM_REGISTER_NAME: get_string(arg_value, xDataGetItem[ITEM_PROP_NAME], charsmax(xDataGetItem[ITEM_PROP_NAME]))
		case PROP_ITEM_REGISTER_FIND_NAME: get_string(arg_value, xDataGetItem[ITEM_PROP_FIND_NAME], charsmax(xDataGetItem[ITEM_PROP_FIND_NAME]))
		case PROP_ITEM_REGISTER_CMD_BUY: get_string(arg_value, xDataGetItem[ITEM_PROP_CMD_BUY], charsmax(xDataGetItem[ITEM_PROP_CMD_BUY]))
		case PROP_ITEM_REGISTER_COST: xDataGetItem[ITEM_PROP_COST] = get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_TEAM: xDataGetItem[ITEM_PROP_TEAM] = eItemTeams:get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_LIMIT_PLAYER_PER_ROUND: xDataGetItem[ITEM_PROP_LIMIT_PLAYER_PER_ROUND] = get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_LIMIT_MAX_PER_ROUND: xDataGetItem[ITEM_PROP_LIMIT_MAX_PER_ROUND] = get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_LIMIT_PER_MAP: xDataGetItem[ITEM_PROP_LIMIT_PER_MAP] = get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_MIN_ZOMBIES: xDataGetItem[ITEM_PROP_MIN_ZOMBIES] = get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_ALLOW_BUY_SPECIAL_MODS: xDataGetItem[ITEM_PROP_ALLOW_BUY_SPECIAL_MODS] = bool:get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_FLAG: xDataGetItem[ITEM_PROP_FLAG] = get_param_byref(arg_value)
		default: return false
	}

	ArraySetArray(aDataItem, item_id, xDataGetItem)
	
	return true
}

public _zpn_item_find(plugin_id, param_nums)
{
	if(param_nums != 1)
		return -1

	static findName[32]; findName[0] = EOS;
	get_string(1, findName, charsmax(findName))

	new find = -1
	new xDataGetItem[ePropItems]

	for(new i = 0; i < ArraySize(aDataItem); i++)
	{
		ArrayGetArray(aDataItem, i, xDataGetItem)
		
		if(zpn_is_null_string(xDataGetItem[ITEM_PROP_FIND_NAME]))
			continue

		if(equal(xDataGetItem[ITEM_PROP_FIND_NAME], findName))
			find = i

		if(find != -1)
			break
	}

	return find
}

public _zpn_item_array_size(plugin_id, param_nums)
{
	return ArraySize(aDataItem)
}