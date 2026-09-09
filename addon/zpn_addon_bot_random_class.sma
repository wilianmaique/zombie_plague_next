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
		new gamemode_id = zpn_get_current_gamemode()

		if(gamemode_id == gm_infection)
		{
			new selected = -1, count, level = zpn_player_data_get_prop(this, PROP_PD_REGISTER_LEVEL)
			for(new i = 0; i < zpn_class_array_size(); i++)
			{
				if(zpn_class_get_prop(i, PROP_CLASS_REGISTER_TYPE) != CLASS_TEAM_TYPE_ZOMBIE
					|| zpn_class_get_prop(i, PROP_CLASS_REGISTER_HIDE_MENU)
					|| zpn_class_get_prop(i, PROP_CLASS_REGISTER_LEVEL) > level
					|| !zpn_class_has_free_slot(i, this))
					continue

				if(random_num(1, ++count) == 1)
					selected = i
			}

			if(selected != -1)
				zpn_set_fw_param_int(3, selected)
		}
	}
}
