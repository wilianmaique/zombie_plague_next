#pragma dynamic 16384

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <reapi>
#include "advanced_npc/advanced_npc"
#include "advanced_npc/advanced_npc_navigation"
#include "advanced_npc/math"

#define TASK_RECORD 7900
#define NAV_SHOW_NODES 8
#define NAV_SHOW_LINKS 8
#define NAV_SHOW_AREAS 4
#define NAV_SHOW_BEAMS (NAV_SHOW_NODES + NAV_SHOW_LINKS + NAV_SHOW_AREAS*4)
#define NAV_SHOW_BATCH 4
#define NAV_SHOW_INTERVAL 0.5
#define NAV_SHOW_RANGE 5000.0
#define NAV_SHOW_CONE_COS 0.5
#define NAV_SHOW_BEAM_WIDTH 10
#define NAV_SHOW_NODE_HEIGHT 20.0
#define NAV_SHOW_LIFT 2.0

new gTrace, gBeamSprite, gAutoSpawn, gRecorder, gRecordedNode = -1
new gMap[64], gBspSize, gSpawnPath[256], gBspHash[33]
new bool:gShow[33]
enum _:NavShowBeam { Float:SHOW_FROM[3], Float:SHOW_TO[3], SHOW_RED, SHOW_GREEN, SHOW_BLUE }
new gShowBeam[33][NAV_SHOW_BEAMS][NavShowBeam], gShowCount[33], gShowCursor[33]
new Float:gNextShow[33], Float:gNextBeamBatch
new xMsgSyncANPC

public plugin_precache()
{
	gBeamSprite = precache_model("sprites/laserbeam.spr")
}

public plugin_init()
{
	register_plugin("Advanced NPC: Administration", ANPC_VERSION, "ZPN")
	register_concmd("anpc_spawn", "command_spawn", ADMIN_RCON, "[type] [x y z yaw] - aim at floor, or supply feet coordinates")
	register_concmd("anpc_remove", "command_remove", ADMIN_RCON, "[entity] - remove aimed NPC or entity id")
	register_concmd("anpc_clear", "command_clear", ADMIN_RCON, "Remove all NPCs")
	register_concmd("anpc_status", "command_status", ADMIN_RCON, "Show entity and navigation status")
	register_concmd("anpc_nav_add", "command_nav_add", ADMIN_RCON, "[flags] [radius] - add a node at your feet")
	register_concmd("anpc_nav_link", "command_nav_link", ADMIN_RCON, "from to flags [vx vy vz] - directed link; flags 0 walk, 1 jump, 2 drop")
	register_concmd("anpc_nav_unlink", "command_nav_unlink", ADMIN_RCON, "from to - remove a directed link")
	register_concmd("anpc_nav_flags", "command_nav_flags", ADMIN_RCON, "node flags - 1 crouch, 2 ladder, 4 disabled")
	register_concmd("anpc_nav_save", "command_nav_save", ADMIN_RCON, "Save the current map's graph")
	register_concmd("anpc_nav_reload", "command_nav_reload", ADMIN_RCON, "Reload the current map's graph")
	register_concmd("anpc_nav_show", "command_nav_show", ADMIN_RCON, "0|1 - show nodes/links ahead of your camera, including spectators")
	register_concmd("anpc_nav_record", "command_nav_record", ADMIN_RCON, "0|1 - record verified walking connections")
	register_concmd("anpc_spawns_save", "command_spawns_save", ADMIN_RCON, "Save live NPC positions as this map's spawn points")
	register_concmd("anpc_spawns_load", "command_spawns_load", ADMIN_RCON, "Spawn saved points; requires no existing NPCs")
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "round_freeze_end_post", true)
	register_forward(FM_StartFrame,"nav_show_frame")
	bind_pcvar_num(create_cvar("anpc_auto_spawn", "0", FCVAR_NONE, "Spawn saved map points after freeze time", true, 0.0, true, 1.0), gAutoSpawn)
	gTrace = create_tr2()
	rh_get_mapname(gMap, charsmax(gMap), MNT_TRUE)
	new directory[192], bsp[128]
	get_configsdir(directory, charsmax(directory))
	formatex(gSpawnPath, charsmax(gSpawnPath), "%s/advanced_npc/maps/%s.spawns", directory, gMap)
	formatex(bsp, charsmax(bsp), "maps/%s.bsp", gMap)
	gBspSize = file_size(bsp)
	if (gBspSize > 0) hash_file(bsp, Hash_Md5, gBspHash, charsmax(gBspHash))

	xMsgSyncANPC = CreateHudSyncObj()
}

