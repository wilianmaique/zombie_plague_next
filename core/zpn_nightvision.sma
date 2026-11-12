#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

const SCREENFADE_SCALE = 1 << 12
const SCREENFADE_MIN_TIME = 4 // 0.001 seconds in the ScreenFade protocol
const SCREENFADE_MAX_TIME = 0xFFFF
const Float:DLIGHT_INTERVAL = 0.05

enum
{
	NIGHTVISION_NONE = 0,
	NIGHTVISION_DLIGHT,
	NIGHTVISION_LIGHTSTYLE,
}

enum _:eCvars
{
	CVAR_METHOD,
	CVAR_ALPHA,
	CVAR_LIGHTING,
	CVAR_DEFAULT_HUMAN_COLOR,
	CVAR_DEFAULT_ZOMBIE_COLOR,
}

new xCvars[eCvars], xMethod, xAlpha, xLighting[2], xDefaultColors[2][3]
new xMsgScreenFade, bool:xSendingFade
new xMapLighting[64] = "m", xLightingRevision, xPlayerLightingRevision[33]
new xAppliedMethod[33], bool:xClient[33], bool:xOverlayVisible[33]
new Float:xNextDlight[33], Float:xFadeUntil[33]
new xFadeOwner[33] // calling plugin id + 1; 0 = external fade or no API owner

public plugin_precache()
{
	register_forward(FM_LightStyle, "LightStyle_Post", true)
}

public plugin_init()
{
	register_plugin("[ZPN] Core: Nightvision", "1.0", "Wilian M.")

	RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink_Pre", false)
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false)

	register_clcmd("nightvision", "clcmd_nightvision")

	xMsgScreenFade = get_user_msgid("ScreenFade")
	RegisterMessage(xMsgScreenFade, "ScreenFade_Post", true)

	xCvars[CVAR_METHOD] = create_cvar("zpn_nightvision_method", "1", .description = "0 = original dynamic light; 1 = lightstyle + ScreenFade", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)
	xCvars[CVAR_ALPHA] = create_cvar("zpn_nightvision_alpha", "63", .description = "ScreenFade opacity for method 1 (0-255)", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 255.0)
	xCvars[CVAR_LIGHTING] = create_cvar("zpn_nightvision_lighting", "z", .flags = FCVAR_NOEXTRAWHITEPACE, .description = "Individual lighting for method 1, one letter a-z")
	xCvars[CVAR_DEFAULT_HUMAN_COLOR] = create_cvar("zpn_default_nv_h", "#00bbff", .flags = FCVAR_NOEXTRAWHITEPACE, .description = "Human nightvision color when the class has no nv_color")
	xCvars[CVAR_DEFAULT_ZOMBIE_COLOR] = create_cvar("zpn_default_nv_z", "#27e30e", .flags = FCVAR_NOEXTRAWHITEPACE, .description = "Zombie nightvision color when the class has no nv_color")

	for(new i = 0; i < eCvars; i++)
		hook_cvar_change(xCvars[i], "cvar_nightvision_changed")

	cache_settings()
	AutoExecConfig(true, "zpn_nightvision", FOLDER_CVARS_CONFIG)
}

public plugin_natives()
{
	register_library("zombie_plague_next_nightvision")

	register_native("zpn_set_user_fade", "_zpn_set_user_fade")
	register_native("zpn_remove_user_fade", "_zpn_remove_user_fade")
}

public OnConfigsExecuted()
{
	cache_settings()
	refresh_all_nightvision()
}

public plugin_end()
{
	for(new id = 1; id <= MaxClients; id++)
	{
		if(xClient[id] && is_user_connected(id))
		{
			clear_user_fade(id)
			clear_user_nightvision(id)
		}
	}
}

public client_putinserver(id)
{
	reset_user_nightvision(id)
	xClient[id] = !is_user_bot(id) && !is_user_hltv(id)
}

public client_disconnected(id)
{
	reset_user_nightvision(id)
}

