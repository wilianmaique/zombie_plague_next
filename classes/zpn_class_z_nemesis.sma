#include <amxmodx>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new class

public plugin_init()
{
	register_plugin("[ZPN] Class: Zombie Nemesis", "1.0", "Wilian M.")
}

public plugin_precache()
{
	class = zpn_class_init("Nemesis", CLASS_TEAM_TYPE_ZOMBIE_SPECIAL)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_FIND_NAME, "class_z_nemesis")
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_HIDE_MENU, true)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_INFO, "Kill no infect")
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_MODEL, "zpn_z_default")
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_MODEL_VIEW, "models/player/zpn_z_default/hand.mdl")
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_SPEED, 450.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_HEALTH, 10000.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_GRAVITY, 0.5)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_KNOCKBACK, 1.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_UPDATE_HITBOX, true)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_SILENT_FOOTSTEPS, true)
}

public zpn_user_infect_attempt(const this, const infector, const class_id)
{
	if(zpn_get_user_selected_class(infector, CLASS_TEAM_TYPE_ZOMBIE, true) == class)
	{
		server_print("nemesis: this: %n - infector: %n", this, infector)
		// damage?
		return ZPN_RETURN_HANDLED
	}

	return ZPN_RETURN_CONTINUE
}