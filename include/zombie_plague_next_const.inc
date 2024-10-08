#if defined _zombie_plague_next_const_included
	#endinput
#endif

#define _zombie_plague_next_const_included

#define zpn_is_invalid_array(%0) (%0 == Invalid_Array || !ArraySize(%0))
#define zpn_is_null_string(%0) bool:(%0[0] == EOS)

stock const PATH_SETTINGS_CONFIG[] = "zombie_plague_next/configs.json";
stock const PATH_SETTINGS_CLASSES[] = "zombie_plague_next/classes.json";
stock const SETTINGS_SECTION_CONFIG[] = "Main Config";

enum
{
	ZPN_RETURN_CONTINUE = 333,
	ZPN_RETURN_HANDLED,
}

enum eClassesType
{
	CLASS_TEAM_TYPE_ZOMBIE = 0,
	CLASS_TEAM_TYPE_HUMAN,
	CLASS_TEAM_TYPE_ZOMBIE_SPECIAL,
	CLASS_TEAM_TYPE_HUMAN_SPECIAL,
}

enum ePropsClassRegisters
{
	CLASS_PROP_REGISTER_TYPE, // eClassesType
	CLASS_PROP_REGISTER_NAME, // string
	CLASS_PROP_REGISTER_INFO, // string
	CLASS_PROP_REGISTER_MODEL, // string
	CLASS_PROP_REGISTER_MODEL_VIEW, // string
	CLASS_PROP_REGISTER_BODY, // int
	CLASS_PROP_REGISTER_HEALTH, // float
	CLASS_PROP_REGISTER_ARMOR, // float
	CLASS_PROP_REGISTER_SPEED, // float
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
	GAMEMODE_PROP_REGISTER_MIN_PLAYERS, // int
	GAMEMODE_PROP_REGISTER_ROUND_TIME, // float
	GAMEMODE_PROP_REGISTER_CHANGE_CLASS, // bool
	GAMEMODE_PROP_REGISTER_DEATHMATCH, // eGameModeDeathMatchType
	GAMEMODE_PROP_REGISTER_RESPAWN_TIME, // float
}