public plugin_cfg()
{
	new directory[192], path[256]
	get_configsdir(directory, charsmax(directory))
	formatex(path, charsmax(path), "%s/advanced_npc/advanced_npc.cfg", directory)
	if (file_exists(path))
	{
		server_cmd("exec ^"%s^"", path)
		server_exec()
	}
}

public plugin_end()
{
	free_tr2(gTrace)
}

public client_disconnected(id)
{
	gShow[id] = false
	gShowCount[id] = gShowCursor[id] = 0
	gNextShow[id] = 0.0
	if (gRecorder == id) { remove_task(TASK_RECORD); gRecorder = 0; gRecordedNode = -1; }
}

stock bool:admin_editor_ready(const id)
{
	if (anpc_nav_editing())
	{
		console_print(id, "[ANPC] Automatic mapper owns the graph. Stop it before editing or spawning NPCs.")
		return false
	}
	if (anpc_get_count())
	{
		console_print(id, "[ANPC] Clear NPCs before editing/reloading navigation. Wait for deferred removal.")
		return false
	}
	return true
}

stock admin_read_vector(const first_argument, Float:vector[3])
{
	new value[48]
	for (new axis = 0; axis < 3; axis++)
	{
		read_argv(first_argument+axis, value, charsmax(value))
		vector[axis] = str_to_float(value)
	}
}

stock bool:admin_aim_floor(const id, Float:feet[3])
{
	if (!id || !is_user_alive(id)) return false
	new Float:start[3], Float:end[3], Float:view[3], Float:direction[3], Float:normal[3], Float:fraction
	get_entvar(id, var_origin, start)
	get_entvar(id, var_view_ofs, view)
	for (new axis = 0; axis < 3; axis++) start[axis] += view[axis]
	get_entvar(id, var_v_angle, view)
	engfunc(EngFunc_MakeVectors, view)
	global_get(glb_v_forward, direction)
	for (new axis = 0; axis < 3; axis++) end[axis] = start[axis]+direction[axis]*2048.0
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, id, gTrace)
	get_tr2(gTrace, TR_flFraction, fraction)
	get_tr2(gTrace, TR_vecPlaneNormal, normal)
	get_tr2(gTrace, TR_vecEndPos, feet)
	return fraction < 1.0 && normal[2] >= 0.7 && !get_tr2(gTrace, TR_StartSolid)
}

stock admin_aim_entity(const id)
{
	if (!id || !is_user_alive(id)) return 0
	new Float:start[3], Float:end[3], Float:view[3], Float:direction[3]
	get_entvar(id, var_origin, start)
	get_entvar(id, var_view_ofs, view)
	for (new axis = 0; axis < 3; axis++) start[axis] += view[axis]
	get_entvar(id, var_v_angle, view)
	engfunc(EngFunc_MakeVectors, view)
	global_get(glb_v_forward, direction)
	for (new axis = 0; axis < 3; axis++) end[axis] = start[axis]+direction[axis]*2048.0
	engfunc(EngFunc_TraceLine, start, end, DONT_IGNORE_MONSTERS, id, gTrace)
	return get_tr2(gTrace, TR_pHit)
}

