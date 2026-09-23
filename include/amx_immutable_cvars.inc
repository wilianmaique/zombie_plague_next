#if defined _amx_immutable_cvars_included
	#endinput
#endif
#define _amx_immutable_cvars_included

#pragma reqlib amx_immutable_cvars
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib amx_immutable_cvars
#endif

/**
 * Changes the protected value of an existing cvar for the current map.
 * Cvars absent from immutable_cvars.ini become protected as well.
 *
 * @return true if the cvar exists and its protected value was updated
 */
native bool:amx_immutable_cvar_set(const cvarName[], const value[]);
