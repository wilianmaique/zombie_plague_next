// vim: set ts=4 sw=4 tw=99 noet:
//
// Zombie Plague Next public API.

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

/**
 * Called before a client is frozen.
 *
 * @param this      Client index
 *
 * @return          ZPN_RETURN_CONTINUE to allow the freeze
 *                  ZPN_RETURN_HANDLED or higher to block it
 */
forward zpn_user_frozen_pre(const this);

/**
 * Called after a client has been frozen.
 *
 * @param this      Client index
 *
 * @noreturn
 */
forward zpn_user_frozen_post(const this);

/**
 * Called before a client is infected and receives the zombie class.
 *
 * @note The forwarded integer parameters can be changed with
 *       zpn_set_fw_param_int().
 * @note Parameter ids used by zpn_set_fw_param_int() in this forward:
 *         1 - infected client index
 *         2 - infector client index
 *         3 - zombie class index
 *
 * @param this      Client index being infected
 * @param infector  Infector client index, or 0 if there is no direct infector
 * @param class_id  Zombie class index that will be applied
 *
 * @noreturn
 */
forward zpn_user_infected_pre(const this, const infector, const class_id);

/**
 * Called after a client has been infected and the zombie class was applied.
 *
 * @param this      Infected client index
 * @param infector  Infector client index, or 0 if there was no direct infector
 * @param class_id  Applied zombie class index
 *
 * @noreturn
 */
forward zpn_user_infected_post(const this, const infector, const class_id);

/**
 * Called before the infection pre-forward.
 *
 * @note Return ZPN_RETURN_HANDLED or higher to block the infection before any
 *       class data is applied.
 *
 * @param this      Client index being infected
 * @param infector  Infector client index, or 0 if there is no direct infector
 * @param class_id  Zombie class index selected for the infection
 *
 * @return          ZPN_RETURN_CONTINUE to allow the infection
 *                  ZPN_RETURN_HANDLED or higher to block it
 */
forward zpn_user_infect_attempt(const this, const infector, const class_id);

/**
 * Called after a client selects an extra item from the buy menu.
 *
 * @param this      Client index
 * @param item_id   Extra item index
 *
 * @noreturn
 */
forward zpn_item_selected_post(const this, const item_id);

/**
 * Called before a client is humanized and receives the human class.
 *
 * @note The forwarded integer parameters can be changed with
 *       zpn_set_fw_param_int().
 * @note Parameter ids used by zpn_set_fw_param_int() in this forward:
 *         1 - humanized client index
 *         2 - human class index
 *
 * @param this      Client index being humanized
 * @param class_id  Human class index that will be applied
 *
 * @noreturn
 */
forward zpn_user_humanized_pre(const this, const class_id);

/**
 * Called after a client has been humanized and the human class was applied.
 *
 * @param this      Humanized client index
 * @param class_id  Applied human class index
 *
 * @noreturn
 */
forward zpn_user_humanized_post(const this, const class_id);

/**
 * Called after a round has started and the game mode was selected.
 *
 * @param gamemode_id  Current game mode index
 *
 * @noreturn
 */
forward zpn_round_started_post(const gamemode_id);

/**
 * Changes an integer parameter value for supported pre-forwards.
 *
 * @note This is intended for mutable ZPN forwards, such as
 *       zpn_user_infected_pre() and zpn_user_humanized_pre().
 * @note Parameter ids are forward-specific and start at 1.
 *
 * @param param     Forward parameter id to change
 * @param value     New integer value
 *
 * @noreturn
 */
native zpn_set_fw_param_int(const param, const value);

/**
 * Returns a random registered class index for the given class type.
 *
 * @param type      Class type
 *
 * @return          Class index
 */
native zpn_class_random_class_id(eClassTypes:type);

/**
 * Registers a new class.
 *
 * @note This should be called from plugin_precache().
 *
 * @param name      Default display name
 * @param type      Class type
 *
 * @return          New class index, or -1 on failure
 */
native zpn_class_init(const name[], eClassTypes:type);

/**
 * Retrieves a class property.
 *
 * @note For string properties, pass an output buffer and its maximum length
 *       after the property id.
 * @note For array properties, pass an output array and its maximum length after
 *       the property id.
 *
 * @param class_id  Class index
 * @param prop      Property to retrieve, from ePropClassRegisters
 * @param ...       Output buffer and length for string or array properties
 *
 * @return          Property value for scalar properties, 1 for copied
 *                  string/array properties, or 0 if class storage is unavailable
 * @error           If class_id is not a valid class index, an error can be
 *                  thrown by the underlying array access.
 */
native any:zpn_class_get_prop(const class_id, ePropClassRegisters:prop, any:...);

/**
 * Sets a class property.
 *
 * @note For model-related properties, call this from plugin_precache() so
 *       models can be precached safely.
 * @note The expected value type depends on the property. See
 *       ePropClassRegisters in zombie_plague_next_const.inc.
 *
 * @param class_id  Class index
 * @param prop      Property to set, from ePropClassRegisters
 * @param ...       New property value
 *
 * @return          1 on success, 0 if class storage is unavailable
 * @error           If class_id is not a valid class index, an error can be
 *                  thrown by the underlying array access.
 */