public command_spawn(const id, const level, const cid)
{
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	if (anpc_nav_editing()) { console_print(id, "[ANPC] Stop the automatic mapper before spawning NPCs."); return PLUGIN_HANDLED; }
	new type_name[48] = "zombie_default", Float:feet[3], Float:yaw
	if (read_argc() >= 2) read_argv(1, type_name, charsmax(type_name))
	if (read_argc() >= 5)
	{
		admin_read_vector(2, feet)
		new value[48]
		read_argv(5, value, charsmax(value))
		yaw = str_to_float(value)
	}
	else if (!admin_aim_floor(id, feet))
	{
		console_print(id, "[ANPC] Aim at walkable floor, or use: anpc_spawn type x y z [yaw]")
		return PLUGIN_HANDLED
	}
	new type = anpc_find_type(type_name), entity
	if (type >= 0) entity = anpc_create(type, feet, yaw)
	console_print(id, "[ANPC] Spawn result: entity %d. Graph, model, floor clearance, type and capacity must be valid.", entity)
	return PLUGIN_HANDLED
}

public command_remove(const id, const level, const cid)
{
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	new value[24], entity
	if (read_argc() >= 2) { read_argv(1, value, charsmax(value)); entity = str_to_num(value); }
	else entity = admin_aim_entity(id)
	console_print(id, "[ANPC] Removal scheduled: %d", anpc_remove(entity))
	return PLUGIN_HANDLED
}

public command_clear(const id, const level, const cid)
{
	if (cmd_access(id, level, cid, 1)) console_print(id, "[ANPC] Scheduled removal of %d NPC entities", anpc_remove_all())
	return PLUGIN_HANDLED
}

public command_status(const id, const level, const cid)
{
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	console_print(id, "[ANPC] Entities %d/%d | navigation nodes %d | revision %d", anpc_get_count(), anpc_get_capacity(), anpc_nav_count(), anpc_nav_revision())
	new entity
	while ((entity = rg_find_ent_by_class(entity, ANPC_CLASSNAME)))
	{
		if (!anpc_is_npc(entity)) continue
		console_print(id, " entity %d serial %d type %d state %d target %d health %.0f", entity, anpc_get_serial(entity), anpc_get_type(entity), anpc_get_state(entity), anpc_get_target(entity), Float:get_entvar(entity, var_health))
	}
	return PLUGIN_HANDLED
}

public command_nav_add(const id, const level, const cid)
{
	if (!cmd_access(id, level, cid, 1) || !admin_editor_ready(id)) return PLUGIN_HANDLED
	if (!id || !is_user_alive(id)) { console_print(id, "[ANPC] This command requires a living admin in the map."); return PLUGIN_HANDLED; }
	new value[32], flags, Float:radius = 24.0, Float:feet[3]
	if (read_argc() >= 2) { read_argv(1, value, charsmax(value)); flags = str_to_num(value); }
	if (read_argc() >= 3) { read_argv(2, value, charsmax(value)); radius = str_to_float(value); }
	anpc_entity_feet(id, feet)
	if (!(get_entvar(id, var_flags) & FL_ONGROUND) && !((flags & ANPC_NODE_LADDER) && anpc_nav_ladder(feet)))
	{
		console_print(id, "[ANPC] Stand on the floor, or mark a node on a real ladder.")
		return PLUGIN_HANDLED
	}
	console_print(id, "[ANPC] Added node %d", anpc_nav_add(feet, flags, radius))
	return PLUGIN_HANDLED
}

public command_nav_link(const id, const level, const cid)
{
	if (!cmd_access(id, level, cid, 4) || !admin_editor_ready(id)) return PLUGIN_HANDLED
	new value[32], from, to, flags, Float:velocity[3], Float:a[3], Float:b[3], Float:radius, af, bf
	read_argv(1, value, charsmax(value)); from = str_to_num(value)
	read_argv(2, value, charsmax(value)); to = str_to_num(value)
	read_argv(3, value, charsmax(value)); flags = str_to_num(value)
	if (flags & ANPC_LINK_JUMP)
	{
		if (read_argc() > 4 && read_argc() < 7) { console_print(id, "[ANPC] Supply all vx vy vz, or omit all for a computed jump."); return PLUGIN_HANDLED; }
		if (read_argc() >= 7) admin_read_vector(4, velocity)
	}
	if (!anpc_nav_node(from, a, af, radius) || !anpc_nav_node(to, b, bf, radius)) return PLUGIN_HANDLED
	if (!flags && !((af | bf) & ANPC_NODE_LADDER)
	&& !anpc_nav_walkable(a, b, bool:((af | bf) & ANPC_NODE_CROUCH), id))
	{
		console_print(id, "[ANPC] Walking connection has a blocked hull or unsafe floor. Use the appropriate jump/drop/ladder route.")
		return PLUGIN_HANDLED
	}
	console_print(id, "[ANPC] Directed link %d -> %d: %d", from, to, anpc_nav_connect(from, to, flags, velocity))
	return PLUGIN_HANDLED
}

