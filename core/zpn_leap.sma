#include <amxmodx>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

enum _:ePropLeap
{
	bool:LEAP_ENABLED,
	Float:LEAP_FORCE,
	Float:LEAP_HEIGHT,
	Float:LEAP_COOLDOWN,
	Float:LEAP_MIN_SPEED,
}

new xPlayerLeap[33][ePropLeap], bool:xLeaping[33]
new HookChain:xPreThinkHook, xEnabledPlayers
new xForwardLeapPre, xForwardLeapPost

public plugin_init()
{
	register_plugin("[ZPN] Core: Leap", "1.0", "Wilian M.")

	xPreThinkHook = RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink_Pre", false)
	if(!xEnabledPlayers)
		DisableHookChain(xPreThinkHook)

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Pre", false)
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false)
	RegisterHookChain(RG_RoundEnd, "RoundEnd_Pre", false)

	xForwardLeapPre = CreateMultiForward("zpn_user_leap_pre", ET_CONTINUE, FP_CELL)
	xForwardLeapPost = CreateMultiForward("zpn_user_leap_post", ET_IGNORE, FP_CELL)
}

public plugin_natives()
{
	register_library("zombie_plague_next_leap")

	register_native("zpn_set_user_leap", "_zpn_set_user_leap")
	register_native("zpn_get_user_leap", "_zpn_get_user_leap")
	register_native("zpn_is_user_leap_enabled", "_zpn_is_user_leap_enabled")
	register_native("zpn_reset_user_leap", "_zpn_reset_user_leap")
	register_native("zpn_get_user_leap_cooldown", "_zpn_get_user_leap_cooldown")
	register_native("zpn_set_user_leap_cooldown", "_zpn_set_user_leap_cooldown")
	register_native("zpn_do_user_leap", "_zpn_do_user_leap")
}

public client_putinserver(id)
{
	clear_user_leap(id)
}

public client_disconnected(id)
{
	clear_user_leap(id)
}

public CBasePlayer_Spawn_Pre(const this)
{
	// The main core applies the new class before its infected/humanized post-forward.
	clear_user_leap(this)
}

public CBasePlayer_Killed_Post(const this, pevAttacker, iGib)
{
	clear_user_leap(this)
}

public CSGameRules_RestartRound_Pre()
{
	for(new id = 1; id <= MaxClients; id++)
	{
		if(is_user_connected(id))
			clear_user_leap(id)
	}
}

public RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event, Float:delay)
{
	for(new id = 1; id <= MaxClients; id++)
	{
		if(is_user_connected(id))
			zpn_player_data_set_prop(id, PROP_PD_REGISTER_LAST_LEAP_TIMEOUT, 0.0)
	}
}

public CBasePlayer_PreThink_Pre(const this)
{
	if(!xPlayerLeap[this][LEAP_ENABLED] || !is_user_alive(this))
		return HC_CONTINUE

	if((get_entvar(this, var_button) & (IN_JUMP | IN_DUCK)) == (IN_JUMP | IN_DUCK))
		do_user_leap(this)

	return HC_CONTINUE
}

public bool:_zpn_set_user_leap(plugin_id, param_nums)
{
	if(param_nums != 6)
		return false

	return set_user_leap(get_param(1), get_param(2) != 0, get_param_f(3), get_param_f(4), get_param_f(5), get_param_f(6))
}

public bool:_zpn_get_user_leap(plugin_id, param_nums)
{
	if(param_nums != 6)
		return false

	new id = get_param(1)
	if(!zpn_is_valid_player_connected(id))
		return false

	set_param_byref(2, xPlayerLeap[id][LEAP_ENABLED])
	set_float_byref(3, xPlayerLeap[id][LEAP_FORCE])
	set_float_byref(4, xPlayerLeap[id][LEAP_HEIGHT])
	set_float_byref(5, xPlayerLeap[id][LEAP_COOLDOWN])
	set_float_byref(6, xPlayerLeap[id][LEAP_MIN_SPEED])
	return true
}

public bool:_zpn_is_user_leap_enabled(plugin_id, param_nums)
{
	if(param_nums != 1)
		return false

	new id = get_param(1)
	return zpn_is_valid_player_connected(id) && xPlayerLeap[id][LEAP_ENABLED]
}

public bool:_zpn_reset_user_leap(plugin_id, param_nums)
{
	if(param_nums != 1)
		return false

	new id = get_param(1)
	if(!zpn_is_valid_player_connected(id))
		return false

	clear_user_leap(id)

	new class_id = zpn_get_user_current_class(id)
	if(class_id < 0 || class_id >= zpn_class_array_size())
		return false

	return set_user_leap(id,
		bool:zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_LEAP_ENABLED),
		Float:zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_LEAP_FORCE),
		Float:zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_LEAP_HEIGHT),
		Float:zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_LEAP_COOLDOWN),
		Float:zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_LEAP_MIN_SPEED))
}

