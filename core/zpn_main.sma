#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <zombie_plague_next>
#include <api_json_settings>
#include <cstrike>

#define wm_is_valid_player_alive(%1) (1 <= %1 <= MaxClients && is_user_alive(%1) && is_user_connected(%1))
#define wm_is_valid_player_connected(%1) (1 <= %1 <= MaxClients && is_user_connected(%1))
#define wm_is_valid_player(%1) (1 <= %1 <= MaxClients)

enum
{
	TASK_COUNTDOWN = 1515,
}

enum _:eCvars
{
	CVAR_START_DELAY,
	CVAR_LAST_HUMAN_INFECT,
}

enum _:eSettingsConfigsNames
{
	CONFIG_DEBUG_ON,
	CONFIG_ZOMBIE_ESCAPE_ON,
	CONFIG_DEFAULT_HUMAN_MODEL[32],
	CONFIG_PREFIX_MENUS[32],
	CONFIG_PREFIX_CHAT[32],
}

enum _:ePropsClass
{
	CLASS_PROP_TYPE,
	CLASS_PROP_NAME[64],
	CLASS_PROP_INFO[64],
	CLASS_PROP_MODEL[64],
	CLASS_PROP_MODEL_VIEW[64],
	Float:CLASS_PROP_HEALTH,
	CLASS_PROP_SPEED,
	Float:CLASS_PROP_GRAVITY,
	Float:CLASS_PROP_KNOCKBACK,
	CLASS_PROP_CLAW_WEAPONLIST[64],
}

enum _:ePropsGameMode
{
	GAMEMODE_PROP_NAME[32],
	GAMEMODE_PROP_NOTICE[64],
	GAMEMODE_PROP_HUD_COLOR[3],
	GAMEMODE_PROP_CHANCE,
	GAMEMODE_PROP_MIN_ALIVES,
	Float:GAMEMODE_PROP_ROUND_TIME,
	bool:GAMEMODE_PROP_CHANGE_CLASS,
	eGameModeDeathMatchType:GAMEMODE_PROP_DEATHMATCH
}

enum _:eGameRule
{
	GAME_RULES_CURRENT_MODE,
	bool:GAME_RULES_IS_ROUND_STARTED,
	GAME_RULES_COUNTDOWN,
	Array:GAME_RULES_USELESS_ENTITIES,
	Array:GAME_RULES_PRIMARY_WEAPONS,
	Array:GAME_RULES_SECONDARY_WEAPONS,
}

enum _:eUserData
{
	bool:UD_HAS_SELECTED_ZOMBIE_CLASS,
	bool:UD_HAS_SELECTED_HUMAN_CLASS,
	UD_CURRENT_ZOMBIE_CLASS,
	UD_CURRENT_HUMAN_CLASS,
	bool:UD_IS_ZOMBIE,
	UD_PRIMARY_WEAPON,
	UD_SECONDARY_WEAPON,
}

enum _:eSyncHuds
{
	SYNC_HUD_MAIN
}

new const CS_SOUNDS[][] = { "items/flashlight1.wav", "items/9mmclip1.wav", "player/bhit_helmet-1.wav" };

new xFwSpawn_Pre
new xCvars[eCvars], xSettingsVars[eSettingsConfigsNames], xMsgSync[eSyncHuds], xUserData[33][eUserData]
new any:xDataGetClass[ePropsClass], any:xDataGetGameMode[ePropsGameMode], any:xDataGetGameRule[eGameRule]

new xDataClassCount, xDataGameModeCount
new Array:aDataClass, Array:aDataGameMode

