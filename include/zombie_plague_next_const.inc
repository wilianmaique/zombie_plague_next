#if defined _zombie_plague_next_const_included
	#endinput
#endif

#define _zombie_plague_next_const_included

#define zpn_is_valid_player_alive(%1) (1 <= %1 <= MaxClients && is_user_alive(%1) && is_user_connected(%1))
#define zpn_is_valid_player_connected(%1) (1 <= %1 <= MaxClients && is_user_connected(%1))
#define zpn_is_invalid_array(%0) (%0 == Invalid_Array || !ArraySize(%0))
#define zpn_is_null_string(%0) bool:(%0[0] == EOS)

stock const MAX_LEVEL = 10000

stock const PATH_SETTINGS_CONFIG[] = "zombie_plague_next/configs.json";
stock const PATH_SETTINGS_CLASSES[] = "zombie_plague_next/classes.json";
stock const PATH_SETTINGS_ITEMS[] = "zombie_plague_next/items.json";
stock const PATH_SETTINGS_GAMEMODES[] = "zombie_plague_next/gamemodes.json";
stock const SETTINGS_SECTION_CONFIG[] = "Main Config";
stock const SETTINGS_SECTION_CLASSES_ZOMBIE[] = "Zombies";
stock const SETTINGS_SECTION_CLASSES_ZOMBIE_SP[] = "Zombies Special";
stock const SETTINGS_SECTION_CLASSES_HUMAN[] = "Humans";
stock const SETTINGS_SECTION_CLASSES_HUMAN_SP[] = "Humans Special";

enum
{
	ZPN_RETURN_CONTINUE = 333,
	ZPN_RETURN_HANDLED,
	ZPN_RETURN_SUPERCED
}

enum eAmmoPackChangeReasons
{
	ZPN_AMMO_PACK_CHANGE_SET = 0,
	ZPN_AMMO_PACK_CHANGE_ADD,
	ZPN_AMMO_PACK_CHANGE_TAKE,
	ZPN_AMMO_PACK_CHANGE_DAMAGE_REWARD,
	ZPN_AMMO_PACK_CHANGE_ITEM_BUY,
}

// EM VEZ DE USAR ESS ENUM, USAR O ENUM DE eClassTypes para ficar mais dinamico, TROCAR DEPOIS.
enum eItemTeams
{
	ITEM_TEAM_ZOMBIE = 0,
	ITEM_TEAM_HUMAN,
}

enum eClassTypes
{
	CLASS_TEAM_TYPE_ZOMBIE = 0,
	CLASS_TEAM_TYPE_HUMAN,
	CLASS_TEAM_TYPE_ZOMBIE_SPECIAL,
	CLASS_TEAM_TYPE_HUMAN_SPECIAL,
}

enum ePropItemRegisters
{
	PROP_ITEM_REGISTER_NAME = 0, // string
	PROP_ITEM_REGISTER_FIND_NAME, // string
	PROP_ITEM_REGISTER_CMD_BUY, //
	PROP_ITEM_REGISTER_COST, // int
	PROP_ITEM_REGISTER_TEAM, // eItemTeams
	PROP_ITEM_REGISTER_LIMIT_PLAYER_PER_ROUND, // int
	PROP_ITEM_REGISTER_LIMIT_MAX_PER_ROUND, // int
	PROP_ITEM_REGISTER_LIMIT_PER_MAP, // int
	PROP_ITEM_REGISTER_MIN_ZOMBIES, // int
	PROP_ITEM_REGISTER_ALLOW_BUY_SPECIAL_MODS, // bool
	PROP_ITEM_REGISTER_FLAG, // int (flags ADMIN_RCON, etc...)
}

enum ePropClassRegisters
{
	PROP_CLASS_REGISTER_TYPE = 0, // eClassesType
	PROP_CLASS_REGISTER_NAME, // string
	PROP_CLASS_REGISTER_INFO, // string
	PROP_CLASS_REGISTER_MODEL, // string
	PROP_CLASS_REGISTER_MODEL_VIEW, // string
	PROP_CLASS_REGISTER_BODY, // int
	PROP_CLASS_REGISTER_HEALTH, // float
	PROP_CLASS_REGISTER_ARMOR, // float
	PROP_CLASS_REGISTER_SPEED, // float
	PROP_CLASS_REGISTER_GRAVITY, // float
	PROP_CLASS_REGISTER_KNOCKBACK, // float
	PROP_CLASS_REGISTER_CLAW_WEAPONLIST, // string
	PROP_CLASS_REGISTER_SKIN, // int
	PROP_CLASS_REGISTER_FIND_NAME, // string,
	PROP_CLASS_REGISTER_NV_COLOR, // string, hex format: #ff0000
	PROP_CLASS_REGISTER_NV_COLOR_CONVERTED, // array [3]
	PROP_CLASS_REGISTER_HIDE_MENU, // bool
	PROP_CLASS_REGISTER_UPDATE_HITBOX, // bool
	PROP_CLASS_REGISTER_MODEL_INDEX, // int
	PROP_CLASS_REGISTER_BLOOD_COLOR, // int
	PROP_CLASS_REGISTER_SILENT_FOOTSTEPS, // bool
	PROP_CLASS_REGISTER_LIMIT, // int
	PROP_CLASS_REGISTER_LEVEL, // int
}

