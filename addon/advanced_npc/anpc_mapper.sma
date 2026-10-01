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
#include "advanced_npc/ground"

#define SCAN_MAX_BOTS 8
#define SCAN_DIRECTIONS 10
#define SCAN_DONE ((1<<SCAN_DIRECTIONS)-1)
#define SCAN_TASK_AUTO 8160
#define SCAN_FRAME_OPERATIONS 96
#define SCAN_SENSE_REACH 3.0
#define SCAN_SECTOR_ALIGNMENT 0.93
#define SCAN_ANCHOR_REUSE 0.75
#define SCAN_GROUND_SAMPLES 16
#define SCAN_BLOCK_LEVELS 4
#define SCAN_BLOCK_BUCKETS 4096
#define SCAN_PLAN_BLOCKED 64

enum _:ScanSeed { Float:SEED_FEET[3], SEED_FLAGS, bool:SEED_USED, SEED_NEXT }
enum _:ScanLadder { LADDER_ENTITY, Float:LADDER_MINS[3], Float:LADDER_MAXS[3] }
enum _:ScanVolume { VOLUME_ENTITY, VOLUME_TYPE, Float:VOLUME_MINS[3], Float:VOLUME_MAXS[3] }
enum ScanBlockStatus { SCAN_BLOCK_PENDING, SCAN_BLOCK_OPEN, SCAN_BLOCK_DETAIL }
enum _:ScanBlock { BL_X, BL_Y, BL_LEVEL, Float:BL_FEET[3], Float:BL_NORMAL[3], BL_FLAGS, BL_SOURCE_FLAGS, BL_NODE, BL_SAMPLE, BL_PHASE, BL_CHILD, BL_NEXT, BL_GEOMETRY, bool:BL_SENSITIVE, ScanBlockStatus:BL_STATUS }
enum _:ScanBlockReject { BLOCK_FLOOR, BLOCK_PLANE, BLOCK_HULL, BLOCK_VOLUME, BLOCK_CAPACITY, BLOCK_REJECT_COUNT }
enum _:ScanFloorReject { FLOOR_SUPPORT, FLOOR_SOLID, FLOOR_ENTITY, FLOOR_HEIGHT, FLOOR_REJECT_COUNT }
enum ScanPurpose { SCAN_FRONTIER, SCAN_RETURN, SCAN_TRAVEL }
enum ScanMotion { SCAN_WALK, SCAN_JUMP, SCAN_DROP, SCAN_LADDER }
enum ScanProbe { PROBE_GROUND, PROBE_LEDGE, PROBE_LANDING, PROBE_FLOOR, PROBE_HULL, PROBE_OBSTACLE, PROBE_TAKEOFF, PROBE_ARC, PROBE_RUNUP, PROBE_INTERIOR, PROBE_KNOWN_PATH }
enum _:ScanProfile { Float:SCAN_CFG_SPACING, Float:SCAN_CFG_SPEED, Float:SCAN_CFG_GRAVITY, Float:SCAN_CFG_DROP, SCAN_CFG_SURVEY }

