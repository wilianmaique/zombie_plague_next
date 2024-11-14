#include <amxmodx>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new item

public plugin_init()
{
	register_plugin("[ZPN] Item: Frost Nade", "1.0", "Wilian M.")
	
	item = zpn_item_init()
	zpn_item_set_prop(item, ITEM_PROP_REGISTER_TEAM, ITEM_TEAM_HUMAN)
	zpn_item_set_prop(item, ITEM_PROP_REGISTER_NAME, "Frost Nade")
	zpn_item_set_prop(item, ITEM_PROP_REGISTER_COST, 0)
}

public zpn_item_selected_post(const id, const item_id)
{
	if(item_id != item)
		return

	rg_give_item(id, "weapon_flashbang")
}