#include <amxmodx>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new class

public plugin_init()
{
	register_plugin("[ZPN] Class: Zombie Charger", "1.0", "Wilian M.")
}

public register_class()
{
	class = zpn_class_init("Charger", CLASS_TEAM_TYPE_ZOMBIE)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_INFO, "Run, and grab the player")
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_MODEL, "zpn_charger")
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_MODEL_VIEW, "models/player/zpn_charger/hand.mdl")
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_SPEED, 360.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_HEALTH, 2200.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_GRAVITY, 0.8)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_KNOCKBACK, 1.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_BLOOD_COLOR, 10)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_UPDATE_HITBOX, true)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_SILENT_FOOTSTEPS, true)
}

public plugin_precache()
{
	register_class()
}