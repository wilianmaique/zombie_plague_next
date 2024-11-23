#include <amxmodx>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new gm_infection

public plugin_init()
{
	register_plugin("[ZPN] Addon: Random class for bots", "1.0", "Wilian M.")

	gm_infection = zpn_gamemode_find("gm_infection")
}

public zpn_user_infected_pre(const this, const infector, const class_id)
{
	if(is_user_bot(this))
	{
		new gamemode_id = zpn_gamemode_current()

		if(gamemode_id == gm_infection)
			zpn_set_fw_param_int(3, zpn_class_random_class_id(CLASS_TEAM_TYPE_ZOMBIE))
	}
}