public plugin_init()
{
	register_plugin("Zombie Plague Next", "1.0", "Wilian M.")

	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false)
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "CSGameRules_OnRoundFreezeEnd_Pre", false)
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy_Pre", false)
	RegisterHookChain(RG_RoundEnd, "RoundEnd_Pre", false)
	RegisterHookChain(RG_CBasePlayer_TraceAttack, "CBasePlayer_TraceAttack_Pre", false)
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre", false)

	for(new i = 0; i < eSyncHuds; i++)
		xMsgSync[i] = CreateHudSyncObj()

	if(zpn_is_invalid_array(aDataClass))
		return set_fail_state("[ZP NEXT] No zombie classes founds")

	if(zpn_is_invalid_array(aDataGameMode))
		return set_fail_state("[ZP NEXT] No gamemodes founds")

	register_dictionary("common.txt")

	RegisterHam(Ham_Touch, "weaponbox", "xHamTouch_Pre", false)
	RegisterHam(Ham_Touch, "armoury_entity", "xHamTouch_Pre", false)
	RegisterHam(Ham_Touch, "weapon_shield", "xHamTouch_Pre", false)

	register_clcmd("chooseteam", "clcmd_changeteam")
	register_clcmd("jointeam", "clcmd_changeteam")

	if (xFwSpawn_Pre)
		unregister_forward(FM_Spawn, xFwSpawn_Pre, false)

	if(xSettingsVars[CONFIG_DEBUG_ON])
	{
		server_print("^n")
		server_print("Classes loaded:")
		new i
		new dataC[ePropsClass]
		for(i = 0; i < ArraySize(aDataClass); i++)
		{
			ArrayGetArray(aDataClass, i, dataC)
			server_print("-> Class: %s | Info: %s | Model: %s | Model View: %s", dataC[CLASS_PROP_NAME], dataC[CLASS_PROP_INFO], dataC[CLASS_PROP_MODEL], dataC[CLASS_PROP_MODEL_VIEW])
		}

		server_print("^n")
		server_print("GameModes loaded:")
		
		new dataG[ePropsGameMode]
		for(i = 0; i < ArraySize(aDataGameMode); i++)
		{
			ArrayGetArray(aDataGameMode, i, dataG)
			server_print("-> GameMode: %s | Chance: %d | Min Alives: %d | Round Time: %0.1f", dataG[GAMEMODE_PROP_NAME], dataG[GAMEMODE_PROP_CHANCE], dataG[GAMEMODE_PROP_MIN_ALIVES], dataG[GAMEMODE_PROP_ROUND_TIME])
		}

		server_print("^n")
	}

	return true
}

public CBasePlayer_TakeDamage_Pre(const this, pevInflictor, pevAttacker, Float:flDamage, bitsDamageType)
{
	if(this == pevAttacker || !wm_is_valid_player_alive(pevAttacker) || !wm_is_valid_player_alive(this))
		return HC_CONTINUE

	if(xUserData[pevAttacker][UD_IS_ZOMBIE] && !xUserData[this][UD_IS_ZOMBIE])
	{
		if(get_num_humans_alive() == 1 && !xCvars[CVAR_LAST_HUMAN_INFECT])
			return HC_CONTINUE

		static Float:armor
		get_entvar(this, var_armorvalue, armor)

		if(armor > 0.0)
		{
			emit_sound(this, CHAN_BODY, CS_SOUNDS[2], 1.0, 0.5, 0, PITCH_NORM)
			
			if(armor - flDamage > 0.0)
				set_entvar(this, var_armorvalue, armor - flDamage)
			else rg_set_user_armor(this, 0, ARMOR_NONE)

			SetHookChainReturn(ATYPE_INTEGER, 0)
			return HC_SUPERCEDE
		}

		set_user_zombie(this, pevAttacker)

		if(get_num_humans_alive() == 0 && xCvars[CVAR_LAST_HUMAN_INFECT])
		{
			rg_round_end(2.0, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN, .trigger = true)

			if(xSettingsVars[CONFIG_DEBUG_ON])
				server_print("^nrg_round_end(2.0, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN, .trigger = true)")
		}
	}

	return HC_CONTINUE
}

public CBasePlayer_TraceAttack_Pre(const this, pevAttacker, Float:flDamage, Float:vecDir[3], tracehandle, bitsDamageType)
{
	if(this == pevAttacker)
		return
	
}

public clcmd_changeteam(id)
{
	new any:team = get_member(id, m_iTeam)

	if(team == TEAM_SPECTATOR || team == TEAM_UNASSIGNED)
		return PLUGIN_CONTINUE

	show_menu_game(id)

	return PLUGIN_HANDLED
}

public client_putinserver(id)
{
	reset_user_vars(id)
}

public show_menu_game(id)
{
	new xFmtx[128], xMenu
	formatex(xFmtx, charsmax(xFmtx), "\yZombie Plague Next")

	xMenu = menu_create(xFmtx, "_show_menu_game")

	menu_additem(xMenu, "Armas")
	menu_additem(xMenu, "Loja")
	menu_additem(xMenu, "Classes De Zombie")

	menu_setprop(xMenu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
	menu_setprop(xMenu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
	menu_setprop(xMenu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))
	menu_display(id, xMenu)
}

public _show_menu_game(id, menu, item)
{
	if(!is_user_connected(id))
		return

	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return
	}

	//menu_item_getinfo(menu, item)
	
	switch(item)
	{
		case 0:
		{
			xUserData[id][UD_PRIMARY_WEAPON] = -1
			xUserData[id][UD_SECONDARY_WEAPON] = -1
			select_primary_weapon(id)
		}
	}
}

public reset_user_vars(id)
{
	xUserData[id][UD_IS_ZOMBIE] = false
	xUserData[id][UD_HAS_SELECTED_ZOMBIE_CLASS] = false
	xUserData[id][UD_HAS_SELECTED_HUMAN_CLASS] = false
	xUserData[id][UD_CURRENT_ZOMBIE_CLASS] = 0
	xUserData[id][UD_CURRENT_HUMAN_CLASS] = 0
	xUserData[id][UD_PRIMARY_WEAPON] = -1
	xUserData[id][UD_SECONDARY_WEAPON] = -1
}

public RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event, Float:delay)
{
	xDataGetGameRule[GAME_RULES_IS_ROUND_STARTED] = false

	if(zpn_is_invalid_array(aDataGameMode))
		xDataGetGameRule[GAME_RULES_CURRENT_MODE] = -1
	else xDataGetGameRule[GAME_RULES_CURRENT_MODE] = 0

	if(xSettingsVars[CONFIG_DEBUG_ON])
		server_print("RoundEnd_Pre: %d - %d - %f", status, event, delay)
}

public CBasePlayerWeapon_DefaultDeploy_Pre(const ent, szViewModel[], szWeaponModel[], iAnim, szAnimExt[], skiplocal)
{
	if(is_nullent(ent))
		return

	new id = get_member(ent, m_pPlayer)
	
	if(xUserData[id][UD_IS_ZOMBIE])
	{
		ArrayGetArray(aDataClass, xUserData[id][UD_CURRENT_ZOMBIE_CLASS], xDataGetClass)
		SetHookChainArg(2, ATYPE_STRING, xDataGetClass[CLASS_PROP_MODEL_VIEW])
		SetHookChainArg(3, ATYPE_STRING, "")

		if(xSettingsVars[CONFIG_DEBUG_ON])
		{
			if(xUserData[id][UD_IS_ZOMBIE])
				server_print("CBasePlayerWeapon_DefaultDeploy_Pre - %n - é zombie", id)
		}
		
	}

	if(xSettingsVars[CONFIG_DEBUG_ON])
	{
		server_print("^n")
		server_print("CBasePlayerWeapon_DefaultDeploy_Pre: %n - %s - %s - %d - %s - %d", id, szViewModel, szWeaponModel, iAnim, szAnimExt, skiplocal)
	}
}

public CBasePlayer_Spawn_Post(id)
{
	if(!wm_is_valid_player_alive(id))
		return

	new TeamName:team = get_member(id, m_iTeam)

	if(team != TEAM_TERRORIST && team != TEAM_CT)
		return
	
	if(xSettingsVars[CONFIG_DEBUG_ON])
	{
		if(xUserData[id][UD_IS_ZOMBIE])
			server_print("CBasePlayer_Spawn_Post - %n - é zombie", id)

		server_print("CBasePlayer_Spawn_Post(id) ---> %n", id)
	}

	if(!xDataGetGameRule[GAME_RULES_IS_ROUND_STARTED] && team != TEAM_CT)
	{
		//xUserData[id][UD_IS_ZOMBIE] = false
		//rg_set_user_model(id, xSettingsVars[CONFIG_DEFAULT_HUMAN_MODEL])
		//rg_set_user_team(id, TEAM_CT)
		deploy_weapon(id)

		if(xSettingsVars[CONFIG_DEBUG_ON])
		{
			server_print("^n")
			server_print("Dentro: !xDataGetGameRule[GAME_RULES_IS_ROUND_STARTED")
		}
	}

	if(xUserData[id][UD_PRIMARY_WEAPON] == -1 && !xUserData[id][UD_IS_ZOMBIE])
		select_primary_weapon(id)
	else if(xUserData[id][UD_PRIMARY_WEAPON] != -1)
	{
		get_selected_weapon(id, xDataGetGameRule[GAME_RULES_PRIMARY_WEAPONS], xUserData[id][UD_PRIMARY_WEAPON], PRIMARY_WEAPON_SLOT)

		if(xUserData[id][UD_PRIMARY_WEAPON] != -1)
			get_selected_weapon(id, xDataGetGameRule[GAME_RULES_SECONDARY_WEAPONS], xUserData[id][UD_SECONDARY_WEAPON], PISTOL_SLOT)
	}

	// if(!xDataGetGameRule[GAME_RULES_IS_ROUND_STARTED])
	// {
	// }
}

public xHamTouch_Pre(weapon, id)
{
	if(!is_user_connected(id) || !is_user_alive(id))
		return HAM_IGNORED

	if(xUserData[id][UD_IS_ZOMBIE])
		return HAM_SUPERCEDE

	return HAM_IGNORED
}