public clcmd_nightvision(id)
{
	if(!zpn_is_valid_player_connected(id) || !xClient[id])
		return PLUGIN_HANDLED

	new Float:time = get_gametime()
	if(Float:get_member(id, m_flLastCommandTime, CMD_NIGHTVISION) > time)
		return PLUGIN_HANDLED

	set_member(id, m_flLastCommandTime, time + 0.3, CMD_NIGHTVISION)
	zpn_player_data_set_prop(id, PROP_PD_REGISTER_NV_ON, !zpn_player_data_get_prop(id, PROP_PD_REGISTER_NV_ON))
	update_user_nightvision(id)
	return PLUGIN_HANDLED
}

public CBasePlayer_PreThink_Pre(const this)
{
	if(xClient[this])
		update_user_nightvision(this)

	return HC_CONTINUE
}

public CBasePlayer_Spawn_Post(const this)
{
	if(!IsReapiHookOriginalWasCalled(RG_CBasePlayer_Spawn))
		return

	clear_user_fade(this)
	update_user_nightvision(this, true)
}

public CBasePlayer_Killed_Post(const this, pevAttacker, iGib)
{
	if(xClient[this] && IsReapiHookOriginalWasCalled(RG_CBasePlayer_Killed) && !is_user_alive(this))
	{
		clear_user_fade(this)
		clear_user_nightvision(this)
	}
}

public CSGameRules_RestartRound_Pre()
{
	for(new id = 1; id <= MaxClients; id++)
	{
		if(xClient[id] && is_user_connected(id) && clear_user_fade(id))
			update_user_nightvision(id, true)
	}
}

public zpn_user_infected_post(const this, const infector, const class_id)
{
	update_user_nightvision(this, true)
}

public zpn_user_humanized_post(const this, const class_id)
{
	update_user_nightvision(this, true)
}

public cvar_nightvision_changed(pcvar, const old_value[], const new_value[])
{
	cache_settings()
	refresh_all_nightvision()
}

public LightStyle_Post(const style, const value[])
{
	if(style == 0)
	{
		copy(xMapLighting, charsmax(xMapLighting), value)
		xLightingRevision++
	}

	return FMRES_IGNORED
}

public ScreenFade_Post(const msg_id, const msg_dest, const msg_entity)
{
	if(xSendingFade || GetMessageArgsNum() != 7)
		return HC_CONTINUE

	for(new i = 1; i <= 7; i++)
	{
		if(GetMessageArgType(i) != (i <= 3 ? ArgShort : ArgByte))
			return HC_CONTINUE
	}

	new flags = GetMessageData(MsgArg, 3)
	new Float:until = get_gametime()
	if(GetMessageData(MsgArg, 7))
	{
		if(flags & ZPN_FADE_STAYOUT)
			until = -1.0
		else
			until += float((GetMessageData(MsgArg, 1) & 0xFFFF) + (GetMessageData(MsgArg, 2) & 0xFFFF)) / float(SCREENFADE_SCALE)
	}

	// Read the final recipient/destination after other pre-hooks have edited them.
	new dest = GetMessageData(MsgDest)
	new id = GetMessageData(MsgTargetId)
	if(dest == MSG_ONE || dest == MSG_ONE_UNRELIABLE)
	{
		if(zpn_is_valid_player_connected(id) && xClient[id])
			track_screenfade(id, until)
	}
	else if(dest == MSG_ALL || dest == MSG_BROADCAST)
	{
		for(id = 1; id <= MaxClients; id++)
		{
			if(xClient[id] && is_user_connected(id))
				track_screenfade(id, until)
		}
	}

	return HC_CONTINUE
}

