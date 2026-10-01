#pragma dynamic 32768

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <reapi>
#include "advanced_npc/advanced_npc_navigation"
#include "advanced_npc/math"
#include "advanced_npc/ground"

new Float:gNodeOrigin[ANPC_MAX_NODES][3], Float:gNodeRadius[ANPC_MAX_NODES]
new gNodeFlags[ANPC_MAX_NODES], gLinkCount[ANPC_MAX_NODES]
enum _:NavLink { NL_TO, NL_FLAGS, Float:NL_VELOCITY[3], Float:NL_COST, Float:NL_BLOCKED }
new Array:gNodeLinks[ANPC_MAX_NODES]
new gBucketHead[ANPC_HASH_BUCKETS], gBucketNext[ANPC_MAX_NODES]
#define NAV_NODE_AREAS 8
#define NAV_BLOCKED_PAIRS 128
#define NAV_EXPLICIT_STRIDE ANPC_MAX_NODES
#define NAV_BUCKET_STRIDE (ANPC_MAX_NODES+2)
#define NAV_NEIGHBOR_STRIDE (9*NAV_BUCKET_STRIDE)

new Float:gAreaNormal[ANPC_MAX_AREAS][3]
new gAreaNodeHead[ANPC_MAX_AREAS], gNodeAreaCount[ANPC_MAX_NODES]
new gNodeArea[ANPC_MAX_NODES][NAV_NODE_AREAS], gNodeAreaNext[ANPC_MAX_NODES][NAV_NODE_AREAS]
new bool:gRegionsReady, gRegionPhase, gRegionCursor, gRegionLink, gRegionOriginal, gRegionKept, gRegionPortals, gRegionEdges
new gRegionBucket, gRegionNeighbor, bool:gRegionKeep[ANPC_MAX_NODES], gRegionMap[ANPC_MAX_NODES]
new gRegionPortalLimit
enum _:NavRegionEdge { RE_FROM, RE_TO, RE_FLAGS, Float:RE_VELOCITY[3], Float:RE_FROM_FEET[3], Float:RE_TO_FEET[3], RE_FROM_FLAGS, RE_TO_FLAGS }
new Array:gRegionTransitions, gRegionNeeded
enum _:NavRegionPortal { RP_ORIGINAL, RP_FLAGS, Float:RP_FEET[3] }
new Array:gRegionPortalPlan, gRegionParent[2][ANPC_MAX_AREAS], gRegionPortalNeeded
new gPairBlockedFrom[NAV_BLOCKED_PAIRS], gPairBlockedTo[NAV_BLOCKED_PAIRS], Float:gPairBlockedUntil[NAV_BLOCKED_PAIRS]
new gJobCurrent[ANPC_SEARCH_JOBS], gJobNeighborCursor[ANPC_SEARCH_JOBS]
new Float:gAreaMins[ANPC_MAX_AREAS][3], Float:gAreaMaxs[ANPC_MAX_AREAS][3]
new gAreaFlags[ANPC_MAX_AREAS], gAreaNext[ANPC_MAX_AREAS], gAreaHead[ANPC_HASH_BUCKETS], gAreaCount
new gNodeCount, gRevision, gChangedForward, gTrace, gExpansions, gFrameForward
new Float:gStepSize
new gMap[64], gNavPath[256], gBspSize, gBspHash[33]
new Array:gLadders
new gEditOwner, bool:gEditDirty

