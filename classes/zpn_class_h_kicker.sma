#include <amxmodx>
#include <fakemeta>
#include <cstrike>
#include <engine>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new const kick[] = "models/zpn/kick.mdl"
new const kick_anim[] = "models/zpn/kick_anim.mdl"
new const kick_miss[] = "zpn/kick_miss.wav"

new const Float:anim_time = 0.75
new const Float:kick_anim_framerate = 2.0
new const Float:kick_anim_floor_offset = 39.5

new const kick_anim_classname[] = "zpn_kick_anim"
new const kick_fake_classname[] = "zpn_kick_fake_player"

new const kick_hit[][] =
{
	"zpn/kick_hit1.wav",
	"zpn/kick_hit2.wav",
}

enum _:eCvars
{
	CVAR_BLOCK_MOVE
}

new class, kick_anim_index
new cvars[eCvars]
new bool:kicking[33]
new kick_anim_player[33]
new kick_fake_player[33]
new camera_users_xvar = -1

public plugin_init()
{
	register_plugin("[ZPN] Class: Human Kicker", "1.0", "Wilian M.")

	register_forward(FM_CmdStart, "@CmdStart_Pre", false)
	register_forward(FM_AddToFullPack, "@AddToFullPack_Post", true)

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false)

	bind_pcvar_num(create_cvar("zpn_class_kicker_block_move", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), cvars[CVAR_BLOCK_MOVE])
}

public plugin_cfg()
{
	camera_users_xvar = get_xvar_id("amx_addon_camera_users")
}

register_class()
{
	class = zpn_class_init("Kick", CLASS_TEAM_TYPE_HUMAN)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_INFO, "You can kick zombies")
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_MODEL, "vip")
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_SPEED, 300.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_HEALTH, 180.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_ARMOR, 25.0)
	zpn_class_set_prop(class, PROP_CLASS_REGISTER_GRAVITY, 0.75)
}

bool:is_class(id)
{
	return (is_user_alive(id) && !zpn_is_user_zombie(id) && zpn_is_user_class(id, class))
}

public client_putinserver(id)
{
	kicking[id] = false
	kick_anim_player[id] = 0
	kick_fake_player[id] = 0
}

public client_disconnected(id)
{
	stop_kick(id, false)
}

public CBasePlayer_Spawn_Post(const this)
{
	stop_kick(this, false)
}

public CBasePlayer_Killed_Post(const this, const attacker, const shouldgib)
{
	stop_kick(this, false)
}

public CSGameRules_RestartRound_Pre()
{
	for(new id = 1; id <= MaxClients; id++)
		stop_kick(id, false)
}

public zpn_user_infected_pre(const this, const infector, const class_id)
{
	stop_kick(this, false)
}

@AddToFullPack_Post(es_handle, e, ent, host, hostflags, player, pset)
{
	new bool:host_using_camera = is_user_using_camera(host)

	if(player)
	{
		if((host != ent || host_using_camera) && is_playing_kick_anim(ent))
			set_es(es_handle, ES_Effects, get_es(es_handle, ES_Effects) | EF_NODRAW)

		return FMRES_IGNORED
	}

	if(0 < host && host <= MaxClients && !host_using_camera && (kick_anim_player[host] == ent || kick_fake_player[host] == ent))
		set_es(es_handle, ES_Effects, get_es(es_handle, ES_Effects) | EF_NODRAW)

	return FMRES_IGNORED
}

@CmdStart_Pre(id, uc_handle, randseed)
{
	if(!is_class(id))
		return FMRES_IGNORED

	if(kicking[id] && cvars[CVAR_BLOCK_MOVE])
		block_kick_move(id, uc_handle)

	static button; button = get_uc(uc_handle, UC_Buttons)
	static oldbutton; oldbutton = get_entvar(id, var_oldbuttons)
	
	if(!(button & IN_USE && !(oldbutton & IN_USE)))
		return FMRES_IGNORED
	
	if(kicking[id])
		return FMRES_IGNORED

	kicking[id] = true

	if(cvars[CVAR_BLOCK_MOVE])
		block_kick_move(id, uc_handle)

	set_entvar(id, var_viewmodel, kick)

	new activeItem = get_member(id, m_pActiveItem)

	if(!is_nullent(activeItem))
	{
		set_member(id, m_flNextAttack, anim_time + 0.2)
		set_member(activeItem, m_Weapon_flTimeWeaponIdle, anim_time + 0.2)
		set_member(activeItem, m_Weapon_flNextPrimaryAttack, anim_time + 0.2)
		rg_weapon_send_animation(activeItem, 1)
	}

	init_anim(id)
	kick_knockback(id)
	set_task(anim_time, "reset_kick", id)

	return FMRES_IGNORED
}

