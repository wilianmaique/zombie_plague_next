#include <amxmodx>
#include <zombie_plague_next>

new class

public plugin_init()
{
	register_plugin("[ZPN] Class: Zombie", "1.0", "Wilian M.")
}

public plugin_precache()
{
	class = zpn_class_init()
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_TYPE, CLASS_TEAM_TYPE_ZOMBIE)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_NAME, "Zombie Default")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_INFO, "Basic Zombie")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_MODEL, "zombie_source")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_MODEL_VIEW, "models/v_knife_zombie.mdl")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_SPEED, 320)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_HEALTH, 500.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_GRAVITY, 1.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_KNOCKBACK, 1.0)
}