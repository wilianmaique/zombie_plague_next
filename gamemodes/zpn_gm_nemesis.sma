#include <amxmodx>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new gamemode, synchud, class_nemesis

public plugin_init()
{
	register_plugin("[ZPN] GameMode: Nemesis", "1.0", "Wilian M.")
	
	synchud = CreateHudSyncObj()
	class_nemesis = zpn_class_find("class_z_nemesis")
}

public plugin_precache()
{
	gamemode = zpn_gamemode_init()
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_NAME, "Nemesis")
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_FIND_NAME, "gm_nemesis")
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_NOTICE, "Nemesis Has Started!")
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_HUD_COLOR, "#ff7456")
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_CHANCE, 20)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_MIN_PLAYERS, 7)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_ROUND_TIME, 5.0)
}

public zpn_user_infected_pre(const this, const infector, const class_id)
{
	new gamemode_id = zpn_get_current_gamemode()

	if(gamemode != gamemode_id)
		return

	if(class_nemesis != -1)
		zpn_set_fw_param_int(3, class_nemesis)
}

public zpn_round_started_post(const game_id)
{
	if(gamemode != game_id)
		return

	new id = random_player()
	zpn_set_user_zombie(id, 0, true)

	set_hudmessage(255, 0, 0, -1.0, 0.30, 2, 0.3, 3.0, 0.06, 0.06, -1, 0, { 100, 200, 50, 100 })
	ShowSyncHudMsg(0, synchud, "%n^nÉ o nemesis!", id)
}

random_player()
{
	new players[32], pnum
	get_players(players, pnum)

	if(!pnum)
		return -1

	return players[random(pnum)]
}