public command_nav_unlink(const id, const level, const cid)
{
	if (!cmd_access(id, level, cid, 3) || !admin_editor_ready(id)) return PLUGIN_HANDLED
	new value[24], from, to
	read_argv(1, value, charsmax(value)); from = str_to_num(value)
	read_argv(2, value, charsmax(value)); to = str_to_num(value)
	console_print(id, "[ANPC] Unlinked: %d", anpc_nav_disconnect(from, to))
	return PLUGIN_HANDLED
}

public command_nav_flags(const id, const level, const cid)
{
	if (!cmd_access(id, level, cid, 3) || !admin_editor_ready(id)) return PLUGIN_HANDLED
	new value[24], node, flags
	read_argv(1, value, charsmax(value)); node = str_to_num(value)
	read_argv(2, value, charsmax(value)); flags = str_to_num(value)
	console_print(id, "[ANPC] Flags changed: %d", anpc_nav_set_flags(node, flags))
	return PLUGIN_HANDLED
}

public command_nav_save(const id, const level, const cid)
{
	if (cmd_access(id, level, cid, 1) && admin_editor_ready(id)) console_print(id, "[ANPC] Graph saved: %d", anpc_nav_save())
	return PLUGIN_HANDLED
}

public command_nav_reload(const id, const level, const cid)
{
	if (cmd_access(id, level, cid, 1) && admin_editor_ready(id)) console_print(id, "[ANPC] Graph loaded: %d", anpc_nav_reload())
	return PLUGIN_HANDLED
}

public command_nav_record(const id, const level, const cid)
{
	if (!cmd_access(id, level, cid, 2) || !id || !admin_editor_ready(id)) return PLUGIN_HANDLED
	new value[16]
	read_argv(1, value, charsmax(value))
	if (!str_to_num(value))
	{
		if (gRecorder == id) { remove_task(TASK_RECORD); gRecorder = 0; gRecordedNode = -1; }
		return PLUGIN_HANDLED
	}
	if (gRecorder && gRecorder != id) { console_print(id, "[ANPC] Another admin is recording."); return PLUGIN_HANDLED; }
	gRecorder = id
	gRecordedNode = -1
	remove_task(TASK_RECORD)
	set_task_ex(0.2, "record_step", TASK_RECORD, .flags = SetTask_Repeat)
	console_print(id, "[ANPC] Recording safe WALK routes. Add directed jumps and ladders explicitly. Save when finished.")
	return PLUGIN_HANDLED
}

public record_step()
{
	new id = gRecorder
	if (!id || !is_user_alive(id) || anpc_get_count() || get_entvar(id, var_movetype) == MOVETYPE_NOCLIP) return
	if (!(get_entvar(id, var_flags) & FL_ONGROUND)) return
	new Float:feet[3], Float:last[3], Float:radius, flags
	anpc_entity_feet(id, feet)
	if (gRecordedNode >= 0 && anpc_nav_node(gRecordedNode, last, flags, radius)
	&& anpc_distance_2d(feet, last) < 128.0 && floatabs(feet[2]-last[2]) < 18.0) return
	new node = anpc_nav_nearest(feet, ANPC_CAP_ALL, id, 64.0)
	if (node < 0) node = anpc_nav_add(feet, get_entvar(id, var_flags) & FL_DUCKING ? ANPC_NODE_CROUCH : 0)
	if (node < 0 || node == gRecordedNode) return
	new Float:destination[3], destination_flags
	anpc_nav_node(node, destination, destination_flags, radius)
	if (gRecordedNode >= 0 && anpc_nav_node(gRecordedNode, last, flags, radius))
	{
		new bool:duck = bool:((flags | destination_flags) & ANPC_NODE_CROUCH)
		if (anpc_nav_walkable(last, destination, duck, id)) anpc_nav_connect(gRecordedNode, node)
		if (anpc_nav_walkable(destination, last, duck, id)) anpc_nav_connect(node, gRecordedNode)
	}
	gRecordedNode = node
	console_print(id, "[ANPC] Recorded node %d", node)
}