new gBot[SCAN_MAX_BOTS], gBotUserid[SCAN_MAX_BOTS], gFrame, gTouch, gTrace, gActiveCvar, gStartForward, gFinishForward, gEdgeForward
new gBeamSprite, gBeamTrace, gBeamEnabled, Float:gNextBeam
new gWatchCamera[SCAN_MAX_BOTS], gWatchPack, gWatch[33]
new bool:gBlockView[33], gBlockViewers, gBlockViewerCursor, Float:gNextBlockDraw
new HookChain:gHooks[7], bool:gActive, bool:gFinishing, bool:gFinishingMap, bool:gDriving
// Only the scheduler and team lifecycle select this context. Entity hooks use
// their own scout index and never replace the context of an in-flight command.
new gWorker, gBotCount, gBotLimit, gWorkerCursor, gDriveCursor, gBeamCursor
new AnpcScanStatus:gSessionStage = ANPC_SCAN_OFF, bool:gPauseRequested
new gClaim[ANPC_MAX_NODES], gClaimNode[SCAN_MAX_BOTS], gClaimEpoch, gPlanClaimEpoch[SCAN_MAX_BOTS]
new gSeedIndex[SCAN_MAX_BOTS], bool:gIdle[SCAN_MAX_BOTS], Float:gRetryAt[SCAN_MAX_BOTS]
new gAvoidances, gAvoidSide[SCAN_MAX_BOTS], Float:gAvoidUntil[SCAN_MAX_BOTS]
new AnpcScanStatus:gStage[SCAN_MAX_BOTS], AnpcScanStatus:gResumeStage[SCAN_MAX_BOTS]
new ScanPurpose:gPurpose[SCAN_MAX_BOTS], ScanMotion:gMotion[SCAN_MAX_BOTS], ScanProbe:gProbe[SCAN_MAX_BOTS]
new gMask[ANPC_MAX_NODES], gVisits[ANPC_MAX_NODES], gUnreachable[SCAN_MAX_BOTS][ANPC_MAX_NODES]
new gExploreParent[ANPC_MAX_NODES], bool:gParentClosed[ANPC_MAX_NODES], bool:gSeedRejected[ANPC_MAX_NODES]
new Float:gKnown[ANPC_MAX_NODES][3], gKnownFlags[ANPC_MAX_NODES], gKnownCount
new Array:gSeeds, gSeedCount, gSeedCursor, gSeedEpisodes
new gSeedHead[SCAN_BLOCK_BUCKETS]
new Array:gLadder, gLadderCount
new Array:gVolumes, gVolumeCount
new Array:gBlock
new gBlockHead[SCAN_BLOCK_BUCKETS], gBlockCount, gBlockCursor, gBlockEpoch, gBlockGeometry
new gNodeBlock[ANPC_MAX_NODES], gBlockMask[ANPC_MAX_NODES], gBlockMaskEpoch[ANPC_MAX_NODES], gInteriorMask[ANPC_MAX_NODES], bool:gNodeLadder[ANPC_MAX_NODES]
new gBlockOpen, gBlockDetail, gBlockSkips, gBlockLimit, gFrontierSkips, gCostSelections
new gBlockReject[BLOCK_REJECT_COUNT], gBlockCrouchRetry
new gBlockFloorReject[FLOOR_REJECT_COUNT]
new gRestoreAreaCount, gRestoreAreaCursor, gRestoreAreaPhase
new gCompactMap[ANPC_MAX_NODES], gCompactOriginal, gCompactCursor, gPrunedNodes, gPortals, gPortalLimit
new gCompactKeep[ANPC_MAX_NODES], gCompactBlocks, gCompactBlockCount, gCompactRemoved, gCompactPortals
new gCurrent[SCAN_MAX_BOTS], gSource[SCAN_MAX_BOTS], gGoalNode[SCAN_MAX_BOTS], gDirection[SCAN_MAX_BOTS], gRangeIndex[SCAN_MAX_BOTS], gHeading[SCAN_MAX_BOTS], gSeedAnchor[SCAN_MAX_BOTS]
new gSenseNode[SCAN_MAX_BOTS], gSenseBlockEpoch[SCAN_MAX_BOTS], gSenseCursor[SCAN_MAX_BOTS], gSenseTarget[SCAN_MAX_BOTS][8], gSenseGain[SCAN_MAX_BOTS][8], bool:gSenseWall[SCAN_MAX_BOTS][8]
new Float:gSenseDistance[SCAN_MAX_BOTS][8], Float:gSenseScore[SCAN_MAX_BOTS][8], Float:gFrontierRange[SCAN_MAX_BOTS]
new Float:gSenseVector[SCAN_MAX_BOTS][8][2], Float:gSenseSlope[SCAN_MAX_BOTS][8], Float:gFrontierVector[SCAN_MAX_BOTS][2]
new gSweeps, gKnownSkips, gReturnTrials, gLongTrials, Float:gExploreDistance, Float:gTravelDistance
new gAreaNodesSkipped, gAreaReturns, gLandingTrials, gLandingSample[SCAN_MAX_BOTS], bool:gLandingActive[SCAN_MAX_BOTS]
new Float:gProbeGoal[SCAN_MAX_BOTS][3], Float:gLandingNear[SCAN_MAX_BOTS], Float:gLandingLength[SCAN_MAX_BOTS]
new Float:gJumpOrigin[SCAN_MAX_BOTS][3], gTakeoffRetry[SCAN_MAX_BOTS]
new gRoute[SCAN_MAX_BOTS], gRouteGoal[SCAN_MAX_BOTS], gRouteCursor[SCAN_MAX_BOTS], gSelectCursor[SCAN_MAX_BOTS]
new gPlanStart[SCAN_MAX_BOTS], gPlanEpoch[SCAN_MAX_BOTS], gPlanGraphEpoch[SCAN_MAX_BOTS], gPlanCurrent[SCAN_MAX_BOTS], gPlanHeapSize[SCAN_MAX_BOTS]
new gPlanNeighbor[SCAN_MAX_BOTS], gPlanCoverageEpoch[SCAN_MAX_BOTS]
new gPlanHeap[SCAN_MAX_BOTS][ANPC_MAX_NODES], gPlanPosition[SCAN_MAX_BOTS][ANPC_MAX_NODES], gPlanStamp[SCAN_MAX_BOTS][ANPC_MAX_NODES], gPlanClosed[SCAN_MAX_BOTS][ANPC_MAX_NODES]
new Float:gPlanDistance[SCAN_MAX_BOTS][ANPC_MAX_NODES], gPlanBest[SCAN_MAX_BOTS], gPlanBestWork[SCAN_MAX_BOTS], gPlanReturn[SCAN_MAX_BOTS], Float:gPlanScore[SCAN_MAX_BOTS], Float:gPlanReturnCost[SCAN_MAX_BOTS]
new gPlanBlockedFrom[SCAN_PLAN_BLOCKED], gPlanBlockedTo[SCAN_PLAN_BLOCKED], Float:gPlanBlockedUntil[SCAN_PLAN_BLOCKED], gPlanBlockedCursor
new gGraphEpoch, gLinks, gWalks, gJumps, gDrops, gClimbs, gFailures, gHazards, gWarps, gUnsupported
new gTraces, gTraceLimit, gAuto, gSurveyEnabled, gRestart, gSaveRecords
new Float:gSpacing, Float:gSpeed, Float:gGravity, Float:gDropLimit, Float:gBudgetMs, Float:gCheckpointInterval
new Float:gNextDrive[SCAN_MAX_BOTS], Float:gLastDrive[SCAN_MAX_BOTS], Float:gStarted, Float:gDeadline[SCAN_MAX_BOTS], Float:gProgressTime[SCAN_MAX_BOTS], Float:gBestDistance[SCAN_MAX_BOTS]
new bool:gAligning[SCAN_MAX_BOTS], gAlignments, gRouteShortcuts, gAnchorReuses
new Float:gCheckpointTime, Float:gFrameStart, Float:gNextUse[SCAN_MAX_BOTS], Float:gStableSince[SCAN_MAX_BOTS]
new Float:gSourceFeet[SCAN_MAX_BOTS][3], Float:gGoalFeet[SCAN_MAX_BOTS][3], Float:gRunupFeet[SCAN_MAX_BOTS][3], Float:gArcPrevious[SCAN_MAX_BOTS][3]
new Float:gFlightTime[SCAN_MAX_BOTS], Float:gJumpSpeed = 268.32816, Float:gLaunchVelocity[SCAN_MAX_BOTS][3], Float:gExpectedVelocity[SCAN_MAX_BOTS][3]
new gInteriorTarget[SCAN_MAX_BOTS], gInteriorSample[SCAN_MAX_BOTS], gInteriorPathCursor[SCAN_MAX_BOTS], Float:gInteriorDistance[SCAN_MAX_BOTS], Float:gInteriorCost[SCAN_MAX_BOTS], Float:gInteriorLimit[SCAN_MAX_BOTS]
new Float:gLaunchFeet[SCAN_MAX_BOTS][3], Float:gLastFeet[SCAN_MAX_BOTS][3], Float:gPreviousGround[SCAN_MAX_BOTS][3], Float:gWalkPrevious[SCAN_MAX_BOTS][3], Float:gGroundNormal[SCAN_MAX_BOTS][3]
new gLaunchNode[SCAN_MAX_BOTS], gArcSample[SCAN_MAX_BOTS], gArcSamples[SCAN_MAX_BOTS], gWalkSample[SCAN_MAX_BOTS], gWalkSamples[SCAN_MAX_BOTS], gGoalFlags[SCAN_MAX_BOTS], gJumpPhase[SCAN_MAX_BOTS]
new gObstacle[SCAN_MAX_BOTS], gObstacleAttempts[SCAN_MAX_BOTS], bool:gDuck[SCAN_MAX_BOTS], bool:gRunup[SCAN_MAX_BOTS], bool:gAirborne[SCAN_MAX_BOTS], bool:gJumped[SCAN_MAX_BOTS]
new bool:gHazard[SCAN_MAX_BOTS], bool:gWarp[SCAN_MAX_BOTS], bool:gTouchedLadder[SCAN_MAX_BOTS], bool:gLowFloorRetry[SCAN_MAX_BOTS], bool:gGroundReady[SCAN_MAX_BOTS], bool:gGroundDirectional[SCAN_MAX_BOTS], bool:gGroundPlaneReady[SCAN_MAX_BOTS]
new Float:gBoundsMin[3], Float:gBoundsMax[3], gSurveyCursor, gSurveyTotal, gSurveySize[3]
new Float:gSurveyStep, bool:gSurveyValid, bool:gSurveyDone
new gMap[64], gNavPath[256], gMemoryPath[256], gReportPath[256], gBspHash[33], gBspSize
new gSaveFile, gSavePhase, gSaveNode, gSaveLink, gSaveCount, bool:gStopAfterSave, bool:gCompleted, bool:gSaved
new gSaveTemporary[288], gNavDigest[33], bool:gMemoryLoaded
new gLoadFile, gLoadPhase, gLoadNode, gLoadSeed, gLoadSeedCount, bool:gResetGraph, bool:gSaveRequested
new gParentNode, gParentLink, bool:gParentsReady
new bool:gCapacityHalt, bool:gSeedSettling[SCAN_MAX_BOTS], bool:gLaunchPending[SCAN_MAX_BOTS], bool:gSegmentDuck[SCAN_MAX_BOTS], bool:gLaunchDuck[SCAN_MAX_BOTS]
new bool:gAbortRequested, bool:gSavePaused
new Float:gServerGravity, Float:gTrialSpeed[SCAN_MAX_BOTS], Float:gSeedDeadline[SCAN_MAX_BOTS], Float:gStepSize
new gConfig[ScanProfile], gPhysicsCvar[7], gPhysicsDigest[33], Float:gJumpDuckLift[SCAN_MAX_BOTS]
new const SCAN_BEAM_MODEL[] = "sprites/laserbeam.spr"
new const Float:SCAN_ZERO[3] = {0.0, 0.0, 0.0}
new const Float:SCAN_DIR[8][2] =
{
	{1.0,0.0}, {0.70710678,0.70710678}, {0.0,1.0}, {-0.70710678,0.70710678},
	{-1.0,0.0}, {-0.70710678,-0.70710678}, {0.0,-1.0}, {0.70710678,-0.70710678}
}
new const Float:SCAN_RANGE[4] = {1.0, 0.5, 1.75, 2.5}
new const Float:SCAN_LANDING_DEPTH[] = {32.0, 48.0, 72.0, 96.0, 128.0}
new const Float:SCAN_TAKEOFF_BACK[] = {16.0, 32.0, 48.0, 72.0, 96.0, 128.0}
new const Float:SCAN_BLOCK_SIZE[SCAN_BLOCK_LEVELS] = {256.0, 128.0, 64.0, 32.0}
new const SCAN_VOLUME_CLASSES[][] = {"trigger_hurt", "trigger_push", "trigger_teleport", "trigger_multiple", "trigger_once", "trigger_changelevel", "func_train", "func_tracktrain", "func_plat", "func_rotating", "func_door", "func_door_rotating", "func_breakable", "func_button", "func_rot_button"}

