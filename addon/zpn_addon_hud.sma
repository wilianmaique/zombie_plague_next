#include <amxmodx>
#include <reapi>

const HUD_HIDE_CAL = (1 << 0)
const HUD_HIDE_FLASH = (1 << 1)
const HUD_HIDE_ALL = (1 << 2)
const HUD_HIDE_RHA = (1 << 3)
const HUD_HIDE_TIMER = (1 << 4)
const HUD_HIDE_MONEY = (1 << 5)
const HUD_HIDE_CROSS = (1 << 6)
const HUD_DRAW_CROSS = (1 << 7)

const HIDE_GENERATE_CROSSHAIR = HUD_HIDE_FLASH|HUD_HIDE_RHA|HUD_HIDE_TIMER|HUD_HIDE_MONEY|HUD_DRAW_CROSS

enum _:eCvars
{
	CVAR_HIDE_CAL = 0,
	CVAR_HIDE_FLASH,
	CVAR_HIDE_ALL,
	CVAR_HIDE_RHA,
	CVAR_HIDE_TIMER,
	CVAR_HIDE_MONEY,
	CVAR_HIDE_CROSS,
	CVAR_DRAW_CROSS,
}

new xCvars[eCvars], xBitHudFlags

public plugin_init()
{
	register_plugin("[ZPN] Addon: Hud Controller", "1.0", "Wilian M.")

	RegisterHookChain(RG_CBasePlayer_Spawn, "xResetHUD", true)
	register_event("ResetHUD", "xResetHUD", "b")
	register_message(get_user_msgid("HideWeapon"), "xHideWeapon")

	xInit()
}

public OnConfigsExecuted() xInit();

public xCvarChanged(pcvar, const old_value[], const new_value[]) xInit();

public xInit()
{
	new flags

	for(new i; i < eCvars; i++)
	{
		if(get_pcvar_num(xCvars[i]))
			flags |= (1 << i)
	}

	if(flags == xBitHudFlags)
		return

	xBitHudFlags = flags

	for(new id = 1; id <= MaxClients; id++)
		xResetHUD(id)
}

public xResetHUD(id)
{
	if(!is_user_connected(id))
		return

	set_member(id, m_iClientHideHUD, -1)

	if(is_user_alive(id) && !((get_member(id, m_iHideHUD)|xBitHudFlags) & HUD_DRAW_CROSS))
		set_member(id, m_pClientActiveItem, NULLENT)
}

public xHideWeapon(msgid, msgdest, id)
{
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE

	new flags = get_msg_arg_int(1)|xBitHudFlags
	set_msg_arg_int(1, ARG_BYTE, flags)

	if((flags & HIDE_GENERATE_CROSSHAIR) && !(flags & HUD_DRAW_CROSS) && is_user_alive(id))
		set_member(id, m_pClientActiveItem, NULLENT)

	return PLUGIN_CONTINUE
}

public plugin_precache()
{
	xCvars[CVAR_HIDE_CAL] = create_cvar("zpn_hud_hide_cross_ammo_weaponlist", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)
	xCvars[CVAR_HIDE_FLASH] = create_cvar("zpn_hud_hide_flashlight", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)
	xCvars[CVAR_HIDE_ALL] = create_cvar("zpn_hud_hide_all", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)
	xCvars[CVAR_HIDE_RHA] = create_cvar("zpn_hud_hide_radar_health_armor", "1", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)
	xCvars[CVAR_HIDE_TIMER] = create_cvar("zpn_hud_hide_timer", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)
	xCvars[CVAR_HIDE_MONEY] = create_cvar("zpn_hud_hide_money", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)
	xCvars[CVAR_HIDE_CROSS] = create_cvar("zpn_hud_hide_crosshair", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)
	xCvars[CVAR_DRAW_CROSS] = create_cvar("zpn_hud_draw_crosshair", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)

	for(new i; i < eCvars; i++)
		hook_cvar_change(xCvars[i], "xCvarChanged")
}