public init_anim(id)
{
	remove_kick_fake_player(id)

	new anim_ent = rg_create_entity("info_target")

	if(is_nullent(anim_ent))
		return

	new model_ent = rg_create_entity("info_target")

	if(is_nullent(model_ent))
	{
		rg_remove_entity(anim_ent)
		return
	}
	
	static Float:origin[3], Float:angles[3], Float:velocity[3]

	get_entvar(id, var_origin, origin)
	get_entvar(id, var_angles, angles)
	get_entvar(id, var_velocity, velocity)
	origin[2] += (kick_anim_floor_offset - 36.0)

	angles[0] = 0.0
	angles[2] = 0.0

	set_entvar(anim_ent, var_classname, kick_anim_classname)
	set_entvar(anim_ent, var_owner, id)
	set_entvar(anim_ent, var_origin, origin)
	set_entvar(anim_ent, var_angles, angles)
	static Float:mins[3] = { -23.1, -21.5, -39.5 }
	static Float:maxs[3] = { 54.4, 24.9, 28.0 }

	engfunc(EngFunc_SetModel, anim_ent, kick_anim)
	engfunc(EngFunc_SetSize, anim_ent, mins, maxs)

	set_entvar(anim_ent, var_modelindex, kick_anim_index)
	set_entvar(anim_ent, var_velocity, velocity)
	set_entvar(anim_ent, var_movetype, MOVETYPE_TOSS)
	set_entvar(anim_ent, var_solid, SOLID_BBOX)
	set_entvar(anim_ent, var_rendermode, kRenderTransAlpha)
	set_entvar(anim_ent, var_renderamt, 1.0)
	set_entvar(anim_ent, var_nextthink, get_gametime() + anim_time)

	set_ent_anim(anim_ent, 0, kick_anim_framerate, true)
	SetThink(anim_ent, "think_kick")

	static model[64], model_path[128]
	cs_get_user_model(id, model, charsmax(model))
	formatex(model_path, charsmax(model_path), "models/player/%s/%s.mdl", model, model)

	new player_model_index = engfunc(EngFunc_ModelIndex, model_path)

	if(!player_model_index)
	{
		rg_remove_entity(model_ent)
		rg_remove_entity(anim_ent)
		return
	}

	set_entvar(model_ent, var_classname, kick_fake_classname)
	set_entvar(model_ent, var_owner, id)
	set_entvar(model_ent, var_origin, origin)
	set_entvar(model_ent, var_angles, angles)
	set_entvar(model_ent, var_movetype, MOVETYPE_FOLLOW)
	set_entvar(model_ent, var_aiment, anim_ent)
	set_entvar(model_ent, var_solid, SOLID_NOT)
	set_entvar(model_ent, var_body, get_entvar(id, var_body))
	set_entvar(model_ent, var_skin, get_entvar(id, var_skin))
	engfunc(EngFunc_SetModel, model_ent, model_path)
	set_entvar(model_ent, var_modelindex, player_model_index)

	kick_anim_player[id] = anim_ent
	kick_fake_player[id] = model_ent
}

public think_kick(const ent)
{
	if(is_nullent(ent))
		return

	new id = get_entvar(ent, var_owner)

	if(0 < id && id <= MaxClients && kick_anim_player[id] == ent)
	{
		if(kick_fake_player[id] > 0 && !is_nullent(kick_fake_player[id]))
			rg_remove_entity(kick_fake_player[id])

		kick_anim_player[id] = 0
		kick_fake_player[id] = 0
	}
	
	rg_remove_entity(ent)
}

