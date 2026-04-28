#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <xs>

#define INVALID_FORWARD -1

new const camera_model[] = "models/rpgrocket.mdl"
new const camera_classname[] = "zpn_camera"

new const Float:camera_distance = 128.0
new const Float:camera_side_distance = 32.0
new const Float:camera_side_offset = 15.0
new const Float:camera_top_distance = 128.0

enum _:eCameraMode
{
	CAMERA_MODE_NONE = 0,
	CAMERA_MODE_THIRD_PERSON,
	CAMERA_MODE_SIDE,
	CAMERA_MODE_TOP,
	CAMERA_MODE_FRONT
}

enum _:ePlayerCamera
{
	PLAYER_CAMERA_ENTITY,
	PLAYER_CAMERA_MODE
}

enum _:eCameraForward
{
	FORWARD_ADD_TO_FULL_PACK,
	FORWARD_PLAYER_POST_THINK
}

new player_camera[MAX_PLAYERS + 1][ePlayerCamera]
new camera_forward[eCameraForward] = { INVALID_FORWARD, INVALID_FORWARD }
new active_cameras

public amx_addon_camera_users

public plugin_precache()
{
	precache_model(camera_model)
}

public plugin_init()
{
	register_plugin("AMXX Camera", "1.1", "Vexd | Wilian M.")

	register_clcmd("say /cam", "command_camera_menu")
	register_clcmd("say /camera", "command_camera_menu")
	register_clcmd("say_team /cam", "command_camera_menu")
	register_clcmd("say_team /camera", "command_camera_menu")
}

public plugin_end()
{
	for(new id = 1; id <= MaxClients; id++)
		clear_player_camera(id)

	disable_camera_forwards()
}

public client_putinserver(id)
{
	reset_player_camera_data(id)
}

public client_disconnected(id)
{
	clear_player_camera(id)
}

public command_camera_menu(const id)
{
	show_camera_menu(id)
	return PLUGIN_HANDLED
}

show_camera_menu(const id)
{
	new menu = menu_create("\ySelecione uma camera", "camera_menu_handler")

	menu_additem(menu, "Camera 3D", "1")
	menu_additem(menu, "Camera 3D de lado", "2")
	menu_additem(menu, "Camera 3D de cima", "3")
	menu_additem(menu, "Camera 3D de frente", "4")
	menu_additem(menu, "Camera padrao", "0")

	menu_setprop(menu, MPROP_EXITNAME, "Cancelar")
	menu_display(id, menu)
}

public camera_menu_handler(const id, const menu, const item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new info[4]
	menu_item_getinfo(menu, item, _, info, charsmax(info))

	set_player_camera_mode(id, str_to_num(info))
	menu_destroy(menu)

	return PLUGIN_HANDLED
}

set_player_camera_mode(const id, const mode)
{
	if(!is_player_index(id))
		return 0

	if(mode == CAMERA_MODE_NONE)
	{
		clear_player_camera(id)
		return 1
	}

	if(!is_valid_camera_mode(mode))
		return 0

	if(player_camera[id][PLAYER_CAMERA_MODE] != CAMERA_MODE_NONE)
	{
		player_camera[id][PLAYER_CAMERA_MODE] = mode
		set_user_camera_state(id, true)
		return 1
	}

	new camera = create_player_camera(id)

	if(is_nullent(camera))
	{
		set_user_camera_state(id, false)
		return 0
	}

	player_camera[id][PLAYER_CAMERA_ENTITY] = camera
	player_camera[id][PLAYER_CAMERA_MODE] = mode
	active_cameras++

	enable_camera_forwards()
	set_user_camera_state(id, true)

	return 1
}

create_player_camera(const id)
{
	new camera = rg_create_entity("info_target")

	if(is_nullent(camera))
		return 0

	set_entvar(camera, var_classname, camera_classname)
	engfunc(EngFunc_SetModel, camera, camera_model)
	engfunc(EngFunc_SetSize, camera, Float:{ 0.0, 0.0, 0.0 }, Float:{ 0.0, 0.0, 0.0 })

	set_entvar(camera, var_movetype, MOVETYPE_NOCLIP)
	set_entvar(camera, var_solid, SOLID_NOT)
	set_entvar(camera, var_takedamage, 0.0)
	set_entvar(camera, var_gravity, 0.0)
	set_entvar(camera, var_owner, id)
	set_entvar(camera, var_rendermode, kRenderTransColor)
	set_entvar(camera, var_renderamt, 0.0)
	set_entvar(camera, var_renderfx, kRenderFxNone)

	engfunc(EngFunc_SetView, id, camera)

	return camera
}

clear_player_camera(const id)
{
	if(!is_player_index(id))
		return

	new previous_mode = player_camera[id][PLAYER_CAMERA_MODE]

	if(is_user_connected(id))
		engfunc(EngFunc_SetView, id, id)

	remove_player_camera_entity(id)
	reset_player_camera_data(id)

	if(previous_mode != CAMERA_MODE_NONE)
		release_active_camera()
}

remove_player_camera_entity(const id)
{
	new camera = player_camera[id][PLAYER_CAMERA_ENTITY]

	if(!is_nullent(camera))
		rg_remove_entity(camera)

	player_camera[id][PLAYER_CAMERA_ENTITY] = 0
}

reset_player_camera_data(const id)
{
	if(!is_player_index(id))
		return

	player_camera[id][PLAYER_CAMERA_ENTITY] = 0
	player_camera[id][PLAYER_CAMERA_MODE] = CAMERA_MODE_NONE
	set_user_camera_state(id, false)
}