native zpn_class_set_prop(const class_id, ePropClassRegisters:prop, any:...);

/**
 * Returns the class selected by a client for the given class type.
 *
 * @note Only CLASS_TEAM_TYPE_ZOMBIE and CLASS_TEAM_TYPE_HUMAN are stored as
 *       selectable classes.
 *
 * @param id        Client index
 * @param type      Class type
 *
 * @return          Selected class index, or -1 if the client is not connected
 *                  or the type is not selectable
 */
native zpn_get_user_selected_class(const id, eClassTypes:type);

/**
 * Returns the class queued by a client for the next class update.
 *
 * @note Only CLASS_TEAM_TYPE_ZOMBIE and CLASS_TEAM_TYPE_HUMAN are stored as
 *       queued selectable classes.
 *
 * @param id        Client index
 * @param type      Class type
 *
 * @return          Queued class index, or -1 if no class is queued, the client
 *                  is not connected, or the type is not selectable
 */
native zpn_get_user_next_class(const id, eClassTypes:type);

/**
 * Returns the currently applied class for a client.
 *
 * @param id        Client index
 *
 * @return          Current class index, or -1 if the client is not connected
 */
native zpn_get_user_current_class(const id);

/**
 * Returns whether a client currently has the given class applied.
 *
 * @param id        Client index
 * @param class_id  Class index to compare against
 *
 * @return          true if the client currently has the class, false otherwise
 */
native bool:zpn_is_user_class(const id, const class_id);

/**
 * Finds a class by its configured find name.
 *
 * @note The name is matched against PROP_CLASS_REGISTER_FIND_NAME.
 *
 * @param class_find_name  Find name to search for
 *
 * @return          Class index if found, -1 otherwise
 */
native zpn_class_find(const class_find_name[]);

/**
 * Returns the number of registered classes.
 *
 * @return          Number of classes registered in the class storage
 */
native zpn_class_array_size();

/**
 * Returns whether a client is using a special zombie class.
 *
 * @param id        Client index
 *
 * @return          true if the client is connected, is a zombie, and the
 *                  current class type is CLASS_TEAM_TYPE_ZOMBIE_SPECIAL;
 *                  false otherwise
 */
native bool:zpn_is_user_zombie_special(const id);

/**
 * Returns whether a client is currently a zombie.
 *
 * @param id        Client index
 *
 * @return          true if the client is connected and is a zombie, false
 *                  otherwise
 */
native bool:zpn_is_user_zombie(const id);

/**
 * Finds a game mode by its configured find name.
 *
 * @note The name is matched against PROP_GAMEMODE_REGISTER_FIND_NAME.
 *
 * @param gamemode_find_name  Find name to search for
 *
 * @return          Game mode index if found, -1 otherwise
 */
native zpn_gamemode_find(const gamemode_find_name[]);

/**
 * Registers a new game mode.
 *
 * @note This should be called from plugin_precache().
 *
 * @return          New game mode index
 */
native zpn_gamemode_init();

/**
 * Retrieves a game mode property.
 *
 * @note For string properties, pass an output buffer and its maximum length
 *       after the property id.
 * @note For array properties, pass an output array and its maximum length after
 *       the property id.
 *
 * @param gamemode_id  Game mode index
 * @param prop         Property to retrieve, from ePropGameModeRegisters
 * @param ...          Output buffer and length for string or array properties
 *
 * @return          Property value for scalar properties, 1 for copied
 *                  string/array properties, or 0 if game mode storage is
 *                  unavailable
 * @error           If gamemode_id is not a valid game mode index, an error can
 *                  be thrown by the underlying array access.
 */
native any:zpn_gamemode_get_prop(const gamemode_id, ePropGameModeRegisters:prop, any:...);

/**
 * Sets a game mode property.
 *
 * @note The expected value type depends on the property. See
 *       ePropGameModeRegisters in zombie_plague_next_const.inc.
 *
 * @param gamemode_id  Game mode index
 * @param prop         Property to set, from ePropGameModeRegisters
 * @param ...          New property value
 *
 * @return          1 on success, 0 if game mode storage is unavailable
 * @error           If gamemode_id is not a valid game mode index, an error can
 *                  be thrown by the underlying array access.
 */
native zpn_gamemode_set_prop(const gamemode_id, ePropGameModeRegisters:prop, any:...);

/**
 * Returns the current game mode.
 *
 * @return          Current game mode index, or -1 if no game mode is available
 */
native zpn_get_current_gamemode();

/**
 * Returns the number of registered game modes.
 *
 * @return          Number of game modes registered in the game mode storage
 */
native zpn_gamemode_array_size();

/**
 * Registers a new extra item.
 *
 * @note This should be called from plugin_precache().
 *
 * @return          New extra item index
 */
native zpn_item_init();

/**
 * Retrieves an extra item property.
 *
 * @note For string properties, pass an output buffer and its maximum length
 *       after the property id.
 *
 * @param item_id   Extra item index
 * @param prop      Property to retrieve, from ePropItemRegisters
 * @param ...       Output buffer and length for string properties
 *
 * @return          Property value for scalar properties, 1 for copied string
 *                  properties, or 0 if item storage is unavailable
 * @error           If item_id is not a valid extra item index, an error can be
 *                  thrown by the underlying array access.
 */