new gRouteOwner[ANPC_MAX_ACTORS], gRouteGeneration[ANPC_MAX_ACTORS]
new AnpcPathStatus:gRouteStatus[ANPC_MAX_ACTORS]
new gRouteStart[ANPC_MAX_ACTORS], gRouteGoal[ANPC_MAX_ACTORS], gRouteCaps[ANPC_MAX_ACTORS]
new Array:gRoutePath[ANPC_MAX_ACTORS]
new bool:gRoutePosition[ANPC_MAX_ACTORS], gRoutePathRevision[ANPC_MAX_ACTORS]
new Float:gRouteOrigin[ANPC_MAX_ACTORS][3], Float:gRouteDestination[ANPC_MAX_ACTORS][3]
new gRouteActor[ANPC_MAX_ACTORS], gRouteTarget[ANPC_MAX_ACTORS]
#define NAV_ATTACH_CANDIDATES (ANPC_NEAR_CANDIDATES*2)
new gJobAttachSide[ANPC_SEARCH_JOBS], gJobAttachCursor[ANPC_SEARCH_JOBS]
new gJobCandidates[ANPC_SEARCH_JOBS][2][NAV_ATTACH_CANDIDATES], gJobCandidateCount[ANPC_SEARCH_JOBS][2]
new gJobAnchor[ANPC_SEARCH_JOBS][2][ANPC_NEAR_CANDIDATES], gJobAnchorCount[ANPC_SEARCH_JOBS][2]
new Float:gJobAnchorCost[ANPC_SEARCH_JOBS][2][ANPC_NEAR_CANDIDATES]
new gJobBestGoal[ANPC_SEARCH_JOBS], Float:gJobBestCost[ANPC_SEARCH_JOBS], gAttachBudget
new gJobRoute[ANPC_SEARCH_JOBS], gJobEpoch[ANPC_SEARCH_JOBS], gHeapSize[ANPC_SEARCH_JOBS]
new gStamp[ANPC_SEARCH_JOBS][ANPC_MAX_NODES], gClosed[ANPC_SEARCH_JOBS][ANPC_MAX_NODES]
new gParent[ANPC_SEARCH_JOBS][ANPC_MAX_NODES], gHeapPos[ANPC_SEARCH_JOBS][ANPC_MAX_NODES]
new gHeap[ANPC_SEARCH_JOBS][ANPC_MAX_NODES]
new Float:gCost[ANPC_SEARCH_JOBS][ANPC_MAX_NODES], Float:gPriority[ANPC_SEARCH_JOBS][ANPC_MAX_NODES]
new gQueueCursor, gJobCursor, gReversePath[ANPC_MAX_NODES]

#include "advanced_npc/navigation_areas"
#include "advanced_npc/navigation_graph"
#include "advanced_npc/navigation_search"
#include "advanced_npc/navigation_portals"

public plugin_natives()
{
	register_library("advanced_npc_navigation")
	register_native("anpc_nav_count", "native_count")
	register_native("anpc_nav_revision", "native_revision")
	register_native("anpc_nav_begin_edit", "native_begin_edit")
	register_native("anpc_nav_end_edit", "native_end_edit")
	register_native("anpc_nav_editing", "native_editing")
	register_native("anpc_nav_reset", "native_reset")
	register_native("anpc_nav_find_near", "native_find_near")
	register_native("anpc_nav_near_candidates", "native_near_candidates")
	register_native("anpc_nav_node", "native_node")
	register_native("anpc_nav_area_count", "native_area_count")
	register_native("anpc_nav_area", "native_area")
	register_native("anpc_nav_area_at", "native_area_at")
	register_native("anpc_nav_area_segment", "native_area_segment")
	register_native("anpc_nav_area_add", "native_area_add")
	register_native("anpc_nav_area_clear", "native_area_clear")
	register_native("anpc_nav_area_finish_step", "native_area_finish_step")
	register_native("anpc_nav_neighbor_next", "native_neighbor_next")
	register_native("anpc_nav_nearest", "native_nearest")
	register_native("anpc_nav_walkable", "native_walkable")
	register_native("anpc_nav_link", "native_link")
	register_native("anpc_nav_link_count", "native_link_count")
	register_native("anpc_nav_link_at", "native_link_at")
	register_native("anpc_nav_block_link", "native_block_link")
	register_native("anpc_nav_ladder", "native_ladder")
	register_native("anpc_nav_open", "native_open")
	register_native("anpc_nav_close", "native_close")
	register_native("anpc_nav_cancel", "native_cancel")
	register_native("anpc_nav_request", "native_request")
	register_native("anpc_nav_request_to", "native_request_to")
	register_native("anpc_nav_status", "native_status")
	register_native("anpc_nav_path_revision", "native_path_revision")
	register_native("anpc_nav_path_size", "native_path_size")
	register_native("anpc_nav_path_node", "native_path_node")
	register_native("anpc_nav_add", "native_add")
	register_native("anpc_nav_set_flags", "native_set_flags")
	register_native("anpc_nav_connect", "native_connect")
	register_native("anpc_nav_disconnect", "native_disconnect")
	register_native("anpc_nav_save", "native_save")
	register_native("anpc_nav_reload", "native_reload")
}