enable_camera_forwards()
{
	if(camera_forward[FORWARD_ADD_TO_FULL_PACK] == INVALID_FORWARD)
		camera_forward[FORWARD_ADD_TO_FULL_PACK] = register_forward(FM_AddToFullPack, "@AddToFullPack_Post", true)

	if(camera_forward[FORWARD_PLAYER_POST_THINK] == INVALID_FORWARD)
		camera_forward[FORWARD_PLAYER_POST_THINK] = register_forward(FM_PlayerPostThink, "@PlayerPostThink_Post", true)
}

disable_camera_forwards()
{
	if(camera_forward[FORWARD_ADD_TO_FULL_PACK] != INVALID_FORWARD)
	{
		unregister_forward(FM_AddToFullPack, camera_forward[FORWARD_ADD_TO_FULL_PACK], true)
		camera_forward[FORWARD_ADD_TO_FULL_PACK] = INVALID_FORWARD
	}

	if(camera_forward[FORWARD_PLAYER_POST_THINK] != INVALID_FORWARD)
	{
		unregister_forward(FM_PlayerPostThink, camera_forward[FORWARD_PLAYER_POST_THINK], true)
		camera_forward[FORWARD_PLAYER_POST_THINK] = INVALID_FORWARD
	}
}

release_active_camera()
{
	if(active_cameras > 0)
		active_cameras--

	if(!active_cameras)
		disable_camera_forwards()
}

@AddToFullPack_Post(const es_handle, const e, const ent, const host, const hostflags, const player, const pset)
{
	if(!ent || !host)
		return FMRES_IGNORED

	if(player && ent != host && player_camera[ent][PLAYER_CAMERA_MODE] != CAMERA_MODE_NONE)
	{
		set_es(es_handle, ES_RenderMode, kRenderTransTexture)
		set_es(es_handle, ES_RenderAmt, 100.0)
	}

	return FMRES_IGNORED
}

@PlayerPostThink_Post(const id)
{
	if(!is_player_index(id) || player_camera[id][PLAYER_CAMERA_MODE] == CAMERA_MODE_NONE)
		return FMRES_IGNORED

	new camera = player_camera[id][PLAYER_CAMERA_ENTITY]

	if(is_nullent(camera))
	{
		clear_player_camera(id)
		return FMRES_IGNORED
	}

	update_player_camera(id, camera)

	return FMRES_IGNORED
}

update_player_camera(const id, const camera)
{
	static Float:view_angle[3], Float:punch_angle[3], Float:aim_angle[3]
	static Float:origin[3], Float:view_offset[3], Float:source[3]
	static Float:aim_forward[3], Float:aim_right[3], Float:aim_up[3]
	static Float:destination[3], Float:end_position[3], Float:camera_angle[3]

	get_entvar(id, var_v_angle, view_angle)
	get_entvar(id, var_punchangle, punch_angle)
	xs_vec_add(view_angle, punch_angle, aim_angle)

	engfunc(EngFunc_MakeVectors, aim_angle)

	get_entvar(id, var_origin, origin)
	get_entvar(id, var_view_ofs, view_offset)
	xs_vec_add(origin, view_offset, source)

	global_get(glb_v_forward, aim_forward)
	copy_vector(view_angle, camera_angle)

	new trace_flags = IGNORE_MONSTERS

	switch(player_camera[id][PLAYER_CAMERA_MODE])
	{
		case CAMERA_MODE_THIRD_PERSON:
		{
			xs_vec_sub_scaled(source, aim_forward, camera_distance, destination)
		}
		case CAMERA_MODE_SIDE:
		{
			global_get(glb_v_right, aim_right)
			global_get(glb_v_up, aim_up)

			for(new i = 0; i < 3; i++)
				destination[i] = source[i] - (aim_forward[i] * camera_side_distance) + (aim_right[i] * camera_side_offset) + (aim_up[i] * camera_side_offset)
		}
		case CAMERA_MODE_TOP:
		{
			destination[0] = source[0]
			destination[1] = source[1]
			destination[2] = source[2] + camera_top_distance

			camera_angle[0] = 90.0
			camera_angle[2] = 0.0
			trace_flags = DONT_IGNORE_MONSTERS
		}
		case CAMERA_MODE_FRONT:
		{
			xs_vec_add_scaled(source, aim_forward, camera_distance, destination)

			camera_angle[0] = -camera_angle[0]
			camera_angle[1] -= 180.0
			camera_angle[2] = 0.0
		}
		default:
		{
			clear_player_camera(id)
			return
		}
	}

	new trace = create_tr2()

	engfunc(EngFunc_TraceLine, source, destination, trace_flags, id, trace)
	get_tr2(trace, TR_vecEndPos, end_position)
	free_tr2(trace)

	engfunc(EngFunc_SetView, id, camera)
	set_entvar(camera, var_origin, end_position)
	set_entvar(camera, var_angles, camera_angle)
}

bool:is_valid_camera_mode(const mode)
{
	return (CAMERA_MODE_THIRD_PERSON <= mode <= CAMERA_MODE_FRONT)
}

bool:is_player_index(const id)
{
	return (1 <= id <= MaxClients)
}

copy_vector(const Float:source[3], Float:destination[3])
{
	destination[0] = source[0]
	destination[1] = source[1]
	destination[2] = source[2]
}

set_user_camera_state(const id, const bool:enabled)
{
	if(!is_player_index(id))
		return

	new bit = 1 << (id - 1)

	if(enabled)
		amx_addon_camera_users |= bit
	else
		amx_addon_camera_users &= ~bit
}
