#include <amxmodx>
#include <regex>
#include <api_json_settings>
#include <zombie_plague_next_const>

enum _:ePropGameModes
{
	GAMEMODE_PROP_NAME[32],
	GAMEMODE_PROP_NOTICE[64],
	GAMEMODE_PROP_HUD_COLOR[9],
	GAMEMODE_PROP_HUD_COLOR_CONVERTED[3],
	GAMEMODE_PROP_CHANCE,
	GAMEMODE_PROP_MIN_PLAYERS,
	Float:GAMEMODE_PROP_ROUND_TIME,
	bool:GAMEMODE_PROP_CHANGE_CLASS,
	eGameModeDeathMatchTypes:GAMEMODE_PROP_DEATHMATCH,
	Float:GAMEMODE_PROP_RESPAWN_TIME,
	GAMEMODE_PROP_FIND_NAME[32]
}

new Array:aDataGameMode

public plugin_init()
{
	register_plugin("[ZPN] Core: GameModes", "1.0", "Wilian M.")

	// LOG
	new i, text[256]

	server_print("^n")
	server_print("GameModes loaded: %d", ArraySize(aDataGameMode))
	
	new xDataGetGameMode[ePropGameModes]
	for(i = 0; i < ArraySize(aDataGameMode); i++)
	{
		ArrayGetArray(aDataGameMode, i, xDataGetGameMode)

		text[0] = EOS
		
		add(text, charsmax(text), fmt("GameIndex: %d | ", i))
		add(text, charsmax(text), fmt("GameMode: %s | ", xDataGetGameMode[GAMEMODE_PROP_NAME]))
		add(text, charsmax(text), fmt("Chance: %d | ", xDataGetGameMode[GAMEMODE_PROP_CHANCE]))
		add(text, charsmax(text), fmt("Min Players: %d | ", xDataGetGameMode[GAMEMODE_PROP_MIN_PLAYERS]))
		add(text, charsmax(text), fmt("Round Time: %0.1f", xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME]))
		server_print(text)
	}

	server_print("^n")
}

public plugin_precache()
{
	aDataGameMode = ArrayCreate(ePropGameModes, 0)
}

public plugin_end()
{
	ArrayDestroy(aDataGameMode)
}

public plugin_natives()
{
	register_library("zombie_plague_next_gamemodes")

	register_native("zpn_gamemode_init", "_zpn_gamemode_init")
	register_native("zpn_gamemode_get_prop", "_zpn_gamemode_get_prop")
	register_native("zpn_gamemode_set_prop", "_zpn_gamemode_set_prop")
	register_native("zpn_gamemode_find", "_zpn_gamemode_find")
	register_native("zpn_gamemode_array_size", "_zpn_gamemode_array_size")
}

public _zpn_gamemode_init(plugin_id, param_nums)
{
	new xDataGetGameMode[ePropGameModes]

	xDataGetGameMode[GAMEMODE_PROP_NAME] = EOS
	xDataGetGameMode[GAMEMODE_PROP_NOTICE] = EOS
	xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR] = EOS
	xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR_CONVERTED] = { 255, 255, 255 }
	xDataGetGameMode[GAMEMODE_PROP_CHANCE] = -1
	xDataGetGameMode[GAMEMODE_PROP_MIN_PLAYERS] = 1
	xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME] = 2.0
	xDataGetGameMode[GAMEMODE_PROP_CHANGE_CLASS] = false
	xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH] = GAMEMODE_DEATHMATCH_DISABLED
	xDataGetGameMode[GAMEMODE_PROP_RESPAWN_TIME] = -1.0
	xDataGetGameMode[GAMEMODE_PROP_FIND_NAME] = EOS

	return ArrayPushArray(aDataGameMode, xDataGetGameMode)
}

