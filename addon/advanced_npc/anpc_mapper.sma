#pragma dynamic 32768

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include "advanced_npc/advanced_npc"
#include "advanced_npc/advanced_npc_navigation"
#include "advanced_npc/advanced_npc_mapper"
#include "advanced_npc/math"

#define SCAN_DIRECTIONS 10
#define SCAN_DONE ((1<<SCAN_DIRECTIONS)-1)
#define SCAN_MAX_SEEDS 512
#define SCAN_MAX_LADDERS 128
#define SCAN_TASK_AUTO 8160
#define SCAN_FRAME_OPERATIONS 96
#define SCAN_SENSE_REACH 3.0
#define SCAN_SECTOR_ALIGNMENT 0.93

enum _:ScanSeed { Float:SEED_FEET[3], SEED_FLAGS, bool:SEED_USED }
enum _:ScanLadder { LADDER_ENTITY, Float:LADDER_MINS[3], Float:LADDER_MAXS[3] }
enum ScanPurpose { SCAN_FRONTIER, SCAN_RETURN, SCAN_TRAVEL }
enum ScanMotion { SCAN_WALK, SCAN_JUMP, SCAN_DROP, SCAN_LADDER }
enum ScanProbe { PROBE_FLOOR, PROBE_HULL, PROBE_WALK, PROBE_ARC, PROBE_RUNUP }
enum _:ScanProfile { Float:SCAN_CFG_SPACING, Float:SCAN_CFG_SPEED, Float:SCAN_CFG_GRAVITY, Float:SCAN_CFG_DROP, SCAN_CFG_SURVEY }

