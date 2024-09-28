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

native zpn_class_init();
native zpn_class_get_prop(const class_id, ePropsClassRegisters:prop, any:...);
native zpn_class_set_prop(const class_id, ePropsClassRegisters:prop, any:...);

native zpn_gamemode_init();
native zpn_gamemode_get_prop(const gamemode_id, ePropsGameModeRegisters:prop, any:...);
native zpn_gamemode_set_prop(const gamemode_id, ePropsGameModeRegisters:prop, any:...);