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
* Executes before the player is infected
* Set params: this = 1, infector = 2, class_id = 3
*/
forward zpn_user_infected_pre(const this, const infector, const class_id);

/*
* Executes when the player has been infected
*/
forward zpn_user_infected_post(const this, const infector, const class_id);

/*
* Run before 'infected_pre', can use 'ZPN_RETURN_HANDLED' to block infection
*/
forward zpn_user_infect_attempt(const this, const infector, const class_id);

/*
* Executes when the player has buyed item
*/
forward zpn_item_selected_post(const this, const item_id);

/*
* Executes before he turns into a human, you can force a class and ignore his selected class.
*/
forward zpn_user_humanized_pre(const this, const class_id);

/*
* Executes when the player turned human
*/
forward zpn_user_humanized_post(const this, const class_id);

/*
* Executes when the round has started 
*/
forward zpn_round_started_post(const gamemode_id);

/*
* Changes the value of a parameter, typically used in forwards
*/
native zpn_set_fw_param_int(const param, const value);

/*
* Returns a random class id by type
*/
native zpn_class_random_class_id(eClassTypes:type);

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
* Get current user selected class by type
*/
native zpn_get_user_selected_class(const id, eClassTypes:type, bool:check_temp = false);

/*
* Returns class_id >= 0 if found or -1 if not found
*/
native zpn_class_find(const class_find_name[]);

/*
* Return true if user is zombie 'special', nemesis, assasin, etc..
*/
native bool:zpn_is_user_zombie_special(const id);

/*
* Return true if user is zombie
*/
native bool:zpn_is_user_zombie(const id);

/*
* Returns gamemode_id >= 0 if found or -1 if not found
*/
native zpn_gamemode_find(const gamemode_find_name[]);

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
* Get current gamemode_id >= 0 valid. -1 error
*/
native zpn_gamemode_current();

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
native zpn_print_color(const id, const sender, const msg[], any:...);

/*
* Check is round started
*/
native bool:zpn_is_round_started();


/*
* Send deploy weapon to user.
*/
native zpn_send_weapon_deploy(const this);