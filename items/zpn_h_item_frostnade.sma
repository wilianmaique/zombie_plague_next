#include <amxmodx>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

#define ITEM_UID 29092025
#define IS_CUSTOM_ITEM(%0) (get_entvar(%0, var_impulse) == ITEM_UID)
#define MAX_GRENADE_AMMO 255 // AmmoX transmits the backpack count as one byte.

new const SPRITE_TRAIL[] = "sprites/laserbeam.spr"
new const SPRITE_RING[] = "sprites/shockwave.spr"
new const Float:FROST_COLOR[3] = { 0.0, 150.0, 255.0 }

enum _:eCvars
{
	Float:CVAR_RADIUS,
	Float:CVAR_DURATION,
	CVAR_PLAY_SOUND,
}

enum eFrostBuyBlock
{
	FROST_BUY_ALLOWED = 0,
	FROST_BUY_OTHER_FLASHBANG,
	FROST_BUY_AMMO_FULL,
	FROST_BUY_WEAPON_BUSY,
}

new item, xCvars[eCvars], xTrailSprite, xRingSprite, xRoundSerial

public plugin_init()
{
	register_plugin("[ZPN] Item: Frost Nade", "1.0", "Wilian M.")
	register_dictionary("zpn_items.txt")

	RegisterHookChain(RG_ThrowFlashbang, "Grenade_ThrowFlashbang_Post", true)
	RegisterHookChain(RG_CGrenade_ExplodeFlashbang, "Grenade_ExplodeFlashbang_Pre", false)
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false)

	bind_pcvar_float(create_cvar("zpn_frostnade_radius", "350.0", .description = "Frost grenade freeze radius in game units.", .has_min = true, .min_val = 1.0, .has_max = true, .max_val = 2048.0), xCvars[CVAR_RADIUS])
	bind_pcvar_float(create_cvar("zpn_frostnade_duration", "3.0", .description = "Freeze duration in seconds; another frost grenade refreshes it.", .has_min = true, .min_val = 0.1, .has_max = true, .max_val = 60.0), xCvars[CVAR_DURATION])
	bind_pcvar_num(create_cvar("zpn_frostnade_play_sound", "1", .description = "Play the core's configured frozen-hit sound on affected zombies.", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_PLAY_SOUND])
	AutoExecConfig(true, "zpn_h_item_frostnade", FOLDER_CVARS_CONFIG)
}

public plugin_precache()
{
	xTrailSprite = precache_model(SPRITE_TRAIL)
	xRingSprite = precache_model(SPRITE_RING)

	item = zpn_item_init()
	zpn_item_set_prop(item, PROP_ITEM_REGISTER_TEAM, CLASS_TEAM_TYPE_HUMAN)
	zpn_item_set_prop(item, PROP_ITEM_REGISTER_FIND_NAME, "item_h_frostnade")
	zpn_item_set_prop(item, PROP_ITEM_REGISTER_NAME, "ZPN_ITEM_FROSTNADE")
	zpn_item_set_prop(item, PROP_ITEM_REGISTER_COST, 0)
}

public zpn_item_buy_pre(const id, const item_id, const bool:preview, extra_text[], const maxlen)
{
	if(item_id != item)
		return ZPN_RETURN_CONTINUE

	if(!can_receive_frost_grenade(id))
		return ZPN_RETURN_HANDLED

	new eFrostBuyBlock:reason = get_frost_buy_block(id)
	if(reason == FROST_BUY_ALLOWED)
		return ZPN_RETURN_CONTINUE

	if(preview)
	{
		new key[64]
		switch(reason)
		{
			case FROST_BUY_OTHER_FLASHBANG: copy(key, charsmax(key), "ZPN_ITEM_FROSTNADE_HAS_FLASHBANG")
			case FROST_BUY_AMMO_FULL: copy(key, charsmax(key), "ZPN_ITEM_FROSTNADE_AMMO_FULL")
			case FROST_BUY_WEAPON_BUSY: copy(key, charsmax(key), "ZPN_ITEM_FROSTNADE_WEAPON_BUSY")
		}
		add(extra_text, maxlen, fmt("%L", id, key))
	}
	return ZPN_RETURN_HANDLED
}

public zpn_item_buy_post(const id, const item_id)
{
	if(item_id != item || !can_receive_frost_grenade(id) || get_frost_buy_block(id) != FROST_BUY_ALLOWED)
		return

	new userid = get_user_userid(id), ammo = rg_get_user_bpammo(id, WEAPON_FLASHBANG)
	new weapon = rg_find_weapon_bpack_by_name(id, "weapon_flashbang")
	if(is_nullent(weapon))
		rg_give_custom_item(id, "weapon_flashbang", GT_APPEND, ITEM_UID)
	else
	{
		// Keep the custom weapon/UID and bypass CS's default pickup cap.
		// The items core already enforces the configured purchase limits.
		rg_set_user_bpammo(id, WEAPON_FLASHBANG, ammo + 1)
	}

	if(!zpn_is_valid_player_connected(id) || get_user_userid(id) != userid)
		return

	weapon = rg_find_weapon_bpack_by_name(id, "weapon_flashbang")
	if(is_nullent(weapon) || !IS_CUSTOM_ITEM(weapon) || rg_get_user_bpammo(id, WEAPON_FLASHBANG) != ammo + 1)
		log_amx("[ZPN] Failed to give a frost grenade to client %d", id)
}

