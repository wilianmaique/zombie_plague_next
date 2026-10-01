#pragma dynamic 32768

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include "advanced_npc/advanced_npc"
#include "advanced_npc/advanced_npc_navigation"
#include "advanced_npc/math"
#include "advanced_npc/ground"

enum _:Actor
{
	ACT_ENTITY, ACT_SERIAL, ACT_TYPE, ACT_ROUTE,
	AnpcState:ACT_STATE,
	ACT_TARGET, ACT_TARGET_USERID, ACT_ATTACK_VICTIM, ACT_ATTACK_USERID,
	ACT_PATH_CURSOR, ACT_PATH_GOAL, ACT_FROM_NODE, ACT_TO_NODE, ACT_REVISION,
	ACT_JUMP_CURSOR, ACT_LADDER, ACT_RECOVERIES, ACT_SENSE_CURSOR, ACT_WAIT_DOOR,
	bool:ACT_REMOVE, bool:ACT_CROUCHED,
	AnpcAnimation:ACT_ANIMATION,
	Float:ACT_LAST_THINK, Float:ACT_NEXT_SENSE, Float:ACT_NEXT_REPATH,
	Float:ACT_LAST_SEEN, Float:ACT_LAST_KNOWN[3], Float:ACT_WINDUP_END,
	Float:ACT_NEXT_ATTACK, Float:ACT_DEATH_TIME, Float:ACT_NEXT_USE,
	Float:ACT_NEXT_JUMP_PROBE,
	Float:ACT_PROGRESS_TIME, Float:ACT_RECOVER_UNTIL, Float:ACT_OBSTACLE_WAIT,
	Float:ACT_KNOCKBACK_UNTIL, Float:ACT_LAST_HIT,
	Float:ACT_DIRECT_UNTIL, Float:ACT_DIRECT_GOAL[3], bool:ACT_DIRECT_OK,
	Float:ACT_PROGRESS_DISTANCE, Float:ACT_PROGRESS_GOAL[3], bool:ACT_PROGRESS_VALID,
	ACT_AGGRESSOR, ACT_AGGRESSOR_USERID
}

enum _:AnimationData { ANIM_SEQUENCE, Float:ANIM_RATE, bool:ANIM_LOOP, bool:ANIM_VALID }
enum _:CoreForwards { FW_TARGET, FW_SPAWN, FW_STATE, FW_DAMAGE_PRE, FW_DAMAGE_POST, FW_ATTACK_PRE, FW_ATTACK_POST, FW_DEATH, FW_REMOVE }

new gActor[ANPC_MAX_ACTORS][Actor], gProfile[ANPC_MAX_TYPES][AnpcProfile]
new gAnimation[ANPC_MAX_TYPES][ANPC_ANIM_COUNT][AnimationData]
new gTypeName[ANPC_MAX_TYPES][48], gTypeModel[ANPC_MAX_TYPES][128], gTypeOwner[ANPC_MAX_TYPES]
new bool:gTypeReady[ANPC_MAX_TYPES], bool:gTypesLocked, bool:gRegistrationOpen, bool:gUnloading
new gTypeCount, gActorCount, gSerial, gTrace, gForwards[CoreForwards], gCapacity
new Float:gThinkInterval, Float:gCorpseTime, Float:gRepathInterval, Float:gSampleTime, Float:gStepSize
new gPlayers[32], gPlayerCount, gPlayerUserid[33]
new Float:gPlayerFeet[33][3], Float:gPlayerOrigin[33][3], Float:gPlayerVelocity[33][3]
new gPlayerNode[ANPC_MAX_TYPES][33], gPlayerNodeRevision[ANPC_MAX_TYPES][33]
new Float:gPlayerNodeTime[ANPC_MAX_TYPES][33], Float:gPlayerNodeOrigin[ANPC_MAX_TYPES][33][3]
new Float:gRejectUntil[ANPC_MAX_ACTORS][33]