#include "advanced_npc/mapper_world"
#include "advanced_npc/mapper_coverage"
#include "advanced_npc/mapper_exploration"
#include "advanced_npc/mapper_frontiers"
#include "advanced_npc/mapper_motion"
#include "advanced_npc/mapper_storage"
#include "advanced_npc/mapper_team"

public plugin_precache()
{
	gBeamSprite = precache_model(SCAN_BEAM_MODEL)
}

public plugin_natives()
{
	register_library("advanced_npc_mapper")
	register_native("anpc_scan_start", "native_scan_start")
	register_native("anpc_scan_stop", "native_scan_stop")
	register_native("anpc_scan_running", "native_scan_running")
	register_native("anpc_scan_bot", "native_scan_bot")
	register_native("anpc_scan_bot_count", "native_scan_bot_count")
	register_native("anpc_scan_is_bot", "native_scan_is_bot")
	register_native("anpc_scan_status", "native_scan_status")
}

public plugin_init()
{
	register_plugin("Advanced NPC: Autonomous Mapper", ANPC_VERSION, "ZPN")
	gActiveCvar = create_cvar("anpc_scan_active", "0", FCVAR_SERVER | FCVAR_SPONLY, "Maintenance state controlled by automatic mapper")
	if (!is_rehlds() || !is_regamedll()) set_fail_state("Automatic mapper requires ReHLDS and ReGameDLL CS")
	register_concmd("anpc_scan", "command_scan", ADMIN_RCON, "start [new] | stop | pause | resume | save | status | seed [x y z] | watch 0|1 [scout] | blocks 0|1")
	bind_pcvar_num(create_cvar("anpc_scan_auto", "0", FCVAR_NONE, "Automatically map when no navigation exists", true, 0.0, true, 1.0), gAuto)
	bind_pcvar_num(create_cvar("anpc_scan_bots", "8", FCVAR_NONE, "Independent scouts; captured at start, keeps one free player slot", true, 1.0, true, float(SCAN_MAX_BOTS)), gBotLimit)
	bind_pcvar_num(create_cvar("anpc_scan_beam", "1", FCVAR_NONE, "Show the scout viewing direction while mapping", true, 0.0, true, 1.0), gBeamEnabled)
	bind_pcvar_num(create_cvar("anpc_scan_traces", "24", FCVAR_NONE, "Shared cooperative hull/line trace budget per frame (player physics excluded)", true, 16.0, true, 64.0), gTraceLimit)
	bind_pcvar_num(create_cvar("anpc_scan_survey", "1", FCVAR_NONE, "Survey BSP bounds for additional exploration seeds", true, 0.0, true, 1.0), gConfig[SCAN_CFG_SURVEY])
	bind_pcvar_num(create_cvar("anpc_scan_restart", "0", FCVAR_NONE, "Optional round restart when mapping ends", true, 0.0, true, 1.0), gRestart)
	bind_pcvar_num(create_cvar("anpc_scan_save_records", "32", FCVAR_NONE, "Maximum records written per frame", true, 4.0, true, 128.0), gSaveRecords)
	bind_pcvar_float(create_cvar("anpc_scan_spacing", "128", FCVAR_NONE, "Exploration and ordinary node spacing; captured when scan starts", true, 48.0, true, 512.0), gConfig[SCAN_CFG_SPACING])
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
	gHooks[6] = RegisterHookChain(RH_SV_AllowPhysent, "scan_physent_pre")
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
	gSeeds = ArrayCreate(ScanSeed,64)
	gLadder = ArrayCreate(ScanLadder,16)
	gVolumes = ArrayCreate(ScanVolume,32)
	gBlock = ArrayCreate(ScanBlock,256)
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
	scan_cache_volumes()
	set_pcvar_num(gActiveCvar, 0)
}

