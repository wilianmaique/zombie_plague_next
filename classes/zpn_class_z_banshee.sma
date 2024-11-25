#include <amxmodx>
#include <xs>
#include <reapi>
#include <fakemeta>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

enum _:eCvars
{
	Float:CVAR_SKILL_TIMEOUT,
	Float:CVAR_BAT_TIME,
	CVAR_BAT_SPEED,
	Float:CVAR_BAT_CATCH_TIME,
	Float:CVAR_BAT_CATCH_SPEED,
}

new const bat_banshee[] = "models/zpn/bat_banshee.mdl"
new const banshee_laugh[] = "zpn/banshee_laugh.wav"
new const banshee_pulling_fail[] = "zpn/banshee_pulling_fail.wav"
new const banshee_pulling_fire[] = "zpn/banshee_pulling_fire.wav"

new spr_explosion_index, bat_banshee_index
new class, cvars[eCvars], xBatEnemy[33], Float:xBatTimeout[33]

public plugin_init()
{
	register_plugin("[ZPN] Class: Zombie Banshee", "1.0", "Wilian M.")
	register_clcmd("drop", "clcmd_drop")

	RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink", false)
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false)

	bind_pcvar_float(create_cvar("zpn_class_banshee_timeout", "15", .has_min = true, .min_val = 5.0, .has_max = true, .max_val = 1000.0), cvars[CVAR_SKILL_TIMEOUT])
	bind_pcvar_float(create_cvar("zpn_class_banshee_bat_time", "3", .has_min = true, .min_val = 1.0, .has_max = true, .max_val = 50.0), cvars[CVAR_BAT_TIME])
	bind_pcvar_num(create_cvar("zpn_class_banshee_bat_speed", "700", .has_min = true, .min_val = 100.0, .has_max = true, .max_val = 2000.0), cvars[CVAR_BAT_SPEED])
	bind_pcvar_float(create_cvar("zpn_class_banshee_bat_catch_time", "3", .has_min = true, .min_val = 1.0, .has_max = true, .max_val = 50.0), cvars[CVAR_BAT_CATCH_TIME])
	bind_pcvar_float(create_cvar("zpn_class_banshee_bat_catch_speed", "110", .has_min = true, .min_val = 20.0, .has_max = true, .max_val = 1000.0), cvars[CVAR_BAT_CATCH_SPEED])
}

register_class()
{
	class = zpn_class_init()
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_TYPE, CLASS_TEAM_TYPE_ZOMBIE)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_NAME, "Banshee")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_INFO, "Pulling \r[G]")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_MODEL, "zpn_banshee")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_MODEL_VIEW, "models/v_knife_banshee.mdl")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_SPEED, 360.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_HEALTH, 2200.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_GRAVITY, 0.5)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_KNOCKBACK, 1.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_BLOOD_COLOR, 208)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_SILENT_FOOTSTEPS, true)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_NV_COLOR, "#872dcc")
}

bool:is_class(id) return (zpn_get_user_selected_class(id, CLASS_TEAM_TYPE_ZOMBIE) == class && zpn_get_user_selected_class(id, CLASS_TEAM_TYPE_ZOMBIE, true) == class);

public zpn_user_infected_post(const this, const infector, const class_id)
{
	if(is_user_bot(this))
		set_task(random_float(10.0, 30.0), "force_bot_skill", this)
}

public force_bot_skill(id)
{
	if(zpn_is_user_zombie(id) && !zpn_is_user_zombie_special(id) && zpn_get_user_selected_class(id, CLASS_TEAM_TYPE_ZOMBIE, true) == class && zpn_is_round_started() && is_user_connected(id))
	{
		create_bat(id)
		set_task(random_float(10.0, 30.0), "force_bot_skill", id)
	}
}

public clcmd_drop(id)
{
	if(!is_class(id))
		return
	
	if(xBatTimeout[id] > get_gametime())
	{
		zpn_print_color(id, print_team_red, "^3Espere ^4%.0f ^3segundos.", xBatTimeout[id] - get_gametime())
		return
	}

	create_bat(id)
}

public CSGameRules_RestartRound_Pre()
{
	for(new id = 1; id <= MaxClients; id++)
	{
		if(!is_user_connected(id))
			continue

		xBatEnemy[id] = 0
	}
}

public client_putinserver(id)
{
	xBatEnemy[id] = 0
}

public client_disconnected(id)
{
	xBatEnemy[id] = 0
}

public CBasePlayer_PreThink(const this)
{
	if(!is_user_alive(this))
		return

	if(xBatEnemy[this] > 0)
	{
		static Float:origin[3]; get_entvar(xBatEnemy[this], var_origin, origin)
		static Float:vec[3]; aim_at_origin(this, origin, vec)

		engfunc(EngFunc_MakeVectors, vec)
		global_get(glb_v_forward, vec)

		vec[0] *= cvars[CVAR_BAT_CATCH_SPEED]
		vec[1] *= cvars[CVAR_BAT_CATCH_SPEED]
		vec[2] = 0.0

		set_entvar(this, var_velocity, vec)
	}
}

public plugin_precache()
{
	register_class()

	bat_banshee_index = precache_model(bat_banshee)
	spr_explosion_index = precache_model("sprites/bexplo.spr")

	precache_sound(banshee_laugh)
	precache_sound(banshee_pulling_fail)
	precache_sound(banshee_pulling_fire)
}