public bool:_zpn_set_user_fade(plugin_id, param_nums)
{
	if(param_nums != 7 || !xMsgScreenFade)
		return false

	new id = get_param(1)
	if(!zpn_is_valid_player_connected(id) || !xClient[id])
		return false

	new Float:time = get_param_f(3), Float:hold_time = get_param_f(4)
	new alpha = get_param(5), flags = get_param(6)
	if((_:time & 0x7F800000) == 0x7F800000 || (_:hold_time & 0x7F800000) == 0x7F800000
	|| !(0.0 <= time <= 16.0) || !(0.0 <= hold_time <= 16.0) || !(1 <= alpha <= 255)
	|| (flags & ~(ZPN_FADE_OUT | ZPN_FADE_MODULATE | ZPN_FADE_STAYOUT)))
		return false

	new rgb[3]
	get_array(2, rgb, sizeof rgb)
	for(new i = 0; i < sizeof rgb; i++)
	{
		if(!(0 <= rgb[i] <= 255))
			return false
	}

	new Float:now = get_gametime()
	if(!get_param(7) && xFadeOwner[id] != plugin_id + 1
	&& (xFadeUntil[id] < 0.0 || now < xFadeUntil[id]))
		return false

	new duration = clamp(floatround(time * SCREENFADE_SCALE, floatround_floor), SCREENFADE_MIN_TIME, SCREENFADE_MAX_TIME)
	new hold = clamp(floatround(hold_time * SCREENFADE_SCALE, floatround_floor), 0, SCREENFADE_MAX_TIME)
	track_screenfade(id, (flags & ZPN_FADE_STAYOUT) ? -1.0 : now + float(duration + hold) / float(SCREENFADE_SCALE))
	xFadeOwner[id] = plugin_id + 1
	send_user_screenfade(id, rgb, alpha, duration, hold, flags)
	return true
}

public bool:_zpn_remove_user_fade(plugin_id, param_nums)
{
	if(param_nums != 1)
		return false

	new id = get_param(1)
	if(!zpn_is_valid_player_connected(id) || !xClient[id] || xFadeOwner[id] != plugin_id + 1)
		return false

	if(!clear_user_fade(id))
		return false

	update_user_nightvision(id, true)
	return true
}

cache_settings()
{
	xMethod = get_pcvar_num(xCvars[CVAR_METHOD])
	xAlpha = get_pcvar_num(xCvars[CVAR_ALPHA])

	new value[64]
	get_pcvar_string(xCvars[CVAR_LIGHTING], value, charsmax(value))
	xLighting[0] = (value[0] >= 'a' && value[0] <= 'z' && !value[1]) ? value[0] : 'z'
	xLighting[1] = EOS

	get_pcvar_string(xCvars[CVAR_DEFAULT_HUMAN_COLOR], value, charsmax(value))
	if(!parse_hex_color(value, xDefaultColors[0]))
	{
		xDefaultColors[0][0] = xDefaultColors[0][1] = 0
		xDefaultColors[0][2] = 100
	}

	get_pcvar_string(xCvars[CVAR_DEFAULT_ZOMBIE_COLOR], value, charsmax(value))
	if(!parse_hex_color(value, xDefaultColors[1]))
	{
		xDefaultColors[1][0] = 100
		xDefaultColors[1][1] = xDefaultColors[1][2] = 0
	}
}

refresh_all_nightvision()
{
	for(new id = 1; id <= MaxClients; id++)
		update_user_nightvision(id, true)
}

reset_user_nightvision(id)
{
	xClient[id] = false
	xAppliedMethod[id] = NIGHTVISION_NONE
	xOverlayVisible[id] = false
	xNextDlight[id] = 0.0
	xFadeUntil[id] = 0.0
	xFadeOwner[id] = 0
	xPlayerLightingRevision[id] = 0
	zpn_player_data_set_prop(id, PROP_PD_REGISTER_NV_ON, false)
}

