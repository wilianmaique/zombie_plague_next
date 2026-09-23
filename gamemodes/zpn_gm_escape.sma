#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <api_json_settings>
#include <amx_immutable_cvars>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

#define ESCAPE_FINISH_MIN_AREA 262144.0

enum
{
	TASK_ESCAPE_TIMEOUT = 3400,
	TASK_ESCAPE_FINISH,
	TASK_ESCAPE_CHECK_TEAMS,
	TASK_ESCAPE_MAP_NUKE
}

new gGameMode
new bool:gReady, bool:gActive, bool:gFinishPending, bool:gRoundClosing
new Array:gHumanSpawns, Array:gZombieSpawns
new gLastHumanSpawn = -1, gLastZombieSpawn = -1
new gMapName[32], gHumanSpawnClass[32], gZombieSpawnClass[32]
new gFinishClass[32], gFinishTarget[32], gFinishEvent[8]
new gFinishEntity
new bool:gFinishHuman[33]
new Float:gRoundMinutes, Float:gFirstRatio, Float:gRespawnDelay, Float:gFinishDelay, gMinFirst

public plugin_precache()
{
	gHumanSpawns = ArrayCreate(1, 0)
	gZombieSpawns = ArrayCreate(1, 0)

	gGameMode = zpn_gamemode_init()
	zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_NAME, "Zombie Escape")
	zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_FIND_NAME, "gm_escape")
	zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_NOTICE, "Fujam dos zombies!")
	zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_HUD_COLOR, "#ffb347")
	zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_CHANCE, 1)
	zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_MIN_PLAYERS, 2)
	zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_ROUND_TIME, 15.0)
	zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_DEATHMATCH, GAMEMODE_DEATHMATCH_ONLY_TR)
	zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_RESPAWN_TIME, 5.0)
	zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_MAP_TYPES, GAMEMODE_MAP_ESCAPE)
}

public plugin_init()
{
	register_plugin("[ZPN] GameMode: Zombie Escape", "1.0", "Wilian M.")

	if(!zpn_is_escape_map())
		return

	get_mapname(gMapName, charsmax(gMapName))
	load_escape_profile()
	collect_spawns(gHumanSpawnClass, gHumanSpawns)
	collect_spawns(gZombieSpawnClass, gZombieSpawns)

	if(!ArraySize(gHumanSpawns) || !ArraySize(gZombieSpawns))
	{
		server_print("[ZPN ZE] Map %s has no usable player spawns. Check escape.json.", gMapName)
		zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_CHANCE, 0)
		return
	}
	detect_finish_entity()

	gReady = true
	RegisterHookChain(RG_CSGameRules_GetPlayerSpawnSpot, "GetPlayerSpawnSpot_Pre", false)
	RegisterHookChain(RG_CSGameRules_RestartRound, "RestartRound_Pre", false)
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)
	RegisterHookChain(RG_RoundEnd, "RoundEnd_Pre", false)
	RegisterHam(Ham_TakeDamage, "player", "PlayerTakeDamage_Pre", false)

	if(rg_find_ent_by_class(NULLENT, "func_button", true))
		RegisterHam(Ham_Use, "func_button", "ButtonUse_Pre", false)

	if(gFinishClass[0])
	{
		if(equal(gFinishEvent, "touch"))
			RegisterHam(Ham_Touch, gFinishClass, "FinishTouch_Post", true)
		else
			RegisterHam(Ham_Use, gFinishClass, "FinishUse_Post", true)
	}
}

public plugin_cfg()
{
	if(gReady)
		set_cvar_float("mp_roundtime", gRoundMinutes + float(get_cvar_num("zpn_delay")) / 60.0)
}

public OnConfigsExecuted()
{
	if(!gReady)
		return

	amx_immutable_cvar_set("mp_round_infinite", "1")
	amx_immutable_cvar_set("mp_autoteambalance", "0")
}

public plugin_end()
{
	ArrayDestroy(gHumanSpawns)
	ArrayDestroy(gZombieSpawns)
}