public select_primary_weapon(id)
{
	if(xDataGetGameRule[GAME_RULES_IS_ROUND_STARTED])
	{
		client_print_color(id, print_team_red, "^3Seleção de armas resetadas! ^1Espere o fim da rodada.")
		return
	}

	new xFmtx[128], xMenu, xWpn[32]
	formatex(xFmtx, charsmax(xFmtx), "\ySelecionar arma primária")

	xMenu = menu_create(xFmtx, "_select_primary_weapon")

	for(new i = 0; i < ArraySize(xDataGetGameRule[GAME_RULES_PRIMARY_WEAPONS]); i++)
	{
		ArrayGetString(xDataGetGameRule[GAME_RULES_PRIMARY_WEAPONS], i, xWpn, charsmax(xWpn))
		mb_strtotitle(xWpn[7])
		menu_additem(xMenu, xWpn[7], fmt("%d", i))
	}

	menu_setprop(xMenu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
	menu_setprop(xMenu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
	menu_setprop(xMenu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))
	menu_display(id, xMenu)
}

public _select_primary_weapon(id, menu, item)
{
	if(xUserData[id][UD_IS_ZOMBIE])
		return

	if(!is_user_connected(id))
		return

	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return
	}
	
	new xInfo[11], xWpnArrayIndex
	menu_item_getinfo(menu, item, _, xInfo, charsmax(xInfo))
	xWpnArrayIndex = str_to_num(xInfo)
	xUserData[id][UD_PRIMARY_WEAPON] = xWpnArrayIndex
	
	get_selected_weapon(id, xDataGetGameRule[GAME_RULES_PRIMARY_WEAPONS], xWpnArrayIndex, PRIMARY_WEAPON_SLOT)
	select_secondary_weapon(id)
}

public select_secondary_weapon(id)
{
	new xFmtx[128], xMenu, xWpn[32]
	formatex(xFmtx, charsmax(xFmtx), "\ySelecionar arma secundária")

	xMenu = menu_create(xFmtx, "_select_secondary_weapon")

	for(new i = 0; i < ArraySize(xDataGetGameRule[GAME_RULES_SECONDARY_WEAPONS]); i++)
	{
		ArrayGetString(xDataGetGameRule[GAME_RULES_SECONDARY_WEAPONS], i, xWpn, charsmax(xWpn))
		mb_strtotitle(xWpn[7])
		menu_additem(xMenu, xWpn[7], fmt("%d", i))
	}

	menu_setprop(xMenu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
	menu_setprop(xMenu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
	menu_setprop(xMenu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))
	menu_display(id, xMenu)
}

public _select_secondary_weapon(id, menu, item)
{
	if(xUserData[id][UD_IS_ZOMBIE])
		return

	if(!is_user_connected(id))
		return

	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return
	}
	
	new xInfo[11], xWpnArrayIndex
	menu_item_getinfo(menu, item, _, xInfo, charsmax(xInfo))
	xWpnArrayIndex = str_to_num(xInfo)
	xUserData[id][UD_SECONDARY_WEAPON] = xWpnArrayIndex

	get_selected_weapon(id, xDataGetGameRule[GAME_RULES_SECONDARY_WEAPONS], xWpnArrayIndex, PISTOL_SLOT)
}

public get_selected_weapon(const id, Array:WpnType, const xWpnArrayIndex, const InventorySlotType:slot)
{
	new xWpn[32]
	ArrayGetString(WpnType, xWpnArrayIndex, xWpn, charsmax(xWpn))
	rg_drop_items_by_slot(id, slot)
	rg_give_item(id, xWpn)

	new WeaponIdType:xWpnIdType = rg_get_weapon_info(xWpn, WI_ID)
	new xWpnBpAmmo = rg_get_weapon_info(xWpnIdType, WI_MAX_ROUNDS)
	rg_set_user_bpammo(id, xWpnIdType, xWpnBpAmmo)
}

public CSGameRules_RestartRound_Pre()
{
	xDataGetGameRule[GAME_RULES_IS_ROUND_STARTED] = false

	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_connected(i))
			continue

		xUserData[i][UD_IS_ZOMBIE] = false
		rg_set_user_model(i, xSettingsVars[CONFIG_DEFAULT_HUMAN_MODEL])
		rg_set_user_team(i, TEAM_CT)
	}

	if(xSettingsVars[CONFIG_DEBUG_ON])
	{
		server_print("^n")
		server_print("CSGameRules_RestartRound_Pre")
		server_print("^n")
	}
}

public CSGameRules_OnRoundFreezeEnd_Pre()
{
	if(xDataGetGameRule[GAME_RULES_CURRENT_MODE] == -1)
	{
		server_print("[ZP NEXT] No gamemodes found.")
		return
	}

	xDataGetGameRule[GAME_RULES_COUNTDOWN] = xCvars[CVAR_START_DELAY]
	remove_task(TASK_COUNTDOWN)
	set_task_ex(0.0, "xStartCountDown", TASK_COUNTDOWN)
}