public plugin_cfg() { set_task(2.0, "scan_auto_start", SCAN_TASK_AUTO); }
public scan_auto_start() { if (gAuto && !anpc_nav_count() && !anpc_nav_area_count()) scan_start(false); }

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
	ArrayDestroy(gSeeds)
	ArrayDestroy(gLadder)
	ArrayDestroy(gVolumes)
	ArrayDestroy(gBlock)
	DestroyForward(gStartForward)
	DestroyForward(gFinishForward)
	DestroyForward(gEdgeForward)
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	gWatch[id] = 0
	if (gBlockView[id]) { gBlockView[id] = false; gBlockViewers--; }
	scan_release_camera()
	for (new scout = 0; scout < gBotCount && !gFinishing; scout++)
	{
		if (id != gBot[scout]) continue
		gBot[scout] = gBotUserid[scout] = 0
		log_amx("Scout %d disconnected; mapping stopped. Last committed checkpoint is preserved.", scout+1)
		if (gDriving) gAbortRequested = true
		else scan_finish(false, "scout disconnected")
		break
	}
}

public bool:native_scan_start() { return scan_start(bool:get_param(1)); }
public bool:native_scan_stop() { return scan_stop(bool:get_param(1)); }
public bool:native_scan_running() { return gActive; }
public native_scan_bot()
{
	new scout = get_param(1)
	return scout >= 0 && scout < gBotCount && scan_bot_valid(scout) ? gBot[scout] : 0
}
public native_scan_bot_count() { return gActive ? gBotCount : 0; }
public bool:native_scan_is_bot() { return gActive && scan_scout_index(get_param(1)) >= 0; }
public AnpcScanStatus:native_scan_status() { return gSessionStage; }

public command_scan(const id, const level, const cid)
{
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	new action[16], option[16]
	read_argv(1, action, charsmax(action))
	read_argv(2, option, charsmax(option))
	if (equal(action, "start")) console_print(id, "[ANPC] Mapper started: %d", scan_start(bool:equal(option, "new")))
	else if (equal(action, "stop")) console_print(id, "[ANPC] Saving and stopping: %d", scan_stop(true))
	else if (equal(action, "pause") && gActive && gSessionStage != ANPC_SCAN_SAVE && gSessionStage != ANPC_SCAN_PAUSED)
	{
		scan_pause_team()
		console_print(id, "[ANPC] Mapper paused; graph ownership and %d scouts are retained.", gBotCount)
	}
	else if (equal(action, "resume") && gActive && gSessionStage == ANPC_SCAN_PAUSED)
	{
		scan_resume_team()
		console_print(id, "[ANPC] Mapper resumed.")
	}
	else if (equal(action, "save") && gActive && gSessionStage != ANPC_SCAN_SAVE) scan_begin_save(false)
	else if (equal(action, "seed") && gActive && gSessionStage != ANPC_SCAN_SAVE && (read_argc() == 5 || (id && is_user_alive(id))))
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
		new selected[16]
		read_argv(3, selected, charsmax(selected))
		new scout = selected[0] ? str_to_num(selected)-1 : 0
		if (!scan_set_watch(id, bool:str_to_num(option), scout)) console_print(id, "[ANPC] Scout camera unavailable; choose 1..%d.", gBotCount)
	}
	else if (equal(action, "blocks") && id && is_user_connected(id))
	{
		new bool:enabled = str_to_num(option) != 0
		if (enabled != gBlockView[id]) gBlockViewers += enabled ? 1 : -1
		gBlockView[id] = enabled
		gNextBlockDraw = 0.0
		console_print(id, "[ANPC] Analyzed floor blocks: %d (blue squares).", enabled)
	}
	else scan_status(id)
	return PLUGIN_HANDLED
}

