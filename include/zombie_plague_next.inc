#if defined _zombie_plague_next_included
	#endinput
#endif

#define _zombie_plague_next_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib zombie_plague_next
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib zombie_plague_next
	#endif
#else
	#pragma library zombie_plague_next
#endif

enum
{
	ZPN_RETURN_HANDLED = 666,
	ZPN_RETURN_CONTINUE,
}

#define zpn_is_invalid_array(%0) (%0 == Invalid_Array || !ArraySize(%0))
#define zpn_is_null_string(%0) bool:(%0[0] == EOS)

stock const PATH_SETTINGS_CONFIG[] = "zombie_plague_next/configs.json";
stock const PATH_SETTINGS_CLASSES[] = "zombie_plague_next/classes.json";
stock const SETTINGS_SECTION_CONFIG[] = "Main Config";

enum
{
	CLASS_TEAM_TYPE_ZOMBIE = 0,
	CLASS_TEAM_TYPE_HUMAN,
	CLASS_TEAM_TYPE_ZOMBIE_SPECIAL,
	CLASS_TEAM_TYPE_HUMAN_SPECIAL,
}

enum ePropsClassRegisters
{
	CLASS_PROP_REGISTER_TYPE, // int
	CLASS_PROP_REGISTER_NAME, // string
	CLASS_PROP_REGISTER_INFO, // string
	CLASS_PROP_REGISTER_MODEL, // string
	CLASS_PROP_REGISTER_MODEL_VIEW, // string
	CLASS_PROP_REGISTER_HEALTH, // float
	CLASS_PROP_REGISTER_SPEED, // int
	CLASS_PROP_REGISTER_GRAVITY, // float
	CLASS_PROP_REGISTER_KNOCKBACK, // float
	CLASS_PROP_REGISTER_CLAW_WEAPONLIST, // string
}

enum eGameModeDeathMatchType
{
	GAMEMODE_DEATHMATCH_DISABLED,
	GAMEMODE_DEATHMATCH_ONLY_TR,
	GAMEMODE_DEATHMATCH_ONLY_CT,
	GAMEMODE_DEATHMATCH_RANDOM,
	GAMEMODE_DEATHMATCH_BALANCE,
}

enum ePropsGameModeRegisters
{
	GAMEMODE_PROP_REGISTER_NAME, // string
	GAMEMODE_PROP_REGISTER_NOTICE, // string
	GAMEMODE_PROP_REGISTER_HUD_COLOR, // array [3]
	GAMEMODE_PROP_REGISTER_CHANCE, // int
	GAMEMODE_PROP_REGISTER_MIN_ALIVES, // int
	GAMEMODE_PROP_REGISTER_ROUND_TIME, // float
	GAMEMODE_PROP_REGISTER_CHANGE_CLASS, // bool
	GAMEMODE_PROP_REGISTER_DEATHMATCH // eGameModeDeathMatchType
}

native zpn_class_init();
native zpn_class_get_prop(const class_id, ePropsClassRegisters:prop, any:...);
native zpn_class_set_prop(const class_id, ePropsClassRegisters:prop, any:...);

native zpn_gamemode_init();
native zpn_gamemode_get_prop(const gamemode_id, ePropsGameModeRegisters:prop, any:...);
native zpn_gamemode_set_prop(const gamemode_id, ePropsGameModeRegisters:prop, any:...);