bool:can_receive_frost_grenade(const id)
{
	if(!zpn_is_valid_player_alive(id) || zpn_is_user_zombie(id))
		return false

	new class_id = zpn_get_user_current_class(id)
	return 0 <= class_id < zpn_class_array_size()
		&& zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_TYPE) == CLASS_TEAM_TYPE_HUMAN
}

eFrostBuyBlock:get_frost_buy_block(const id)
{
	new weapon = rg_find_weapon_bpack_by_name(id, "weapon_flashbang")
	new ammo = rg_get_user_bpammo(id, WEAPON_FLASHBANG)
	// All flashbang ammo shares one weapon/UID: never convert a normal or
	// another addon's flashbang by merging a frost-grenade purchase into it.
	if((!is_nullent(weapon) && !IS_CUSTOM_ITEM(weapon)) || (is_nullent(weapon) && ammo > 0))
		return FROST_BUY_OTHER_FLASHBANG
	// The last thrown flashbang can leave its empty weapon awaiting destruction.
	if(!is_nullent(weapon) && ammo <= 0)
		return FROST_BUY_WEAPON_BUSY

	if(ammo >= MAX_GRENADE_AMMO)
		return FROST_BUY_AMMO_FULL

	return FROST_BUY_ALLOWED
}

public CSGameRules_RestartRound_Pre()
{
	++xRoundSerial
}

public Grenade_ThrowFlashbang_Post(const this, Float:vecStart[3], Float:vecVelocity[3], Float:time)
{
	if(!IsReapiHookOriginalWasCalled(RG_ThrowFlashbang) || !zpn_is_valid_player_connected(this))
		return

	new grenade = GetHookChainReturn(ATYPE_INTEGER)

	if(is_nullent(grenade))
		return

	new weapon = get_member(this, m_pActiveItem)

	if(is_nullent(weapon) || get_member(weapon, m_iId) != WEAPON_FLASHBANG || !IS_CUSTOM_ITEM(weapon))
		return

	set_entvar(grenade, var_impulse, ITEM_UID)
	set_entvar(grenade, var_iuser3, xRoundSerial)
	set_entvar(grenade, var_iuser4, 0)
	set_entvar(grenade, var_renderfx, kRenderFxGlowShell)
	set_entvar(grenade, var_rendercolor, FROST_COLOR)
	set_entvar(grenade, var_renderamt, 16.0)

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(grenade)
	write_short(xTrailSprite)
	write_byte(10)
	write_byte(10)
	write_byte(0)
	write_byte(150)
	write_byte(255)
	write_byte(200)
	message_end()
}

public Grenade_ExplodeFlashbang_Pre(const this, tracehandle, const bitsDamageType)
{
	if(is_nullent(this) || !IS_CUSTOM_ITEM(this))
		return HC_CONTINUE
	if(get_entvar(this, var_iuser4))
		return HC_SUPERCEDE

	new Float:origin[3]
	get_entvar(this, var_origin, origin)
	new round_serial = get_entvar(this, var_iuser3)

	// Consume before frozen forwards; recursive explosions stay suppressed
	// while ReGameDLL completes the deferred removal.
	set_entvar(this, var_iuser4, 1)
	set_entvar(this, var_effects, get_entvar(this, var_effects) | EF_NODRAW)
	set_entvar(this, var_solid, SOLID_NOT)
	rg_remove_entity(this)

	if(round_serial != xRoundSerial || !zpn_is_round_started() || get_member_game(m_bRoundTerminating))
		return HC_SUPERCEDE

	new Float:radius = xCvars[CVAR_RADIUS], Float:duration = xCvars[CVAR_DURATION]
	new bool:play_sound = xCvars[CVAR_PLAY_SOUND] != 0
	create_frost_explosion(origin, radius)

	new Float:target_origin[3]
	for(new target = 1; target <= MaxClients; target++)
	{
		if(round_serial != xRoundSerial || !zpn_is_round_started() || get_member_game(m_bRoundTerminating))
			break
		if(!zpn_is_valid_player_alive(target) || !zpn_is_user_zombie(target))
			continue

		get_entvar(target, var_origin, target_origin)
		if(vector_distance(origin, target_origin) > radius)
			continue

		zpn_set_user_frozen(target, duration, true, play_sound)
	}

	return HC_SUPERCEDE
}

create_frost_explosion(const Float:origin[3], const Float:radius)
{
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_BEAMCYLINDER)
	write_coord_f(origin[0])
	write_coord_f(origin[1])
	write_coord_f(origin[2] + 8.0)
	write_coord_f(origin[0])
	write_coord_f(origin[1])
	write_coord_f(origin[2] + 8.0 + radius)
	write_short(xRingSprite)
	write_byte(0) // starting frame
	write_byte(0) // framerate
	write_byte(5) // lifetime
	write_byte(40) // width
	write_byte(0) // noise
	write_byte(0)
	write_byte(150)
	write_byte(255)
	write_byte(200)
	write_byte(0) // scroll speed
	message_end()

	message_begin_f(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_DLIGHT)
	write_coord_f(origin[0])
	write_coord_f(origin[1])
	write_coord_f(origin[2] + 8.0)
	write_byte(clamp(floatround(radius / 10.0), 1, 255))
	write_byte(0)
	write_byte(150)
	write_byte(255)
	write_byte(5)
	write_byte(50)
	message_end()
}