stock bool:scan_start(const bool:reset)
{
	if (gActive || gFinishing || anpc_get_count() || !gTrace || gBspSize <= 0 || !gBspHash[0] || get_maxplayers() < 2) return false
	new available = MaxClients-1-get_playersnum()
	if (available <= 0 || !anpc_nav_begin_edit()) return false
	gBotCount = min(clamp(gBotLimit,1,SCAN_MAX_BOTS),available)
	gActive = true
	gSessionStage = ANPC_SCAN_SEED
	gCompleted = gSaved = gStopAfterSave = false
	gPrunedNodes = gPortals = gPortalLimit = 0
	gResetGraph = reset
	gCapacityHalt = gSaveRequested = gAbortRequested = gPauseRequested = gSavePaused = false
	gLoadPhase = gLoadNode = gLoadSeed = 0
	gParentNode = gParentLink = 0
	gParentsReady = false
	gStarted = get_gametime()
	gCheckpointTime = gStarted+gCheckpointInterval
	gWorkerCursor = gDriveCursor = gBeamCursor = gAvoidances = 0
	gClaimEpoch = 1
	arrayset(gClaim,0,sizeof gClaim)
	for (gWorker = 0; gWorker < gBotCount; gWorker++) scan_reset_scout()
	gWorker = 0
	set_pcvar_num(gActiveCvar,1)
	for (new i = 0; i < sizeof gHooks; i++) EnableHookChain(gHooks[i])
	arrayset(gMask,0,sizeof gMask)
	arrayset(gVisits,0,sizeof gVisits)
	arrayset(gExploreParent,-1,sizeof gExploreParent)
	arrayset(gParentClosed,false,sizeof gParentClosed)
	arrayset(gSeedRejected,false,sizeof gSeedRejected)
	scan_blocks_reset()
	arrayset(gPlanBlockedUntil,0,sizeof gPlanBlockedUntil)
	gPlanBlockedCursor = 0
	gKnownCount = gLinks = gWalks = gJumps = gDrops = gClimbs = gFailures = 0
	gHazards = gWarps = gUnsupported = gSeedEpisodes = 0
	ArrayClear(gSeeds)
	gSeedCount = gSeedCursor = gSurveyCursor = 0
	gSweeps = gKnownSkips = gReturnTrials = gLongTrials = 0
	gFrontierSkips = gCostSelections = 0
	gAreaNodesSkipped = gAreaReturns = gLandingTrials = 0
	gAlignments = gRouteShortcuts = gAnchorReuses = 0
	gExploreDistance = gTravelDistance = 0.0
	gGraphEpoch = 1
	arrayset(gSeedHead,-1,sizeof gSeedHead)
	gSpacing = gConfig[SCAN_CFG_SPACING]
	gSpeed = gConfig[SCAN_CFG_SPEED]
	gGravity = gConfig[SCAN_CFG_GRAVITY]
	gDropLimit = gConfig[SCAN_CFG_DROP]
	gSurveyEnabled = gConfig[SCAN_CFG_SURVEY]
	gServerGravity = floatmax(1.0,get_cvar_float("sv_gravity"))
	gStepSize = floatmax(0.0,get_pcvar_float(gPhysicsCvar[1]))
	gJumpSpeed = gPhysicsCvar[6] ? floatsqroot(1600.0*floatmax(1.0,get_pcvar_float(gPhysicsCvar[6]))) : 268.32816
	scan_physics_digest()
	gNextBeam = gNextBlockDraw = 0.0
	gMemoryLoaded = false
	scan_init_survey()
	scan_collect_seeds()
	if (reset && !anpc_nav_reset()) { scan_finish(false,"navigation reset failed"); return false; }
	for (gWorker = 0; gWorker < gBotCount; gWorker++)
	{
		gRoute[gWorker] = anpc_nav_open()
		if (!gRoute[gWorker]) { scan_finish(false,"route allocation failed"); return false; }
		if (!scan_create_bot()) { scan_finish(false,"scout initialization failed"); return false; }
		gLastDrive[gWorker] = gStarted
		gNextDrive[gWorker] = gStarted+0.02*float(gWorker)/float(gBotCount)
	}
	gWorker = 0
	// Restore shared geometry/journal once before distributing exploration.
	gRestoreAreaCount = anpc_nav_area_count()
	gRestoreAreaCursor = gRestoreAreaPhase = 0
	gFrame = register_forward(FM_StartFrame,"mapper_frame")
	gTouch = register_forward(FM_Touch,"scan_touch")
	new result
	ExecuteForward(gStartForward,result,gBotCount)
	if (!gActive) return false
	log_amx("Mapping %s with %d/%d independent scouts; one player slot reserved. Existing graph %d nodes.",gMap,gBotCount,gBotLimit,anpc_nav_count())
	return true
}

stock bool:scan_stop(const bool:save)
{
	if (!gActive) return false
	gCompleted = false
	if (!save)
	{
		if (gDriving) gAbortRequested = true
		else scan_finish(false,"requested stop without saving")
		return true
	}
	if (gSessionStage == ANPC_SCAN_SAVE) gStopAfterSave = true
	else scan_begin_save(true)
	return true
}