public xStartCountDown()
{
	if(xDataGetGameRule[GAME_RULES_COUNTDOWN] <= 0)
	{
		xInitRound()
		remove_task(TASK_COUNTDOWN)
		return
	}

	set_hudmessage(255, 0, 0, -1.0, 0.30, 2, 0.3, 1.0, 0.05, 0.05, -1, 0, { 100, 200, 50, 100 })
	ShowSyncHudMsg(0, xMsgSync[SYNC_HUD_MAIN], "Nova infecção em: %d", xDataGetGameRule[GAME_RULES_COUNTDOWN])

	if(xDataGetGameRule[GAME_RULES_COUNTDOWN] <= 10)
	{
		static nword[20]
		num_to_word(xDataGetGameRule[GAME_RULES_COUNTDOWN], nword, charsmax(nword))
		client_cmd(0, "spk sound/vox/%s.wav", nword)
	}

	xDataGetGameRule[GAME_RULES_COUNTDOWN] --
	set_task_ex(1.0, "xStartCountDown", TASK_COUNTDOWN)
}

public xInitRound()
{
	new id = random_player()

	if(id == -1)
	{
		server_print("[ZP NEXT] No player found.")
		return
	}

	set_hudmessage(255, 0, 0, -1.0, 0.30, 2, 0.3, 3.0, 0.06, 0.06, -1, 0, { 100, 200, 50, 100 })
	ShowSyncHudMsg(0, xMsgSync[SYNC_HUD_MAIN], "%n^nÉ o primeiro zombie!", id)

	set_user_zombie(id, 0)
	xDataGetGameRule[GAME_RULES_IS_ROUND_STARTED] = true

	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_connected(i))
			continue

		if(i == id)
			continue

		rg_set_user_model(i, xSettingsVars[CONFIG_DEFAULT_HUMAN_MODEL])
		rg_set_user_team(i, TEAM_CT)
	}
}