public command_nav_show(const id, const level, const cid)
{
	if (!cmd_access(id, level, cid, 2) || !id) return PLUGIN_HANDLED
	new value[16]
	read_argv(1, value, charsmax(value))
	gShow[id] = bool:str_to_num(value)
	gShowCount[id] = gShowCursor[id] = 0
	gNextShow[id] = 0.0
	return PLUGIN_HANDLED
}

stock admin_beam(const id, const Float:from[3], const Float:to[3], const red, const green, const blue = 40)
{
	if (gShowCount[id] >= NAV_SHOW_BEAMS) return
	new index = gShowCount[id]++
	anpc_copy_vec(from,gShowBeam[id][index][SHOW_FROM])
	anpc_copy_vec(to,gShowBeam[id][index][SHOW_TO])
	gShowBeam[id][index][SHOW_RED] = red
	gShowBeam[id][index][SHOW_GREEN] = green
	gShowBeam[id][index][SHOW_BLUE] = blue
}

stock admin_send_beam(const id, const index)
{
	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id)
	write_byte(TE_BEAMPOINTS)
	for (new axis = 0; axis < 3; axis++) engfunc(EngFunc_WriteCoord,gShowBeam[id][index][SHOW_FROM+axis])
	for (new axis = 0; axis < 3; axis++) engfunc(EngFunc_WriteCoord,gShowBeam[id][index][SHOW_TO+axis])
	write_short(gBeamSprite)
	write_byte(0); write_byte(0); write_byte(6); write_byte(NAV_SHOW_BEAM_WIDTH); write_byte(0)
	write_byte(gShowBeam[id][index][SHOW_RED]); write_byte(gShowBeam[id][index][SHOW_GREEN]); write_byte(gShowBeam[id][index][SHOW_BLUE]); write_byte(170); write_byte(0)
	message_end()
}

public nav_show_frame()
{
	new Float:now = get_gametime()
	if (now < gNextBeamBatch) return FMRES_IGNORED
	gNextBeamBatch = now+0.05
	// Keep a bounded per-viewer batch out of the large unreliable datagram
	// bursts. No repeating task can disappear and leave the toggle enabled.
	for (new id = 1; id <= MaxClients; id++)
	{
		if (!gShow[id] || !is_user_connected(id)) continue
		if (gShowCursor[id] >= gShowCount[id] && now >= gNextShow[id])
		{
			gShowCursor[id] = gShowCount[id] = 0
			show_nodes(id)
			gNextShow[id] = now+NAV_SHOW_INTERVAL
		}
		for (new batch = 0; batch < NAV_SHOW_BATCH && gShowCursor[id] < gShowCount[id]; batch++)
		{
			admin_send_beam(id,gShowCursor[id])
			gShowCursor[id]++
		}
	}
	return FMRES_IGNORED
}

stock admin_nav_view(const id, Float:eye[3], Float:direction[3])
{
	new Float:angles[3], Float:offset[3], source = id, view_entity = get_viewent(id)
	if (view_entity > MaxClients && is_entity(view_entity))
	{
		// SetView cameras use their own origin/angles, not the player's aim.
		get_entvar(view_entity, var_origin, eye)
		get_entvar(view_entity, var_angles, angles)
		angle_vector(angles, ANGLEVECTOR_FORWARD, direction)
		return
	}
	new mode = get_entvar(id, var_iuser1)
	get_entvar(id, var_v_angle, angles)
	if (!is_user_alive(id) && (mode == OBS_IN_EYE || mode == OBS_CHASE_FREE || mode == OBS_CHASE_LOCKED))
	{
		new target = get_member(id, m_hObserverTarget)
		if (target >= 1 && target <= MaxClients && is_user_connected(target))
		{
			source = target
			if (mode == OBS_IN_EYE) get_entvar(target, var_v_angle, angles)
			else if (mode == OBS_CHASE_LOCKED)
			{
				get_entvar(target, var_angles, angles)
				angles[0] = -angles[0]
			}
		}
	}
	get_entvar(source, var_origin, eye)
	get_entvar(source, var_view_ofs, offset)
	for (new axis = 0; axis < 3; axis++) eye[axis] += offset[axis]
	angle_vector(angles, ANGLEVECTOR_FORWARD, direction)
	if (source != id && (mode == OBS_CHASE_FREE || mode == OBS_CHASE_LOCKED))
	{
		// Chase cameras are client-side; approximate the standard 112-unit offset.
		new Float:end[3]
		get_entvar(source, var_origin, eye)
		eye[2] += 28.0
		for (new axis = 0; axis < 3; axis++) end[axis] = eye[axis]-direction[axis]*112.0
		engfunc(EngFunc_TraceLine, eye, end, IGNORE_MONSTERS, source, gTrace)
		get_tr2(gTrace, TR_vecEndPos, eye)
	}
}

