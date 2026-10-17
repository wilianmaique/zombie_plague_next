#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new gamemode, synchud, class_nemesis

public plugin_init()
{
	register_dictionary("zpn_gamemodes.txt")
	register_plugin("[ZPN] GameMode: Nemesis", "1.0", "Wilian M.")
	
	synchud = CreateHudSyncObj()
	class_nemesis = zpn_class_find("class_z_nemesis")
}

public plugin_precache()
{
	gamemode = zpn_gamemode_init()
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_NAME, "ZPN_GM_NEMESIS")
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_FIND_NAME, "gm_nemesis")
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_NOTICE, "ZPN_GM_NEMESIS_NOTICE")
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_HUD_COLOR, "#ff7456")
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_CHANCE, 20)
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_MIN_PLAYERS, 7)
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_ROUND_TIME, 5.0)
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_MAP_TYPES, GAMEMODE_MAP_NORMAL)
}

public zpn_user_frozen_pre(const this)
{
	if(zpn_is_user_class(this, class_nemesis))
		return ZPN_RETURN_HANDLED
	
	return ZPN_RETURN_CONTINUE
}

public zpn_user_infected_pre(const this, const infector, const class_id)
{
	new gamemode_id = zpn_get_current_gamemode()

	if(gamemode != gamemode_id)
		return

	if(class_nemesis != -1)
		zpn_set_fw_param_int(3, class_nemesis)
}

public zpn_round_started_post(const game_id, const start_player)
{
	if(gamemode != game_id)
		return

	new id = start_player
	if(!id || !zpn_is_user_zombie(id))
		id = infect_first_zombie(start_player)

	if(!id)
	{
		rg_round_end(2.0, WINSTATUS_DRAW, ROUND_END_DRAW, .trigger = true)
		return
	}

	set_hudmessage(255, 0, 0, -1.0, 0.30, 2, 0.3, 3.0, 0.06, 0.06, -1, 0, { 100, 200, 50, 100 })
	ShowSyncHudMsg(0, synchud, "%L", LANG_PLAYER, "ZPN_GM_NEMESIS_PLAYER", id)
}

infect_first_zombie(const exclude_player)
{
	new players[32], pnum
	get_players_ex(players, pnum, GetPlayers_ExcludeDead | GetPlayers_ExcludeHLTV)

	while(pnum > 0)
	{
		new index = random_num(0, pnum - 1), id = players[index]
		players[index] = players[--pnum]
		if(id != exclude_player && !zpn_is_user_zombie(id) && zpn_set_user_zombie(id, 0, true))
			return id
	}
	return 0
}