stock scan_finish(const bool:saved, const reason[])
{
	if (!gActive || gFinishing) return
	gFinishing = true
	new AnpcScanStatus:stage = gSessionStage, scouts = gBotCount
	if (gFrame) { unregister_forward(FM_StartFrame,gFrame); gFrame = 0; }
	if (gTouch) { unregister_forward(FM_Touch,gTouch); gTouch = 0; }
	if (gSaveFile) { fclose(gSaveFile); gSaveFile = 0; }
	if (gLoadFile) { fclose(gLoadFile); gLoadFile = 0; }
	if (!gFinishingMap && stage == ANPC_SCAN_SAVE && gSavePhase == -2)
	{
		if (!anpc_nav_reload()) anpc_nav_reset()
		gKnownCount = anpc_nav_count()
		gCompleted = false
	}
	for (new id = 1; id <= MaxClients; id++)
	{
		if (gWatch[id] && is_user_connected(id)) engset_view(id,id)
		gWatch[id] = 0
	}
	scan_release_camera()
	for (gWorker = 0; gWorker < gBotCount; gWorker++)
	{
		scan_release_claim()
		scan_remove_bot()
		if (gRoute[gWorker]) { anpc_nav_close(gRoute[gWorker]); gRoute[gWorker] = 0; }
		gStage[gWorker] = gCompleted ? ANPC_SCAN_COMPLETE : ANPC_SCAN_OFF
	}
	gWorker = gBotCount = 0
	gKnownCount = anpc_nav_count()
	anpc_nav_end_edit()
	gActive = false
	set_pcvar_num(gActiveCvar,0)
	for (new i = 0; i < sizeof gHooks; i++) DisableHookChain(gHooks[i])
	gSessionStage = gCompleted ? ANPC_SCAN_COMPLETE : ANPC_SCAN_OFF
	new result
	ExecuteForward(gFinishForward,result,gCompleted,saved,gKnownCount,gLinks)
	log_amx("Mapper ended: reason=%s; stage=%d scouts=%d completed=%d saved=%d nodes=%d links=%d jumps=%d failures=%d episodes=%d",reason,stage,scouts,gCompleted,saved,gKnownCount,gLinks,gJumps,gFailures,gSeedEpisodes)
	if (gRestart && !gFinishingMap) set_cvar_num("sv_restart",1)
	gFinishing = false
}

public mapper_frame()
{
	if (!gActive) return FMRES_IGNORED
	gTraces = 0
	gFrameStart = Float:engfunc(EngFunc_Time)
	new Float:now = get_gametime()
	// Service every physical client; rotate who receives the first command.
	for (new driven = 0; driven < gBotCount; driven++)
	{
		gWorker = (gDriveCursor+driven)%gBotCount
		if (!scan_check_bot()) return FMRES_IGNORED
		if (now < gNextDrive[gWorker]) continue
		new msec = clamp(floatround((now-gLastDrive[gWorker])*1000.0),1,50)
		gLastDrive[gWorker] = now
		gNextDrive[gWorker] = now+0.02
		scan_drive(now,msec)
		if (!gActive) return FMRES_IGNORED
	}
	gDriveCursor = (gDriveCursor+1)%gBotCount
	gWorker = 0
	scan_update_camera()
	scan_show_blocks(now)
	if (gSessionStage == ANPC_SCAN_PAUSED) return FMRES_IGNORED
	if (gSessionStage == ANPC_SCAN_SAVE) { scan_save_step(); return FMRES_IGNORED; }
	if (gRestoreAreaPhase < 2)
	{
		for (new operation = 0; operation < 8 && gActive && scan_work_available(); operation++)
			if (scan_restore_areas_step()) break
		if (!gActive || gRestoreAreaPhase < 2) return FMRES_IGNORED
	}
	if (gSessionStage == ANPC_SCAN_SEED)
	{
		for (new operation = 0; operation < SCAN_FRAME_OPERATIONS && gActive && scan_work_available() && gTraceLimit-gTraces >= 6; operation++)
			if (scan_prepare_step()) { gSessionStage = ANPC_SCAN_SELECT; break; }
		if (!gActive || gSessionStage == ANPC_SCAN_SEED) return FMRES_IGNORED
	}
	if (gSaveRequested) { scan_begin_save(gStopAfterSave); return FMRES_IGNORED; }
	// Geometry/planning share one frame budget, regardless of scout count.
	new bool:waiting[SCAN_MAX_BOTS], skipped
	for (new operation = 0; operation < SCAN_FRAME_OPERATIONS && gActive && scan_work_available(); operation++)
	{
		gWorker = gWorkerCursor
		gWorkerCursor = (gWorkerCursor+1)%gBotCount
		if (gIdle[gWorker] && now >= gRetryAt[gWorker]) { gIdle[gWorker] = false; gSelectCursor[gWorker] = 0; }
		if (waiting[gWorker] || gIdle[gWorker])
		{
			if (++skipped >= gBotCount) break
			continue
		}
		skipped = 0
		waiting[gWorker] = !scan_scout_step()
		if (gSessionStage == ANPC_SCAN_SAVE) break
	}
	gWorker = 0
	if (!gActive || gSessionStage == ANPC_SCAN_SAVE) return FMRES_IGNORED
	for (new block = 0; block < 8 && scan_work_available(); block++) if (!scan_block_background()) break
	for (new cell = 0; cell < 8 && !gSurveyDone && scan_work_available() && gTraceLimit-gTraces >= 6; cell++) scan_survey_step()
	scan_team_complete()
	if (gActive && gSessionStage != ANPC_SCAN_SAVE && (gSaveRequested || now >= gCheckpointTime)) scan_begin_save(gStopAfterSave)
	// A single rotating beam uses only spare shared budget.
	if (gActive && gSessionStage != ANPC_SCAN_SAVE)
	{
		gWorker = gBeamCursor
		new Float:previous_beam = gNextBeam
		scan_show_look(now)
		if (gNextBeam != previous_beam) gBeamCursor = (gBeamCursor+1)%gBotCount
		gWorker = 0
	}
	return FMRES_IGNORED
}