load_escape_profile()
{
	gRoundMinutes = 15.0
	gFirstRatio = 0.12
	gMinFirst = 1
	gRespawnDelay = 5.0
	gFinishDelay = 5.0
	copy(gHumanSpawnClass, charsmax(gHumanSpawnClass), "both")
	copy(gZombieSpawnClass, charsmax(gZombieSpawnClass), "both")
	copy(gFinishEvent, charsmax(gFinishEvent), "auto")
	gFinishClass[0] = EOS
	gFinishTarget[0] = EOS

	// A ze_ map runs with the common CT/T spawns. The optional map section
	// only overrides maps whose objective needs a different interpretation.
	if(!json_setting_get_string(PATH_SETTINGS_ESCAPE, "Defaults", "human_spawn_class", gHumanSpawnClass, charsmax(gHumanSpawnClass)))
		json_setting_set_string(PATH_SETTINGS_ESCAPE, "Defaults", "human_spawn_class", gHumanSpawnClass)

	if(!json_setting_get_string(PATH_SETTINGS_ESCAPE, "Defaults", "zombie_spawn_class", gZombieSpawnClass, charsmax(gZombieSpawnClass)))
		json_setting_set_string(PATH_SETTINGS_ESCAPE, "Defaults", "zombie_spawn_class", gZombieSpawnClass)

	if(!json_setting_get_string(PATH_SETTINGS_ESCAPE, "Defaults", "finish_class", gFinishClass, charsmax(gFinishClass)))
		json_setting_set_string(PATH_SETTINGS_ESCAPE, "Defaults", "finish_class", gFinishClass)

	if(!json_setting_get_string(PATH_SETTINGS_ESCAPE, "Defaults", "finish_target", gFinishTarget, charsmax(gFinishTarget)))
		json_setting_set_string(PATH_SETTINGS_ESCAPE, "Defaults", "finish_target", gFinishTarget)

	if(!json_setting_get_string(PATH_SETTINGS_ESCAPE, "Defaults", "finish_event", gFinishEvent, charsmax(gFinishEvent)))
		json_setting_set_string(PATH_SETTINGS_ESCAPE, "Defaults", "finish_event", gFinishEvent)

	if(!json_setting_get_float(PATH_SETTINGS_ESCAPE, "Defaults", "round_minutes", gRoundMinutes))
		json_setting_set_float(PATH_SETTINGS_ESCAPE, "Defaults", "round_minutes", gRoundMinutes)

	if(!json_setting_get_float(PATH_SETTINGS_ESCAPE, "Defaults", "first_zombie_ratio", gFirstRatio))
		json_setting_set_float(PATH_SETTINGS_ESCAPE, "Defaults", "first_zombie_ratio", gFirstRatio)

	if(!json_setting_get_int(PATH_SETTINGS_ESCAPE, "Defaults", "first_zombie_min", gMinFirst))
		json_setting_set_int(PATH_SETTINGS_ESCAPE, "Defaults", "first_zombie_min", gMinFirst)

	if(!json_setting_get_float(PATH_SETTINGS_ESCAPE, "Defaults", "zombie_respawn_delay", gRespawnDelay))
		json_setting_set_float(PATH_SETTINGS_ESCAPE, "Defaults", "zombie_respawn_delay", gRespawnDelay)

	if(!json_setting_get_float(PATH_SETTINGS_ESCAPE, "Defaults", "finish_resolve_delay", gFinishDelay))
		json_setting_set_float(PATH_SETTINGS_ESCAPE, "Defaults", "finish_resolve_delay", gFinishDelay)

	json_setting_get_string(PATH_SETTINGS_ESCAPE, gMapName, "human_spawn_class", gHumanSpawnClass, charsmax(gHumanSpawnClass))
	json_setting_get_string(PATH_SETTINGS_ESCAPE, gMapName, "zombie_spawn_class", gZombieSpawnClass, charsmax(gZombieSpawnClass))
	json_setting_get_string(PATH_SETTINGS_ESCAPE, gMapName, "finish_class", gFinishClass, charsmax(gFinishClass))
	json_setting_get_string(PATH_SETTINGS_ESCAPE, gMapName, "finish_target", gFinishTarget, charsmax(gFinishTarget))
	json_setting_get_string(PATH_SETTINGS_ESCAPE, gMapName, "finish_event", gFinishEvent, charsmax(gFinishEvent))
	json_setting_get_float(PATH_SETTINGS_ESCAPE, gMapName, "round_minutes", gRoundMinutes)
	json_setting_get_float(PATH_SETTINGS_ESCAPE, gMapName, "first_zombie_ratio", gFirstRatio)
	json_setting_get_int(PATH_SETTINGS_ESCAPE, gMapName, "first_zombie_min", gMinFirst)
	json_setting_get_float(PATH_SETTINGS_ESCAPE, gMapName, "zombie_respawn_delay", gRespawnDelay)
	json_setting_get_float(PATH_SETTINGS_ESCAPE, gMapName, "finish_resolve_delay", gFinishDelay)

	if(gRoundMinutes < 1.0) gRoundMinutes = 1.0
	if(gFirstRatio < 0.01) gFirstRatio = 0.01
	if(gFirstRatio > 0.49) gFirstRatio = 0.49
	if(gMinFirst < 1) gMinFirst = 1
	if(gRespawnDelay < 0.5) gRespawnDelay = 0.5
	if(gFinishDelay < 0.1) gFinishDelay = 0.1

	zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_ROUND_TIME, gRoundMinutes)
	zpn_gamemode_set_prop(gGameMode, PROP_GAMEMODE_REGISTER_RESPAWN_TIME, gRespawnDelay)
}

