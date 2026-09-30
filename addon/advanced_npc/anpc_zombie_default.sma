#include <amxmodx>
#include "advanced_npc/advanced_npc"

new gZombieType = ANPC_INVALID_TYPE
new const MODEL[] = "models/player/zpn_z_default/zpn_z_default.mdl"
new const HIT_SOUND[] = "weapons/knife_hit1.wav"
new const ANIMATION_LABELS[][] =
{
	"idle1", "run", "crouchrun", "jump", "ref_shoot_knife", "crouch_shoot_knife", "death1"
}

public plugin_precache()
{
	new profile[AnpcProfile]
	profile[ANPC_HEALTH] = 5000.0
	profile[ANPC_SPEED] = 300.0
	profile[ANPC_GRAVITY] = 0.7
	profile[ANPC_DAMAGE] = 35.0
	profile[ANPC_ATTACK_RANGE] = 72.0
	profile[ANPC_ATTACK_COOLDOWN] = 1.0
	profile[ANPC_ATTACK_WINDUP] = 0.28
	profile[ANPC_HEAD_MULTIPLIER] = 2.0
	profile[ANPC_KNOCKBACK] = 0.5
	profile[ANPC_SENSE_INTERVAL] = 0.3
	profile[ANPC_MEMORY_TIME] = 8.0
	profile[ANPC_SIGHT_RANGE] = 2048.0
	profile[ANPC_JUMP_SPEED] = 320.0
	profile[ANPC_CAPABILITIES] = ANPC_CAP_ALL
	profile[ANPC_FACTION] = ANPC_FACTION_ZOMBIE
	profile[ANPC_BLOOD_COLOR] = 110
	profile[ANPC_GLOBAL_HUNT] = 1
	gZombieType = anpc_register_type("zombie_default", MODEL, profile)
	if (gZombieType == ANPC_INVALID_TYPE)
	{
		set_fail_state("Cannot register zombie_default. Check core load order and models/player/zpn_z_default/zpn_z_default.mdl")
		return
	}
	for (new animation = 0; animation < _:ANPC_ANIM_COUNT; animation++)
	{
		if (!anpc_register_animation(gZombieType, AnpcAnimation:animation, ANIMATION_LABELS[animation]))
		{
			set_fail_state("zpn_z_default.mdl is missing a required animation label")
			return
		}
	}
	precache_sound(HIT_SOUND)
}

public plugin_init()
{
	register_plugin("Advanced NPC: Default Zombie", ANPC_VERSION, "ZPN")
}

public anpc_attack_post(const entity, const victim, const Float:damage)
{
	if (anpc_get_type(entity) == gZombieType)
		emit_sound(entity, CHAN_WEAPON, HIT_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}