stock bool:scan_work_available()
{
	return gTraces <= gTraceLimit-4 && (Float:engfunc(EngFunc_Time)-gFrameStart)*1000.0 < gBudgetMs
}

stock bool:scan_set_watch(const id, const bool:enabled, const scout)
{
	if (!enabled)
	{
		if (gWatch[id]) engset_view(id,id)
		gWatch[id] = 0
		scan_release_camera()
		return true
	}
	if (scout < 0 || scout >= gBotCount || !scan_bot_valid(scout)) return false
	if (!gWatchCamera[scout])
	{
		gWatchCamera[scout] = rg_create_entity("info_target",false)
		if (!is_entity(gWatchCamera[scout])) { gWatchCamera[scout] = 0; return false; }
		set_entvar(gWatchCamera[scout],var_classname,"anpc_scan_camera")
		engfunc(EngFunc_SetModel,gWatchCamera[scout],SCAN_BEAM_MODEL)
		engfunc(EngFunc_SetSize,gWatchCamera[scout],SCAN_ZERO,SCAN_ZERO)
		set_entvar(gWatchCamera[scout],var_movetype,MOVETYPE_NONE)
		set_entvar(gWatchCamera[scout],var_solid,SOLID_NOT)
		set_entvar(gWatchCamera[scout],var_rendermode,kRenderTransTexture)
		set_entvar(gWatchCamera[scout],var_renderamt,0.0)
	}
	if (!is_entity(gWatchCamera[scout])) return false
	if (!gWatchPack) gWatchPack = register_forward(FM_AddToFullPack,"scan_watch_pack_post",true)
	gWatch[id] = scout+1
	scan_update_camera()
	engset_view(id,gWatchCamera[scout])
	scan_release_camera()
	return true
}

stock scan_update_camera()
{
	for (new scout = 0; scout < gBotCount; scout++)
	{
		if (!gWatchCamera[scout] || !is_entity(gWatchCamera[scout]) || !scan_bot_valid(scout)) continue
		new Float:origin[3], Float:view[3], Float:angles[3]
		get_entvar(gBot[scout],var_origin,origin)
		get_entvar(gBot[scout],var_view_ofs,view)
		get_entvar(gBot[scout],var_v_angle,angles)
		for (new axis = 0; axis < 3; axis++) origin[axis] += view[axis]
		engfunc(EngFunc_SetOrigin,gWatchCamera[scout],origin)
		set_entvar(gWatchCamera[scout],var_angles,angles)
	}
}

public scan_watch_pack_post(const handle, const index, const entity, const host, const host_flags, const player, const visibility_set)
{
	new scout = host > 0 && host <= MaxClients ? gWatch[host]-1 : -1
	if (player && scout >= 0 && scout < gBotCount && entity == gBot[scout] && get_orig_retval())
		set_es(handle,ES_Effects,get_es(handle,ES_Effects) | EF_NODRAW)
	return FMRES_IGNORED
}

stock scan_release_camera()
{
	new bool:watching
	for (new scout = 0; scout < SCAN_MAX_BOTS; scout++)
	{
		new bool:used
		for (new id = 1; id <= MaxClients; id++) if (gWatch[id] == scout+1) { used = watching = true; break; }
		if (used) continue
		if (gWatchCamera[scout] && is_entity(gWatchCamera[scout])) rg_remove_entity(gWatchCamera[scout])
		gWatchCamera[scout] = 0
	}
	if (!watching && gWatchPack) { unregister_forward(FM_AddToFullPack,gWatchPack,true); gWatchPack = 0; }
}

stock scan_show_look(const Float:now)
{
	if (!gBeamEnabled || !gBeamSprite || !gBeamTrace || now < gNextBeam || !scan_work_available()) return
	gNextBeam = now+0.1
	new Float:start[3], Float:end[3], Float:view[3], Float:angles[3], Float:direction[3]
	get_entvar(gBot[gWorker], var_origin, start)
	get_entvar(gBot[gWorker], var_view_ofs, view)
	get_entvar(gBot[gWorker], var_v_angle, angles)
	angle_vector(angles, ANGLEVECTOR_FORWARD, direction)
	for (new axis = 0; axis < 3; axis++)
	{
		start[axis] += view[axis]
		end[axis] = start[axis]+direction[axis]*1024.0
	}
	// This visual has its own trace handle and does not change planner readings.
	gTraces++
	engfunc(EngFunc_TraceLine, start, end, 0, gBot[gWorker], gBeamTrace)
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

stock scan_show_blocks(const Float:now)
{
	if (!gBlockViewers || !gBeamSprite || now < gNextBlockDraw || !scan_work_available()) return
	gNextBlockDraw = now+0.5/float(gBlockViewers)
	new viewer
	for (new checked = 0; checked < MaxClients; checked++)
	{
		gBlockViewerCursor = gBlockViewerCursor%MaxClients+1
		if (gBlockView[gBlockViewerCursor] && is_user_connected(gBlockViewerCursor)) { viewer = gBlockViewerCursor; break; }
	}
	if (!viewer) return
	new Float:feet[3], Float:point[3], selected[12], count
	new scout = gWatch[viewer] ? gWatch[viewer]-1 : 0
	if (!scan_bot_valid(scout)) return
	anpc_entity_feet(gBot[scout],feet)
	for (new x = -3; x <= 3 && count < sizeof selected; x++)
	{
		for (new y = -3; y <= 3 && count < sizeof selected; y++)
		{
			anpc_copy_vec(feet, point)
			point[0] += float(x)*32.0
			point[1] += float(y)*32.0
			new base = scan_block_open_at(feet)
			if (base >= 0) point[2] = scan_block_height(base,point[0],point[1])
			new block = scan_block_open_at(point), bool:duplicate
			if (block < 0) continue
			for (new old = 0; old < count; old++) if (selected[old] == block) { duplicate = true; break; }
			if (!duplicate) selected[count++] = block
		}
	}
	for (new index = 0; index < count && scan_work_available(); index++)
	{
		new block = selected[index], data[ScanBlock], Float:corner[4][3]
		ArrayGetArray(gBlock,block,data)
		new Float:size = SCAN_BLOCK_SIZE[data[BL_LEVEL]]
		for (new side = 0; side < 4; side++)
		{
			corner[side][0] = float(data[BL_X])*size+((side == 1 || side == 2) ? size : 0.0)
			corner[side][1] = float(data[BL_Y])*size+(side >= 2 ? size : 0.0)
			corner[side][2] = scan_block_plane_height(data,corner[side][0],corner[side][1])+2.0
		}
		for (new side = 0; side < 4; side++)
		{
			engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, SCAN_ZERO, viewer)
			write_byte(TE_BEAMPOINTS)
			for (new axis = 0; axis < 3; axis++) engfunc(EngFunc_WriteCoord, corner[side][axis])
			for (new axis = 0; axis < 3; axis++) engfunc(EngFunc_WriteCoord, corner[(side+1)%4][axis])
			write_short(gBeamSprite)
			write_byte(0); write_byte(0); write_byte(10); write_byte(2); write_byte(0)
			write_byte(64); write_byte(144); write_byte(255); write_byte(150); write_byte(0)
			message_end()
		}
	}
}