stock bool:admin_nav_in_view(const Float:eye[3], const Float:direction[3], const Float:point[3], &Float:distance_sq)
{
	// Test the vertical marker's center, including its offset above the floor.
	new Float:x = point[0]-eye[0], Float:y = point[1]-eye[1], Float:z = point[2]+NAV_SHOW_LIFT+NAV_SHOW_NODE_HEIGHT*0.5-eye[2]
	distance_sq = x*x+y*y+z*z
	if (distance_sq > NAV_SHOW_RANGE*NAV_SHOW_RANGE) return false
	new Float:depth = x*direction[0]+y*direction[1]+z*direction[2]
	// A broad 120-degree cone includes the floor and screen corners, but never the rear.
	return depth > 0.0 && depth*depth >= distance_sq*NAV_SHOW_CONE_COS*NAV_SHOW_CONE_COS
}

stock show_nodes(const id)
{
	if (!is_user_connected(id) || !gShow[id]) return
	new Float:eye[3], Float:direction[3], Float:point[3], Float:top[3], Float:radius, Float:distance_sq
	new nodes[NAV_SHOW_NODES], Float:distances[NAV_SHOW_NODES], flags, shown, links_shown, count = anpc_nav_count()
	admin_nav_view(id, eye, direction)
	// Select the nearest nodes in front before spending the message budget; IDs do not imply proximity.
	for (new node = 0; node < count; node++)
	{
		if (!anpc_nav_node(node,point,flags,radius) || !admin_nav_in_view(eye,direction,point,distance_sq)) continue
		// The scout keeps temporary discovery samples until finalization. Show the
		// certified interior as an area; special anchors and portals stay visible.
		if (anpc_nav_editing() && radius > 8.0 && !(flags & (ANPC_NODE_LADDER | ANPC_NODE_DISABLED | ANPC_NODE_PORTAL))
		&& anpc_nav_area_at(point) >= 0) continue
		new position = shown
		while (position > 0 && distance_sq < distances[position-1]) position--
		if (position >= NAV_SHOW_NODES) continue
		for (new move = min(shown, NAV_SHOW_NODES-1); move > position; move--)
		{
			nodes[move] = nodes[move-1]
			distances[move] = distances[move-1]
		}
		nodes[position] = node
		distances[position] = distance_sq
		if (shown < NAV_SHOW_NODES) shown++
	}
	new nearest = shown ? nodes[0] : -1
	// Areas are selected independently: an empty interior needs no point to draw.
	new areas[NAV_SHOW_AREAS], Float:area_distances[NAV_SHOW_AREAS], areas_shown
	for (new area = 0, total = anpc_nav_area_count(); area < total; area++)
	{
		new Float:mins[3], Float:maxs[3], Float:normal[3], area_flags
		if (!anpc_nav_area(area,mins,maxs,normal,area_flags)) continue
		new bool:visible, Float:closest = NAV_SHOW_RANGE*NAV_SHOW_RANGE
		for (new sample = 0; sample < 6; sample++)
		{
			point[0] = sample == 5 ? floatclamp(eye[0]+direction[0]*128.0,mins[0],maxs[0]) : sample == 4 ? (mins[0]+maxs[0])*0.5 : sample%2 ? maxs[0] : mins[0]
			point[1] = sample == 5 ? floatclamp(eye[1]+direction[1]*128.0,mins[1],maxs[1]) : sample == 4 ? (mins[1]+maxs[1])*0.5 : sample/2 ? maxs[1] : mins[1]
			point[2] = mins[2]-((point[0]-mins[0])*normal[0]+(point[1]-mins[1])*normal[1])/normal[2]
			if (admin_nav_in_view(eye,direction,point,distance_sq)) { visible = true; closest = floatmin(closest,distance_sq); }
		}
		if (!visible) continue
		new position = areas_shown
		while (position > 0 && closest < area_distances[position-1]) position--
		if (position >= NAV_SHOW_AREAS) continue
		for (new move = min(areas_shown,NAV_SHOW_AREAS-1); move > position; move--)
		{ areas[move] = areas[move-1]; area_distances[move] = area_distances[move-1]; }
		areas[position] = area; area_distances[position] = closest
		if (areas_shown < NAV_SHOW_AREAS) areas_shown++
	}
	for (new index = 0; index < areas_shown; index++)
	{
		new Float:mins[3], Float:maxs[3], Float:normal[3], Float:corner[4][3], area_flags
		if (!anpc_nav_area(areas[index],mins,maxs,normal,area_flags)) continue
		for (new side = 0; side < 4; side++)
		{
			corner[side][0] = side == 1 || side == 2 ? maxs[0] : mins[0]
			corner[side][1] = side >= 2 ? maxs[1] : mins[1]
			corner[side][2] = mins[2]-((corner[side][0]-mins[0])*normal[0]+(corner[side][1]-mins[1])*normal[1])/normal[2]+NAV_SHOW_LIFT
		}
		for (new side = 0; side < 4; side++) admin_beam(id,corner[side],corner[(side+1)%4],40,140,255)
	}
	for (new index = 0; index < shown; index++)
	{
		new node = nodes[index]
		if (!anpc_nav_node(node,point,flags,radius)) continue
		point[2] += NAV_SHOW_LIFT
		anpc_copy_vec(point, top)
		top[2] += NAV_SHOW_NODE_HEIGHT
		admin_beam(id,point,top,flags & ANPC_NODE_DISABLED ? 255 : 40,node == nearest ? 255 : 100,flags & ANPC_NODE_PORTAL ? 255 : 40)
		for (new link = 0, links = anpc_nav_link_count(node); link < links && links_shown < NAV_SHOW_LINKS; link++)
		{
			new to, link_flags, destination_flags, Float:destination[3], Float:velocity[3]
			if (!anpc_nav_link_at(node, link, to, link_flags, velocity) || !anpc_nav_node(to, destination, destination_flags, radius)) continue
			new Float:source[3]
			anpc_copy_vec(point,source); source[2] -= NAV_SHOW_LIFT
			if (!link_flags && !((flags | destination_flags) & ANPC_NODE_LADDER) && anpc_nav_area_segment(source,destination)) continue
			if (!admin_nav_in_view(eye, direction, destination, distance_sq)) continue
			destination[2] += NAV_SHOW_LIFT
			admin_beam(id, point, destination, link_flags ? 220 : 40, 100)
			links_shown++
		}
	}

	set_hudmessage(0, 255, 255, 0.7, 0.4, 0, 0.0, 0.65, 0.05, 0.05)
	ShowSyncHudMsg(id, xMsgSyncANPC, "ANPC: nearest anchor %d^n%s %d^nareas %d/%d",nearest,anpc_nav_editing() ? "scan samples" : "anchors",count,areas_shown,anpc_nav_area_count())
}