update_user_nightvision(id, bool:refresh = false)
{
	if(!xClient[id] || !is_user_connected(id))
		return

	new Float:time = get_gametime()
	if(xFadeOwner[id] && xFadeUntil[id] >= 0.0 && time >= xFadeUntil[id])
		xFadeOwner[id] = 0

	new method = NIGHTVISION_NONE
	if(is_user_alive(id) && zpn_player_data_get_prop(id, PROP_PD_REGISTER_NV_ON))
		method = xMethod ? NIGHTVISION_LIGHTSTYLE : NIGHTVISION_DLIGHT

	if(method != xAppliedMethod[id])
	{
		clear_user_nightvision(id)
		xAppliedMethod[id] = method
		refresh = true
	}

	if(method == NIGHTVISION_NONE)
		return

	if(method == NIGHTVISION_DLIGHT)
	{
		if(refresh || time >= xNextDlight[id])
		{
			send_user_dlight(id)
			xNextDlight[id] = time + DLIGHT_INTERVAL
		}
		return
	}

	if(refresh || xPlayerLightingRevision[id] != xLightingRevision)
	{
		send_user_lightstyle(id, xLighting)
		xPlayerLightingRevision[id] = xLightingRevision
	}

	// A flash or another fade temporarily owns the client's single fade layer.
	if((refresh || !xOverlayVisible[id]) && xFadeUntil[id] >= 0.0 && time >= xFadeUntil[id])
	{
		new rgb[3]
		get_user_nv_color(id, rgb)
		send_user_screenfade(id, rgb, xAlpha, 0, SCREENFADE_MIN_TIME, ZPN_FADE_OUT | ZPN_FADE_STAYOUT)
		xOverlayVisible[id] = true
	}
}

clear_user_nightvision(id)
{
	if(xAppliedMethod[id] == NIGHTVISION_LIGHTSTYLE)
	{
		send_user_lightstyle(id, xMapLighting)
		if(xOverlayVisible[id])
		{
			new rgb[3]
			send_user_screenfade(id, rgb, 0, SCREENFADE_MIN_TIME, 0, ZPN_FADE_IN)
		}
	}

	xAppliedMethod[id] = NIGHTVISION_NONE
	xOverlayVisible[id] = false
	xNextDlight[id] = 0.0
}

track_screenfade(id, Float:until)
{
	// Never send a nested message from the message hook. PreThink restores it.
	xOverlayVisible[id] = false
	xFadeUntil[id] = until
	xFadeOwner[id] = 0
}

bool:clear_user_fade(id)
{
	if(!xFadeOwner[id])
		return false

	xFadeOwner[id] = 0
	if(xFadeUntil[id] >= 0.0 && get_gametime() >= xFadeUntil[id])
		return false

	new rgb[3]
	track_screenfade(id, 0.0)
	send_user_screenfade(id, rgb, 0, SCREENFADE_MIN_TIME, 0, ZPN_FADE_IN)
	return true
}

get_user_nv_color(id, rgb[3])
{
	new class_id = zpn_get_user_current_class(id)
	if(0 <= class_id < zpn_class_array_size())
	{
		new color[12]
		zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_NV_COLOR, color, charsmax(color))
		if(!zpn_is_null_string(color))
		{
			zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_NV_COLOR_CONVERTED, rgb, sizeof(rgb))
			return
		}
	}

	new team = zpn_player_data_get_prop(id, PROP_PD_REGISTER_IS_ZOMBIE) ? 1 : 0
	for(new i = 0; i < sizeof(rgb); i++)
		rgb[i] = xDefaultColors[team][i]
}

send_user_dlight(id)
{
	new Float:origin[3]
	new rgb[3]
	get_entvar(id, var_origin, origin)
	get_user_nv_color(id, rgb)

	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, .player = id)
	write_byte(TE_DLIGHT)
	write_coord_f(origin[0])
	write_coord_f(origin[1])
	write_coord_f(origin[2])
	write_byte(40) // radius in tens of units, as in the original core
	write_byte(rgb[0])
	write_byte(rgb[1])
	write_byte(rgb[2])
	write_byte(1) // 0.1 second lifetime
	write_byte(0) // no decay
	message_end()
}

send_user_lightstyle(id, const lighting[])
{
	message_begin(MSG_ONE, SVC_LIGHTSTYLE, .player = id)
	write_byte(0)
	write_string(lighting)
	message_end()
}

send_user_screenfade(id, const rgb[3], alpha, duration, hold, flags)
{
	xSendingFade = true
	message_begin(MSG_ONE, xMsgScreenFade, .player = id)
	write_short(duration)
	write_short(hold)
	write_short(flags)
	write_byte(rgb[0])
	write_byte(rgb[1])
	write_byte(rgb[2])
	write_byte(alpha)
	message_end()
	xSendingFade = false
}
