#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new gamemode, synchud

public plugin_init()
{
	register_plugin("[ZPN] GameMode: Infection", "1.0", "Wilian M.")
	synchud = CreateHudSyncObj()
}

public plugin_precache()
{
	gamemode = zpn_gamemode_init()
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_NAME, "Infection")
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_FIND_NAME, "gm_infection")
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_NOTICE, "Infection Has Started!")
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_HUD_COLOR, "#ffffff")
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_CHANCE, 20)
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_MIN_PLAYERS, 1)
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_ROUND_TIME, 5.0)
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_CHANGE_CLASS, true)
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_DEATHMATCH, GAMEMODE_DEATHMATCH_ONLY_TR)
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_RESPAWN_TIME, 5.0)
	zpn_gamemode_set_prop(gamemode, PROP_GAMEMODE_REGISTER_MAP_TYPES, GAMEMODE_MAP_NORMAL)
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
	ShowSyncHudMsg(0, synchud, "%n^nÉ o primeiro zombie!", id)
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