public any:_zpn_gamemode_get_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataGameMode))
		return false

	enum { arg_gamemode_id = 1, arg_prop, arg_value, arg_len }

	new gamemode_id = get_param(arg_gamemode_id)
	new prop = get_param(arg_prop)

	new xDataGetGameMode[ePropGameModes]
	ArrayGetArray(aDataGameMode, gamemode_id, xDataGetGameMode)

	switch(ePropGameModeRegisters:prop)
	{
		case PROP_GAMEMODE_REGISTER_NAME: set_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NAME], get_param_byref(arg_len))
		case PROP_GAMEMODE_REGISTER_NOTICE: set_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NOTICE], get_param_byref(arg_len))
		case PROP_GAMEMODE_REGISTER_HUD_COLOR: return xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR]
		case PROP_GAMEMODE_REGISTER_HUD_COLOR_CONVERTED: set_array(arg_value, xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR_CONVERTED], get_param_byref(arg_len))
		case PROP_GAMEMODE_REGISTER_CHANCE: return xDataGetGameMode[GAMEMODE_PROP_CHANCE]
		case PROP_GAMEMODE_REGISTER_MIN_PLAYERS: return xDataGetGameMode[GAMEMODE_PROP_MIN_PLAYERS]
		case PROP_GAMEMODE_REGISTER_ROUND_TIME: return Float:xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME]
		case PROP_GAMEMODE_REGISTER_CHANGE_CLASS: return bool:xDataGetGameMode[GAMEMODE_PROP_CHANGE_CLASS]
		case PROP_GAMEMODE_REGISTER_DEATHMATCH: return xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH]
		case PROP_GAMEMODE_REGISTER_RESPAWN_TIME: return xDataGetGameMode[GAMEMODE_PROP_RESPAWN_TIME]
		case PROP_GAMEMODE_REGISTER_FIND_NAME: set_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_FIND_NAME], get_param_byref(arg_len))
	}

	return true
}

public any:_zpn_gamemode_set_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataGameMode))
		return false

	enum { arg_gamemode_id = 1, arg_prop, arg_value }

	new gamemode_id = get_param(arg_gamemode_id)
	new prop = get_param(arg_prop)

	new xDataGetGameMode[ePropGameModes]
	ArrayGetArray(aDataGameMode, gamemode_id, xDataGetGameMode)

	switch(ePropGameModeRegisters:prop)
	{
		case PROP_GAMEMODE_REGISTER_NAME: get_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NAME], charsmax(xDataGetGameMode[GAMEMODE_PROP_NAME]))
		case PROP_GAMEMODE_REGISTER_NOTICE: get_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NOTICE], charsmax(xDataGetGameMode[GAMEMODE_PROP_NOTICE]))
		case PROP_GAMEMODE_REGISTER_HUD_COLOR:
		{
			get_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR], charsmax(xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR]))

			if(!zpn_is_null_string(xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR]))
				parse_hex_color(xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR], xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR_CONVERTED])
		}
		case PROP_GAMEMODE_REGISTER_CHANCE: xDataGetGameMode[GAMEMODE_PROP_CHANCE] = get_param_byref(arg_value)
		case PROP_GAMEMODE_REGISTER_MIN_PLAYERS: xDataGetGameMode[GAMEMODE_PROP_MIN_PLAYERS] = get_param_byref(arg_value)
		case PROP_GAMEMODE_REGISTER_ROUND_TIME: xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME] = get_float_byref(arg_value)
		case PROP_GAMEMODE_REGISTER_CHANGE_CLASS: xDataGetGameMode[GAMEMODE_PROP_CHANGE_CLASS] = bool:get_param_byref(arg_value)
		case PROP_GAMEMODE_REGISTER_DEATHMATCH: xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH] = eGameModeDeathMatchTypes:get_param_byref(arg_value)
		case PROP_GAMEMODE_REGISTER_RESPAWN_TIME: xDataGetGameMode[GAMEMODE_PROP_RESPAWN_TIME] = get_float_byref(arg_value)
		case PROP_GAMEMODE_REGISTER_FIND_NAME: get_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_FIND_NAME], charsmax(xDataGetGameMode[GAMEMODE_PROP_FIND_NAME]))
	}

	ArraySetArray(aDataGameMode, gamemode_id, xDataGetGameMode)
	
	return true
}

public _zpn_gamemode_find(plugin_id, param_nums)
{
	if(param_nums != 1)
		return -1

	static findName[32]; findName[0] = EOS;
	get_string(1, findName, charsmax(findName))

	new find = -1
	new xDataGetGameMode[ePropGameModes]

	for(new i = 0; i < ArraySize(aDataGameMode); i++)
	{
		ArrayGetArray(aDataGameMode, i, xDataGetGameMode)
		
		if(zpn_is_null_string(xDataGetGameMode[GAMEMODE_PROP_FIND_NAME]))
			continue

		if(equal(xDataGetGameMode[GAMEMODE_PROP_FIND_NAME], findName))
			find = i

		if(find != -1)
			break
	}

	return find
}

public _zpn_gamemode_array_size(plugin_id, param_nums)
{
	return ArraySize(aDataGameMode)
}