public round_freeze_end_post()
{
	if (gAutoSpawn && !anpc_nav_editing() && !anpc_get_count() && !gRecorder) admin_load_spawns(0)
}

public anpc_nav_changed(const revision)
{
	if (!anpc_nav_editing() || !gRecorder) return
	console_print(gRecorder, "[ANPC] Recording stopped: automatic mapper owns navigation.")
	remove_task(TASK_RECORD)
	gRecorder = 0
	gRecordedNode = -1
}

public command_spawns_save(const id, const level, const cid)
{
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	new directory[256], temporary[272]
	get_configsdir(directory, charsmax(directory))
	add(directory, charsmax(directory), "/advanced_npc")
	if (!dir_exists(directory)) mkdir(directory)
	add(directory, charsmax(directory), "/maps")
	if (!dir_exists(directory)) mkdir(directory)
	formatex(temporary, charsmax(temporary), "%s.tmp", gSpawnPath)
	new file = fopen(temporary, "wt")
	if (!file) { console_print(id, "[ANPC] Cannot open spawn file for writing."); return PLUGIN_HANDLED; }
	fprintf(file, "ANPC_SPAWNS 1 ^"%s^" %d %s^n", gMap, gBspSize, gBspHash)
	new entity, count, name[48], Float:feet[3], Float:angles[3]
	while ((entity = rg_find_ent_by_class(entity, ANPC_CLASSNAME)))
	{
		if (!anpc_is_npc(entity) || anpc_get_state(entity) == ANPC_DEAD) continue
		anpc_get_type_name(anpc_get_type(entity), name, charsmax(name))
		anpc_entity_feet(entity, feet)
		get_entvar(entity, var_angles, angles)
		fprintf(file, "S ^"%s^" %.4f %.4f %.4f %.2f^n", name, feet[0], feet[1], feet[2], angles[1])
		count++
	}
	fclose(file)
	console_print(id, "[ANPC] Saved %d spawn points: %d", count, anpc_commit_file(temporary, gSpawnPath))
	return PLUGIN_HANDLED
}