public plugin_init()
{
	register_plugin("Advanced NPC: Navigation", ANPC_VERSION, "ZPN")
	if (!is_rehlds() || !is_regamedll())
		set_fail_state("Advanced NPC requires ReHLDS and ReGameDLL CS")

	gTrace = create_tr2()
	bind_pcvar_float(get_cvar_pointer("sv_stepsize"), gStepSize)
	gLadders = ArrayCreate(1)
	gChangedForward = CreateMultiForward("anpc_nav_changed", ET_IGNORE, FP_CELL)
	bind_pcvar_num(create_cvar("anpc_nav_expansions", "192", FCVAR_NONE, "A* bounded search operations per server frame", true, 16.0, true, 1024.0), gExpansions)
	for (new job = 0; job < ANPC_SEARCH_JOBS; job++)
		gJobRoute[job] = -1
	for (new route = 0; route < ANPC_MAX_ACTORS; route++)
		gRoutePath[route] = ArrayCreate(1)

	rh_get_mapname(gMap, charsmax(gMap), MNT_TRUE)
	new path[256], directory[192]
	get_configsdir(directory, charsmax(directory))
	formatex(gNavPath, charsmax(gNavPath), "%s/advanced_npc/maps/%s.nav", directory, gMap)
	formatex(path, charsmax(path), "maps/%s.bsp", gMap)
	gBspSize = file_size(path)
	if (gBspSize > 0) hash_file(path, Hash_Md5, gBspHash, charsmax(gBspHash))
	nav_clear_graph()
}

public plugin_cfg()
{
	new entity
	while ((entity = rg_find_ent_by_class(entity, "func_ladder")))
		ArrayPushCell(gLadders, entity)
	if (!nav_load())
		log_amx("No valid graph for %s. Generate with anpc_scan start new or use the navigation editor. NPC creation requires navigation.", gMap)
}

public plugin_end()
{
	gEditOwner = 0
	if (gFrameForward)
		unregister_forward(FM_StartFrame, gFrameForward)
	for (new route = 0; route < ANPC_MAX_ACTORS; route++)
	{
		// Consumers may run plugin_end after this provider during shutdown.
		gRouteOwner[route] = 0
		ArrayDestroy(gRoutePath[route])
	}
	for (new node = 0; node < ANPC_MAX_NODES; node++) if (gNodeLinks[node]) ArrayDestroy(gNodeLinks[node])
	if (gRegionTransitions) ArrayDestroy(gRegionTransitions)
	if (gRegionPortalPlan) ArrayDestroy(gRegionPortalPlan)
	ArrayDestroy(gLadders)
	free_tr2(gTrace)
	gTrace = 0
	DestroyForward(gChangedForward)
}

public native_count() { return gNodeCount; }
public native_revision() { return gRevision; }
public bool:native_editing() { return gEditOwner != 0; }

public bool:native_begin_edit(const plugin)
{
	if (!gTrace || gEditOwner) return false
	gEditOwner = plugin+1
	gEditDirty = false
	nav_invalidate()
	// Editing always uses spatial enumeration. A pending cursor cannot switch
	// between membership-list and bucket encodings when a certificate changes.
	gRegionsReady = false
	return true
}

public bool:native_end_edit(const plugin)
{
	if (!gTrace || gEditOwner != plugin+1) return false
	new bool:membership_changed = !gRegionsReady
	if (membership_changed) nav_build_area_membership()
	gEditOwner = 0
	if (gEditDirty || membership_changed) nav_invalidate()
	gEditDirty = false
	return true
}

public bool:native_reset(const plugin)
{
	if (!gTrace || gEditOwner != plugin+1) return false
	for (new route = 0; route < ANPC_MAX_ACTORS; route++) nav_cancel_route(route)
	nav_clear_graph()
	gEditDirty = true
	return true
}

public native_find_near()
{
	new Float:feet[3], Float:radius = get_param_f(2), Float:height = get_param_f(3)
	get_array_f(1, feet, 3)
	if (!gTrace || !anpc_finite(radius, 512.0) || radius < 1.0 || !anpc_finite(height, 512.0) || height < 0.0) return ANPC_INVALID_NODE
	return nav_find_near(feet, radius, height, get_param(4))
}

