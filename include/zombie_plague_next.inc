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
* Executes when the player has been infected
*/
forward zpn_user_infected_post(const this, const infector, const class_id);

/*
* Executes when the player turned human
*/
forward zpn_user_humanized_post(const this, const class_id);

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
native zpn_class_get_prop(const class_id, ePropClassRegisters:prop, any:...);

/*
* Set property to class
*/
native zpn_class_set_prop(const class_id, ePropClassRegisters:prop, any:...);

/*
* Get current user class by type
*/
native zpn_class_get_user_current(const id, eClassTypes:type);

/*
* Return true if user is zombie
*/
native bool:zpn_is_user_zombie(const id);


/*
* Init new gamemode, use in: plugin_precache
*/
native zpn_gamemode_init();

/*
* Get property info from gamemode
*/
native zpn_gamemode_get_prop(const gamemode_id, ePropGameModeRegisters:prop, any:...);

/*
* Set property to gamemode
*/
native zpn_gamemode_set_prop(const gamemode_id, ePropGameModeRegisters:prop, any:...);

/*
* Init new extra item
*/
native zpn_item_init();

/*
* Get property info from item
*/
native zpn_item_get_prop(const item_id, ePropItemRegisters:prop, any:...);

/*
* Set property to item
*/
native zpn_item_set_prop(const item_id, ePropItemRegisters:prop, any:...);

/*
* Set player as zombie
*/
native bool:zpn_set_user_zombie(const this, const attacker, bool:set_first = false);

/*
* Send message with prefix.
*/
native zpn_print_color(id, sender, const msg[], any:...);