new gBot, gBotUserid, gFrame, gTouch, gTrace, gActiveCvar, gStartForward, gFinishForward, gEdgeForward
new gBeamSprite, gBeamTrace, gBeamEnabled, Float:gNextBeam
new HookChain:gHooks[6], bool:gActive, bool:gFinishing, bool:gFinishingMap, bool:gDriving, bool:gWatch[33]
new AnpcScanStatus:gStage = ANPC_SCAN_OFF, AnpcScanStatus:gResumeStage
new ScanPurpose:gPurpose, ScanMotion:gMotion, ScanProbe:gProbe
new gMask[ANPC_MAX_NODES], gVisits[ANPC_MAX_NODES], gUnreachable[ANPC_MAX_NODES]
new gExploreParent[ANPC_MAX_NODES], bool:gParentClosed[ANPC_MAX_NODES], bool:gSeedRejected[ANPC_MAX_NODES]
new Float:gKnown[ANPC_MAX_NODES][3], gKnownFlags[ANPC_MAX_NODES], gKnownCount
new gSeeds[SCAN_MAX_SEEDS][ScanSeed], gSeedCount, gSeedCursor, gSeedEpisodes
new gLadder[SCAN_MAX_LADDERS][ScanLadder], gLadderCount
new gCurrent = -1, gSource = -1, gGoalNode = -1, gDirection, gRangeIndex, gHeading = -1, gSeedAnchor = -1
new gSenseNode = -1, gSenseEpoch, gSenseCursor, gSenseTarget[8]
new Float:gSenseDistance[8], Float:gSenseScore[8], Float:gFrontierRange
new Float:gSenseVector[8][2], Float:gFrontierVector[2]
new gSweeps, gKnownSkips, gReturnTrials, gLongTrials, Float:gExploreDistance, Float:gTravelDistance
new gRoute, gRouteGoal = -1, gRouteCursor, gSelectCursor, gSelectBest = -1, Float:gSelectScore
new gGraphEpoch, gLinks, gWalks, gJumps, gDrops, gClimbs, gFailures, gHazards, gWarps, gUnsupported, gCapacitySkips
new gTraces, gTraceLimit, gAuto, gSurveyEnabled, gRestart, gSaveRecords
new Float:gSpacing, Float:gSpeed, Float:gGravity, Float:gDropLimit, Float:gBudgetMs, Float:gCheckpointInterval
new Float:gNextDrive, Float:gLastDrive, Float:gStarted, Float:gDeadline, Float:gProgressTime, Float:gBestDistance
new Float:gCheckpointTime, Float:gFrameStart, Float:gNextUse, Float:gStableSince
new Float:gSourceFeet[3], Float:gGoalFeet[3], Float:gRunupFeet[3], Float:gArcPrevious[3]
new Float:gFlightTime, Float:gJumpSpeed = 268.32816, Float:gLaunchVelocity[3], Float:gExpectedVelocity[3]
new Float:gLaunchFeet[3], Float:gLastFeet[3], Float:gPreviousGround[3], Float:gWalkPreviousZ
new gLaunchNode = -1, gArcSample, gArcSamples, gWalkSample, gWalkSamples, gGoalFlags, gJumpPhase
new gObstacle, gObstacleAttempts, bool:gDuck, bool:gRunup, bool:gAirborne, bool:gJumped
new bool:gHazard, bool:gWarp, bool:gTouchedLadder, bool:gLowFloorRetry, bool:gRaisedWalk
new Float:gBoundsMin[3], Float:gBoundsMax[3], gSurveyCursor, gSurveyTotal, gSurveySize[3]
new Float:gSurveyStep, bool:gSurveyValid, bool:gSurveyDone
new gMap[64], gNavPath[256], gMemoryPath[256], gReportPath[256], gBspHash[33], gBspSize
new gSaveFile, gSavePhase, gSaveNode, gSaveLink, gSaveCount, bool:gStopAfterSave, bool:gCompleted, bool:gSaved
new gSaveTemporary[288], gNavDigest[33], bool:gMemoryLoaded
new gLoadFile, gLoadPhase, gLoadNode, gLoadSeed, gLoadSeedCount, bool:gResetGraph, bool:gSaveRequested
new bool:gCapacityHalt, bool:gSeedSettling, bool:gLaunchPending, bool:gSegmentDuck
new bool:gAbortRequested
new Float:gServerGravity, Float:gTrialSpeed, Float:gSeedDeadline
new gConfig[ScanProfile], gPhysicsCvar[7], gPhysicsDigest[33], Float:gJumpDuckLift
new const Float:SCAN_ZERO[3] = {0.0, 0.0, 0.0}
new const Float:SCAN_DIR[8][2] =
{
	{1.0,0.0}, {0.70710678,0.70710678}, {0.0,1.0}, {-0.70710678,0.70710678},
	{-1.0,0.0}, {-0.70710678,-0.70710678}, {0.0,-1.0}, {0.70710678,-0.70710678}
}
new const Float:SCAN_RANGE[4] = {1.0, 0.5, 1.75, 2.5}

#include "advanced_npc/mapper_world"
#include "advanced_npc/mapper_exploration"
#include "advanced_npc/mapper_motion"
#include "advanced_npc/mapper_storage"

public plugin_precache()
{
	gBeamSprite = precache_model("sprites/laserbeam.spr")
}

public plugin_natives()
{
	register_library("advanced_npc_mapper")
	register_native("anpc_scan_start", "native_scan_start")
	register_native("anpc_scan_stop", "native_scan_stop")
	register_native("anpc_scan_running", "native_scan_running")
	register_native("anpc_scan_bot", "native_scan_bot")
	register_native("anpc_scan_status", "native_scan_status")
}