public plugin_precache()
{
	new i
	for(i = 0; i < sizeof(CS_SOUNDS); i++) engfunc(EngFunc_PrecacheSound, CS_SOUNDS[i])

	aDataClass = ArrayCreate(ePropsClass)
	aDataGameMode = ArrayCreate(ePropsGameMode)

	bind_pcvar_num(create_cvar("zpn_start_countdown_delay", "15", .has_min = true, .min_val = 1.0), xCvars[CVAR_START_DELAY])
	bind_pcvar_num(create_cvar("zpn_last_human_infect", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_LAST_HUMAN_INFECT])

	if(!json_setting_get_int(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Enable Debug", xSettingsVars[CONFIG_DEBUG_ON]))
	{
		xSettingsVars[CONFIG_DEBUG_ON] = 1
		json_setting_set_int(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Enable Debug", 1)
	}

	if(!json_setting_get_int(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Enable Zombie Escape", xSettingsVars[CONFIG_ZOMBIE_ESCAPE_ON]))
	{
		xSettingsVars[CONFIG_ZOMBIE_ESCAPE_ON] = 0
		json_setting_set_int(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Enable Zombie Escape", 0)
	}

	if(!json_setting_get_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Prefix Chat", xSettingsVars[CONFIG_PREFIX_CHAT], charsmax(xSettingsVars[CONFIG_PREFIX_CHAT])))
	{
		xSettingsVars[CONFIG_PREFIX_CHAT] = "!y[ZP]"
		json_setting_set_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Prefix Chat", "!y[ZP]")
	}

	if(!json_setting_get_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Prefix Menus", xSettingsVars[CONFIG_PREFIX_MENUS], charsmax(xSettingsVars[CONFIG_PREFIX_MENUS])))
	{
		xSettingsVars[CONFIG_PREFIX_MENUS] = "!y[!rZP!y]"
		json_setting_set_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Prefix Menus", "!y[!rZP!y]")
	}

	if(!json_setting_get_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Default Human Model", xSettingsVars[CONFIG_DEFAULT_HUMAN_MODEL], charsmax(xSettingsVars[CONFIG_DEFAULT_HUMAN_MODEL])))
	{
		xSettingsVars[CONFIG_DEFAULT_HUMAN_MODEL] = "sas"
		json_setting_set_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Default Human Model", "sas")
	}

	xDataGetGameRule[GAME_RULES_USELESS_ENTITIES] = ArrayCreate(64, 0)

	if(!json_setting_get_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Useless Entities", xDataGetGameRule[GAME_RULES_USELESS_ENTITIES]))
	{
		new const uselessEntities[][] =
		{
			"func_bomb_target",
			"info_bomb_target",
			"info_vip_start",
			"func_vip_safetyzone",
			"func_escapezone",
			"func_hostage_rescue",
			"info_hostage_rescue",
			"hostage_entity",
			"armoury_entity",
			"player_weaponstrip",
			"game_player_equip",
			"env_fog",
			"env_rain",
			"env_snow",
			"monster_scientist",
			"item_longjump",
		}

		for(new i = 0; i < sizeof(uselessEntities); i++)
			ArrayPushString(xDataGetGameRule[GAME_RULES_USELESS_ENTITIES], uselessEntities[i])

		json_setting_set_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Useless Entities", xDataGetGameRule[GAME_RULES_USELESS_ENTITIES])
	}

	if (!zpn_is_invalid_array(xDataGetGameRule[GAME_RULES_USELESS_ENTITIES]))
		xFwSpawn_Pre = register_forward(FM_Spawn, "Spawn_Pre", false)

	xDataGetGameRule[GAME_RULES_PRIMARY_WEAPONS] = ArrayCreate(32, 0)

	if(!json_setting_get_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Primary Weapons", xDataGetGameRule[GAME_RULES_PRIMARY_WEAPONS]))
	{
		ArrayPushString(xDataGetGameRule[GAME_RULES_PRIMARY_WEAPONS], "weapon_famas")
		ArrayPushString(xDataGetGameRule[GAME_RULES_PRIMARY_WEAPONS], "weapon_galil")
		ArrayPushString(xDataGetGameRule[GAME_RULES_PRIMARY_WEAPONS], "weapon_ak47")
		ArrayPushString(xDataGetGameRule[GAME_RULES_PRIMARY_WEAPONS], "weapon_m4a1")
		json_setting_set_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Primary Weapons", xDataGetGameRule[GAME_RULES_PRIMARY_WEAPONS])
	}

	xDataGetGameRule[GAME_RULES_SECONDARY_WEAPONS] = ArrayCreate(32, 0)

	if(!json_setting_get_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Secondary Weapons", xDataGetGameRule[GAME_RULES_SECONDARY_WEAPONS]))
	{
		ArrayPushString(xDataGetGameRule[GAME_RULES_SECONDARY_WEAPONS], "weapon_p228")
		ArrayPushString(xDataGetGameRule[GAME_RULES_SECONDARY_WEAPONS], "weapon_usp")
		ArrayPushString(xDataGetGameRule[GAME_RULES_SECONDARY_WEAPONS], "weapon_deagle")
		ArrayPushString(xDataGetGameRule[GAME_RULES_SECONDARY_WEAPONS], "weapon_elite")
		json_setting_set_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Secondary Weapons", xDataGetGameRule[GAME_RULES_SECONDARY_WEAPONS])
	}
}

public Spawn_Pre(this)
{
	new classname[32]; get_entvar(this, var_classname, classname, charsmax(classname))

	if(ArrayFindString(xDataGetGameRule[GAME_RULES_USELESS_ENTITIES], classname) != -1)
	{
		forward_return(FMV_CELL, -1)
		return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}

public plugin_end()
{
	ArrayDestroy(xDataGetGameRule[GAME_RULES_USELESS_ENTITIES])
	ArrayDestroy(xDataGetGameRule[GAME_RULES_PRIMARY_WEAPONS])
	ArrayDestroy(xDataGetGameRule[GAME_RULES_SECONDARY_WEAPONS])
}

public plugin_natives()
{
	register_library("zombie_plague_next")

	register_native("zpn_class_init", "_zpn_class_init")
	register_native("zpn_class_get_prop", "_zpn_class_get_prop")
	register_native("zpn_class_set_prop", "_zpn_class_set_prop")

	register_native("zpn_gamemode_init", "_zpn_gamemode_init")
	register_native("zpn_gamemode_get_prop", "_zpn_gamemode_get_prop")
	register_native("zpn_gamemode_set_prop", "_zpn_gamemode_set_prop")
}

public _zpn_gamemode_init(plugin_id, param_nums)
{
	new key = (++xDataGameModeCount - 1)

	xDataGetGameMode[GAMEMODE_PROP_NAME] = EOS
	xDataGetGameMode[GAMEMODE_PROP_NOTICE] = EOS
	xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR] = { 255, 255, 255 }
	xDataGetGameMode[GAMEMODE_PROP_CHANCE] = -1
	xDataGetGameMode[GAMEMODE_PROP_MIN_ALIVES] = 1
	xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME] = 2.0
	xDataGetGameMode[GAMEMODE_PROP_CHANGE_CLASS] = false
	xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH] = GAMEMODE_DEATHMATCH_DISABLED

	ArrayPushArray(aDataGameMode, xDataGetGameMode)

	return key
}

public any:_zpn_gamemode_get_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataGameMode))
		return false

	enum { arg_gamemode_id = 1, arg_prop, arg_value, arg_len }

	new gamemode_id = get_param(arg_gamemode_id)
	new prop = get_param(arg_prop)

	ArrayGetArray(aDataGameMode, gamemode_id, xDataGetGameMode)

	switch(ePropsGameModeRegisters:prop)
	{
		case GAMEMODE_PROP_REGISTER_NAME: set_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NAME], get_param_byref(arg_len))
		case GAMEMODE_PROP_REGISTER_NOTICE: set_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NOTICE], get_param_byref(arg_len))
		case GAMEMODE_PROP_REGISTER_HUD_COLOR: return xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR]
		case GAMEMODE_PROP_REGISTER_CHANCE: return xDataGetGameMode[GAMEMODE_PROP_CHANCE]
		case GAMEMODE_PROP_REGISTER_MIN_ALIVES: return xDataGetGameMode[GAMEMODE_PROP_MIN_ALIVES]
		case GAMEMODE_PROP_REGISTER_ROUND_TIME: return Float:xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME]
		case GAMEMODE_PROP_REGISTER_CHANGE_CLASS: return bool:xDataGetGameMode[GAMEMODE_PROP_CHANGE_CLASS]
		case GAMEMODE_PROP_REGISTER_DEATHMATCH: return xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH]
		default: return false
	}

	return true
}

