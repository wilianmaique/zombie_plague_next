#include <amxmodx>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

#define ITEM_UID 31102026
#define IS_CUSTOM_ITEM(%0) (get_entvar(%0, var_impulse) == ITEM_UID)
#define MAX_GRENADE_AMMO 255 // AmmoX transmits the backpack count as one byte.

new const SPRITE_TRAIL[] = "sprites/laserbeam.spr"
new const SPRITE_EXPLOSION[] = "sprites/zerogxplode.spr"
new const Float:FIRE_COLOR[3] = { 255.0, 100.0, 0.0 }

enum _:eCvars
{
	Float:CVAR_RADIUS,
	Float:CVAR_DURATION,
	Float:CVAR_DAMAGE,
	Float:CVAR_SLOWDOWN,
	CVAR_CAN_KILL,
}

enum eFireBuyBlock
{
	FIRE_BUY_ALLOWED = 0,
	FIRE_BUY_OTHER_HEGRENADE,
	FIRE_BUY_AMMO_FULL,
	FIRE_BUY_WEAPON_BUSY,
}

new item, xCvars[eCvars], xTrailSprite, xExplosionSprite, xRoundSerial

public plugin_init()
{
	register_plugin("[ZPN] Item: Fire Nade", "1.0", "Wilian M.")
	register_dictionary("zpn_items.txt")

	RegisterHookChain(RG_ThrowHeGrenade, "Grenade_ThrowHeGrenade_Post", true)
	RegisterHookChain(RG_CGrenade_ExplodeHeGrenade, "Grenade_ExplodeHeGrenade_Pre", false)
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false)

	bind_pcvar_float(create_cvar("zpn_firenade_radius", "350.0", .description = "Fire grenade ignition radius in game units.", .has_min = true, .min_val = 1.0, .has_max = true, .max_val = 2048.0), xCvars[CVAR_RADIUS])
	bind_pcvar_float(create_cvar("zpn_firenade_duration", "5.0", .description = "Flame duration in seconds; another fire grenade refreshes it.", .has_min = true, .min_val = 0.1, .has_max = true, .max_val = 3600.0), xCvars[CVAR_DURATION])
	bind_pcvar_float(create_cvar("zpn_firenade_damage", "5.0", .description = "Flame damage per 0.2-second tick; 0 disables damage.", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1000000.0), xCvars[CVAR_DAMAGE])
	bind_pcvar_float(create_cvar("zpn_firenade_slowdown", "0.5", .description = "Continuous grounded normal-zombie maxspeed multiplier; 0 uses 1 unit/s, 1 disables slowdown.", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_SLOWDOWN])
	bind_pcvar_num(create_cvar("zpn_firenade_can_kill", "0", .description = "Allow flame damage to kill the victim.", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_CAN_KILL])
	AutoExecConfig(true, "zpn_h_item_firenade", FOLDER_CVARS_CONFIG)
}

public plugin_precache()
{
	xTrailSprite = precache_model(SPRITE_TRAIL)
	xExplosionSprite = precache_model(SPRITE_EXPLOSION)

	item = zpn_item_init()
	zpn_item_set_prop(item, PROP_ITEM_REGISTER_TEAM, CLASS_TEAM_TYPE_HUMAN)
	zpn_item_set_prop(item, PROP_ITEM_REGISTER_FIND_NAME, "item_h_firenade")
	zpn_item_set_prop(item, PROP_ITEM_REGISTER_NAME, "ZPN_ITEM_FIRENADE")
	zpn_item_set_prop(item, PROP_ITEM_REGISTER_COST, 0)
}

public zpn_item_buy_pre(const id, const item_id, const bool:preview, extra_text[], const maxlen)
{
	if(item_id != item)
		return ZPN_RETURN_CONTINUE

	if(!can_receive_fire_grenade(id))
		return ZPN_RETURN_HANDLED

	new eFireBuyBlock:reason = get_fire_buy_block(id)
	if(reason == FIRE_BUY_ALLOWED)
		return ZPN_RETURN_CONTINUE

	if(preview)
	{
		new key[64]
		switch(reason)
		{
			case FIRE_BUY_OTHER_HEGRENADE: copy(key, charsmax(key), "ZPN_ITEM_FIRENADE_HAS_HEGRENADE")
			case FIRE_BUY_AMMO_FULL: copy(key, charsmax(key), "ZPN_ITEM_FIRENADE_AMMO_FULL")
			case FIRE_BUY_WEAPON_BUSY: copy(key, charsmax(key), "ZPN_ITEM_FIRENADE_WEAPON_BUSY")
		}
		add(extra_text, maxlen, fmt("%L", id, key))
	}
	return ZPN_RETURN_HANDLED
}

public zpn_item_buy_post(const id, const item_id)
{
	if(item_id != item)
		return

	// Recheck after purchase forwards, which can change the player/inventory.
	if(!can_receive_fire_grenade(id) || get_fire_buy_block(id) != FIRE_BUY_ALLOWED)
		return

	new userid = get_user_userid(id), ammo = rg_get_user_bpammo(id, WEAPON_HEGRENADE)
	new weapon = rg_find_weapon_bpack_by_name(id, "weapon_hegrenade")
	if(is_nullent(weapon))
		rg_give_custom_item(id, "weapon_hegrenade", GT_APPEND, ITEM_UID)
	else
	{
		// Keep the custom weapon/UID and bypass CS's default pickup cap.
		// The items core already enforces the configured purchase limits.
		rg_set_user_bpammo(id, WEAPON_HEGRENADE, ammo + 1)
	}

	if(!zpn_is_valid_player_connected(id) || get_user_userid(id) != userid)
		return

	weapon = rg_find_weapon_bpack_by_name(id, "weapon_hegrenade")
	if(is_nullent(weapon) || !IS_CUSTOM_ITEM(weapon) || rg_get_user_bpammo(id, WEAPON_HEGRENADE) != ammo + 1)
		log_amx("[ZPN] Failed to give a fire grenade to client %d", id)
}