public plugin_init()
{
	register_plugin("Advanced NPC: Autonomous Mapper", ANPC_VERSION, "ZPN")
	gActiveCvar = create_cvar("anpc_scan_active", "0", FCVAR_SERVER | FCVAR_SPONLY, "Maintenance state controlled by automatic mapper")
	if (!is_rehlds() || !is_regamedll()) set_fail_state("Automatic mapper requires ReHLDS and ReGameDLL CS")
	register_concmd("anpc_scan", "command_scan", ADMIN_RCON, "start [new] | stop | pause | resume | save | status | seed [x y z] | watch 0|1")
	bind_pcvar_num(create_cvar("anpc_scan_auto", "0", FCVAR_NONE, "Automatically map when no navigation exists", true, 0.0, true, 1.0), gAuto)
	bind_pcvar_num(create_cvar("anpc_scan_beam", "1", FCVAR_NONE, "Show the scout viewing direction while mapping", true, 0.0, true, 1.0), gBeamEnabled)
	bind_pcvar_num(create_cvar("anpc_scan_traces", "24", FCVAR_NONE, "Maximum mapper hull/line traces per frame (engine player physics excluded)", true, 16.0, true, 64.0), gTraceLimit)
	bind_pcvar_num(create_cvar("anpc_scan_survey", "1", FCVAR_NONE, "Survey BSP bounds for additional exploration seeds", true, 0.0, true, 1.0), gConfig[SCAN_CFG_SURVEY])
	bind_pcvar_num(create_cvar("anpc_scan_restart", "0", FCVAR_NONE, "Optional round restart when mapping ends", true, 0.0, true, 1.0), gRestart)
	bind_pcvar_num(create_cvar("anpc_scan_save_records", "32", FCVAR_NONE, "Maximum records written per frame", true, 4.0, true, 128.0), gSaveRecords)
	bind_pcvar_float(create_cvar("anpc_scan_spacing", "96", FCVAR_NONE, "Exploration spacing; captured when scan starts", true, 48.0, true, 160.0), gConfig[SCAN_CFG_SPACING])
	bind_pcvar_float(create_cvar("anpc_scan_speed", "300", FCVAR_NONE, "Scout player maximum speed; captured when scan starts", true, 100.0, true, 320.0), gConfig[SCAN_CFG_SPEED])
	bind_pcvar_float(create_cvar("anpc_scan_gravity", "0.7", FCVAR_NONE, "Scout gravity multiplier; captured when scan starts", true, 0.3, true, 1.5), gConfig[SCAN_CFG_GRAVITY])
	bind_pcvar_float(create_cvar("anpc_scan_max_drop", "160", FCVAR_NONE, "Maximum admitted drop; captured when scan starts", true, 18.0, true, 256.0), gConfig[SCAN_CFG_DROP])
	bind_pcvar_float(create_cvar("anpc_scan_budget_ms", "1.0", FCVAR_NONE, "Cooperative CPU budget per frame; movement is serviced first", true, 0.2, true, 4.0), gBudgetMs)
	bind_pcvar_float(create_cvar("anpc_scan_checkpoint", "60", FCVAR_NONE, "Seconds between incremental checkpoints", true, 15.0, true, 600.0), gCheckpointInterval)
	gHooks[0] = RegisterHookChain(RG_CSGameRules_CheckWinConditions, "scan_round_pre")
	gHooks[1] = RegisterHookChain(RG_CSGameRules_RestartRound, "scan_round_pre")
	gHooks[2] = RegisterHookChain(RG_CBasePlayer_TakeDamage, "scan_damage_pre")
	gHooks[3] = RegisterHookChain(RG_CBasePlayer_Killed, "scan_killed_pre")
	gHooks[4] = RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "scan_speed_post", true)
	gHooks[5] = RegisterHookChain(RG_PM_Jump, "scan_jump_post", true)
	for (new i = 0; i < sizeof gHooks; i++) DisableHookChain(gHooks[i])
	new const physics_cvars[][] = {"sv_gravity", "sv_stepsize", "sv_accelerate", "sv_airaccelerate", "sv_friction", "sv_maxspeed", "mp_jump_height"}
	for (new i = 0; i < sizeof physics_cvars; i++)
	{
		gPhysicsCvar[i] = get_cvar_pointer(physics_cvars[i])
		if (gPhysicsCvar[i]) hook_cvar_change(gPhysicsCvar[i], "scan_physics_changed")
	}
	gStartForward = CreateMultiForward("anpc_scan_started", ET_IGNORE, FP_CELL)
	gFinishForward = CreateMultiForward("anpc_scan_finished", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL)
	gEdgeForward = CreateMultiForward("anpc_scan_edge_verified", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	gTrace = create_tr2()
	gBeamTrace = create_tr2()
	rh_get_mapname(gMap, charsmax(gMap), MNT_TRUE)
	new directory[192], bsp[128]
	get_configsdir(directory, charsmax(directory))
	formatex(gNavPath, charsmax(gNavPath), "%s/advanced_npc/maps/%s.nav", directory, gMap)
	formatex(gMemoryPath, charsmax(gMemoryPath), "%s/advanced_npc/maps/%s.scan", directory, gMap)
	formatex(gReportPath, charsmax(gReportPath), "%s/advanced_npc/maps/%s.scan.txt", directory, gMap)
	formatex(bsp, charsmax(bsp), "maps/%s.bsp", gMap)
	gBspSize = file_size(bsp)
	if (gBspSize > 0) hash_file(bsp, Hash_Md5, gBspHash, charsmax(gBspHash))
	scan_read_bounds(bsp)
	scan_cache_ladders()
	set_pcvar_num(gActiveCvar, 0)
}