public any:_zpn_gamemode_set_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataGameMode))
		return false

	enum { arg_gamemode_id = 1, arg_prop, arg_value }

	new gamemode_id = get_param(arg_gamemode_id)
	new prop = get_param(arg_prop)

	ArrayGetArray(aDataGameMode, gamemode_id, xDataGetGameMode)

	switch(ePropsGameModeRegisters:prop)
	{
		case GAMEMODE_PROP_REGISTER_NAME: get_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NAME], charsmax(xDataGetGameMode[GAMEMODE_PROP_NAME]))
		case GAMEMODE_PROP_REGISTER_NOTICE: get_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NOTICE], charsmax(xDataGetGameMode[GAMEMODE_PROP_NOTICE]))
		case GAMEMODE_PROP_REGISTER_HUD_COLOR: xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR] = get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_CHANCE: xDataGetGameMode[GAMEMODE_PROP_CHANCE] = get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_MIN_ALIVES: xDataGetGameMode[GAMEMODE_PROP_MIN_ALIVES] = get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_ROUND_TIME: xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME] = get_float_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_CHANGE_CLASS: xDataGetGameMode[GAMEMODE_PROP_CHANGE_CLASS] = bool:get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_DEATHMATCH: xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH] = eGameModeDeathMatchType:get_param_byref(arg_value)
		default: return false
	}

	ArraySetArray(aDataGameMode, gamemode_id, xDataGetGameMode)
	
	return true
}

public _zpn_class_init(plugin_id, param_nums)
{
	new key = (++xDataClassCount - 1)

	xDataGetClass[CLASS_PROP_TYPE] = 0
	xDataGetClass[CLASS_PROP_NAME] = EOS
	xDataGetClass[CLASS_PROP_INFO] = EOS
	xDataGetClass[CLASS_PROP_MODEL] = EOS
	xDataGetClass[CLASS_PROP_MODEL_VIEW] = EOS
	xDataGetClass[CLASS_PROP_HEALTH] = 100.0
	xDataGetClass[CLASS_PROP_SPEED] = 320
	xDataGetClass[CLASS_PROP_GRAVITY] = 1.0
	xDataGetClass[CLASS_PROP_KNOCKBACK] = 1.0
	xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST] = EOS

	ArrayPushArray(aDataClass, xDataGetClass)

	return key
}