bool:can_receive_fire_grenade(const id)
{
	if(!zpn_is_valid_player_alive(id) || zpn_is_user_zombie(id))
		return false

	new class_id = zpn_get_user_current_class(id)
	return 0 <= class_id < zpn_class_array_size()
		&& zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_TYPE) == CLASS_TEAM_TYPE_HUMAN
}

eFireBuyBlock:get_fire_buy_block(const id)
{
	new weapon = rg_find_weapon_bpack_by_name(id, "weapon_hegrenade")
	new ammo = rg_get_user_bpammo(id, WEAPON_HEGRENADE)
	// HE ammo shares one weapon/UID; do not turn another grenade into a fire nade.
	if((!is_nullent(weapon) && !IS_CUSTOM_ITEM(weapon)) || (is_nullent(weapon) && ammo > 0))
		return FIRE_BUY_OTHER_HEGRENADE
	// An empty grenade weapon may already be scheduled for destruction.
	if(!is_nullent(weapon) && ammo <= 0)
		return FIRE_BUY_WEAPON_BUSY

	if(ammo >= MAX_GRENADE_AMMO)
		return FIRE_BUY_AMMO_FULL

	return FIRE_BUY_ALLOWED
}

public CSGameRules_RestartRound_Pre()
{
	++xRoundSerial
}

public Grenade_ThrowHeGrenade_Post(const this, Float:vecStart[3], Float:vecVelocity[3], Float:time, const team, const usEvent)
{
	if(!IsReapiHookOriginalWasCalled(RG_ThrowHeGrenade) || !zpn_is_valid_player_connected(this))
		return

	new grenade = GetHookChainReturn(ATYPE_INTEGER)
	if(is_nullent(grenade))
		return

	new weapon = get_member(this, m_pActiveItem)
	if(is_nullent(weapon) || get_member(weapon, m_iId) != WEAPON_HEGRENADE || !IS_CUSTOM_ITEM(weapon))
		return

	set_entvar(grenade, var_impulse, ITEM_UID)
	set_entvar(grenade, var_iuser1, this)
	set_entvar(grenade, var_iuser2, get_user_userid(this))
	set_entvar(grenade, var_iuser3, xRoundSerial)
	set_entvar(grenade, var_iuser4, 0)
	set_entvar(grenade, var_renderfx, kRenderFxGlowShell)
	set_entvar(grenade, var_rendercolor, FIRE_COLOR)
	set_entvar(grenade, var_renderamt, 16.0)

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(grenade)
	write_short(xTrailSprite)
	write_byte(10) // life in 0.1 seconds
	write_byte(10) // width in 0.1 units
	write_byte(255)
	write_byte(100)
	write_byte(0)
	write_byte(200)
	message_end()
}

public Grenade_ExplodeHeGrenade_Pre(const this, tracehandle, const bitsDamageType)
{
	if(is_nullent(this) || !IS_CUSTOM_ITEM(this))
		return HC_CONTINUE

	if(get_entvar(this, var_iuser4))
		return HC_SUPERCEDE

	new Float:origin[3]
	get_entvar(this, var_origin, origin)
	new thrower = get_entvar(this, var_iuser1), userid = get_entvar(this, var_iuser2)
	new round_serial = get_entvar(this, var_iuser3)
	new bool:underwater = get_entvar(this, var_waterlevel) > 0

	// Consume before calling flame forwards. Keep the UID so a recursive
	// explosion is still suppressed while ReGameDLL defers entity removal.
	set_entvar(this, var_iuser4, 1)
	set_entvar(this, var_effects, get_entvar(this, var_effects) | EF_NODRAW)
	set_entvar(this, var_solid, SOLID_NOT)
	rg_remove_entity(this)

	if(underwater || round_serial != xRoundSerial || !zpn_is_round_started() || get_member_game(m_bRoundTerminating))
		return HC_SUPERCEDE

	create_fire_explosion(origin)

	// Snapshot the settings so every target in this explosion receives the
	// same request, even when an addon changes cvars from a flame forward.
	new Float:radius = xCvars[CVAR_RADIUS], Float:duration = xCvars[CVAR_DURATION]
	new Float:damage = xCvars[CVAR_DAMAGE], Float:slowdown = xCvars[CVAR_SLOWDOWN]
	new bool:can_kill = xCvars[CVAR_CAN_KILL] != 0
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

		// A disconnected/reused thrower slot is world damage, never a new client.
		new attacker = zpn_is_valid_player_connected(thrower) && get_user_userid(thrower) == userid ? thrower : 0
		zpn_set_user_flame(target, duration, attacker, damage, slowdown, true, can_kill)
	}

	return HC_SUPERCEDE
}

create_fire_explosion(const Float:origin[3])
{
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_EXPLOSION)
	write_coord_f(origin[0])
	write_coord_f(origin[1])
	write_coord_f(origin[2] + 8.0)
	write_short(xExplosionSprite)
	write_byte(30) // scale in 0.1 units
	write_byte(20) // animation framerate
	write_byte(0) // standard client explosion light, particles and sound
	message_end()
}
