#include <amxmodx>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new class

public plugin_init()
{
	register_plugin("[ZPN] Class: Zombie Default", "1.0", "Wilian M.")
}

public plugin_precache()
{
	class = zpn_class_init("Default", CLASS_TEAM_TYPE_ZOMBIE)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_INFO, "Balanced")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_MODEL, "zpn_z_default")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_MODEL_VIEW, "models/player/zpn_z_default/hand.mdl")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_SPEED, 300.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_HEALTH, 5000.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_GRAVITY, 0.7)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_KNOCKBACK, 1.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_BLOOD_COLOR, 110)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_UPDATE_HITBOX, true)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_SILENT_FOOTSTEPS, true)
}