new const Float:STAND_MINS[3] = {-16.0, -16.0, -36.0}
new const Float:STAND_MAXS[3] = {16.0, 16.0, 36.0}
new const Float:DUCK_MINS[3] = {-16.0, -16.0, -18.0}
new const Float:DUCK_MAXS[3] = {16.0, 16.0, 18.0}
new const Float:ZERO_VECTOR[3] = {0.0, 0.0, 0.0}

#include "advanced_npc/studio"
#include "advanced_npc/perception"
#include "advanced_npc/movement"
#include "advanced_npc/combat"

public plugin_natives()
{
	register_library("advanced_npc")
	register_native("anpc_register_type", "native_register_type")
	register_native("anpc_register_animation", "native_register_animation")
	register_native("anpc_find_type", "native_find_type")
	register_native("anpc_get_type_name", "native_type_name")
	register_native("anpc_create", "native_create")
	register_native("anpc_remove", "native_remove")
	register_native("anpc_remove_all", "native_remove_all")
	register_native("anpc_is_npc", "native_is_npc")
	register_native("anpc_get_type", "native_get_type")
	register_native("anpc_get_faction", "native_get_faction")
	register_native("anpc_get_state", "native_get_state")
	register_native("anpc_get_target", "native_get_target")
	register_native("anpc_get_count", "native_get_count")
	register_native("anpc_get_capacity", "native_get_capacity")
	register_native("anpc_get_serial", "native_get_serial")
}

public plugin_precache()
{
	gRegistrationOpen = true
}

