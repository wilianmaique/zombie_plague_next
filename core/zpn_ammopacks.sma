#include <amxmodx>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

enum _:eCvars
{
	Float:CVAR_DAMAGE_REQUIRED,
	CVAR_DAMAGE_REWARD,
	CVAR_MAX_AMMO_PACKS,
}

enum _:eForwards
{
	FW_AMMO_PACKS_CHANGED_POST,
}

new xCvars[eCvars]
new xForwards[eForwards], xForwardReturn

public plugin_precache()
{
	bind_pcvar_float(create_cvar("zpn_ap_dmg_reached", "1000", .has_min = true, .min_val = 50.0, .has_max = true, .max_val = 10000.0), xCvars[CVAR_DAMAGE_REQUIRED])
	bind_pcvar_num(create_cvar("zpn_ap_dmg_reward", "1", .has_min = true, .min_val = 1.0, .has_max = true, .max_val = 1000.0), xCvars[CVAR_DAMAGE_REWARD])
	bind_pcvar_num(create_cvar("zpn_ap_max_packs", "0", .has_min = true, .min_val = 0.0), xCvars[CVAR_MAX_AMMO_PACKS])
}

public plugin_init()
{
	register_plugin("[ZPN] Core: Ammo Packs", "1.0", "Wilian M.")

	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre", false)
	RegisterHookChain(RG_RoundEnd, "RoundEnd_Pre", false)

	xForwards[FW_AMMO_PACKS_CHANGED_POST] = CreateMultiForward("zpn_ammo_pack_user_ap_changed", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL)
}

public plugin_natives()
{
	register_library("zombie_plague_next_ammopacks")

	register_native("zpn_ammo_pack_get_user_ap", "_zpn_ammo_pack_get_user_ap")
	register_native("zpn_ammo_pack_set_user_ap", "_zpn_ammo_pack_set_user_ap")
	register_native("zpn_ammo_pack_add_user_ap", "_zpn_ammo_pack_add_user_ap")
	register_native("zpn_ammo_pack_take_user_ap", "_zpn_ammo_pack_take_user_ap")
	register_native("zpn_ammo_pack_can_user_afford_ap", "_zpn_ammo_pack_can_user_afford_ap")
}

public client_putinserver(id)
{
	reset_user_ammopacks(id)
}

public client_disconnected(id)
{
	reset_user_ammopacks(id)
}

public CBasePlayer_TakeDamage_Pre(const victim, pevInflictor, attacker, Float:flDamage, bitsDamageType)
{
	if(victim == attacker || flDamage <= 0.0 || !zpn_is_valid_player_alive(attacker) || !zpn_is_valid_player_alive(victim))
		return HC_CONTINUE

	if(zpn_is_user_zombie(attacker) || !zpn_is_user_zombie(victim))
		return HC_CONTINUE

	reward_damage(attacker, flDamage)

	return HC_CONTINUE
}

public RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event, Float:delay)
{
	for(new id = 1; id <= MaxClients; id++)
	{
		if(!is_user_connected(id))
			continue

		reset_user_damage(id)
	}
}

public _zpn_ammo_pack_get_user_ap(plugin_id, param_nums)
{
	if(param_nums != 1)
		return 0

	return get_user_ammopacks(get_param(1))
}

public bool:_zpn_ammo_pack_set_user_ap(plugin_id, param_nums)
{
	if(param_nums != 3)
		return false

	return set_user_ammopacks(get_param(1), get_param(2), eAmmoPackChangeReasons:get_param(3))
}

public bool:_zpn_ammo_pack_add_user_ap(plugin_id, param_nums)
{
	if(param_nums != 3)
		return false

	return add_user_ammopacks(get_param(1), get_param(2), eAmmoPackChangeReasons:get_param(3))
}

public bool:_zpn_ammo_pack_take_user_ap(plugin_id, param_nums)
{
	if(param_nums != 3)
		return false

	return take_user_ammopacks(get_param(1), get_param(2), eAmmoPackChangeReasons:get_param(3))
}

public bool:_zpn_ammo_pack_can_user_afford_ap(plugin_id, param_nums)
{
	if(param_nums != 2)
		return false

	return can_user_afford_ammopacks(get_param(1), get_param(2))
}

reward_damage(const id, const Float:damage)
{
	if(xCvars[CVAR_DAMAGE_REQUIRED] <= 0.0 || xCvars[CVAR_DAMAGE_REWARD] <= 0)
		return

	new Float:damageProgress = zpn_player_data_get_prop(id, PROP_PD_REGISTER_DMG_DEALT) + damage
	new rewards = floatround(damageProgress / xCvars[CVAR_DAMAGE_REQUIRED], floatround_floor)

	if(rewards > 0)
		damageProgress -= (xCvars[CVAR_DAMAGE_REQUIRED] * rewards)

	zpn_player_data_set_prop(id, PROP_PD_REGISTER_DMG_DEALT, damageProgress)

	if(rewards > 0)
		add_user_ammopacks(id, rewards * xCvars[CVAR_DAMAGE_REWARD], ZPN_AMMO_PACK_CHANGE_DAMAGE_REWARD)
}

bool:add_user_ammopacks(const id, const amount, const eAmmoPackChangeReasons:reason)
{
	if(amount < 0)
		return false

	return set_user_ammopacks(id, get_user_ammopacks(id) + amount, reason)
}

bool:take_user_ammopacks(const id, const amount, const eAmmoPackChangeReasons:reason)
{
	if(!can_user_afford_ammopacks(id, amount))
		return false

	return set_user_ammopacks(id, get_user_ammopacks(id) - amount, reason)
}

bool:can_user_afford_ammopacks(const id, const amount)
{
	if(amount < 0 || !zpn_is_valid_player_connected(id))
		return false

	return get_user_ammopacks(id) >= amount
}

bool:set_user_ammopacks(const id, amount, const eAmmoPackChangeReasons:reason)
{
	if(!zpn_is_valid_player_connected(id))
		return false

	amount = clamp_ammopacks(amount)

	new oldAmount = get_user_ammopacks(id)

	if(oldAmount == amount)
		return true

	zpn_player_data_set_prop(id, PROP_PD_REGISTER_AMMO_PACKS, amount)

	ExecuteForward(xForwards[FW_AMMO_PACKS_CHANGED_POST], xForwardReturn, id, amount, oldAmount, amount - oldAmount, reason)

	return true
}

get_user_ammopacks(const id)
{
	if(!zpn_is_valid_player_connected(id))
		return 0

	return zpn_player_data_get_prop(id, PROP_PD_REGISTER_AMMO_PACKS)
}

reset_user_ammopacks(const id)
{
	if(!(1 <= id <= MaxClients))
		return

	zpn_player_data_set_prop(id, PROP_PD_REGISTER_AMMO_PACKS, 0)
	reset_user_damage(id)
}

reset_user_damage(const id)
{
	if(!(1 <= id <= MaxClients))
		return

	zpn_player_data_set_prop(id, PROP_PD_REGISTER_DMG_DEALT, 0.0)
}

clamp_ammopacks(amount)
{
	if(amount < 0)
		amount = 0

	if(xCvars[CVAR_MAX_AMMO_PACKS] > 0 && amount > xCvars[CVAR_MAX_AMMO_PACKS])
		amount = xCvars[CVAR_MAX_AMMO_PACKS]

	return amount
}