public Float:_zpn_get_user_leap_cooldown(plugin_id, param_nums)
{
	if(param_nums != 1)
		return 0.0

	new id = get_param(1)
	if(!zpn_is_valid_player_connected(id))
		return 0.0

	return floatmax(0.0, Float:zpn_player_data_get_prop(id, PROP_PD_REGISTER_LAST_LEAP_TIMEOUT) - get_gametime())
}

public bool:_zpn_set_user_leap_cooldown(plugin_id, param_nums)
{
	if(param_nums != 2)
		return false

	new id = get_param(1)
	new Float:seconds = get_param_f(2)
	if(!zpn_is_valid_player_connected(id) || seconds < 0.0)
		return false

	zpn_player_data_set_prop(id, PROP_PD_REGISTER_LAST_LEAP_TIMEOUT, get_gametime() + seconds)
	return true
}

public bool:_zpn_do_user_leap(plugin_id, param_nums)
{
	if(param_nums != 1)
		return false

	return do_user_leap(get_param(1))
}

bool:set_user_leap(id, bool:enabled, Float:force, Float:height, Float:cooldown, Float:min_speed)
{
	if(!zpn_is_valid_player_connected(id) || force < 0.0 || height < 0.0 || cooldown < 0.0 || min_speed < 0.0)
		return false

	xPlayerLeap[id][LEAP_FORCE] = force
	xPlayerLeap[id][LEAP_HEIGHT] = height
	xPlayerLeap[id][LEAP_COOLDOWN] = cooldown
	xPlayerLeap[id][LEAP_MIN_SPEED] = min_speed
	set_user_leap_enabled(id, enabled)
	return true
}

set_user_leap_enabled(id, bool:enabled)
{
	if(xPlayerLeap[id][LEAP_ENABLED] == enabled)
		return

	xPlayerLeap[id][LEAP_ENABLED] = enabled
	xEnabledPlayers += enabled ? 1 : -1

	if(!xPreThinkHook)
		return

	if(enabled && xEnabledPlayers == 1)
		EnableHookChain(xPreThinkHook)
	else if(!xEnabledPlayers)
		DisableHookChain(xPreThinkHook)
}

clear_user_leap(id)
{
	set_user_leap_enabled(id, false)
	xPlayerLeap[id][LEAP_FORCE] = 500.0
	xPlayerLeap[id][LEAP_HEIGHT] = 300.0
	xPlayerLeap[id][LEAP_COOLDOWN] = 5.0
	xPlayerLeap[id][LEAP_MIN_SPEED] = 80.0
	zpn_player_data_set_prop(id, PROP_PD_REGISTER_LAST_LEAP_TIMEOUT, 0.0)
}

bool:can_user_leap(id)
{
	if(!zpn_is_valid_player_alive(id) || !xPlayerLeap[id][LEAP_ENABLED])
		return false

	if(get_member_game(m_bFreezePeriod) || zpn_is_user_freezed(id) || get_member(id, m_bIsDefusing))
		return false

	new flags = get_entvar(id, var_flags)
	if(!(flags & FL_ONGROUND) || (flags & FL_FROZEN) || (get_entvar(id, var_iuser3) & PLAYER_PREVENT_JUMP))
		return false

	if(get_entvar(id, var_movetype) != MOVETYPE_WALK || get_entvar(id, var_waterlevel) >= 2)
		return false

	if(Float:zpn_player_data_get_prop(id, PROP_PD_REGISTER_LAST_LEAP_TIMEOUT) > get_gametime())
		return false

	new Float:velocity[3]
	get_entvar(id, var_velocity, velocity)
	return vector_length(velocity) >= xPlayerLeap[id][LEAP_MIN_SPEED]
}

bool:do_user_leap(id)
{
	if(!can_user_leap(id) || xLeaping[id])
		return false

	// Prevent recursive attempts from the leap forwards, including zero cooldowns.
	xLeaping[id] = true
	new forward_return
	ExecuteForward(xForwardLeapPre, forward_return, id)

	// An addon may disable the ability, freeze or kill the player in the forward.
	if(forward_return >= ZPN_RETURN_HANDLED || !can_user_leap(id))
	{
		xLeaping[id] = false
		return false
	}

	new Float:angles[3], Float:velocity[3]
	get_entvar(id, var_v_angle, angles)
	angle_vector(angles, ANGLEVECTOR_FORWARD, velocity)
	velocity[0] *= xPlayerLeap[id][LEAP_FORCE]
	velocity[1] *= xPlayerLeap[id][LEAP_FORCE]
	velocity[2] = xPlayerLeap[id][LEAP_HEIGHT]
	set_entvar(id, var_velocity, velocity)
	zpn_player_data_set_prop(id, PROP_PD_REGISTER_LAST_LEAP_TIMEOUT, get_gametime() + xPlayerLeap[id][LEAP_COOLDOWN])

	ExecuteForward(xForwardLeapPost, forward_return, id)
	xLeaping[id] = false
	return true
}
