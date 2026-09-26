#include <amxmodx>
#include <reapi>
#include <regex>
#include <api_json_settings>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

enum _:ePropItems
{
	ITEM_PROP_NAME[32],
	ITEM_PROP_FIND_NAME[32],
	ITEM_PROP_CMD_BUY[32],
	ITEM_PROP_COST,
	eClassTypes:ITEM_PROP_TEAM,
	ITEM_PROP_LIMIT_PLAYER_PER_ROUND,
	ITEM_PROP_LIMIT_MAX_PER_ROUND,
	ITEM_PROP_LIMIT_PER_MAP,
	ITEM_PROP_MIN_ZOMBIES,
	bool:ITEM_PROP_ALLOW_BUY_SPECIAL_MODS,
	ITEM_PROP_FLAG,
}

enum _:eItemPurchaseCounts
{
	ITEM_PURCHASES_PLAYER_ROUND[33],
	ITEM_PURCHASES_ROUND,
	ITEM_PURCHASES_MAP,
}

new Array:aDataItem
new Array:aPurchaseCounts
new xItemBuyPreForward, xItemBuyPostForward

public plugin_init()
{
	register_plugin("[ZPN] Core: Items", "1.0", "Wilian M.")
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false)
	xItemBuyPreForward = CreateMultiForward("zpn_item_buy_pre", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_ARRAY, FP_CELL)
	xItemBuyPostForward = CreateMultiForward("zpn_item_buy_post", ET_IGNORE, FP_CELL, FP_CELL)

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
	aPurchaseCounts = ArrayCreate(eItemPurchaseCounts, 0)
}

public plugin_end()
{
	ArrayDestroy(aDataItem)
	ArrayDestroy(aPurchaseCounts)
	DestroyForward(xItemBuyPreForward)
	DestroyForward(xItemBuyPostForward)
}

public client_putinserver(id)
{
	reset_player_purchases(id)
}

public client_disconnected(id)
{
	reset_player_purchases(id)
}

public CSGameRules_RestartRound_Pre()
{
	new xCounts[eItemPurchaseCounts]

	for(new i = 0; i < ArraySize(aPurchaseCounts); i++)
	{
		ArrayGetArray(aPurchaseCounts, i, xCounts)
		xCounts[ITEM_PURCHASES_ROUND] = 0

		for(new id = 1; id <= MaxClients; id++)
			xCounts[ITEM_PURCHASES_PLAYER_ROUND][id] = 0

		ArraySetArray(aPurchaseCounts, i, xCounts)
	}
}

public plugin_natives()
{
	register_library("zombie_plague_next_items")

	register_native("zpn_item_init", "_zpn_item_init")
	register_native("zpn_item_get_prop", "_zpn_item_get_prop")
	register_native("zpn_item_set_prop", "_zpn_item_set_prop")
	register_native("zpn_item_find", "_zpn_item_find")
	register_native("zpn_item_array_size", "_zpn_item_array_size")
	register_native("zpn_item_get_limit_state", "_zpn_item_get_limit_state")
	register_native("zpn_item_preview_buy", "_zpn_item_preview_buy")
	register_native("zpn_item_buy", "_zpn_item_buy")
}