public command_spawns_load(const id, const level, const cid)
{
	if (cmd_access(id, level, cid, 1) && admin_editor_ready(id)) admin_load_spawns(id)
	return PLUGIN_HANDLED
}

stock admin_load_spawns(const id)
{
	new file = fopen(gSpawnPath, "rt")
	if (!file) { console_print(id, "[ANPC] No saved spawn file for %s.", gMap); return; }
	new line[256], token[7][64], bool:header, bool:valid = true, count
	// Validate all records BEFORE creating anything; malformed input cannot
	// leave a half-loaded NPC group.
	new Array:points = ArrayCreate(5), record[5]
	while (!feof(file))
	{
		fgets(file, line, charsmax(line)); trim(line)
		if (!line[0] || line[0] == ';' || line[0] == '#') continue
		new fields = parse(line, token[0],63, token[1],63, token[2],63, token[3],63, token[4],63, token[5],63, token[6],63)
		if (!header)
		{
			valid = fields == 5 && equal(token[0], "ANPC_SPAWNS") && equal(token[1], "1") && equal(token[2], gMap)
			&& anpc_number(token[3], true) && str_to_num(token[3]) == gBspSize && gBspSize > 0
			&& equal(token[4], gBspHash) && strlen(gBspHash) == 32
			header = true
		}
		else
		{
			valid = fields == 6 && equal(token[0], "S") && ArraySize(points) < ANPC_MAX_ACTORS
			record[0] = anpc_find_type(token[1])
			if (record[0] < 0) valid = false
			for (new axis = 1; axis <= 4; axis++)
			{
				new Float:value = str_to_float(token[axis+1])
				if (!anpc_number(token[axis+1]) || !anpc_finite(value)) valid = false
				record[axis] = _:value
			}
			if (valid) ArrayPushArray(points, record)
		}
		if (!valid) break
	}
	fclose(file)
	if (header && valid)
	{
		for (new i = 0, total = ArraySize(points); i < total; i++)
		{
			ArrayGetArray(points, i, record)
			new Float:feet[3]
			for (new axis = 0; axis < 3; axis++) feet[axis] = Float:record[axis+1]
			if (anpc_create(record[0], feet, Float:record[4])) count++
			else log_amx("Spawn point %d failed: navigation, clearance, type or capacity", i)
		}
		console_print(id, "[ANPC] Spawned %d/%d saved NPCs", count, ArraySize(points))
	}
	else log_amx("Invalid spawn file rejected: %s", gSpawnPath)
	ArrayDestroy(points)
}
