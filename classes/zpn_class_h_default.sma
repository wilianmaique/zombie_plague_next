#include <amxmodx>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new class

public plugin_init()
{
	register_plugin("[ZPN] Class: Human Default", "1.0", "Wilian M.")
}

public plugin_precache()
{
	class = zpn_class_init("Default", CLASS_TEAM_TYPE_HUMAN)

	zpn_class_set_prop(class, PROP_CLASS_REGISTER_FIND_NAME, "default")
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_INFO, "Balanced")
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_MODEL, "sas")
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_SPEED, 280.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_HEALTH, 120.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_ARMOR, 15.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_GRAVITY, 0.5)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_KNOCKBACK, 1.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_BLOOD_COLOR, 110)
}