collect_spawns(const classname[], Array:spawns)
{
	if(!classname[0])
		return

	if(equal(classname, "both"))
	{
		collect_spawn_class("info_player_start", spawns)
		collect_spawn_class("info_player_deathmatch", spawns)
		return
	}
	collect_spawn_class(classname, spawns)
}

collect_spawn_class(const classname[], Array:spawns)
{
	new ent = NULLENT
	while((ent = rg_find_ent_by_class(ent, classname, true)))
		ArrayPushCell(spawns, ent)
}

detect_finish_entity()
{
	new ent = NULLENT, target[32]
	if(gFinishClass[0])
	{
		if(!equal(gFinishEvent, "use") && !equal(gFinishEvent, "touch"))
		{
			if(equal(gFinishClass, "trigger_hurt"))
				copy(gFinishEvent, charsmax(gFinishEvent), "use")
			else
				copy(gFinishEvent, charsmax(gFinishEvent), "touch")
		}

		while((ent = rg_find_ent_by_class(ent, gFinishClass, true)))
		{
			if(!gFinishTarget[0])
				return
			get_entvar(ent, var_targetname, target, charsmax(target))
			if(equal(target, gFinishTarget))
				return
		}
		server_print("[ZPN ZE] Finish override %s/%s not found on %s; trying automatic detection.", gFinishClass, gFinishTarget, gMapName)
		gFinishClass[0] = EOS
		gFinishTarget[0] = EOS
		ent = NULLENT
	}

	if(rg_find_ent_by_class(NULLENT, "func_escapezone", true))
	{
		copy(gFinishClass, charsmax(gFinishClass), "func_escapezone")
		copy(gFinishEvent, charsmax(gFinishEvent), "touch")
		return
	}

	new Float:size[3], Float:damage, Float:volume, Float:bestVolume
	// Final nukes are typically large named hurt brushes switched on by the map.
	while((ent = rg_find_ent_by_class(ent, "trigger_hurt", true)))
	{
		get_entvar(ent, var_targetname, target, charsmax(target))
		if(!target[0] || !(get_entvar(ent, var_spawnflags) & 2))
			continue

		damage = get_entvar(ent, var_dmg)
		if(damage < 1000.0)
			continue

		get_entvar(ent, var_size, size)
		volume = size[0] * size[1] * size[2]
		if(!is_large_hurt(ent))
			continue

		if(volume > bestVolume)
		{
			bestVolume = volume
			gFinishEntity = ent
			copy(gFinishTarget, charsmax(gFinishTarget), target)
		}
	}

	if(gFinishEntity)
	{
		copy(gFinishClass, charsmax(gFinishClass), "trigger_hurt")
		copy(gFinishEvent, charsmax(gFinishEvent), "use")
		server_print("[ZPN ZE] Detected final trigger %s on %s.", gFinishTarget, gMapName)
	}
}

bool:is_large_hurt(const ent)
{
	new Float:size[3]
	get_entvar(ent, var_size, size)
	return bool:(size[0] * size[1] >= ESCAPE_FINISH_MIN_AREA
	|| size[0] * size[2] >= ESCAPE_FINISH_MIN_AREA
	|| size[1] * size[2] >= ESCAPE_FINISH_MIN_AREA)
}

public GetPlayerSpawnSpot_Pre(const id)
{
	new TeamName:team = get_member(id, m_iTeam)
	if(team != TEAM_CT && team != TEAM_TERRORIST)
		return HC_CONTINUE

	new spot = find_free_spawn(id, team == TEAM_TERRORIST)
	if(!spot)
		return HC_CONTINUE

	move_to_spot(id, spot)
	SetHookChainReturn(ATYPE_INTEGER, spot)
	return HC_SUPERCEDE
}