native any:zpn_item_get_prop(const item_id, ePropItemRegisters:prop, any:...);

/**
 * Sets an extra item property.
 *
 * @note The expected value type depends on the property. See
 *       ePropItemRegisters in zombie_plague_next_const.inc.
 *
 * @param item_id   Extra item index
 * @param prop      Property to set, from ePropItemRegisters
 * @param ...       New property value
 *
 * @return          1 on success, 0 if item storage is unavailable
 * @error           If item_id is not a valid extra item index, an error can be
 *                  thrown by the underlying array access.
 */
native zpn_item_set_prop(const item_id, ePropItemRegisters:prop, any:...);

/**
 * Finds an extra item by its configured find name.
 *
 * @note The name is matched against PROP_ITEM_REGISTER_FIND_NAME.
 *
 * @param item_find_name  Find name to search for
 *
 * @return          Extra item index if found, -1 otherwise
 */
native zpn_item_find(const item_find_name[]);

/**
 * Returns the number of registered extra items.
 *
 * @return          Number of extra items registered in the item storage
 */
native zpn_item_array_size();

/**
 * Retrieves a client data property.
 *
 * @note This is a low-level accessor. Prefer the specific helper natives when
 *       one exists for the value you need.
 *
 * @param player    Client index
 * @param prop      Property to retrieve, from ePropPlayerDataRegisters
 * @param ...       Reserved for future property-specific outputs
 *
 * @return          Property value, or 1 if the property is not handled
 * @error           If player is not within the valid client range, an error can
 *                  be thrown by the underlying array access.
 */
native any:zpn_player_data_get_prop(const player, ePropPlayerDataRegisters:prop, any:...);

/**
 * Sets a client data property.
 *
 * @note This is a low-level accessor. Prefer the specific helper natives when
 *       one exists for the value you need.
 * @note The expected value type depends on the property. See
 *       ePropPlayerDataRegisters in zombie_plague_next_const.inc.
 *
 * @param player    Client index
 * @param prop      Property to set, from ePropPlayerDataRegisters
 * @param ...       New property value
 *
 * @return          1 on success
 * @error           If player is not within the valid client range, an error can
 *                  be thrown by the underlying array access.
 */
native zpn_player_data_set_prop(const player, ePropPlayerDataRegisters:prop, any:...);

/**
 * Infects a client and applies the selected zombie class.
 *
 * @note This calls zpn_user_infect_attempt(), zpn_user_infected_pre(), and
 *       zpn_user_infected_post() when the infection is not blocked.
 *
 * @param this      Client index to infect
 * @param attacker  Infector client index, or 0 if there is no direct infector
 * @param set_first Whether the client should be marked as the first zombie
 *
 * @return          true on successful infection, false if the client is not
 *                  alive or the infection was blocked
 */
native bool:zpn_set_user_zombie(const this, const attacker, bool:set_first = false);

/**
 * Sends a prefixed colored chat message.
 *
 * @note This wraps client_print_color() and prepends the configured chat prefix.
 * @note Use 0 as id to send to all connected clients.
 *
 * @param id        Client index, or 0 for all clients
 * @param sender    Client index or print_team_* constant used for team color
 * @param msg       Formatting rules
 * @param ...       Variable number of formatting parameters
 *
 * @return          Number of printed characters
 * @error           If a single client is specified and the index is not within
 *                  the range of 1 to MaxClients, an error can be thrown by
 *                  client_print_color().
 */
native zpn_print_color(const id, const sender, const msg[], any:...);

/**
 * Returns whether a ZPN round is currently active.
 *
 * @return          true if the round has started, false otherwise
 */
native bool:zpn_is_round_started();

/**
 * Sends the current weapon deploy animation to a client.
 *
 * @param this      Client index
 *
 * @return          1 if the deploy request was sent, 0 otherwise
 */
native zpn_send_weapon_deploy(const this);

/**
 * Freezes a client for a limited time.
 *
 * @note This calls zpn_user_frozen_pre() before applying the frozen state and
 *       zpn_user_frozen_post() after the state is applied.
 * @note The time value is clamped internally between 0.1 and 60.0 seconds.
 *
 * @param this       Client index
 * @param time       Freeze duration in seconds
 * @param reset_time Whether an existing freeze task should be replaced
 * @param play_sound Whether a freeze sound should be played
 *
 * @return          true if the client was frozen, false if the forward blocked
 *                  the freeze
 */
native bool:zpn_set_user_frozen(const this, const Float:time = 3.0, const bool:reset_time = false, const bool:play_sound = true);

/**
 * Removes the frozen state from a client.
 *
 * @param this      Client index
 *
 * @return          true if the unfreeze routine was executed, false otherwise
 */
native bool:zpn_remove_user_frozen(const this);

/**
 * Returns whether a client is currently frozen.
 *
 * @param this      Client index
 *
 * @return          true if the client is frozen, false otherwise
 */
native bool:zpn_is_user_freezed(const this);