public any:_zpn_class_get_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataClass))
		return false

	enum { arg_class_id = 1, arg_prop, arg_value, arg_len }

	new class_id = get_param(arg_class_id)
	new prop = get_param(arg_prop)

	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	switch(ePropsClassRegisters:prop)
	{
		case CLASS_PROP_REGISTER_TYPE: return xDataGetClass[CLASS_PROP_TYPE]
		case CLASS_PROP_REGISTER_NAME: set_string(arg_value, xDataGetClass[CLASS_PROP_NAME], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_INFO: set_string(arg_value, xDataGetClass[CLASS_PROP_INFO], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_MODEL: set_string(arg_value, xDataGetClass[CLASS_PROP_MODEL], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_MODEL_VIEW: set_string(arg_value, xDataGetClass[CLASS_PROP_MODEL_VIEW], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_HEALTH: return xDataGetClass[CLASS_PROP_HEALTH]
		case CLASS_PROP_REGISTER_SPEED: return xDataGetClass[CLASS_PROP_SPEED]
		case CLASS_PROP_REGISTER_GRAVITY: return xDataGetClass[CLASS_PROP_GRAVITY]
		case CLASS_PROP_REGISTER_KNOCKBACK: return xDataGetClass[CLASS_PROP_KNOCKBACK]
		case CLASS_PROP_REGISTER_CLAW_WEAPONLIST: return set_string(arg_value, xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST], get_param_byref(arg_len))
		default: return false
	}

	return true
}

public any:_zpn_class_set_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataClass))
		return false

	enum { arg_class_id = 1, arg_prop, arg_value }

	new class_id = get_param(arg_class_id)
	new prop = get_param(arg_prop)

	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	switch(ePropsClassRegisters:prop)
	{
		case CLASS_PROP_REGISTER_TYPE: xDataGetClass[CLASS_PROP_TYPE] = get_param_byref(arg_value)
		case CLASS_PROP_REGISTER_NAME: get_string(arg_value, xDataGetClass[CLASS_PROP_NAME], charsmax(xDataGetClass[CLASS_PROP_NAME]))
		case CLASS_PROP_REGISTER_INFO: get_string(arg_value, xDataGetClass[CLASS_PROP_INFO], charsmax(xDataGetClass[CLASS_PROP_INFO]))
		case CLASS_PROP_REGISTER_MODEL:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_MODEL], charsmax(xDataGetClass[CLASS_PROP_MODEL]))

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_MODEL]))
				precache_player_model(xDataGetClass[CLASS_PROP_MODEL])
		}
		case CLASS_PROP_REGISTER_MODEL_VIEW:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_MODEL_VIEW], charsmax(xDataGetClass[CLASS_PROP_MODEL_VIEW]))

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_MODEL_VIEW]))
				precache_model(xDataGetClass[CLASS_PROP_MODEL_VIEW])
		}
		case CLASS_PROP_REGISTER_HEALTH: xDataGetClass[CLASS_PROP_HEALTH] = get_float_byref(arg_value)
		case CLASS_PROP_REGISTER_SPEED: xDataGetClass[CLASS_PROP_SPEED] = get_param_byref(arg_value)
		case CLASS_PROP_REGISTER_GRAVITY: xDataGetClass[CLASS_PROP_GRAVITY] = get_float_byref(arg_value)
		case CLASS_PROP_REGISTER_KNOCKBACK: xDataGetClass[CLASS_PROP_KNOCKBACK] = get_float_byref(arg_value)
		case CLASS_PROP_REGISTER_CLAW_WEAPONLIST: get_string(arg_value, xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST], charsmax(xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST]))
		default: return false
	}

	ArraySetArray(aDataClass, class_id, xDataGetClass)

	return true
}

precache_player_model(const modelname[])
{
	static longname[128], index
	formatex(longname, charsmax(longname), "models/player/%s/%s.mdl", modelname, modelname)
	index = precache_model(longname)

	copy(longname[strlen(longname)-4], charsmax(longname) - (strlen(longname)-4), "T.mdl")

	if(file_exists(longname))
		precache_model(longname)

	return index
}

public set_user_zombie(this, attacker)
{
	if(zpn_is_invalid_array(aDataClass))
		return

	if(!is_user_alive(this) || !is_user_connected(this))
		return

	ArrayGetArray(aDataClass, xUserData[this][UD_CURRENT_ZOMBIE_CLASS], xDataGetClass)

	xUserData[this][UD_IS_ZOMBIE] = true

	rg_drop_items_by_slot(this, PRIMARY_WEAPON_SLOT)
	rg_drop_items_by_slot(this, PISTOL_SLOT)
	rg_drop_items_by_slot(this, GRENADE_SLOT)
	rg_set_user_team(this, TEAM_TERRORIST)
	rg_set_user_model(this, xDataGetClass[CLASS_PROP_MODEL])
	set_entvar(this, var_health, xDataGetClass[CLASS_PROP_HEALTH])
	set_entvar(this, var_max_health, xDataGetClass[CLASS_PROP_HEALTH])
	set_entvar(this, var_gravity, xDataGetClass[CLASS_PROP_GRAVITY])
	rg_set_user_armor(this, 0, ARMOR_NONE)

	new activeItem = get_member(this, m_pActiveItem)

	if(!is_nullent(activeItem))
		rg_weapon_deploy(activeItem, xDataGetClass[CLASS_PROP_MODEL_VIEW], "", 0, "knife", 0)

	if(xSettingsVars[CONFIG_DEBUG_ON])
		server_print("%n virou zombie, class id: %d - health: %0.1f - model: %s - v_model: %s", this, xUserData[this][UD_CURRENT_ZOMBIE_CLASS], xDataGetClass[CLASS_PROP_HEALTH], xDataGetClass[CLASS_PROP_MODEL], xDataGetClass[CLASS_PROP_MODEL_VIEW])
}

public set_user_human(this, attacker)
{
	
}

random_player()
{
	new players[32], pnum
	get_players(players, pnum)

	if(!pnum)
		return -1

	return players[random(pnum)]
}

get_num_humans_alive()
{
	static h, id; h = 0
	for(id = 1; id <= MaxClients; id++) if(is_user_alive(id) && !xUserData[id][UD_IS_ZOMBIE]) h++
	return h
}

deploy_weapon(id)
{
	new activeItem = get_member(id, m_pActiveItem)
	if(!is_nullent(activeItem)) ExecuteHamB(Ham_Item_Deploy, activeItem)
}