public bool:native_node()
{
	new node = get_param(1)
	if (!nav_valid_node(node)) return false
	set_array_f(2, gNodeOrigin[node], 3)
	set_param_byref(3, gNodeFlags[node])
	set_float_byref(4, gNodeRadius[node])
	return true
}

public native_near_candidates()
{
	new Float:feet[3], Float:radius = get_param_f(2), Float:height = get_param_f(3), nodes[ANPC_NEAR_CANDIDATES]
	get_array_f(1,feet,3)
	arrayset(nodes,-1,sizeof nodes)
	new count
	if (gTrace && anpc_finite(radius,512.0) && radius >= 1.0 && anpc_finite(height,512.0) && height >= 0.0)
		count = nav_near_candidates(feet,radius,height,nodes,get_param(5))
	set_array(4,nodes,sizeof nodes)
	return count
}

public native_area_count() { return gAreaCount; }

public bool:native_area()
{
	new area = get_param(1)
	if (!(0 <= area < gAreaCount)) return false
	set_array_f(2, gAreaMins[area], 3)
	set_array_f(3, gAreaMaxs[area], 3)
	set_array_f(4, gAreaNormal[area], 3)
	set_param_byref(5, gAreaFlags[area])
	return true
}

public native_area_at()
{
	new Float:feet[3]
	get_array_f(1, feet, 3)
	return nav_area_at(feet, get_param(2))
}

public bool:native_area_segment()
{
	new Float:from[3], Float:to[3]
	get_array_f(1,from,3); get_array_f(2,to,3)
	return nav_area_segment(from,to,get_param(3))
}

public native_area_add(const plugin)
{
	if (!nav_edit_allowed(plugin) || gEditOwner != plugin+1) return -1
	new Float:mins[3], Float:maxs[3], Float:normal[3]
	get_array_f(1,mins,3); get_array_f(2,maxs,3); get_array_f(3,normal,3)
	new area = nav_add_area(mins,maxs,normal,get_param(4),true)
	if (area >= 0) nav_changed()
	return area
}

public bool:native_area_clear(const plugin)
{
	if (!gTrace || gEditOwner != plugin+1) return false
	nav_clear_areas()
	nav_changed()
	return true
}

public native_nearest()
{
	new Float:feet[3]
	get_array_f(1, feet, 3)
	new Float:range = get_param_f(4)
	if (!anpc_finite(range)) return ANPC_INVALID_NODE
	return nav_nearest(feet, get_param(2), get_param(3), floatclamp(range, 32.0, 512.0))
}

public bool:native_walkable()
{
	new Float:from[3], Float:to[3]
	get_array_f(1, from, 3)
	get_array_f(2, to, 3)
	return nav_walkable(from, to, bool:get_param(3), get_param(4))
}

public bool:native_link()
{
	new from = get_param(1), to = get_param(2), link = nav_find_link(from,to)
	if (from == to) return false
	if (link >= 0)
	{
		new data[NavLink]
		ArrayGetArray(gNodeLinks[from],link,data)
		if (data[NL_BLOCKED] > get_gametime()) return false
		set_param_byref(3,data[NL_FLAGS])
		set_array_f(4,data[NL_VELOCITY],3)
		return true
	}
	if (nav_common_area(from,to) < 0 || nav_pair_blocked(from,to,get_gametime())) return false
	new Float:zero[3]
	set_param_byref(3,0); set_array_f(4,zero,3)
	return true
}

public bool:native_block_link(const plugin)
{
	if (!nav_edit_allowed(plugin)) return false
	new from = get_param(1), to = get_param(2), link = nav_find_link(from,to)
	if (from == to) return false
	new Float:until = get_gametime()+floatclamp(get_param_f(3),0.1,10.0)
	if (link >= 0) { ArraySetCell(gNodeLinks[from],link,until,NL_BLOCKED); return true; }
	if (nav_common_area(from,to) < 0) return false
	new slot = nav_pair_slot(from,to)
	gPairBlockedFrom[slot] = from; gPairBlockedTo[slot] = to; gPairBlockedUntil[slot] = until
	return true
}

