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

/*
* Executes when the round has started 
*/
forward zpn_round_started_post(const gamemode_id);

/*
* Init new class, use in: plugin_precache
*/
native zpn_class_init();

/*
* Get property info from class
*/
native zpn_class_get_prop(const class_id, ePropsClassRegisters:prop, any:...);

/*
* Set property to class
*/
native zpn_class_set_prop(const class_id, ePropsClassRegisters:prop, any:...);

/*
* Init new gamemode, use in: plugin_precache
*/
native zpn_gamemode_init();

/*
* Get property info from gamemode
*/
native zpn_gamemode_get_prop(const gamemode_id, ePropsGameModeRegisters:prop, any:...);

/*
* Set property to gamemode
*/
native zpn_gamemode_set_prop(const gamemode_id, ePropsGameModeRegisters:prop, any:...);

/*
* Set player as zombie
*/
native bool:zpn_set_user_zombie(const this, const attacker, bool:set_first = false);