public plugin_cfg() { set_task(2.0, "scan_auto_start", SCAN_TASK_AUTO); }
public scan_auto_start() { if (gAuto && !anpc_nav_count()) scan_start(false); }

public plugin_end()
{
	gFinishingMap = true
	remove_task(SCAN_TASK_AUTO)
	if (gLoadFile) { fclose(gLoadFile); gLoadFile = 0; }
	if (gSaveFile) { fclose(gSaveFile); gSaveFile = 0; }
	// An interrupted temporary file is never committed over a good checkpoint.
	if (gActive) scan_finish(false, "map shutdown")
	if (gTrace) free_tr2(gTrace)
	if (gBeamTrace) free_tr2(gBeamTrace)
	DestroyForward(gStartForward)
	DestroyForward(gFinishForward)
	DestroyForward(gEdgeForward)
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	gWatch[id] = false
	if (id == gBot && !gFinishing)
	{
		gBot = gBotUserid = 0
		log_amx("Scout disconnected; mapping stopped. Last committed checkpoint is preserved.")
		scan_finish(false, "scout disconnected")
	}
}

public bool:native_scan_start() { return scan_start(bool:get_param(1)); }
public bool:native_scan_stop() { return scan_stop(bool:get_param(1)); }
public bool:native_scan_running() { return gActive; }
public native_scan_bot() { return scan_bot_valid() ? gBot : 0; }
public AnpcScanStatus:native_scan_status() { return gStage; }

public command_scan(const id, const level, const cid)
{
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	new action[16], option[16]
	read_argv(1, action, charsmax(action))
	read_argv(2, option, charsmax(option))
	if (equal(action, "start")) console_print(id, "[ANPC] Mapper started: %d", scan_start(bool:equal(option, "new")))
	else if (equal(action, "stop")) console_print(id, "[ANPC] Saving and stopping: %d", scan_stop(true))
	else if (equal(action, "pause") && gActive && gStage != ANPC_SCAN_SAVE && gStage != ANPC_SCAN_PAUSED)
	{
		scan_interrupt_trial()
		gResumeStage = gStage
		gStage = ANPC_SCAN_PAUSED
		console_print(id, "[ANPC] Mapper paused; graph ownership and scout are retained.")
	}
	else if (equal(action, "resume") && gActive && gStage == ANPC_SCAN_PAUSED)
	{
		// Restart the interrupted local trial from a verified anchor.
		scan_relocate_current()
		gStage = ANPC_SCAN_SELECT
		console_print(id, "[ANPC] Mapper resumed.")
	}
	else if (equal(action, "save") && gActive && gStage != ANPC_SCAN_SAVE) scan_begin_save(false)
	else if (equal(action, "seed") && gActive && gStage != ANPC_SCAN_SAVE && (read_argc() == 5 || (id && is_user_alive(id))))
	{
		new Float:feet[3]
		if (read_argc() == 5)
		{
			new coordinate[32]
			for (new axis = 0; axis < 3; axis++)
			{
				read_argv(axis+2,coordinate,charsmax(coordinate))
				if (!anpc_number(coordinate)) { console_print(id,"[ANPC] Seed coordinates must be finite decimal numbers."); return PLUGIN_HANDLED; }
				feet[axis] = str_to_float(coordinate)
			}
		}
		else anpc_entity_feet(id, feet)
		console_print(id, "[ANPC] Exploration seed added: %d", scan_add_seed(feet, 0))
	}
	else if (equal(action, "watch") && id && is_user_connected(id))
	{
		gWatch[id] = bool:str_to_num(option) && scan_bot_valid()
		engfunc(EngFunc_SetView, id, gWatch[id] ? gBot : id)
	}
	else scan_status(id)
	return PLUGIN_HANDLED
}

