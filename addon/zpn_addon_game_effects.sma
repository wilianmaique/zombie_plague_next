#include <amxmodx>
#include <reapi>
#include <hamsandwich>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new const v_infection[] = "models/zpn/v_infection.mdl"
new const spr_poison[] = "sprites/zpn/poison.spr"
new const spr_poison_explode[] = "sprites/zpn/poison_explode.spr"
new const spr_toxic_gib[] = "sprites/zpn/toxic_gib.spr"

new const Float:infection_anim_time = 1.6

new spr_poison_index, spr_poison_explode_index, spr_toxic_gib_index

public plugin_precache()
{
	register_plugin("[ZPN] Addon: Game Effects", "1.0", "Wilian M.")
	precache_model(v_infection)
	spr_poison_index = precache_model(spr_poison)
	spr_poison_explode_index = precache_model(spr_poison_explode)
	spr_toxic_gib_index = precache_model(spr_toxic_gib)
}

public zpn_user_infected_post(const id, const infector, const class_id)
{
	if(!zpn_is_user_zombie(id) || zpn_is_user_zombie_special(id))
		return

	new Float:origin[3]; get_entvar(id, var_origin, origin)
	origin[2] += 15.0

	create_explosion(origin, spr_poison_explode_index, 15)
	create_explosion(origin, spr_poison_index, 15)

	new activeItem = get_member(id, m_pActiveItem)

	if(!is_nullent(activeItem))
	{
		set_entvar(id, var_viewmodel, v_infection)
		set_member(id, m_flNextAttack, infection_anim_time)
		set_member(activeItem, m_Weapon_flTimeWeaponIdle, infection_anim_time)
		set_member(activeItem, m_Weapon_flNextPrimaryAttack, infection_anim_time)
		rg_weapon_send_animation(activeItem, 0)
		set_task(infection_anim_time, "deploy_weapon", id)
	}
}

public deploy_weapon(const this)
{
	new activeItem = get_member(this, m_pActiveItem)
	if(!is_nullent(activeItem)) ExecuteHamB(Ham_Item_Deploy, activeItem)
}

create_explosion(Float:origin[3], spr_index, scale = 30, framerate = 30)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	write_coord(floatround(origin[0]))
	write_coord(floatround(origin[1]))
	write_coord(floatround(origin[2]))
	write_short(spr_index)
	write_byte(scale) //scale
	write_byte(framerate) // framerate
	write_byte(TE_EXPLFLAG_NOSOUND)
	message_end()
}