public _zpn_item_init(plugin_id, param_nums)
{
	new xDataGetItem[ePropItems]

	xDataGetItem[ITEM_PROP_NAME] = EOS
	xDataGetItem[ITEM_PROP_FIND_NAME] = EOS
	xDataGetItem[ITEM_PROP_CMD_BUY] = EOS
	xDataGetItem[ITEM_PROP_COST] = 0
	xDataGetItem[ITEM_PROP_TEAM] = CLASS_TEAM_TYPE_HUMAN
	xDataGetItem[ITEM_PROP_LIMIT_PLAYER_PER_ROUND] = 0
	xDataGetItem[ITEM_PROP_LIMIT_MAX_PER_ROUND] = 0
	xDataGetItem[ITEM_PROP_LIMIT_PER_MAP] = 0
	xDataGetItem[ITEM_PROP_MIN_ZOMBIES] = 0
	xDataGetItem[ITEM_PROP_ALLOW_BUY_SPECIAL_MODS] = false
	xDataGetItem[ITEM_PROP_FLAG] = ADMIN_ALL

	new xCounts[eItemPurchaseCounts]
	arrayset(xCounts, 0, sizeof xCounts)

	new item_id = ArrayPushArray(aDataItem, xDataGetItem)
	ArrayPushArray(aPurchaseCounts, xCounts)

	return item_id
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
		case PROP_ITEM_REGISTER_TEAM: xDataGetItem[ITEM_PROP_TEAM] = eClassTypes:get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_LIMIT_PLAYER_PER_ROUND: xDataGetItem[ITEM_PROP_LIMIT_PLAYER_PER_ROUND] = get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_LIMIT_MAX_PER_ROUND: xDataGetItem[ITEM_PROP_LIMIT_MAX_PER_ROUND] = get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_LIMIT_PER_MAP: xDataGetItem[ITEM_PROP_LIMIT_PER_MAP] = get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_MIN_ZOMBIES: xDataGetItem[ITEM_PROP_MIN_ZOMBIES] = get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_ALLOW_BUY_SPECIAL_MODS: xDataGetItem[ITEM_PROP_ALLOW_BUY_SPECIAL_MODS] = bool:get_param_byref(arg_value)
		case PROP_ITEM_REGISTER_FLAG: xDataGetItem[ITEM_PROP_FLAG] = get_param_byref(arg_value)
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

public bool:_zpn_item_get_limit_state(plugin_id, param_nums)
{
	if(param_nums != 5)
		return false

	new id = get_param(1)
	new item_id = get_param(2)

	if(!zpn_is_valid_player_connected(id) || !is_valid_item(item_id))
	{
		set_param_byref(3, 0)
		set_param_byref(4, 0)
		set_param_byref(5, 0)
		return false
	}

	new xDataGetItem[ePropItems], xCounts[eItemPurchaseCounts]
	ArrayGetArray(aDataItem, item_id, xDataGetItem)
	ArrayGetArray(aPurchaseCounts, item_id, xCounts)

	set_param_byref(3, xCounts[ITEM_PURCHASES_PLAYER_ROUND][id])
	set_param_byref(4, xCounts[ITEM_PURCHASES_ROUND])
	set_param_byref(5, xCounts[ITEM_PURCHASES_MAP])

	return has_free_limit(id, xDataGetItem, xCounts)
}

public eItemBuyResults:_zpn_item_preview_buy(plugin_id, param_nums)
{
	if(param_nums != 4)
		return ITEM_BUY_INVALID

	new id = get_param(1)
	new item_id = get_param(2)
	new extra_text[ZPN_ITEM_EXTRA_TEXT_SIZE]
	extra_text[0] = EOS

	if(!zpn_is_valid_player_connected(id) || !is_valid_item(item_id))
	{
		set_string(3, extra_text, get_param(4))
		return ITEM_BUY_INVALID
	}

	new bool:blocked = item_buy_pre(id, item_id, true, extra_text, charsmax(extra_text))
	set_string(3, extra_text, get_param(4))

	if(!is_user_connected(id))
		return ITEM_BUY_INVALID

	if(blocked)
		return ITEM_BUY_BLOCKED

	new xDataGetItem[ePropItems], xCounts[eItemPurchaseCounts]
	ArrayGetArray(aDataItem, item_id, xDataGetItem)
	ArrayGetArray(aPurchaseCounts, item_id, xCounts)

	return get_item_buy_result(id, xDataGetItem, xCounts)
}

public eItemBuyResults:_zpn_item_buy(plugin_id, param_nums)
{
	if(param_nums != 2)
		return ITEM_BUY_INVALID

	new id = get_param(1)
	new item_id = get_param(2)

	if(!zpn_is_valid_player_connected(id) || !is_valid_item(item_id))
		return ITEM_BUY_INVALID

	new extra_text[ZPN_ITEM_EXTRA_TEXT_SIZE]
	extra_text[0] = EOS
	new bool:blocked = item_buy_pre(id, item_id, false, extra_text, charsmax(extra_text))

	if(!is_user_connected(id))
		return ITEM_BUY_INVALID

	if(blocked)
		return ITEM_BUY_BLOCKED

	new xDataGetItem[ePropItems], xCounts[eItemPurchaseCounts]
	ArrayGetArray(aDataItem, item_id, xDataGetItem)
	ArrayGetArray(aPurchaseCounts, item_id, xCounts)

	new eItemBuyResults:result = get_item_buy_result(id, xDataGetItem, xCounts)
	if(result != ITEM_BUY_SUCCESS)
		return result

	new cost = xDataGetItem[ITEM_PROP_COST]
	if(cost < 0)
		return ITEM_BUY_INVALID

	// Reserve the purchase before the Ammo Packs changed forward can run.
	xCounts[ITEM_PURCHASES_PLAYER_ROUND][id]++
	xCounts[ITEM_PURCHASES_ROUND]++
	xCounts[ITEM_PURCHASES_MAP]++
	ArraySetArray(aPurchaseCounts, item_id, xCounts)

	if(!zpn_ammo_pack_take_user_ap(id, cost, ZPN_AMMO_PACK_CHANGE_ITEM_BUY))
	{
		xCounts[ITEM_PURCHASES_PLAYER_ROUND][id]--
		xCounts[ITEM_PURCHASES_ROUND]--
		xCounts[ITEM_PURCHASES_MAP]--
		ArraySetArray(aPurchaseCounts, item_id, xCounts)
		return ITEM_BUY_NO_AMMO_PACKS
	}

	new forward_return
	ExecuteForward(xItemBuyPostForward, forward_return, id, item_id)

	return ITEM_BUY_SUCCESS
}

bool:item_buy_pre(const id, const item_id, const bool:preview, extra_text[], const maxlen)
{
	new forward_return
	ExecuteForward(xItemBuyPreForward, forward_return, id, item_id, preview, PrepareArray(extra_text, maxlen + 1, 1), maxlen)
	return forward_return >= ZPN_RETURN_HANDLED
}

eItemBuyResults:get_item_buy_result(const id, const item[ePropItems], const counts[eItemPurchaseCounts])
{
	if(item[ITEM_PROP_MIN_ZOMBIES] > 0 && count_alive_zombies() < item[ITEM_PROP_MIN_ZOMBIES])
		return ITEM_BUY_NOT_ENOUGH_ZOMBIES

	if(!has_free_limit(id, item, counts))
		return ITEM_BUY_LIMIT_REACHED

	return ITEM_BUY_SUCCESS
}

count_alive_zombies()
{
	new count

	for(new id = 1; id <= MaxClients; id++)
	{
		if(is_user_alive(id) && zpn_is_user_zombie(id))
			count++
	}

	return count
}

bool:is_valid_item(const item_id)
{
	return !zpn_is_invalid_array(aDataItem) && 0 <= item_id < ArraySize(aDataItem)
}

bool:has_free_limit(const id, const item[ePropItems], const counts[eItemPurchaseCounts])
{
	if(item[ITEM_PROP_LIMIT_PLAYER_PER_ROUND] > 0
	&& counts[ITEM_PURCHASES_PLAYER_ROUND][id] >= item[ITEM_PROP_LIMIT_PLAYER_PER_ROUND])
		return false

	if(item[ITEM_PROP_LIMIT_MAX_PER_ROUND] > 0
	&& counts[ITEM_PURCHASES_ROUND] >= item[ITEM_PROP_LIMIT_MAX_PER_ROUND])
		return false

	if(item[ITEM_PROP_LIMIT_PER_MAP] > 0
	&& counts[ITEM_PURCHASES_MAP] >= item[ITEM_PROP_LIMIT_PER_MAP])
		return false

	return true
}

reset_player_purchases(const id)
{
	new xCounts[eItemPurchaseCounts]

	for(new i = 0; i < ArraySize(aPurchaseCounts); i++)
	{
		ArrayGetArray(aPurchaseCounts, i, xCounts)
		xCounts[ITEM_PURCHASES_PLAYER_ROUND][id] = 0
		ArraySetArray(aPurchaseCounts, i, xCounts)
	}
}