stock bool:scan_start(const bool:reset)
{
	if (gActive || gFinishing || anpc_get_count() || !gTrace || gBspSize <= 0 || !gBspHash[0] || get_maxplayers() < 2) return false
	if (get_playersnum() >= MaxClients-1) return false
	if (!anpc_nav_begin_edit()) return false
	gActive = true
	gCompleted = gSaved = gStopAfterSave = false
	gResetGraph = reset
	gCapacityHalt = gSaveRequested = gSeedSettling = false
	gAbortRequested = false
	gLoadPhase = gLoadNode = gLoadSeed = 0
	set_pcvar_num(gActiveCvar, 1)
	for (new i = 0; i < sizeof gHooks; i++) EnableHookChain(gHooks[i])
	arrayset(gMask, 0, sizeof gMask)
	arrayset(gVisits, 0, sizeof gVisits)
	arrayset(gUnreachable, 0, sizeof gUnreachable)
	arrayset(gExploreParent, -1, sizeof gExploreParent)
	arrayset(gParentClosed, false, sizeof gParentClosed)
	arrayset(gSeedRejected, false, sizeof gSeedRejected)
	gKnownCount = gLinks = gWalks = gJumps = gDrops = gClimbs = gFailures = 0
	gHazards = gWarps = gUnsupported = gCapacitySkips = gSeedEpisodes = 0
	gSeedCount = gSeedCursor = gSurveyCursor = 0
	gCurrent = gSource = gGoalNode = gRouteGoal = gHeading = gSeedAnchor = -1
	gSenseNode = -1
	gSweeps = gKnownSkips = gReturnTrials = gLongTrials = 0
	gExploreDistance = gTravelDistance = 0.0
	gGraphEpoch = 1
	gSelectCursor = -1
	gSpacing = gConfig[SCAN_CFG_SPACING]
	gSpeed = gConfig[SCAN_CFG_SPEED]
	gGravity = gConfig[SCAN_CFG_GRAVITY]
	gDropLimit = gConfig[SCAN_CFG_DROP]
	gSurveyEnabled = gConfig[SCAN_CFG_SURVEY]
	gServerGravity = floatmax(1.0, get_cvar_float("sv_gravity"))
	gJumpSpeed = gPhysicsCvar[6] ? floatsqroot(1600.0*floatmax(1.0,get_pcvar_float(gPhysicsCvar[6]))) : 268.32816
	scan_physics_digest()
	gRoute = anpc_nav_open()
	gStarted = get_gametime()
	gCheckpointTime = gStarted+gCheckpointInterval
	gNextDrive = gLastDrive = gStarted
	gNextBeam = 0.0
	gMemoryLoaded = false
	scan_init_survey()
	scan_collect_seeds()
	if (!gRoute) { scan_finish(false, "route allocation failed"); return false; }
	if (!scan_create_bot()) { scan_finish(false, "scout initialization failed"); return false; }
	if (reset && !anpc_nav_reset()) { scan_finish(false, "navigation reset failed"); return false; }
	gStage = ANPC_SCAN_SEED
	gFrame = register_forward(FM_StartFrame, "mapper_frame")
	gTouch = register_forward(FM_Touch, "scan_touch")
	new result
	ExecuteForward(gStartForward, result, gBot)
	log_amx("Mapping %s with real player movement. Maintenance active; bot=%d userid=%d. Existing graph %d nodes.", gMap, gBot, gBotUserid, anpc_nav_count())
	return true
}