public kick_knockback(id)
{
	static Float:origin[3], Float:myorigin[3], Float:speed[3]

	new bool:sound = false
	get_entvar(id, var_origin, myorigin)
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_alive(i))
			continue
		
		if(id == i)
			continue

		get_entvar(i, var_origin, origin)

		if(!is_in_viewcone(id, origin, 1))
			continue

		if(entity_range(id, i) > 110)
			continue

		if(!zpn_is_user_zombie(i))
			continue
		
		sound = true
		origin[2] += 36.0

		speed_vector(myorigin, origin, 800.0, speed)
		set_entvar(i, var_velocity, speed)
	}
	
	if(sound) rh_emit_sound2(id, 0, CHAN_STATIC, kick_hit[random_num(0, charsmax(kick_hit))], .attn = 0.5)
	else rh_emit_sound2(id, 0, CHAN_STATIC, kick_miss, .attn = 0.5)
}

public reset_kick(id)
{
	stop_kick(id, true)
}

public plugin_precache()
{
	register_class()

	precache_model(kick)
	kick_anim_index = precache_model(kick_anim)
	precache_sound(kick_miss)

	for(new i = 0; i < sizeof(kick_hit); i++)
		precache_sound(kick_hit[i])
}

speed_vector(const Float:origin1[3], const Float:origin2[3], Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]

	new Float:num = floatsqroot(speed * speed / (new_velocity[0] * new_velocity[0] + new_velocity[1] * new_velocity[1] + new_velocity[2] * new_velocity[2]))

	new_velocity[0] *= (num)
	new_velocity[1] *= (num)
	new_velocity[2] *= (num)
}

stock set_ent_anim(ent, anim, Float:framerate, bool:reset = false)
{
	if(is_nullent(ent))
		return

	set_entvar(ent, var_animtime, get_gametime())
	set_entvar(ent, var_framerate, framerate)
	set_entvar(ent, var_sequence, anim)

	if(reset)
		set_entvar(ent, var_frame, 0.0)
}

stop_kick(id, bool:deploy_weapon)
{
	if(!(0 < id && id <= MaxClients))
		return

	remove_task(id)
	remove_kick_fake_player(id)

	if(deploy_weapon && is_user_connected(id))
		zpn_send_weapon_deploy(id)

	kicking[id] = false
}

remove_kick_fake_player(id)
{
	if(!(0 < id && id <= MaxClients))
		return

	if(kick_fake_player[id] > 0 && !is_nullent(kick_fake_player[id]))
		rg_remove_entity(kick_fake_player[id])

	if(kick_anim_player[id] > 0 && !is_nullent(kick_anim_player[id]))
		rg_remove_entity(kick_anim_player[id])

	kick_anim_player[id] = 0
	kick_fake_player[id] = 0
}

bool:is_playing_kick_anim(id)
{
	if(!(0 < id && id <= MaxClients))
		return false

	return (kicking[id] && kick_anim_player[id] > 0 && !is_nullent(kick_anim_player[id]) && kick_fake_player[id] > 0 && !is_nullent(kick_fake_player[id]))
}

bool:is_user_using_camera(id)
{
	if(!(0 < id && id <= MaxClients) || camera_users_xvar == -1)
		return false

	return (get_xvar_num(camera_users_xvar) & (1 << (id - 1))) ? true : false
}

block_kick_move(id, uc_handle)
{
	new buttons = get_uc(uc_handle, UC_Buttons)
	buttons &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_JUMP | IN_DUCK)

	set_uc(uc_handle, UC_Buttons, buttons)
	set_uc(uc_handle, UC_ForwardMove, 0.0)
	set_uc(uc_handle, UC_SideMove, 0.0)
	set_uc(uc_handle, UC_UpMove, 0.0)

	static Float:velocity[3]
	get_entvar(id, var_velocity, velocity)
	velocity[0] = 0.0
	velocity[1] = 0.0

	if(get_entvar(id, var_flags) & FL_ONGROUND)
		velocity[2] = 0.0

	set_entvar(id, var_velocity, velocity)
}