public plugin_init()
{
	gRegistrationOpen = false
	register_plugin("Advanced NPC: Entity Core", ANPC_VERSION, "ZPN")
	if (!is_rehlds() || !is_regamedll()) set_fail_state("Advanced NPC requires ReHLDS and ReGameDLL CS")
	gTrace = create_tr2()
	bind_pcvar_float(get_cvar_pointer("sv_stepsize"), gStepSize)
	RegisterHam(Ham_TraceAttack, "info_target", "npc_trace_attack_pre")
	RegisterHam(Ham_TakeDamage, "info_target", "npc_take_damage_pre")
	RegisterHam(Ham_BloodColor, "info_target", "npc_blood_color_pre")
	RegisterHookChain(RG_CSGameRules_RestartRound, "round_restart_pre")
	register_forward(FM_FreeEntPrivateData, "entity_freed")

	gForwards[FW_TARGET] = CreateMultiForward("anpc_target_filter", ET_STOP, FP_CELL, FP_CELL)
	gForwards[FW_SPAWN] = CreateMultiForward("anpc_spawn_post", ET_IGNORE, FP_CELL, FP_CELL)
	gForwards[FW_STATE] = CreateMultiForward("anpc_state_changed", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	gForwards[FW_DAMAGE_PRE] = CreateMultiForward("anpc_damage_pre", ET_STOP, FP_CELL, FP_CELL, FP_FLOAT, FP_CELL)
	gForwards[FW_DAMAGE_POST] = CreateMultiForward("anpc_damage_post", ET_IGNORE, FP_CELL, FP_CELL, FP_FLOAT, FP_CELL)
	gForwards[FW_ATTACK_PRE] = CreateMultiForward("anpc_attack_pre", ET_STOP, FP_CELL, FP_CELL, FP_FLOAT)
	gForwards[FW_ATTACK_POST] = CreateMultiForward("anpc_attack_post", ET_IGNORE, FP_CELL, FP_CELL, FP_FLOAT)
	gForwards[FW_DEATH] = CreateMultiForward("anpc_death_post", ET_IGNORE, FP_CELL, FP_CELL)
	gForwards[FW_REMOVE] = CreateMultiForward("anpc_remove_pre", ET_IGNORE, FP_CELL, FP_CELL)
	bind_pcvar_num(create_cvar("anpc_capacity", "24", FCVAR_NONE, "Maximum occupied NPC entity slots", true, 1.0, true, float(ANPC_MAX_ACTORS)), gCapacity)
	bind_pcvar_float(create_cvar("anpc_think_interval", "0.05", FCVAR_NONE, "Active NPC think interval", true, 0.04, true, 0.2), gThinkInterval)
	bind_pcvar_float(create_cvar("anpc_repath_interval", "0.75", FCVAR_NONE, "Minimum interval between route requests", true, 0.3, true, 3.0), gRepathInterval)
	bind_pcvar_float(create_cvar("anpc_corpse_time", "4.5", FCVAR_NONE, "Corpse lifetime", true, 0.0, true, 15.0), gCorpseTime)
}

public plugin_cfg()
{
	gTypesLocked = true
	for (new type = 0; type < gTypeCount; type++)
	{
		gTypeReady[type] = true
		for (new AnpcAnimation:animation = ANPC_ANIM_IDLE; animation < ANPC_ANIM_COUNT; animation++)
			if (!gAnimation[type][animation][ANIM_VALID]) gTypeReady[type] = false
		if (!gTypeReady[type]) log_amx("Type '%s' disabled: an animation label is missing/invalid", gTypeName[type])
	}
}

public plugin_end()
{
	gUnloading = true
	for (new slot = 0; slot < ANPC_MAX_ACTORS; slot++) if (gActor[slot][ACT_ENTITY]) npc_destroy(slot)
	for (new i = 0; i < CoreForwards; i++) DestroyForward(gForwards[i])
	free_tr2(gTrace)
	gTrace = 0
}

stock npc_slot(const entity)
{
	if (entity <= MaxClients || !is_entity(entity) || get_entvar(entity, var_iuser4) != ANPC_MARKER) return -1
	new slot = get_entvar(entity, var_iuser1)-1
	if (!(0 <= slot < ANPC_MAX_ACTORS) || gActor[slot][ACT_ENTITY] != entity
	|| get_entvar(entity, var_iuser2) != gActor[slot][ACT_SERIAL]) return -1
	return slot
}

stock bool:npc_live(const slot)
{
	return 0 <= slot < ANPC_MAX_ACTORS && gActor[slot][ACT_ENTITY] && !gActor[slot][ACT_REMOVE]
	&& gActor[slot][ACT_STATE] != ANPC_DEAD && npc_slot(gActor[slot][ACT_ENTITY]) == slot
}

stock npc_state(const slot, const AnpcState:next_state)
{
	if (gActor[slot][ACT_STATE] == next_state) return
	new AnpcState:previous = gActor[slot][ACT_STATE], result
	gActor[slot][ACT_STATE] = next_state
	ExecuteForward(gForwards[FW_STATE], result, gActor[slot][ACT_ENTITY], previous, next_state)
}

stock npc_mark_remove(const slot)
{
	if (gActor[slot][ACT_REMOVE]) return
	gActor[slot][ACT_REMOVE] = true
	new entity = gActor[slot][ACT_ENTITY]
	set_entvar(entity, var_takedamage, DAMAGE_NO)
	set_entvar(entity, var_solid, SOLID_NOT)
	set_entvar(entity, var_velocity, ZERO_VECTOR)
	set_entvar(entity, var_nextthink, get_gametime()+0.01)
	anpc_nav_cancel(gActor[slot][ACT_ROUTE])
}

stock npc_release_slot(const slot)
{
	anpc_nav_close(gActor[slot][ACT_ROUTE])
	arrayset(gActor[slot], 0, Actor)
	for (new id = 1; id <= MaxClients; id++) gRejectUntil[slot][id] = 0.0
	gActorCount--
}

stock npc_destroy(const slot)
{
	new entity = gActor[slot][ACT_ENTITY], type = gActor[slot][ACT_TYPE], result
	if (npc_slot(entity) == slot)
	{
		gActor[slot][ACT_REMOVE] = true
		if (!gUnloading) ExecuteForward(gForwards[FW_REMOVE], result, entity, type)
		// The forward may already have removed the entity through another module.
		if (npc_slot(entity) == slot)
		{
			SetThink(entity, "")
			set_entvar(entity, var_iuser4, 0)
			rg_remove_entity(entity)
		}
	}
	if (gActor[slot][ACT_ENTITY] == entity) npc_release_slot(slot)
}

public entity_freed(const entity)
{
	new slot = npc_slot(entity)
	if (slot >= 0) npc_release_slot(slot)
	return FMRES_IGNORED
}

public round_restart_pre()
{
	for (new slot = 0; slot < ANPC_MAX_ACTORS; slot++) if (gActor[slot][ACT_ENTITY]) npc_mark_remove(slot)
}

public native_register_type(const plugin)
{
	if (!gRegistrationOpen || gTypesLocked || gTypeCount == ANPC_MAX_TYPES) return ANPC_INVALID_TYPE
	new name[48], model[128], profile[AnpcProfile]
	get_string(1, name, charsmax(name))
	get_string(2, model, charsmax(model))
	get_array(3, profile, AnpcProfile)
	if (!name[0] || !model[0] || !file_exists(model) || !npc_profile_valid(profile)) return ANPC_INVALID_TYPE
	for (new type = 0; type < gTypeCount; type++) if (equal(gTypeName[type], name)) return ANPC_INVALID_TYPE
	new type = gTypeCount++
	copy(gTypeName[type], charsmax(gTypeName[]), name)
	copy(gTypeModel[type], charsmax(gTypeModel[]), model)
	for (new field = 0; field < AnpcProfile; field++) gProfile[type][field] = profile[field]
	gTypeOwner[type] = plugin
	precache_model(model)
	return type
}

stock bool:npc_profile_valid(const profile[AnpcProfile])
{
	for (new field = ANPC_HEALTH; field <= ANPC_JUMP_SPEED; field++)
		if (!anpc_finite(Float:profile[field], 1000000.0)) return false
	return 1.0 <= profile[ANPC_HEALTH] <= 1000000.0 && 50.0 <= profile[ANPC_SPEED] <= 450.0
	&& 0.1 <= profile[ANPC_GRAVITY] <= 2.0 && 1.0 <= profile[ANPC_DAMAGE] <= 10000.0
	&& 32.0 <= profile[ANPC_ATTACK_RANGE] <= 112.0 && 0.2 <= profile[ANPC_ATTACK_COOLDOWN] <= 10.0
	&& 0.05 <= profile[ANPC_ATTACK_WINDUP] < profile[ANPC_ATTACK_COOLDOWN]
	&& 1.0 <= profile[ANPC_HEAD_MULTIPLIER] <= 10.0 && 0.0 <= profile[ANPC_KNOCKBACK] <= 5.0
	&& 0.1 <= profile[ANPC_SENSE_INTERVAL] <= 2.0 && 0.0 <= profile[ANPC_MEMORY_TIME] <= 60.0
	&& 64.0 <= profile[ANPC_SIGHT_RANGE] <= 8192.0 && 100.0 <= profile[ANPC_JUMP_SPEED] <= 600.0
	&& !(profile[ANPC_CAPABILITIES] & ~ANPC_CAP_ALL) && profile[ANPC_FACTION] >= 0
	&& (profile[ANPC_GLOBAL_HUNT] == 0 || profile[ANPC_GLOBAL_HUNT] == 1)
}

public bool:native_register_animation(const plugin)
{
	new type = get_param(1), animation = get_param(2), label[32]
	if (!gRegistrationOpen || gTypesLocked || !(0 <= type < gTypeCount) || gTypeOwner[type] != plugin || !(0 <= animation < _:ANPC_ANIM_COUNT)) return false
	get_string(3, label, charsmax(label))
	return studio_sequence(gTypeModel[type], label, gAnimation[type][AnpcAnimation:animation])
}

public native_find_type()
{
	new name[48]
	get_string(1, name, charsmax(name))
	for (new type = 0; type < gTypeCount; type++) if (equal(gTypeName[type], name)) return type
	return ANPC_INVALID_TYPE
}

public native_create()
{
	new type = get_param(1), Float:feet[3], Float:yaw = get_param_f(3)
	get_array_f(2, feet, 3)
	if (gUnloading || !gTrace || !gTypesLocked || !(0 <= type < gTypeCount) || !gTypeReady[type] || gActorCount >= gCapacity
	|| !anpc_finite(yaw, 36000.0) || anpc_nav_editing() || (!anpc_nav_count() && !anpc_nav_area_count())
	|| (anpc_nav_area_at(feet,gProfile[type][ANPC_CAPABILITIES]) < 0
		&& anpc_nav_nearest(feet,gProfile[type][ANPC_CAPABILITIES]) < 0)) return 0
	new slot = -1
	for (new i = 0; i < ANPC_MAX_ACTORS; i++) if (!gActor[i][ACT_ENTITY]) { slot = i; break; }
	if (slot < 0) return 0
	new Float:origin[3], Float:angles[3], bool:duck
	anpc_copy_vec(feet, origin)
	origin[2] += 36.1
	engfunc(EngFunc_TraceHull, origin, origin, DONT_IGNORE_MONSTERS, HULL_HUMAN, 0, gTrace)
	if (get_tr2(gTrace, TR_StartSolid) || get_tr2(gTrace, TR_AllSolid)
	|| (anpc_nav_area_at(feet,gProfile[type][ANPC_CAPABILITIES]) >= 0 && anpc_nav_area_at(feet,0) < 0))
	{
		if (!(gProfile[type][ANPC_CAPABILITIES] & ANPC_CAP_CROUCH)) return 0
		duck = true
		origin[2] -= 18.0
		engfunc(EngFunc_TraceHull, origin, origin, DONT_IGNORE_MONSTERS, HULL_HEAD, 0, gTrace)
		if (get_tr2(gTrace, TR_StartSolid) || get_tr2(gTrace, TR_AllSolid)) return 0
	}
	new route = anpc_nav_open()
	if (!route) return 0
	new entity = rg_create_entity("info_target", false)
	if (!entity) { anpc_nav_close(route); return 0; }
	dllfunc(DLLFunc_Spawn, entity)
	set_entvar(entity, var_classname, ANPC_CLASSNAME)
	engfunc(EngFunc_SetModel, entity, gTypeModel[type])
	if (duck) engfunc(EngFunc_SetSize, entity, DUCK_MINS, DUCK_MAXS)
	else engfunc(EngFunc_SetSize, entity, STAND_MINS, STAND_MAXS)
	engfunc(EngFunc_SetOrigin, entity, origin)
	set_entvar(entity, var_movetype, MOVETYPE_STEP)
	set_entvar(entity, var_solid, SOLID_SLIDEBOX)
	set_entvar(entity, var_flags, FL_MONSTER | FL_MONSTERCLIP | (duck ? FL_DUCKING : 0))
	set_entvar(entity, var_takedamage, DAMAGE_AIM)
	set_entvar(entity, var_health, gProfile[type][ANPC_HEALTH])
	set_entvar(entity, var_max_health, gProfile[type][ANPC_HEALTH])
	set_entvar(entity, var_gravity, gProfile[type][ANPC_GRAVITY])
	set_entvar(entity, var_friction, 1.0)
	if (!engfunc(EngFunc_DropToFloor, entity)) { rg_remove_entity(entity); anpc_nav_close(route); return 0; }
	angles[1] = yaw
	set_entvar(entity, var_angles, angles)
	set_entvar(entity, var_iuser4, ANPC_MARKER)
	set_entvar(entity, var_iuser1, slot+1)
	set_entvar(entity, var_iuser2, ++gSerial)
	gActor[slot][ACT_ENTITY] = entity
	gActor[slot][ACT_SERIAL] = gSerial
	gActor[slot][ACT_TYPE] = type
	gActor[slot][ACT_ROUTE] = route
	gActor[slot][ACT_CROUCHED] = duck
	gActor[slot][ACT_PATH_GOAL] = ANPC_INVALID_NODE
	gActor[slot][ACT_FROM_NODE] = ANPC_INVALID_NODE
	gActor[slot][ACT_TO_NODE] = ANPC_INVALID_NODE
	gActor[slot][ACT_JUMP_CURSOR] = -1
	gActor[slot][ACT_REVISION] = anpc_nav_revision()
	gActor[slot][ACT_LAST_THINK] = get_gametime()
	gActor[slot][ACT_NEXT_SENSE] = get_gametime() + float(slot % 5)*0.03
	gActor[slot][ACT_PROGRESS_TIME] = get_gametime()
	gActorCount++
	npc_animation(slot, ANPC_ANIM_IDLE, true)
	SetThink(entity, "npc_think")
	set_entvar(entity, var_nextthink, get_gametime()+0.01+float(slot % 5)*0.01)
	new result
	ExecuteForward(gForwards[FW_SPAWN], result, entity, type)
	return npc_live(slot) ? entity : 0
}

public bool:native_remove()
{
	new slot = npc_slot(get_param(1))
	if (slot < 0) return false
	npc_mark_remove(slot)
	return true
}

public native_remove_all()
{
	new count
	for (new slot = 0; slot < ANPC_MAX_ACTORS; slot++) if (gActor[slot][ACT_ENTITY]) { npc_mark_remove(slot); count++; }
	return count
}

public bool:native_is_npc() { return npc_slot(get_param(1)) >= 0; }
public native_get_count() { return gActorCount; }
public native_get_capacity() { return gCapacity; }
public native_get_type() { new slot = npc_slot(get_param(1)); return slot < 0 ? ANPC_INVALID_TYPE : gActor[slot][ACT_TYPE]; }
public native_get_faction() { new slot = npc_slot(get_param(1)); return slot < 0 ? ANPC_FACTION_NEUTRAL : gProfile[gActor[slot][ACT_TYPE]][ANPC_FACTION]; }
public AnpcState:native_get_state() { new slot = npc_slot(get_param(1)); return slot < 0 ? ANPC_DEAD : gActor[slot][ACT_STATE]; }
public native_get_target() { new slot = npc_slot(get_param(1)); return slot < 0 ? 0 : gActor[slot][ACT_TARGET]; }
public native_get_serial() { new slot = npc_slot(get_param(1)); return slot < 0 ? 0 : gActor[slot][ACT_SERIAL]; }

public native_type_name()
{
	new type = get_param(1)
	if (!(0 <= type < gTypeCount) || get_param(3) < 0) return 0
	return set_string(2, gTypeName[type], get_param(3))
}

public npc_think(const entity)
{
	new slot = npc_slot(entity)
	if (slot < 0) return
	if (gActor[slot][ACT_REMOVE]) { npc_destroy(slot); return; }
	new Float:now = get_gametime(), Float:dt = floatclamp(now-gActor[slot][ACT_LAST_THINK], 0.001, 0.2)
	gActor[slot][ACT_LAST_THINK] = now
	if (gActor[slot][ACT_STATE] == ANPC_DEAD)
	{
		npc_animate(slot, dt)
		if (now >= gActor[slot][ACT_DEATH_TIME]) { npc_destroy(slot); return; }
		set_entvar(entity, var_nextthink, now+0.1)
		return
	}
	if (gActor[slot][ACT_REVISION] != anpc_nav_revision())
	{
		gActor[slot][ACT_REVISION] = anpc_nav_revision()
		npc_clear_route(slot)
		gActor[slot][ACT_NEXT_SENSE] = now
	}
	if (now >= gActor[slot][ACT_NEXT_SENSE])
	{
		npc_sense(slot, now)
		if (!npc_live(slot)) return
		gActor[slot][ACT_NEXT_SENSE] = now+gProfile[gActor[slot][ACT_TYPE]][ANPC_SENSE_INTERVAL]
	}
	if (gActor[slot][ACT_STATE] == ANPC_ATTACK) npc_attack_impact(slot, now)
	else if (gActor[slot][ACT_TARGET] && npc_target_current(slot)) npc_hunt(slot, dt, now)
	else
	{
		npc_clear_target(slot)
		npc_stop_ground(slot)
		npc_state(slot, ANPC_IDLE)
		if (!npc_live(slot)) return
		npc_animation(slot, ANPC_ANIM_IDLE)
	}
	if (!npc_live(slot)) return
	npc_animate(slot, dt)
	set_entvar(entity, var_nextthink, now + (gActor[slot][ACT_TARGET] || gActor[slot][ACT_STATE] == ANPC_ATTACK ? gThinkInterval : 0.2))
}
