#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <hamsandwich>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

#define ITEM_UID 29092025
#define IS_CUSTOM_ITEM(%0) (get_entvar(%0, var_impulse) == ITEM_UID)

new item

public plugin_init()
{
	register_plugin("[ZPN] Item: Frost Nade", "1.0", "Wilian M.")

	RegisterHookChain(RG_CGrenade_ExplodeFlashbang, "Grenade_ExplodeFlashbang_Pre", false)
	RegisterHookChain(RG_ThrowFlashbang, "Grenade_ThrowFlashbang_Post", true)
}

public plugin_precache()
{
	item = zpn_item_init()
	zpn_item_set_prop(item, PROP_ITEM_REGISTER_TEAM, ITEM_TEAM_HUMAN)
	zpn_item_set_prop(item, PROP_ITEM_REGISTER_FIND_NAME, "item_h_frostnade")
	zpn_item_set_prop(item, PROP_ITEM_REGISTER_NAME, "Frost Nade")
	zpn_item_set_prop(item, PROP_ITEM_REGISTER_COST, 0)
}

public zpn_item_selected_post(const id, const item_id)
{
	if(item_id != item)
		return

	rg_give_custom_item(id, "weapon_flashbang", GT_APPEND, ITEM_UID)
}

public Grenade_ThrowFlashbang_Post(const this, Float:vecStart[3], Float:vecVelocity[3], Float:time)
{
	new grenade = GetHookChainReturn(ATYPE_INTEGER)

	if(is_nullent(grenade))
		return

	new weapon = get_member(this, m_pActiveItem)

	if(is_nullent(weapon) || !IS_CUSTOM_ITEM(weapon))
		return

	set_entvar(grenade, var_impulse, ITEM_UID)
}

public Grenade_ExplodeFlashbang_Pre(const this, tracehandle, const bitsDamageType)
{
	if(is_nullent(this) || !IS_CUSTOM_ITEM(this))
		return HC_CONTINUE

	new Float:grenadeOrigin[3]; get_entvar(this, var_origin, grenadeOrigin)
	new Float:targetOrigin[3]

	for(new target = 1; target <= MaxClients; target++)
	{
		if(!is_user_connected(target) || !is_user_alive(target))
			continue

		get_entvar(target, var_origin, targetOrigin)
	
		new Float:distance = 350.0

		if(vector_distance(targetOrigin, grenadeOrigin) > distance)
			continue

		if(!zpn_is_user_zombie(target))
			continue

		zpn_set_user_frozen(target, 3.0, true, true)
	}

	rg_remove_entity(this)

	return HC_SUPERCEDE
}