stock bool:scan_stop(const bool:save)
{
	if (!gActive) return false
	gCompleted = false
	if (!save)
	{
		if (gDriving) gAbortRequested = true
		else scan_finish(false, "requested stop without saving")
		return true
	}
	if (gStage == ANPC_SCAN_SAVE) gStopAfterSave = true
	else scan_begin_save(true)
	return true
}

stock scan_finish(const bool:saved, const reason[])
{
	if (!gActive || gFinishing) return
	gFinishing = true
	new AnpcScanStatus:stage = gStage
	if (gFrame) { unregister_forward(FM_StartFrame, gFrame); gFrame = 0; }
	if (gTouch) { unregister_forward(FM_Touch, gTouch); gTouch = 0; }
	if (gSaveFile) { fclose(gSaveFile); gSaveFile = 0; }
	if (gLoadFile) { fclose(gLoadFile); gLoadFile = 0; }
	for (new id = 1; id <= MaxClients; id++)
	{
		if (gWatch[id] && is_user_connected(id)) engfunc(EngFunc_SetView, id, id)
		gWatch[id] = false
	}
	scan_remove_bot()
	if (gRoute) { anpc_nav_close(gRoute); gRoute = 0; }
	anpc_nav_end_edit()
	gActive = false
	set_pcvar_num(gActiveCvar, 0)
	for (new i = 0; i < sizeof gHooks; i++) DisableHookChain(gHooks[i])
	gStage = gCompleted ? ANPC_SCAN_COMPLETE : ANPC_SCAN_OFF
	new result
	ExecuteForward(gFinishForward, result, gCompleted, saved, gKnownCount, gLinks)
	log_amx("Mapper ended: reason=%s; stage=%d completed=%d saved=%d nodes=%d links=%d jumps=%d failures=%d episodes=%d", reason, stage, gCompleted, saved, gKnownCount, gLinks, gJumps, gFailures, gSeedEpisodes)
	if (gRestart && !gFinishingMap) set_cvar_num("sv_restart", 1)
	gFinishing = false
}

public mapper_frame()
{
	if (!gActive) return FMRES_IGNORED
	if (!scan_check_bot()) return FMRES_IGNORED
	gTraces = 0
	gFrameStart = Float:engfunc(EngFunc_Time)
	new Float:now = get_gametime()
	if (now >= gNextDrive)
	{
		new msec = clamp(floatround((now-gLastDrive)*1000.0), 1, 50)
		gLastDrive = now
		gNextDrive = now+0.02
		scan_drive(now, msec)
		if (!gActive) return FMRES_IGNORED
	}
	scan_show_look(now)
	if (gStage == ANPC_SCAN_PAUSED) return FMRES_IGNORED
	if (gStage == ANPC_SCAN_SAVE) { scan_save_step(); return FMRES_IGNORED; }
	for (new operation = 0; operation < SCAN_FRAME_OPERATIONS && scan_work_available(); operation++)
	{
		switch (gStage)
		{
			case ANPC_SCAN_SEED: scan_seed_step()
			case ANPC_SCAN_SELECT: scan_select_step()
			case ANPC_SCAN_ROUTE: { scan_route_step(); break; }
			case ANPC_SCAN_PROBE: scan_probe_step()
			default: break
		}
		if (!gActive || gStage == ANPC_SCAN_MOVE || gStage == ANPC_SCAN_SAVE) break
		if (gStage == ANPC_SCAN_SEED && gSeedSettling) break
	}
	// Discover disconnected regions while the scout moves, using only spare budget.
	if (gActive && (gStage == ANPC_SCAN_SELECT || gStage == ANPC_SCAN_MOVE || gStage == ANPC_SCAN_ROUTE))
		for (new cell = 0; cell < 8 && !gSurveyDone && scan_work_available(); cell++) scan_survey_step()
	if (gActive && (gSaveRequested || now >= gCheckpointTime) && gStage != ANPC_SCAN_MOVE && gStage != ANPC_SCAN_SAVE && gLoadPhase == 2) scan_begin_save(gStopAfterSave)
	return FMRES_IGNORED
}