public AnpcNeighborStatus:native_neighbor_next()
{
	new cursor = get_param_byref(2), destination, flags, Float:cost
	new AnpcNeighborStatus:result = nav_next_neighbor(get_param(1),cursor,destination,flags,cost,get_param(6),get_gametime())
	set_param_byref(2,cursor)
	if (result == ANPC_NEIGHBOR_EDGE)
	{ set_param_byref(3,destination); set_param_byref(4,flags); set_float_byref(5,cost); }
	return result
}

public native_area_finish_step(const plugin)
{
	if (!gTrace || gEditOwner != plugin+1) return -1
	if (!gRegionPhase)
	{
		nav_region_begin()
		get_array(1,gRegionKeep,ANPC_MAX_NODES)
	}
	if (!nav_region_step()) return 0
	set_array(2,gRegionMap,ANPC_MAX_NODES)
	set_param_byref(3,gRegionOriginal-gRegionKept); set_param_byref(4,gRegionPortals)
	set_param_byref(5,gRegionEdges)
	set_param_byref(6,gRegionPortalLimit)
	gRegionPhase = 0
	return 1
}

public native_link_count()
{
	new node = get_param(1)
	return nav_valid_node(node) ? gLinkCount[node] : 0
}

public bool:native_link_at()
{
	new node = get_param(1), link = get_param(2)
	if (!nav_valid_node(node) || !(0 <= link < gLinkCount[node])) return false
	new data[NavLink]
	ArrayGetArray(gNodeLinks[node],link,data)
	set_param_byref(3,data[NL_TO])
	set_param_byref(4,data[NL_FLAGS])
	set_array_f(5,data[NL_VELOCITY],3)
	return true
}

public native_ladder()
{
	new Float:feet[3]
	get_array_f(1, feet, 3)
	return nav_ladder_at(feet)
}

stock nav_ladder_at(const Float:feet[3])
{
	new Float:mins[3], Float:maxs[3]
	for (new i = 0, count = ArraySize(gLadders); i < count; i++)
	{
		new entity = ArrayGetCell(gLadders, i)
		if (!FClassnameIs(entity, "func_ladder")) continue
		get_entvar(entity, var_absmin, mins)
		get_entvar(entity, var_absmax, maxs)
		if (feet[0] >= mins[0]-40.0 && feet[0] <= maxs[0]+40.0
		&& feet[1] >= mins[1]-40.0 && feet[1] <= maxs[1]+40.0
		&& feet[2] >= mins[2]-40.0 && feet[2] <= maxs[2]+40.0)
			return entity
	}
	return 0
}

public native_add(const plugin)
{
	if (!nav_edit_allowed(plugin)) return ANPC_INVALID_NODE
	new Float:feet[3]
	get_array_f(1, feet, 3)
	new node = nav_add_node(feet, get_param(2), get_param_f(3))
	if (node >= 0) { if (gRegionsReady) nav_attach_node(node); nav_changed(); }
	return node
}

public bool:native_set_flags(const plugin)
{
	if (!nav_edit_allowed(plugin)) return false
	new node = get_param(1), flags = get_param(2)
	if (!nav_valid_node(node) || (flags & ~ANPC_NODE_FLAGS)) return false
	gNodeFlags[node] = flags
	if (gEditOwner) gRegionsReady = false
	else nav_build_area_membership()
	nav_changed()
	return true
}

public bool:native_connect(const plugin)
{
	if (!nav_edit_allowed(plugin)) return false
	new Float:velocity[3]
	get_array_f(4, velocity, 3)
	if (!nav_add_link(get_param(1), get_param(2), get_param(3), velocity)) return false
	nav_changed()
	return true
}

public bool:native_disconnect(const plugin)
{
	if (!nav_edit_allowed(plugin)) return false
	new from = get_param(1), link = nav_find_link(from,get_param(2))
	if (link < 0) return false
	new last = --gLinkCount[from], data[NavLink]
	if (link != last)
	{
		ArrayGetArray(gNodeLinks[from],last,data)
		ArraySetArray(gNodeLinks[from],link,data)
	}
	ArrayResize(gNodeLinks[from],last)
	nav_changed()
	return true
}

public bool:native_save(const plugin) { return nav_edit_allowed(plugin) && nav_save(); }
public bool:native_reload(const plugin) { return nav_edit_allowed(plugin) && nav_load(); }
