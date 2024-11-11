#include <amxmodx>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new gamemode, synchud
new const GAMEMODE_NAME[] = "Infection"
new const GAMEMODE_NOTICE[] = "Infection Has Started!"

public plugin_init()
{
	register_plugin("[ZPN] GameMode: Infection", "1.0", "Wilian M.")
	synchud = CreateHudSyncObj()
}

public plugin_precache()
{
	gamemode = zpn_gamemode_init()
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_NAME, GAMEMODE_NAME)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_FIND_NAME, "gm_infection")
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_NOTICE, GAMEMODE_NOTICE)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_HUD_COLOR, { 255, 0, 255 })
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_CHANCE, 20)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_MIN_PLAYERS, 1)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_ROUND_TIME, 5.0)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_CHANGE_CLASS, true)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_DEATHMATCH, GAMEMODE_DEATHMATCH_ONLY_TR)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_RESPAWN_TIME, 5.0)
}

public zpn_round_started_post(const game_id)
{
	if(gamemode != game_id)
		return

	new id = random_player()

	if(id == -1)
		return
	
	zpn_set_user_zombie(id, 0, true)

	set_hudmessage(255, 0, 0, -1.0, 0.30, 2, 0.3, 3.0, 0.06, 0.06, -1, 0, { 100, 200, 50, 100 })
	ShowSyncHudMsg(0, synchud, "%n^nÉ o primeiro zombie!", id)
}

random_player()
{
	new players[32], pnum
	get_players(players, pnum)

	if(!pnum)
		return -1

	return players[random(pnum)]
}
