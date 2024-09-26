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

	register_event("HLTV", "xNewRound", "a", "1=0", "2=0")

	RegisterHookChain(RG_CBasePlayer_Spawn, "xResetHUD", true)
	register_event("ResetHUD", "xResetHUD", "b")
	register_event("HideWeapon", "xHideWeapon", "b")

	xInit()
}

public xNewRound() xInit();

public xInit()
{
	for(new i; i < eCvars; i++)
	{
		if(xCvars[i])
			xBitHudFlags |= (1 << i)
		else xBitHudFlags &= ~(1 << i)
	}
}

public xResetHUD(id)
{
	if(!is_user_connected(id))
		return

	set_member(id, m_iClientHideHUD, 0)
	set_member(id, m_iHideHUD, xBitHudFlags)
}

public xHideWeapon(id)
{
	if(!is_user_connected(id))
		return

	new flags = read_data(1)

	if(xBitHudFlags && (flags & xBitHudFlags != xBitHudFlags))
	{
		set_member(id, m_iClientHideHUD, 0)
		set_member(id, m_iHideHUD, flags|xBitHudFlags)
	}

	if(flags & HIDE_GENERATE_CROSSHAIR && !(xBitHudFlags & HUD_DRAW_CROSS) && is_user_alive(id))
		set_member(id, m_pClientActiveItem, NULLENT)
}

public plugin_precache()
{
	bind_pcvar_num(create_cvar("zpn_hud_hide_cross_ammo_weaponlist", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_HIDE_CAL])
	bind_pcvar_num(create_cvar("zpn_hud_hide_flashlight", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_HIDE_FLASH])
	bind_pcvar_num(create_cvar("zpn_hud_hide_all", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_HIDE_ALL])
	bind_pcvar_num(create_cvar("zpn_hud_hide_radar_health_armor", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_HIDE_RHA])
	bind_pcvar_num(create_cvar("zpn_hud_hide_timer", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_HIDE_TIMER])
	bind_pcvar_num(create_cvar("zpn_hud_hide_money", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_HIDE_MONEY])
	bind_pcvar_num(create_cvar("zpn_hud_hide_crosshair", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_HIDE_CROSS])
	bind_pcvar_num(create_cvar("zpn_hud_draw_crosshair", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_DRAW_CROSS])
}