create_bat(id)
{
	new ent = rg_create_entity("info_target")

	if(is_nullent(ent))
		return
	
	new Float:origin[3]; get_user_front_origin(id, 10.0, 0.0, -1.0, origin)

	new Float:angles[3]; get_entvar(id, var_angles, angles)
	engfunc(EngFunc_MakeVectors, angles)

	new Float:mins[3] = { -12.0, -12.0, -2.0 }
	new Float:maxs[3] = { 12.0, 12.0, 4.0 }

	new Float:velocity[3]
	velocity_by_aim(id, cvars[CVAR_BAT_SPEED], velocity)

	set_entvar(ent, var_classname, "bat")
	set_entvar(ent, var_model, bat_banshee)
	set_entvar(ent, var_modelindex, bat_banshee_index)
	set_entvar(ent, var_mins, mins)
	set_entvar(ent, var_maxs, maxs)
	set_entvar(ent, var_solid, SOLID_BBOX)
	set_entvar(ent, var_owner, id)
	set_entvar(ent, var_movetype, MOVETYPE_FLY)
	set_entvar(ent, var_origin, origin)
	set_entvar(ent, var_angles, angles)
	set_entvar(ent, var_animtime, get_gametime())
	set_entvar(ent, var_framerate, 1.0)
	set_entvar(ent, var_velocity, velocity)
	set_entvar(ent, var_nextthink, get_gametime() + cvars[CVAR_BAT_TIME])

	SetThink(ent, "bat_think")
	SetTouch(ent, "bat_touch")

	rh_emit_sound2(ent, 0, CHAN_STATIC, banshee_pulling_fire, .attn = 0.3)

	xBatTimeout[id] = get_gametime() + cvars[CVAR_SKILL_TIMEOUT]

	new activeItem = get_member(id, m_pActiveItem)

	if(!is_nullent(activeItem))
	{
		set_member(activeItem, m_Weapon_flTimeWeaponIdle, 1.0)
		set_member(activeItem, m_Weapon_flNextPrimaryAttack, 1.0)
		rg_weapon_send_animation(activeItem, 2)
	}
}

public bat_touch(const ent, const other)
{
	if(is_nullent(ent))
		return

	if(is_nullent(other))
	{
		del_bat(ent)
		return
	}

	if(zpn_is_user_zombie(other) && is_user_alive(other) && is_user_connected(other))
	{
		del_bat(ent)
		return
	}

	new owner = get_entvar(ent, var_owner)
		
	if(0 < other && other <= MaxClients && is_user_alive(other) && other != owner && !zpn_is_user_zombie(other))
	{
		rh_emit_sound2(ent, 0, CHAN_STATIC, banshee_laugh, .attn = 0.3)

		xBatEnemy[other] = owner
		
		set_entvar(ent, var_movetype, MOVETYPE_FOLLOW)
		set_entvar(ent, var_aiment, other)
		set_entvar(ent, var_iuser4, other)
		SetTouch(ent, "")

		set_entvar(ent, var_nextthink, get_gametime() + cvars[CVAR_BAT_CATCH_TIME])
		SetThink(ent, "bat_think")
	}
}

public bat_think(const ent)
{
	if(is_nullent(ent))
		return

	new other = get_entvar(ent, var_iuser4)

	if(is_user_connected(other))
		xBatEnemy[other] = 0

	rh_emit_sound2(ent, 0, CHAN_STATIC, banshee_pulling_fire, .flags = SND_STOP)

	new Float:origin[3]; get_entvar(ent, var_origin, origin); create_explosion(origin)
	rg_remove_entity(ent)
}

del_bat(ent)
{
	static Float:origin[3]
	
	rh_emit_sound2(ent, 0, CHAN_STATIC, banshee_pulling_fire, .flags = SND_STOP)
	rh_emit_sound2(ent, 0, CHAN_STATIC, banshee_pulling_fail, .attn = 0.3)
	get_entvar(ent, var_origin, origin)
	create_explosion(origin)
	rg_remove_entity(ent)
}

get_user_front_origin(id, Float:forw, Float:right, Float:up, Float:vStart[])
{
	new Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	get_entvar(id, var_origin, vOrigin)
	get_entvar(id, var_v_angle, vAngle)
	
	engfunc(EngFunc_MakeVectors, vAngle)
	
	global_get(glb_v_forward, vForward)
	global_get(glb_v_right, vRight)
	global_get(glb_v_up, vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

create_explosion(Float:origin[3])
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	write_coord(floatround(origin[0]))
	write_coord(floatround(origin[1]))
	write_coord(floatround(origin[2]))
	write_short(spr_explosion_index)
	write_byte(30)
	write_byte(30)
	write_byte(TE_EXPLFLAG_NOSOUND)
	message_end()
}

aim_at_origin(id, Float:target[3], Float:angles[3])
{
	static Float:vec[3]
	get_entvar(id, var_origin, vec)

	vec[0] = target[0] - vec[0]
	vec[1] = target[1] - vec[1]
	vec[2] = target[2] - vec[2]

	engfunc(EngFunc_VecToAngles, vec, angles)

	angles[0] *= -1.0
	angles[2] = 0.0
}