enum eGameModeDeathMatchTypes
{
	GAMEMODE_DEATHMATCH_DISABLED = 0,
	GAMEMODE_DEATHMATCH_ONLY_TR,
	GAMEMODE_DEATHMATCH_ONLY_CT,
	GAMEMODE_DEATHMATCH_RANDOM,
	GAMEMODE_DEATHMATCH_BALANCE,
}

enum ePropGameModeRegisters
{
	PROP_GAMEMODE_REGISTER_NAME = 0, // string
	PROP_GAMEMODE_REGISTER_NOTICE, // string
	PROP_GAMEMODE_REGISTER_HUD_COLOR, // string, hex format: #ff0000
	PROP_GAMEMODE_REGISTER_HUD_COLOR_CONVERTED, // array [3]
	PROP_GAMEMODE_REGISTER_CHANCE, // int
	PROP_GAMEMODE_REGISTER_MIN_PLAYERS, // int
	PROP_GAMEMODE_REGISTER_ROUND_TIME, // float
	PROP_GAMEMODE_REGISTER_CHANGE_CLASS, // bool
	PROP_GAMEMODE_REGISTER_DEATHMATCH, // eGameModeDeathMatchTypes
	PROP_GAMEMODE_REGISTER_RESPAWN_TIME, // float
	PROP_GAMEMODE_REGISTER_FIND_NAME, // string
}

enum ePropPlayerDataRegisters
{
	PROP_PD_REGISTER_CURRENT_SELECTED_ZOMBIE_CLASS, // int
	PROP_PD_REGISTER_CURRENT_SELECTED_HUMAN_CLASS, // int
	PROP_PD_REGISTER_IS_ZOMBIE, // bool
	PROP_PD_REGISTER_IS_FIRST_ZOMBIE, // bool
	PROP_PD_REGISTER_PRIMARY_WEAPON, // int
	PROP_PD_REGISTER_SECONDARY_WEAPON, // int
	PROP_PD_REGISTER_CLASS_TIMEOUT, // float
	PROP_PD_REGISTER_LAST_LEAP_TIMEOUT, // float
	PROP_PD_REGISTER_IS_LAST_HUMAN,
	PROP_PD_REGISTER_NV_ON, // bool
	PROP_PD_REGISTER_NV_SPAM, // float
	PROP_PD_REGISTER_AMMO_PACKS, // int
	PROP_PD_REGISTER_DMG_DEALT, // float
	PROP_PD_REGISTER_NEXT_ZOMBIE_CLASS, // int
	PROP_PD_REGISTER_NEXT_HUMAN_CLASS, // int
	PROP_PD_REGISTER_CURRENT_TEMP_ZOMBIE_CLASS, // int
	PROP_PD_REGISTER_CURRENT_TEMP_HUMAN_CLASS, // int
	PROP_PD_REGISTER_LEVEL, // int
	PROP_PD_REGISTER_IS_FREEZED, // bool
}

stock create_slug(const input[], output[], maxlen)
{
	new Regex:rx_slug = regex_compile("[^^a-z0-9]+|^^-+|-+$|[áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ]")
	new replaced[256]

	copy(replaced, charsmax(replaced), input)
	strtolower(replaced)

	regex_replace(rx_slug, replaced, charsmax(replaced), "-")
	copy(output, maxlen, replaced)

	regex_free(rx_slug)

	return strlen(output)
}

stock bool:parse_hex_color(const hexColor[], rgb[3])
{
	if (hexColor[0] != '#' || strlen(hexColor) != 7)
		return false

	for (new i = 0; i < 3; i++)
		rgb[i] = (__parse_hex_color(hexColor[1 + i * 2]) * 16 + __parse_hex_color(hexColor[2 + i * 2]))

	return true
}

stock __parse_hex_color(const c)
{
	return (c >= '0' && c <= '9') ? (c - '0') : (c >= 'a' && c <= 'f') ? (10 + c - 'a') : (c >= 'A' && c <= 'F') ? (10 + c - 'A') : 0
}

stock precache_player_model(const modelname[])
{
	static longname[128], index
	formatex(longname, charsmax(longname), "models/player/%s/%s.mdl", modelname, modelname)
	index = precache_model(longname)

	copy(longname[strlen(longname)-4], charsmax(longname) - (strlen(longname)-4), "T.mdl")

	if(file_exists(longname))
		precache_model(longname)

	return index
}