find_free_spawn(const id, bool:zombie)
{
	new Array:spawns = zombie ? gZombieSpawns : gHumanSpawns
	new count = ArraySize(spawns)
	if(!count)
		return 0

	new last = zombie ? gLastZombieSpawn : gLastHumanSpawn
	new spot, index, Float:origin[3]
	for(new i = 0; i < count; i++)
	{
		index = (last + i + 1) % count
		spot = ArrayGetCell(spawns, index)
		if(is_nullent(spot))
			continue

		get_entvar(spot, var_origin, origin)
		origin[2] += 1.0
		engfunc(EngFunc_TraceHull, origin, origin, 0, HULL_HUMAN, id, 0)
		if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
			continue

		if(zombie) gLastZombieSpawn = index
		else gLastHumanSpawn = index
		return spot
	}
	return 0
}

move_to_spot(const id, const spot)
{
	new Float:origin[3], Float:angles[3], Float:zero[3]
	get_entvar(spot, var_origin, origin)
	get_entvar(spot, var_angles, angles)
	origin[2] += 1.0
	engfunc(EngFunc_SetOrigin, id, origin)
	set_entvar(id, var_angles, angles)
	set_entvar(id, var_fixangle, 1)
	set_entvar(id, var_velocity, zero)
}

public zpn_round_started_post(const gamemode_id)
{
	if(!gReady || gamemode_id != gGameMode)
		return

	gActive = true
	gFinishPending = false
	gRoundClosing = false
	new players[32], count
	get_players(players, count, "ae", "CT")

	if(count < 2)
	{
		gActive = false
		rg_round_end(2.0, WINSTATUS_DRAW, ROUND_END_DRAW, .trigger = true)
		return
	}

	new wanted = floatround(float(count) * gFirstRatio, floatround_ceil)
	wanted = clamp(max(wanted, gMinFirst), 1, count - 1)

	for(new i = 0; i < count; i++)
	{
		new j = random_num(i, count - 1)
		new swap = players[i]
		players[i] = players[j]
		players[j] = swap
	}

	new chosen, spot
	for(new i = 0; i < count && chosen < wanted; i++)
	{
		spot = find_free_spawn(players[i], true)
		if(!spot || !zpn_set_user_zombie(players[i], 0, chosen == 0))
			continue

		move_to_spot(players[i], spot)
		chosen++
	}

	if(!chosen)
	{
		gActive = false
		rg_round_end(2.0, WINSTATUS_DRAW, ROUND_END_DRAW, .trigger = true)
		return
	}

	new Float:duration = gRoundMinutes * 60.0
	// Keep ReGameDLL's timer in sync for players who join during the escape.
	set_member_game(m_iRoundTimeSecs, floatround(get_gametime() + duration - Float:get_member_game(m_fRoundStartTimeReal), floatround_ceil))
	message_begin(MSG_ALL, get_user_msgid("RoundTime"))
	write_short(floatround(duration, floatround_ceil))
	message_end()
	set_task_ex(duration, "EscapeTimeout", TASK_ESCAPE_TIMEOUT)
}

public EscapeTimeout()
{
	if(gActive)
		end_escape_round(false)
}

public FinishUse_Post(const this, const caller, const activator, const use_type, const Float:value)
{
	if(!gActive || gFinishPending || !is_finish_entity(this))
		return

	// A finale trigger can be used again to turn it off. Only activation
	// starts the result check, after its lethal touch has had time to run.
	if(equal(gFinishClass, "trigger_hurt") && get_entvar(this, var_solid) != SOLID_TRIGGER)
		return

	gFinishPending = true
	for(new id = 1; id <= MaxClients; id++)
		gFinishHuman[id] = bool:(is_user_alive(id) && !zpn_is_user_zombie(id))
	set_task_ex(gFinishDelay, "ResolveFinish", TASK_ESCAPE_FINISH)
}

public FinishTouch_Post(const this, const other)
{
	if(!gActive || !is_finish_entity(this) || other < 1 || other > MaxClients
	|| !is_user_alive(other) || zpn_is_user_zombie(other))
		return

	end_escape_round(true)
}

bool:is_finish_entity(const ent)
{
	if(gFinishEntity)
		return ent == gFinishEntity

	if(!gFinishTarget[0])
		return true

	new target[32]
	get_entvar(ent, var_targetname, target, charsmax(target))
	return bool:equal(target, gFinishTarget)
}

public ResolveFinish()
{
	if(!gActive)
		return

	new humans
	for(new id = 1; id <= MaxClients; id++)
	{
		if(gFinishHuman[id] && is_user_alive(id) && !zpn_is_user_zombie(id))
			humans++
	}
	end_escape_round(bool:(humans > 0))
}

