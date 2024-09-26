#include <amxmodx>
#include <reapi>
#include <zombie_plague_next>

new gamemode

public plugin_init()
{
	register_plugin("[ZPN] GameMode: Infection", "1.0", "Wilian M.")
}

public plugin_precache()
{
	gamemode = zpn_gamemode_init()
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_NAME, "Infection")
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_NOTICE, "Mode Infection Started!")
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_HUD_COLOR, { 255, 0, 255 })
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_CHANCE, 20)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_MIN_ALIVES, 1)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_ROUND_TIME, 5.0)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_CHANGE_CLASS, true)
	zpn_gamemode_set_prop(gamemode, GAMEMODE_PROP_REGISTER_DEATHMATCH, GAMEMODE_DEATHMATCH_ONLY_TR)
}