stock bool:scan_work_available()
{
	return gTraces <= gTraceLimit-4 && (Float:engfunc(EngFunc_Time)-gFrameStart)*1000.0 < gBudgetMs
}

stock scan_show_look(const Float:now)
{
	if (!gBeamEnabled || !gBeamSprite || !gBeamTrace || now < gNextBeam || !scan_work_available()) return
	gNextBeam = now+0.1
	new Float:start[3], Float:end[3], Float:view[3], Float:angles[3], Float:direction[3]
	get_entvar(gBot, var_origin, start)
	get_entvar(gBot, var_view_ofs, view)
	get_entvar(gBot, var_v_angle, angles)
	angle_vector(angles, ANGLEVECTOR_FORWARD, direction)
	for (new axis = 0; axis < 3; axis++)
	{
		start[axis] += view[axis]
		end[axis] = start[axis]+direction[axis]*1024.0
	}
	// This visual has its own trace handle and does not change planner readings.
	gTraces++
	engfunc(EngFunc_TraceLine, start, end, 0, gBot, gBeamTrace)
	get_tr2(gBeamTrace, TR_vecEndPos, end)
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, start, 0)
	write_byte(TE_BEAMPOINTS)
	for (new axis = 0; axis < 3; axis++) engfunc(EngFunc_WriteCoord, start[axis])
	for (new axis = 0; axis < 3; axis++) engfunc(EngFunc_WriteCoord, end[axis])
	write_short(gBeamSprite)
	write_byte(0); write_byte(0); write_byte(2); write_byte(8); write_byte(0)
	write_byte(40); write_byte(255); write_byte(80); write_byte(220); write_byte(0)
	message_end()
}

stock scan_status(const id)
{
	new pending
	for (new node = 0; node < gKnownCount; node++) if (scan_frontier_weight(node)) pending++
	console_print(id, "[ANPC] Mapper active=%d stage=%d bot=%d nodes=%d/%d links=%d pending=%d", gActive, gStage, gBot, gKnownCount, ANPC_MAX_NODES, gLinks, pending)
	console_print(id, "[ANPC] Verified walk=%d jump=%d drop=%d ladder=%d | failures=%d hazards=%d warps=%d unsupported=%d link-limit=%d", gWalks,gJumps,gDrops,gClimbs,gFailures,gHazards,gWarps,gUnsupported,gCapacitySkips)
	console_print(id, "[ANPC] Seeds %d/%d episodes=%d | survey %d/%d | elapsed %.1f min | last checkpoint saved=%d", gSeedCursor,gSeedCount,gSeedEpisodes,gSurveyCursor,gSurveyTotal,(get_gametime()-gStarted)/60.0,gSaved)
	console_print(id, "[ANPC] Resumed memory=%d | trace/frame limit=%d | cooperative budget=%.2f ms",gMemoryLoaded,gTraceLimit,gBudgetMs)
	console_print(id, "[ANPC] Sweeps=%d known-direction skips=%d long walks=%d deferred returns=%d | distance: explore=%.0f travel/return=%.0f",gSweeps,gKnownSkips,gLongTrials,gReturnTrials,gExploreDistance,gTravelDistance)
	if (scan_bot_valid())
	{
		new Float:feet[3]
		anpc_entity_feet(gBot, feet)
		console_print(id, "[ANPC] Scout feet %.1f %.1f %.1f | anchor=%d source=%d goal=%d motion=%d", feet[0],feet[1],feet[2],gCurrent,gSource,gGoalNode,gMotion)
	}
}
