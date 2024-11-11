#include <amxmodx>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new gamemode_infection
new g_max_helpers, g_helper_count, helper_ckeck[33]

public plugin_init()
{
	register_plugin("[ZPN] Addon: First Zombie Helper", "1.0", "Wilian M.")

	gamemode_infection = zpn_gamemode_find("gm_infection")
}

public client_disconnected(id)
{
	helper_ckeck[id] = false
}

public zpn_round_started_post(const gamemode_id)
{
	if(gamemode_id != gamemode_infection)
		return

	static id, i

	switch(get_alive_players())
	{
		case 0..9: g_max_helpers = 0
		case 10..19: g_max_helpers = 1
		case 20..24: g_max_helpers = 2
		case 25..32: g_max_helpers = 3
	}
	
	if(g_max_helpers > 0) 
	{
		g_helper_count = 0

		for(i = 0; i <= g_max_helpers; i++)
		{
			id = random_player()

			if(id == -1)
				continue		

			if(g_helper_count >= g_max_helpers)
				break
			
			if(zpn_is_user_zombie(id) || !is_user_alive(id))
			{
				i--
				continue
			}

			if(helper_ckeck[id])
				continue

			zpn_set_user_zombie(id, 0)
			g_helper_count++
			helper_ckeck[id] = true

			zpn_print_color(id, print_team_red, "^3Você foi escolhido para ajudar o primeiro zombie.")
		}

		zpn_print_color(0, print_team_default, "^1Escolhido ^4%d ^1jogadores para ajudar o primeiro zombie.", g_helper_count)
	}

	for(i = 1; i <= MaxClients; i++)
	{
		if(!is_user_connected(i))
			continue

		if(!zpn_is_user_zombie(i) && helper_ckeck[i])
			helper_ckeck[i] = false
	}
}

get_alive_players()
{
	static i_alive, id
	i_alive = 0
	
	for(id = 1; id <= MaxClients; id++)
	{
		if(is_user_alive(id))
			i_alive++
	}

	return i_alive
}

random_player()
{
	new players[32], pnum
	get_players(players, pnum, "ae", "CT")

	if(!pnum)
		return -1

	return players[random(pnum)]
}