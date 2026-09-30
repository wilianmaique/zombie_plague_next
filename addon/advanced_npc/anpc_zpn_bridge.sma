#include <amxmodx>
#include <zombie_plague_next_const>
#include <zombie_plague_next>
#include "advanced_npc/advanced_npc"

// Optional adapter. No ZPN dependency leaks into core, navigation or types.
public plugin_init()
{
	register_plugin("Advanced NPC: ZPN Bridge", ANPC_VERSION, "ZPN")
}

public anpc_target_filter(const entity, const player)
{
	if (!zpn_is_round_started() || bridge_friendly(entity, player)) return ANPC_BLOCK
	return ANPC_CONTINUE
}

public anpc_attack_pre(const entity, const victim, const Float:damage)
{
	// Recheck at impact: a player may be infected during attack windup.
	if (!zpn_is_round_started() || bridge_friendly(entity, victim)) return ANPC_BLOCK
	return ANPC_CONTINUE
}

public anpc_damage_pre(const entity, const attacker, const Float:damage, const bits)
{
	if (1 <= attacker <= MaxClients && is_user_connected(attacker) && bridge_friendly(entity, attacker)) return ANPC_BLOCK
	return ANPC_CONTINUE
}

stock bool:bridge_friendly(const entity, const player)
{
	new faction = anpc_get_faction(entity)
	if (faction == ANPC_FACTION_ZOMBIE) return zpn_is_user_zombie(player)
	if (faction == ANPC_FACTION_HUMAN) return !zpn_is_user_zombie(player)
	return false
}