stock scan_status(const id)
{
	new pending
	// Count cached work; asking for status must not classify every map direction.
	for (new node = 0; node < gKnownCount; node++) if (scan_frontier_weight(node,false)) pending++
	console_print(id, "[ANPC] Mapper active=%d stage=%d bots=%d nodes=%d/%d links=%d pending-estimate=%d", gActive, gSessionStage, gBotCount, gKnownCount, ANPC_MAX_NODES, gLinks, pending)
	console_print(id, "[ANPC] Verified walk=%d jump=%d drop=%d ladder=%d | failures=%d hazards=%d warps=%d unsupported=%d", gWalks,gJumps,gDrops,gClimbs,gFailures,gHazards,gWarps,gUnsupported)
	console_print(id, "[ANPC] Seeds %d/%d episodes=%d | survey %d/%d | elapsed %.1f min | last checkpoint saved=%d", scan_used_seeds(),gSeedCount,gSeedEpisodes,gSurveyCursor,gSurveyTotal,(get_gametime()-gStarted)/60.0,gSaved)
	console_print(id, "[ANPC] Resumed memory=%d | trace/frame limit=%d | cooperative budget=%.2f ms",gMemoryLoaded,gTraceLimit,gBudgetMs)
	console_print(id, "[ANPC] Sweeps=%d known-direction skips=%d long walks=%d deferred returns=%d | distance: explore=%.0f travel/return=%.0f",gSweeps,gKnownSkips,gLongTrials,gReturnTrials,gExploreDistance,gTravelDistance)
	console_print(id, "[ANPC] Blocks: open=%d detail=%d total=%d (dynamic) | pruned bearings=%d skipped interior trials=%d cost-ranked targets=%d coverage-limit=%d",gBlockOpen,gBlockDetail,gBlockCount,gBlockSkips,gFrontierSkips,gCostSelections,gBlockLimit)
	console_print(id, "[ANPC] Area rejections: floor=%d plane=%d hull=%d sensitive=%d capacity=%d | crouch retries=%d",gBlockReject[BLOCK_FLOOR],gBlockReject[BLOCK_PLANE],gBlockReject[BLOCK_HULL],gBlockReject[BLOCK_VOLUME],gBlockReject[BLOCK_CAPACITY],gBlockCrouchRetry)
	console_print(id, "[ANPC] Floor probe failures: support=%d solid-start=%d non-world=%d height=%d",gBlockFloorReject[FLOOR_SUPPORT],gBlockFloorReject[FLOOR_SOLID],gBlockFloorReject[FLOOR_ENTITY],gBlockFloorReject[FLOOR_HEIGHT])
	console_print(id, "[ANPC] Survey: enabled=%d valid-BSP-bounds=%d step=%.0f",gSurveyEnabled,gSurveyValid,gSurveyStep)
	console_print(id, "[ANPC] Navigation areas=%d | suppressed node samples=%d symmetric floor returns=%d local landings=%d",anpc_nav_area_count(),gAreaNodesSkipped,gAreaReturns,gLandingTrials)
	console_print(id, "[ANPC] Finalization: removed interior samples=%d generated portals=%d portal capacity skips=%d",gPrunedNodes,gPortals,gPortalLimit)
	console_print(id, "[ANPC] Retained area revalidation: phase=%d source areas=%d/%d",gRestoreAreaPhase,gRestoreAreaCursor,gRestoreAreaCount)
	console_print(id,"[ANPC] Reused anchors=%d bounded alignments=%d certified route shortcuts=%d",gAnchorReuses,gAlignments,gRouteShortcuts)
	console_print(id,"[ANPC] Scouts=%d | safe lateral commands=%d | shared trace/CPU limits are not multiplied",gBotCount,gAvoidances)
	for (new scout = 0; scout < gBotCount; scout++)
	{
		if (!scan_bot_valid(scout)) continue
		new Float:feet[3]
		anpc_entity_feet(gBot[scout],feet)
		console_print(id,"[ANPC] Scout %d bot=%d stage=%d idle=%d feet %.1f %.1f %.1f | anchor=%d source=%d goal=%d claim=%d motion=%d",scout+1,gBot[scout],gStage[scout],gIdle[scout],feet[0],feet[1],feet[2],gCurrent[scout],gSource[scout],gGoalNode[scout],gClaimNode[scout],gMotion[scout])
	}
}
