#include <amxmodx>
#include <fakemeta>
#include <cstrike>
#include <engine>
#include <xs>
#include <reapi>
#include <hamsandwich>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new const kick[] = "models/zpn/kick.mdl"
new const kick_anim[] = "models/zpn/kick_anim.mdl"
new const kick_miss[] = "zpn/kick_miss.wav"

new const Float:anim_time = 0.75

new const kick_hit[][] =
{
	"zpn/kick_hit1.wav",
	"zpn/kick_hit2.wav",
}

new class
new kick_anim_index, kicking[33]

public plugin_init()
{
	register_plugin("[ZPN] Class: Human Kicker", "1.0", "Wilian M.")

	register_forward(FM_CmdStart, "@CmdStart_Pre", false)
	//register_forward(FM_AddToFullPack, "@AddToFullPack_Post", true)
}

register_class()
{
	class = zpn_class_init()
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_TYPE, CLASS_TEAM_TYPE_HUMAN)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_NAME, "Kick")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_INFO, "You can kick zombies")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_MODEL, "vip")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_SPEED, 300.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_HEALTH, 180.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_ARMOR, 25.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_GRAVITY, 0.75)
}

bool:is_class(id) return (zpn_get_user_selected_class(id, CLASS_TEAM_TYPE_HUMAN) == class && zpn_get_user_selected_class(id, CLASS_TEAM_TYPE_HUMAN, true) == class && is_user_alive(id));

public client_putinserver(id)
{
	kicking[id] = false
}

@CmdStart_Pre(id, uc_handle, randseed)
{
	if(!is_class(id))
		return FMRES_IGNORED

	static button; button = get_uc(uc_handle, UC_Buttons)
	static oldbutton; oldbutton = get_entvar(id, var_oldbuttons)
	
	if(!(button & IN_USE && !(oldbutton & IN_USE)))
		return FMRES_IGNORED
	
	if(kicking[id])
		return FMRES_IGNORED

	kicking[id] = true

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
	new model_ent = rg_create_entity("info_target")

	if(is_nullent(model_ent))
		return
	
	static Float:origin[3], Float:angles[3], Float:velocity[3]

	get_entvar(id, var_origin, origin)
	get_entvar(id, var_angles, angles)
	get_entvar(id, var_velocity, velocity)

	static model[64]; cs_get_user_model(id, model, charsmax(model))

	// FAKE MODEL
	set_entvar(model_ent, var_classname, "fake_model")
	set_entvar(model_ent, var_owner, id)
	set_entvar(model_ent, var_origin, origin)
	set_entvar(model_ent, var_movetype, MOVETYPE_FOLLOW)
	set_entvar(model_ent, var_solid, SOLID_NOT)
	set_entvar(model_ent, var_body, get_entvar(id, var_body))
	set_entvar(model_ent, var_skin, get_entvar(id, var_skin))
	set_entvar(model_ent, var_model, fmt("models/player/%s/%s.mdl", model, model))
	set_entvar(id, var_aiment, model_ent)


	// TERMINANDO....
	
	// ANIM
	// new anim_ent = rg_create_entity("info_target")

	// if(is_nullent(anim_ent))
	// 	return

	// new Float:mins[3] = { -16.0, -16.0, -36.0 }
	// new Float:maxs[3] = { 16.0, 16.0, 36.0 }
	// new Float:size[3]
	// math_mins_maxs(mins, maxs, size)

	// angles[0] = 0.0
	// angles[2] = 0.0

	// set_entvar(anim_ent, var_classname, "anim_kick")
	// set_entvar(anim_ent, var_model, kick_anim)
	// set_entvar(anim_ent, var_modelindex, kick_anim_index)
	// set_entvar(anim_ent, var_owner, id)
	// set_entvar(anim_ent, var_movetype, MOVETYPE_TOSS)
	// set_entvar(anim_ent, var_solid, SOLID_NOT)
	// set_entvar(anim_ent, var_mins, mins)
	// set_entvar(anim_ent, var_maxs, maxs)
	// set_entvar(anim_ent, var_size, size)
	// set_entvar(anim_ent, var_origin, origin)
	// set_entvar(anim_ent, var_angles, angles)
	// set_entvar(anim_ent, var_velocity, velocity)
	// set_entvar(model_ent, var_aiment, anim_ent)
	
	// set_ent_anim(anim_ent, 0, 1.5, true)

	//set_entvar(anim_ent, var_nextthink, get_gametime() + anim_time)
	//set_entvar(model_ent, var_nextthink, get_gametime() + anim_time)

	//SetThink(anim_ent, "think_kick")
	//SetThink(model_ent, "think_kick")
}

public think_kick(const ent)
{
	if(is_nullent(ent))
		return

	// new id = get_entvar(ent, var_owner)

	// if(is_user_connected(id))
	// 	rg_set_user_invisibility(id, false)
	
	rg_remove_entity(ent)
}

public kick_knockback(id)
{
	static Float:origin[3], Float:myorigin[3], Float:speed[3]

	new bool:sound = false
	get_entvar(id, var_origin, myorigin)
	
	for(new i = 0; i < MaxClients; i++)
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
	if(is_user_connected(id))
	{
		zpn_send_weapon_deploy(id)
		kicking[id] = false
	}
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

set_ent_anim(ent, anim, Float:framerate, bool:reset = false)
{
	if(is_nullent(ent))
		return

	set_entvar(ent, var_animtime, get_gametime())
	set_entvar(ent, var_framerate, framerate)
	set_entvar(ent, var_sequence, anim)

	if(reset)
		set_entvar(ent, var_frame, 0.0)
}

rg_set_user_invisibility(const id, bool:bToggle = true)
{
	new eff = get_entvar(id,var_effects)
	set_entvar(id, var_effects, bToggle ? (eff |= EF_NODRAW) : (eff &= ~EF_NODRAW))
}

math_mins_maxs(const Float:mins[3], const Float:maxs[3], Float:size[3])
{
	size[0] = (xs_fsign(mins[0]) * mins[0]) + maxs[0]
	size[1] = (xs_fsign(mins[1]) * mins[1]) + maxs[1]
	size[2] = (xs_fsign(mins[2]) * mins[2]) + maxs[2]
}