public ButtonUse_Pre(const this, const caller, const activator, const use_type, const Float:value)
{
	if(gRoundClosing)
		return HAM_SUPERCEDE

	if(!gActive)
		return HAM_IGNORED

	if((1 <= activator <= MaxClients && zpn_is_user_zombie(activator))
	|| (1 <= caller <= MaxClients && zpn_is_user_zombie(caller)))
		return HAM_SUPERCEDE

	return HAM_IGNORED
}

public PlayerTakeDamage_Pre(const victim, const inflictor, const attacker, const Float:damage, const damage_type)
{
	if(!is_user_alive(victim) || inflictor <= MaxClients || is_nullent(inflictor))
		return HAM_IGNORED

	new classname[32]
	get_entvar(inflictor, var_classname, classname, charsmax(classname))
	if(!equal(classname, "trigger_hurt"))
		return HAM_IGNORED

	if(gActive)
	{
		new Float:hurtDamage = get_entvar(inflictor, var_dmg)
		if(!gFinishPending && zpn_is_user_zombie(victim) && hurtDamage >= 1000.0
		&& is_large_hurt(inflictor) && !task_exists(TASK_ESCAPE_MAP_NUKE))
			set_task_ex(1.0, "CheckMapNuke", TASK_ESCAPE_MAP_NUKE)
		return HAM_IGNORED
	}

	if(zpn_is_round_started())
		return HAM_IGNORED

	new spot = find_free_spawn(victim, false)
	if(spot)
		move_to_spot(victim, spot)
	return HAM_SUPERCEDE
}

public CheckMapNuke()
{
	if(!gActive || gFinishPending)
		return

	new humans, zombies
	for(new id = 1; id <= MaxClients; id++)
	{
		if(!is_user_alive(id))
			continue

		if(zpn_is_user_zombie(id)) zombies++
		else humans++
	}

	if(humans && !zombies)
		end_escape_round(true)
}

public CBasePlayer_Killed_Post(const victim, const attacker, const shouldgib)
{
	schedule_team_check()
}

public zpn_user_infected_post(const victim, const infector, const class_id)
{
	schedule_team_check()
}

public client_disconnected(id)
{
	schedule_team_check()
}

schedule_team_check()
{
	if(gActive && !task_exists(TASK_ESCAPE_CHECK_TEAMS))
		set_task_ex(0.1, "CheckEscapeTeams", TASK_ESCAPE_CHECK_TEAMS)
}

public CheckEscapeTeams()
{
	if(!gActive)
		return

	new humans, zombies
	for(new id = 1; id <= MaxClients; id++)
	{
		if(!is_user_connected(id))
			continue

		if(zpn_is_user_zombie(id))
			zombies++
		else if(is_user_alive(id))
			humans++
	}

	if(!humans && !zombies)
	{
		gActive = false
		rg_round_end(2.0, WINSTATUS_DRAW, ROUND_END_DRAW, .trigger = true)
	}
	else if(!humans)
		end_escape_round(false)
	else if(!zombies)
		end_escape_round(true)
}

end_escape_round(bool:humans_won)
{
	if(!gActive)
		return

	gActive = false
	gFinishPending = false
	remove_task(TASK_ESCAPE_TIMEOUT)
	remove_task(TASK_ESCAPE_FINISH)
	remove_task(TASK_ESCAPE_CHECK_TEAMS)
	remove_task(TASK_ESCAPE_MAP_NUKE)

	if(humans_won)
	{
		zpn_print_color(0, print_team_blue, "^3Os humanos escaparam!")
		rg_round_end(2.0, WINSTATUS_CTS, ROUND_CTS_WIN, .trigger = true)
	}
	else
	{
		zpn_print_color(0, print_team_red, "^3Os zombies impediram a fuga!")
		rg_round_end(2.0, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN, .trigger = true)
	}
}

public RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event, Float:delay)
{
	gActive = false
	gFinishPending = false
	gRoundClosing = true
	remove_task(TASK_ESCAPE_TIMEOUT)
	remove_task(TASK_ESCAPE_FINISH)
	remove_task(TASK_ESCAPE_CHECK_TEAMS)
	remove_task(TASK_ESCAPE_MAP_NUKE)
}

public RestartRound_Pre()
{
	gActive = false
	gFinishPending = false
	gRoundClosing = false
	remove_task(TASK_ESCAPE_TIMEOUT)
	remove_task(TASK_ESCAPE_FINISH)
	remove_task(TASK_ESCAPE_CHECK_TEAMS)
	remove_task(TASK_ESCAPE_MAP_NUKE)
}
