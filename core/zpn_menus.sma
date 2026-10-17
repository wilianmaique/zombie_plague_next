#include <amxmodx>
#include <reapi>
#include <api_json_settings>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

enum _:eForwards
{
	FW_SHOW_MENU_GAME_PRE,
	FW_SHOW_MENU_GAME_POST,
	FW_SHOW_MENU_ITEMS_PRE,
	FW_SHOW_MENU_ITEMS_POST,
	FW_SHOW_MENU_CLASS_TYPE_PRE,
	FW_SHOW_MENU_CLASS_TYPE_POST,
	FW_SHOW_MENU_CLASS_PRE,
	FW_SHOW_MENU_CLASS_POST,
	FW_SHOW_MENU_PRIMARY_WEAPON_PRE,
	FW_SHOW_MENU_PRIMARY_WEAPON_POST,
	FW_SHOW_MENU_SECONDARY_WEAPON_PRE,
	FW_SHOW_MENU_SECONDARY_WEAPON_POST,
}

enum eMenuParents
{
	MENU_PARENT_NONE,
	MENU_PARENT_GAME,
	MENU_PARENT_ADMIN,
	MENU_PARENT_ADMIN_SPECIAL_CLASSES,
	MENU_PARENT_CLASS_TYPE,
	MENU_PARENT_PRIMARY_WEAPON,
}

new xForwards[eForwards] = { -1, ... }
new xMenuPrefix[32], xBuyItemCallback
new xAdminMenuFlags[27], xAdminAccessCallback, xAdminPlayerCallback
new xDisplayedMenu[33] = { -1, ... }
new eMenuParents:xMenuParent[33], eMenuParents:xMenuReturn[33]
new xMenuParentData[33], xMenuReturnData[33], xMenuReturnUserid[33]

public plugin_precache()
{
	bind_pcvar_string(create_cvar("zpn_admin_menu_flags", "d"), xAdminMenuFlags, charsmax(xAdminMenuFlags))

	if(!json_setting_get_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Prefix Menus", xMenuPrefix, charsmax(xMenuPrefix)))
	{
		copy(xMenuPrefix, charsmax(xMenuPrefix), "!y[!rZM!y]")
		json_setting_set_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Prefix Menus", "!y[!rZM!y]")
	}

	replace_string(xMenuPrefix, charsmax(xMenuPrefix), "!y", "\y")
	replace_string(xMenuPrefix, charsmax(xMenuPrefix), "!d", "\d")
	replace_string(xMenuPrefix, charsmax(xMenuPrefix), "!r", "\r")
	replace_string(xMenuPrefix, charsmax(xMenuPrefix), "!w", "\w")
}

public plugin_init()
{
	register_plugin("[ZPN] Core: Menus", "1.0", "Wilian M.")
	register_dictionary("common.txt")

	if(!is_regamedll())
	{
		set_fail_state("[ZP NEXT] Menus require ReGameDLL_CS")
		return
	}

	register_clcmd("chooseteam", "clcmd_changeteam")
	register_clcmd("jointeam", "clcmd_changeteam")

	xBuyItemCallback = menu_makecallback("_buy_items_callback")
	xAdminAccessCallback = menu_makecallback("_admin_access_callback")
	xAdminPlayerCallback = menu_makecallback("_admin_player_callback")

	AutoExecConfig(true, "zpn_menus", FOLDER_CVARS_CONFIG)

	xForwards[FW_SHOW_MENU_GAME_PRE] = CreateMultiForward("zpn_show_menu_game_pre", ET_CONTINUE, FP_CELL)
	xForwards[FW_SHOW_MENU_GAME_POST] = CreateMultiForward("zpn_show_menu_game_post", ET_IGNORE, FP_CELL)
	xForwards[FW_SHOW_MENU_ITEMS_PRE] = CreateMultiForward("zpn_show_menu_items_pre", ET_CONTINUE, FP_CELL, FP_CELL)
	xForwards[FW_SHOW_MENU_ITEMS_POST] = CreateMultiForward("zpn_show_menu_items_post", ET_IGNORE, FP_CELL, FP_CELL)
	xForwards[FW_SHOW_MENU_CLASS_TYPE_PRE] = CreateMultiForward("zpn_show_menu_class_type_pre", ET_CONTINUE, FP_CELL)
	xForwards[FW_SHOW_MENU_CLASS_TYPE_POST] = CreateMultiForward("zpn_show_menu_class_type_post", ET_IGNORE, FP_CELL)
	xForwards[FW_SHOW_MENU_CLASS_PRE] = CreateMultiForward("zpn_show_menu_class_pre", ET_CONTINUE, FP_CELL, FP_CELL)
	xForwards[FW_SHOW_MENU_CLASS_POST] = CreateMultiForward("zpn_show_menu_class_post", ET_IGNORE, FP_CELL, FP_CELL)
	xForwards[FW_SHOW_MENU_PRIMARY_WEAPON_PRE] = CreateMultiForward("zpn_show_menu_primary_weapon_pre", ET_CONTINUE, FP_CELL)
	xForwards[FW_SHOW_MENU_PRIMARY_WEAPON_POST] = CreateMultiForward("zpn_show_menu_primary_weapon_post", ET_IGNORE, FP_CELL)
	xForwards[FW_SHOW_MENU_SECONDARY_WEAPON_PRE] = CreateMultiForward("zpn_show_menu_secondary_weapon_pre", ET_CONTINUE, FP_CELL)
	xForwards[FW_SHOW_MENU_SECONDARY_WEAPON_POST] = CreateMultiForward("zpn_show_menu_secondary_weapon_post", ET_IGNORE, FP_CELL)
}

public plugin_natives()
{
	register_library("zombie_plague_next_menus")

	register_native("zpn_show_menu_game", "_zpn_show_menu_game")
	register_native("zpn_show_menu_items", "_zpn_show_menu_items")
	register_native("zpn_show_menu_class_type", "_zpn_show_menu_class_type")
	register_native("zpn_show_menu_class", "_zpn_show_menu_class")
	register_native("zpn_show_menu_primary_weapon", "_zpn_show_menu_primary_weapon")
	register_native("zpn_show_menu_secondary_weapon", "_zpn_show_menu_secondary_weapon")
}

public plugin_end()
{
	for(new i = 0; i < eForwards; i++)
	{
		if(xForwards[i] != -1)
			DestroyForward(xForwards[i])
	}
}

public bool:_zpn_show_menu_game(plugin_id, param_nums)
{
	return param_nums == 1 ? show_menu_game(get_param(1)) : false
}

public bool:_zpn_show_menu_items(plugin_id, param_nums)
{
	return param_nums == 1 ? buy_items(get_param(1)) : false
}

public bool:_zpn_show_menu_class_type(plugin_id, param_nums)
{
	return param_nums == 1 ? select_class_type(get_param(1)) : false
}

public bool:_zpn_show_menu_class(plugin_id, param_nums)
{
	if(param_nums != 2)
		return false

	return select_class(get_param(1), eClassTypes:get_param(2))
}

public bool:_zpn_show_menu_primary_weapon(plugin_id, param_nums)
{
	return param_nums == 1 ? select_weapon_menu(get_param(1), ZPN_WEAPON_PRIMARY) : false
}

public bool:_zpn_show_menu_secondary_weapon(plugin_id, param_nums)
{
	return param_nums == 1 ? select_weapon_menu(get_param(1), ZPN_WEAPON_SECONDARY) : false
}

public clcmd_changeteam(id)
{
	if(!is_menu_client(id))
		return PLUGIN_CONTINUE

	new TeamName:team = get_member(id, m_iTeam)
	if(team == TEAM_SPECTATOR || team == TEAM_UNASSIGNED)
		return PLUGIN_CONTINUE

	show_menu_game(id)
	return PLUGIN_HANDLED
}

public zpn_user_spawn_post(const id)
{
	if(is_menu_client(id) && !zpn_is_user_zombie(id)
	&& zpn_player_data_get_prop(id, PROP_PD_REGISTER_PRIMARY_WEAPON) == -1)
		select_weapon_menu(id, ZPN_WEAPON_PRIMARY)
}

bool:show_menu_game(const id)
{
	if(!is_menu_client(id))
		return false

	new forward_return
	ExecuteForward(xForwards[FW_SHOW_MENU_GAME_PRE], forward_return, id)
	if(forward_return >= ZPN_RETURN_HANDLED || !is_menu_client(id))
		return false

	new menu = menu_create(fmt("%s \yZombie Plague Next", xMenuPrefix), "_show_menu_game")
	menu_additem(menu, "Selecionar Armas")
	menu_additem(menu, "Loja De Itens")
	menu_additem(menu, "Selecionar Classes^n")
	menu_additem(menu, "Administração", .callback = xAdminAccessCallback)
	display_menu(id, menu)

	ExecuteForward(xForwards[FW_SHOW_MENU_GAME_POST], forward_return, id)
	return true
}

public _show_menu_game(id, menu, item)
{
	close_menu(id, menu, item)
	if(!is_menu_client(id) || item < 0)
		return PLUGIN_HANDLED

	switch(item)
	{
		case 0: select_weapon_menu(id, ZPN_WEAPON_PRIMARY)
		case 1: buy_items(id)
		case 2: select_class_type(id)
		case 3: admin_menu(id)
	}

	return PLUGIN_HANDLED
}

bool:has_admin_menu_access(const id)
{
	if(!is_menu_client(id))
		return false

	new flags = read_flags(xAdminMenuFlags)
	return flags != 0 && (get_user_flags(id) & flags) == flags
}

public _admin_access_callback(id, menu, item)
{
	return has_admin_menu_access(id) ? ITEM_ENABLED : ITEM_DISABLED
}

bool:admin_menu(const id)
{
	if(!has_admin_menu_access(id))
		return false

	new menu = menu_create(fmt("%s \yAdministração", xMenuPrefix), "_admin_menu")
	menu_additem(menu, "Transformar: \rZombie \w/ \yHumano")
	menu_additem(menu, "Transformar em \rZombie Especial")
	menu_additem(menu, "Transformar em \yHumano Especial")
	display_menu(id, menu, .parent = MENU_PARENT_GAME)
	return true
}

public _admin_menu(id, menu, item)
{
	close_menu(id, menu, item)
	if(item < 0 || !has_admin_menu_access(id))
		return PLUGIN_HANDLED

	switch(item)
	{
		case 0: admin_players(id)
		case 1: admin_special_classes(id, CLASS_TEAM_TYPE_ZOMBIE_SPECIAL)
		case 2: admin_special_classes(id, CLASS_TEAM_TYPE_HUMAN_SPECIAL)
	}
	return PLUGIN_HANDLED
}

bool:admin_special_classes(const id, const eClassTypes:type)
{
	if(!has_admin_menu_access(id)
	|| (type != CLASS_TEAM_TYPE_ZOMBIE_SPECIAL && type != CLASS_TEAM_TYPE_HUMAN_SPECIAL))
		return false

	new menu = menu_create(fmt("%s \yClasses %s Especiais", xMenuPrefix, type == CLASS_TEAM_TYPE_ZOMBIE_SPECIAL ? "\rZombies" : "\yHumanas"), "_admin_special_classes")
	new name[64], count
	for(new class_id = 0; class_id < zpn_class_array_size(); class_id++)
	{
		if(zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_TYPE) != type)
			continue

		// Hidden special classes belong in administration, even when players cannot select them.
		zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_NAME, name, charsmax(name))
		menu_additem(menu, fmt("%s%s", type == CLASS_TEAM_TYPE_ZOMBIE_SPECIAL ? "\r" : "\y", name), fmt("%d %d", type, class_id))
		count++
	}

	if(!count)
	{
		zpn_print_color(id, print_team_red, "^3Nenhuma classe especial cadastrada para esta raça.")
		menu_destroy(menu)
		return admin_menu(id)
	}

	display_menu(id, menu, .parent = MENU_PARENT_ADMIN)
	return true
}

public _admin_special_classes(id, menu, item)
{
	new info[32], type_text[12], class_text[12]
	if(!read_menu_selection(id, menu, item, info, charsmax(info)) || !has_admin_menu_access(id))
		return PLUGIN_HANDLED

	parse(info, type_text, charsmax(type_text), class_text, charsmax(class_text))
	new class_id = str_to_num(class_text)
	if(is_admin_special_class(class_id)
	&& zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_TYPE) == eClassTypes:str_to_num(type_text))
		admin_players(id, class_id)

	return PLUGIN_HANDLED
}

bool:is_admin_special_class(const class_id)
{
	if(!(0 <= class_id < zpn_class_array_size()))
		return false

	new eClassTypes:type = zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_TYPE)
	return type == CLASS_TEAM_TYPE_ZOMBIE_SPECIAL || type == CLASS_TEAM_TYPE_HUMAN_SPECIAL
}

bool:admin_players(const id, const class_id = -1, const page = 0)
{
	if(!has_admin_menu_access(id) || (class_id != -1 && !is_admin_special_class(class_id)))
		return false

	new name[64]
	if(class_id == -1)
		copy(name, charsmax(name), "\rZombie \w/ \yHumano")
	else
		zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_NAME, name, charsmax(name))

	new menu = menu_create(fmt("%s \yTransformar: %s%s", xMenuPrefix, class_id != -1 && zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_TYPE) == CLASS_TEAM_TYPE_ZOMBIE_SPECIAL ? "\r" : "\y", name), "_admin_players")
	new count
	for(new target = 1; target <= MaxClients; target++)
	{
		if(!is_user_alive(target) || is_user_hltv(target))
			continue

		menu_additem(menu, " ", fmt("%d %d %d", get_user_userid(target), class_id, _:zpn_is_user_zombie(target)), .callback = xAdminPlayerCallback)
		count++
	}

	if(!count)
	{
		zpn_print_color(id, print_team_red, "^3Nenhum jogador vivo disponível.")
		menu_destroy(menu)
		if(class_id != -1)
			return admin_special_classes(id, eClassTypes:zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_TYPE))
		return admin_menu(id)
	}

	display_menu(id, menu, page, class_id == -1 ? MENU_PARENT_ADMIN : MENU_PARENT_ADMIN_SPECIAL_CLASSES, class_id)
	return true
}

public _admin_player_callback(id, menu, item)
{
	if(!has_admin_menu_access(id) || item < 0)
		return ITEM_DISABLED

	new info[48], userid_text[12], class_text[12], state_text[4]
	if(!menu_item_getinfo(menu, item, .info = info, .infolen = charsmax(info)))
		return ITEM_DISABLED

	parse(info, userid_text, charsmax(userid_text), class_text, charsmax(class_text), state_text, charsmax(state_text))
	new target = find_player_ex(FindPlayer_MatchUserId, str_to_num(userid_text))
	if(!target || !is_user_alive(target))
	{
		menu_item_setname(menu, item, "Jogador indisponível")
		return ITEM_DISABLED
	}

	new class_id = str_to_num(class_text), name[32], state_label[96], state_color[3] = "\d", text[192]
	new bool:zombie = zpn_is_user_zombie(target)
	get_user_name(target, name, charsmax(name))
	if(get_member_game(m_bRoundTerminating))
		copy(state_label, charsmax(state_label), "Fim da rodada")
	else if(!zpn_is_round_started())
		copy(state_label, charsmax(state_label), "Início do game")
	else
	{
		copy(state_color, charsmax(state_color), zombie ? "\r" : "\y")
		new current = zpn_get_user_current_class(target)
		if(is_admin_special_class(current))
			zpn_class_get_prop(current, PROP_CLASS_REGISTER_NAME, state_label, charsmax(state_label))
		else
			copy(state_label, charsmax(state_label), zombie ? "Zombie" : "Humano")
	}

	new bool:enabled = !get_member_game(m_bRoundTerminating) && !get_member_game(m_bFreezePeriod)
	if(class_id != -1)
	{
		enabled = enabled && is_admin_special_class(class_id) && !zpn_is_user_class(target, class_id) && zpn_class_has_free_slot(class_id, target)
		if(is_admin_special_class(class_id) && !zpn_class_has_free_slot(class_id, target))
			add(state_label, charsmax(state_label), " \d/ Classe lotada")
	}

	formatex(text, charsmax(text), "%s%s %s%s", enabled ? "\w" : "\d", name, state_color, state_label)
	menu_item_setname(menu, item, text)

	menu_item_setcmd(menu, item, fmt("%d %d %d", get_user_userid(target), class_id, _:zombie))
	return enabled ? ITEM_ENABLED : ITEM_DISABLED
}

public _admin_players(id, menu, item)
{
	new info[48], userid_text[12], class_text[12], state_text[4]
	if(!read_menu_selection(id, menu, item, info, charsmax(info)) || !has_admin_menu_access(id))
		return PLUGIN_HANDLED

	parse(info, userid_text, charsmax(userid_text), class_text, charsmax(class_text), state_text, charsmax(state_text))
	new userid = str_to_num(userid_text), class_id = str_to_num(class_text)
	new target = find_player_ex(FindPlayer_MatchUserId, userid)
	if(!target || !is_user_alive(target))
		zpn_print_color(id, print_team_red, "^3Este jogador não está mais vivo ou conectado.")
	else if(get_member_game(m_bRoundTerminating) || get_member_game(m_bFreezePeriod))
		zpn_print_color(id, print_team_red, "^3Aguarde a contagem ou uma rodada em andamento.")
	else if(class_id == -1 && _:zpn_is_user_zombie(target) != str_to_num(state_text))
		zpn_print_color(id, print_team_red, "^3O estado do jogador mudou. A lista foi atualizada.")
	else
	{
		new eClassTypes:type
		if(class_id == -1)
			type = zpn_is_user_zombie(target) ? CLASS_TEAM_TYPE_HUMAN : CLASS_TEAM_TYPE_ZOMBIE
		else if(is_admin_special_class(class_id))
			type = eClassTypes:zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_TYPE)
		else
			return PLUGIN_HANDLED

		new name[32], class_name[64]
		get_user_name(target, name, charsmax(name))
		if(zpn_transform_user(target, type, class_id))
		{
			new current = is_user_connected(target) && get_user_userid(target) == userid ? zpn_get_user_current_class(target) : -1
			if(0 <= current < zpn_class_array_size())
			{
				zpn_class_get_prop(current, PROP_CLASS_REGISTER_NAME, class_name, charsmax(class_name))
				if(is_menu_client(id))
					zpn_print_color(id, print_team_default, "^3%s ^1transformado em ^4%s^1.", name, class_name)
				log_amx("Admin %n transformou %s (#%d) em %s", id, name, userid, class_name)
			}
		}
		else
			zpn_print_color(id, print_team_red, "^3Não foi possível transformar: verifique as vagas da classe, os jogadores vivos ou bloqueios de outros plugins.")
	}

	admin_players(id, class_id, item / 7)
	return PLUGIN_HANDLED
}

bool:buy_items(const id)
{
	if(!is_menu_client(id))
		return false

	new eClassTypes:item_team = get_user_current_class_type(id)
	new forward_return
	ExecuteForward(xForwards[FW_SHOW_MENU_ITEMS_PRE], forward_return, id, item_team)
	if(forward_return >= ZPN_RETURN_HANDLED || !is_menu_client(id))
		return false

	item_team = get_user_current_class_type(id)
	if(count_item(item_team) <= 0)
	{
		zpn_print_color(id, print_team_red, "^3Nenhum item encontrado.")
		return false
	}

	new menu = menu_create(fmt("%s \yLoja de Itens", xMenuPrefix), "_buy_items")
	new item_name[32], item_text[256], extra_text[ZPN_ITEM_EXTRA_TEXT_SIZE]
	new player_round, round, map, player_limit, round_limit, map_limit, min_zombies
	new alive_zombies = count_alive_zombies()

	for(new i = 0; i < zpn_item_array_size(); i++)
	{
		if(eClassTypes:zpn_item_get_prop(i, PROP_ITEM_REGISTER_TEAM) != item_team)
			continue

		zpn_item_get_prop(i, PROP_ITEM_REGISTER_NAME, item_name, charsmax(item_name))
		new bool:can_buy = (zpn_item_preview_buy(id, i, extra_text, charsmax(extra_text)) == ITEM_BUY_SUCCESS)
		if(!is_menu_client(id))
		{
			menu_destroy(menu)
			return false
		}

		zpn_item_get_limit_state(id, i, player_round, round, map)
		player_limit = zpn_item_get_prop(i, PROP_ITEM_REGISTER_LIMIT_PLAYER_PER_ROUND)
		round_limit = zpn_item_get_prop(i, PROP_ITEM_REGISTER_LIMIT_MAX_PER_ROUND)
		map_limit = zpn_item_get_prop(i, PROP_ITEM_REGISTER_LIMIT_PER_MAP)
		min_zombies = zpn_item_get_prop(i, PROP_ITEM_REGISTER_MIN_ZOMBIES)

		formatex(item_text, charsmax(item_text), "%s%s", can_buy ? "\w" : "\d", item_name)
		if(extra_text[0] != EOS)
			add(item_text, charsmax(item_text), fmt(" %s", extra_text))
		if(player_limit > 0)
			add(item_text, charsmax(item_text), fmt(" \d[LP: %d/%d]", player_round, player_limit))
		if(round_limit > 0)
			add(item_text, charsmax(item_text), fmt(" \d[LR: %d/%d]", round, round_limit))
		if(map_limit > 0)
			add(item_text, charsmax(item_text), fmt(" \d[LM: %d/%d]", map, map_limit))
		if(min_zombies > 0)
			add(item_text, charsmax(item_text), fmt(" \d[Z: %d/%d]", alive_zombies, min_zombies))

		if(can_buy)
			add(item_text, charsmax(item_text), fmt(" \y(\d%s\y)", format_number_point(zpn_item_get_prop(i, PROP_ITEM_REGISTER_COST))))
		else add(item_text, charsmax(item_text), fmt(" \d(%s)", format_number_point(zpn_item_get_prop(i, PROP_ITEM_REGISTER_COST))))

		menu_additem(menu, item_text, fmt("%d", i), .callback = xBuyItemCallback)
	}

	display_menu(id, menu, .parent = MENU_PARENT_GAME)
	ExecuteForward(xForwards[FW_SHOW_MENU_ITEMS_POST], forward_return, id, item_team)
	return true
}

public _buy_items_callback(id, menu, item)
{
	if(!is_menu_client(id) || item < 0)
		return ITEM_DISABLED

	new info[12]
	if(!menu_item_getinfo(menu, item, .info = info, .infolen = charsmax(info)))
		return ITEM_DISABLED

	new item_id = str_to_num(info)
	if(!(0 <= item_id < zpn_item_array_size())
	|| eClassTypes:zpn_item_get_prop(item_id, PROP_ITEM_REGISTER_TEAM) != get_user_current_class_type(id))
		return ITEM_DISABLED

	new extra_text[ZPN_ITEM_EXTRA_TEXT_SIZE]
	return zpn_item_preview_buy(id, item_id, extra_text, charsmax(extra_text)) == ITEM_BUY_SUCCESS ? ITEM_ENABLED : ITEM_DISABLED
}

public _buy_items(id, menu, item)
{
	new info[12]
	if(!read_menu_selection(id, menu, item, info, charsmax(info)))
		return PLUGIN_HANDLED

	new item_id = str_to_num(info)
	if(!(0 <= item_id < zpn_item_array_size())
	|| eClassTypes:zpn_item_get_prop(item_id, PROP_ITEM_REGISTER_TEAM) != get_user_current_class_type(id))
		return PLUGIN_HANDLED

	new eItemBuyResults:result = zpn_item_buy(id, item_id)
	if(!is_menu_client(id))
		return PLUGIN_HANDLED

	switch(result)
	{
		case ITEM_BUY_INVALID:
		{
			zpn_print_color(id, print_team_red, "^3Este item não está disponível.")
			return PLUGIN_HANDLED
		}
		case ITEM_BUY_BLOCKED: zpn_print_color(id, print_team_red, "^3A compra deste item foi bloqueada.")
		case ITEM_BUY_NOT_ENOUGH_ZOMBIES: zpn_print_color(id, print_team_red, "^3Este item exige pelo menos ^4%d zumbis vivos^3.", zpn_item_get_prop(item_id, PROP_ITEM_REGISTER_MIN_ZOMBIES))
		case ITEM_BUY_LIMIT_REACHED: zpn_print_color(id, print_team_red, "^3Limite de compras deste item atingido.")
		case ITEM_BUY_NO_AMMO_PACKS: zpn_print_color(id, print_team_red, "^3Você não tem ^4Ammo Packs ^3suficiente.")
		case ITEM_BUY_SUCCESS: return PLUGIN_HANDLED
	}

	buy_items(id)
	return PLUGIN_HANDLED
}

bool:select_class_type(const id)
{
	if(!is_menu_client(id))
		return false

	new forward_return
	ExecuteForward(xForwards[FW_SHOW_MENU_CLASS_TYPE_PRE], forward_return, id)
	if(forward_return >= ZPN_RETURN_HANDLED || !is_menu_client(id))
		return false

	new menu = menu_create(fmt("%s \yEscolha a raça", xMenuPrefix), "_select_class_type")
	menu_additem(menu, fmt("Zombie \y(\d%d classes\y)", count_class(CLASS_TEAM_TYPE_ZOMBIE)), fmt("%d", CLASS_TEAM_TYPE_ZOMBIE))
	menu_additem(menu, fmt("Humano \y(\d%d classes\y)", count_class(CLASS_TEAM_TYPE_HUMAN)), fmt("%d", CLASS_TEAM_TYPE_HUMAN))
	display_menu(id, menu, .parent = MENU_PARENT_GAME)

	ExecuteForward(xForwards[FW_SHOW_MENU_CLASS_TYPE_POST], forward_return, id)
	return true
}

public _select_class_type(id, menu, item)
{
	new info[12]
	if(!read_menu_selection(id, menu, item, info, charsmax(info)))
		return PLUGIN_HANDLED

	select_class(id, eClassTypes:str_to_num(info))
	return PLUGIN_HANDLED
}

bool:select_class(const id, const eClassTypes:class_type)
{
	if(!is_menu_client(id) || (class_type != CLASS_TEAM_TYPE_ZOMBIE && class_type != CLASS_TEAM_TYPE_HUMAN))
		return false

	if(count_class(class_type) <= 0)
	{
		zpn_print_color(id, print_team_red, "^3Nenhuma classe encontrada.")
		return false
	}

	new forward_return
	ExecuteForward(xForwards[FW_SHOW_MENU_CLASS_PRE], forward_return, id, class_type)
	if(forward_return >= ZPN_RETURN_HANDLED || !is_menu_client(id))
		return false

	new menu = menu_create(fmt("%s \ySelecionar classe: %s", xMenuPrefix, class_type == CLASS_TEAM_TYPE_ZOMBIE ? "\rZombie" : "\yHumano"), "_select_class")
	new name[32], class_info[32], item_text[160], level_text[32], limit_text[32], selected_text[12]
	new user_level = zpn_level_get_user_level(id)
	new selected = zpn_get_user_next_class(id, class_type)
	if(selected == -1)
		selected = zpn_get_user_selected_class(id, class_type)

	for(new i = 0; i < zpn_class_array_size(); i++)
	{
		if(zpn_class_get_prop(i, PROP_CLASS_REGISTER_TYPE) != class_type
		|| zpn_class_get_prop(i, PROP_CLASS_REGISTER_HIDE_MENU))
			continue

		new required_level = zpn_class_get_prop(i, PROP_CLASS_REGISTER_LEVEL)
		new limit = zpn_class_get_prop(i, PROP_CLASS_REGISTER_LIMIT)
		new bool:locked = user_level < required_level || !zpn_class_has_free_slot(i, id)
		zpn_class_get_prop(i, PROP_CLASS_REGISTER_NAME, name, charsmax(name))
		zpn_class_get_prop(i, PROP_CLASS_REGISTER_INFO, class_info, charsmax(class_info))

		if(required_level > 0)
			formatex(level_text, charsmax(level_text), " \d(Lvl: %d)", required_level)
		else level_text[0] = EOS

		if(limit > 0)
			formatex(limit_text, charsmax(limit_text), " \d(Lmt: %d/%d)", zpn_class_get_user_count(i), limit)
		else limit_text[0] = EOS

		if(i == selected)
			copy(selected_text, charsmax(selected_text), " \r•")
		else selected_text[0] = EOS

		formatex(item_text, charsmax(item_text), "%s%s \y(\d%s\y)%s%s%s", locked ? "\d" : "\w", name, class_info, level_text, limit_text, selected_text)
		menu_additem(menu, item_text, fmt("%d", i))
	}

	display_menu(id, menu, .parent = MENU_PARENT_CLASS_TYPE)
	ExecuteForward(xForwards[FW_SHOW_MENU_CLASS_POST], forward_return, id, class_type)
	return true
}

public _select_class(id, menu, item)
{
	new info[12]
	if(!read_menu_selection(id, menu, item, info, charsmax(info)))
		return PLUGIN_HANDLED

	new class_id = str_to_num(info)
	new eClassSelectResults:result = zpn_select_user_class(id, class_id)
	if(!is_menu_client(id) || result == CLASS_SELECT_INVALID)
		return PLUGIN_HANDLED

	new name[32]
	zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_NAME, name, charsmax(name))
	switch(result)
	{
		case CLASS_SELECT_LEVEL_REQUIRED:
		{
			zpn_print_color(id, print_team_red, "^3Voce precisa estar no ^4Level %d ^3para usar esta classe. Seu level: ^4%d^1.", zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_LEVEL), zpn_level_get_user_level(id))
			return PLUGIN_HANDLED
		}
		case CLASS_SELECT_LIMIT_REACHED:
		{
			zpn_print_color(id, print_team_red, "^3A classe ^4%s ^3esta lotada (^4%d/%d^3).", name, zpn_class_get_user_count(class_id), zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_LIMIT))
			return PLUGIN_HANDLED
		}
		case CLASS_SELECT_COOLDOWN:
		{
			zpn_print_color(id, print_team_default, "^3Espere: ^4%.0f ^3segundos para alterar de classe novamente.", zpn_player_data_get_prop(id, PROP_PD_REGISTER_CLASS_TIMEOUT) - get_gametime())
			return PLUGIN_HANDLED
		}
		case CLASS_SELECT_APPLIED:
		{
			class_id = zpn_get_user_current_class(id)
			if(class_id < 0 || class_id >= zpn_class_array_size())
				return PLUGIN_HANDLED
			zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_NAME, name, charsmax(name))
			zpn_print_color(id, print_team_default, "^3Agora sua classe e: ^4%s^1.", name)
		}
		case CLASS_SELECT_RESERVED: zpn_print_color(id, print_team_default, "^3Classe reservada para a proxima aplicacao: ^4%s^1.", name)
	}

	new Float:health = zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_HEALTH)
	new Float:gravity = zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_GRAVITY)
	new Float:speed = zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_SPEED)
	zpn_print_color(id, print_team_default, "^3Vida: ^1%s ^4- ^3Gravidade: ^1%d ^4- ^3Velocidade: ^1%0.0f", format_number_point(floatround(health)), floatround(gravity * 800.0), speed)
	return PLUGIN_HANDLED
}

bool:select_weapon_menu(const id, const eWeaponTypes:type)
{
	if(!is_menu_client(id) || zpn_is_user_zombie(id))
		return false

	if(zpn_is_round_started())
	{
		zpn_print_color(id, print_team_red, "^3Seleção de armas resetadas! ^1Espere o fim da rodada.")
		return false
	}

	new forward_return
	new pre = type == ZPN_WEAPON_PRIMARY ? FW_SHOW_MENU_PRIMARY_WEAPON_PRE : FW_SHOW_MENU_SECONDARY_WEAPON_PRE
	new post = type == ZPN_WEAPON_PRIMARY ? FW_SHOW_MENU_PRIMARY_WEAPON_POST : FW_SHOW_MENU_SECONDARY_WEAPON_POST
	ExecuteForward(xForwards[pre], forward_return, id)
	if(forward_return >= ZPN_RETURN_HANDLED || !is_menu_client(id)
	|| zpn_is_user_zombie(id) || zpn_is_round_started())
		return false

	if(zpn_weapon_count(type) <= 0)
	{
		zpn_print_color(id, print_team_red, "^3Nenhuma arma encontrada.")
		return false
	}

	new menu = menu_create(fmt("%s \ySelecionar arma %s", xMenuPrefix, type == ZPN_WEAPON_PRIMARY ? "primária" : "secundária"), type == ZPN_WEAPON_PRIMARY ? "_select_primary_weapon" : "_select_secondary_weapon")
	new weapon[32]
	for(new i = 0; i < zpn_weapon_count(type); i++)
	{
		if(!zpn_weapon_get_name(type, i, weapon, charsmax(weapon)))
			continue

		mb_strtotitle(weapon[7])
		menu_additem(menu, weapon[7], fmt("%d", i))
	}

	display_menu(id, menu, .parent = type == ZPN_WEAPON_PRIMARY ? MENU_PARENT_GAME : MENU_PARENT_PRIMARY_WEAPON)
	ExecuteForward(xForwards[post], forward_return, id)
	return true
}

public _select_primary_weapon(id, menu, item)
{
	new info[12]
	if(!read_menu_selection(id, menu, item, info, charsmax(info)))
		return PLUGIN_HANDLED

	if(zpn_select_user_weapon(id, ZPN_WEAPON_PRIMARY, str_to_num(info)))
		select_weapon_menu(id, ZPN_WEAPON_SECONDARY)
	return PLUGIN_HANDLED
}

public _select_secondary_weapon(id, menu, item)
{
	new info[12]
	if(!read_menu_selection(id, menu, item, info, charsmax(info)))
		return PLUGIN_HANDLED

	zpn_select_user_weapon(id, ZPN_WEAPON_SECONDARY, str_to_num(info))
	return PLUGIN_HANDLED
}

bool:is_menu_client(const id)
{
	return zpn_is_valid_player_connected(id) && !is_user_bot(id) && !is_user_hltv(id)
}

display_menu(const id, const menu, const page = 0, const eMenuParents:parent = MENU_PARENT_NONE, const parent_data = -1)
{
	menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
	menu_setprop(menu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
	menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, parent == MENU_PARENT_NONE ? "EXIT" : "BACK"))
	menu_display(id, menu, clamp(page, 0, menu_pages(menu) - 1))

	// Displaying a replacement may cancel the old menu; discard its queued return.
	xMenuReturnUserid[id] = 0
	xDisplayedMenu[id] = menu
	xMenuParent[id] = parent
	xMenuParentData[id] = parent_data
}

close_menu(const id, const menu, const item)
{
	if(xDisplayedMenu[id] == menu)
	{
		xDisplayedMenu[id] = -1
		if(item == MENU_EXIT && xMenuParent[id] != MENU_PARENT_NONE && is_menu_client(id))
		{
			xMenuReturn[id] = xMenuParent[id]
			xMenuReturnData[id] = xMenuParentData[id]
			xMenuReturnUserid[id] = get_user_userid(id)
			RequestFrame("return_to_parent_menu", xMenuReturnUserid[id])
		}
	}
	menu_destroy(menu)
}

public return_to_parent_menu(const userid)
{
	new id = find_player_ex(FindPlayer_MatchUserId, userid)
	if(!is_menu_client(id) || xMenuReturnUserid[id] != userid)
		return

	xMenuReturnUserid[id] = 0
	new menu, newmenu
	player_menu_info(id, menu, newmenu)
	if(menu > 0 || newmenu >= 0)
		return

	// MENU_EXIT also covers cancellations; reopen only with no replacement menu.
	switch(xMenuReturn[id])
	{
		case MENU_PARENT_GAME: show_menu_game(id)
		case MENU_PARENT_ADMIN: admin_menu(id)
		case MENU_PARENT_ADMIN_SPECIAL_CLASSES:
		{
			new class_id = xMenuReturnData[id]
			if(is_admin_special_class(class_id))
				admin_special_classes(id, eClassTypes:zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_TYPE))
		}
		case MENU_PARENT_CLASS_TYPE: select_class_type(id)
		case MENU_PARENT_PRIMARY_WEAPON: select_weapon_menu(id, ZPN_WEAPON_PRIMARY)
	}
}

bool:read_menu_selection(const id, const menu, const item, info[], const maxlen)
{
	new bool:selected = false
	if(is_menu_client(id) && item >= 0)
		selected = bool:menu_item_getinfo(menu, item, .info = info, .infolen = maxlen)

	// Each menu is created for one display; cancellation also ends its ownership.
	close_menu(id, menu, item)
	return selected
}

eClassTypes:get_user_current_class_type(const id)
{
	new class_id = zpn_get_user_current_class(id)
	if(0 <= class_id < zpn_class_array_size())
		return eClassTypes:zpn_class_get_prop(class_id, PROP_CLASS_REGISTER_TYPE)

	return zpn_is_user_zombie(id) ? CLASS_TEAM_TYPE_ZOMBIE : CLASS_TEAM_TYPE_HUMAN
}

count_alive_zombies()
{
	new count
	for(new id = 1; id <= MaxClients; id++)
	{
		if(is_user_alive(id) && zpn_is_user_zombie(id))
			count++
	}
	return count
}

count_item(const eClassTypes:item_team)
{
	new count
	for(new i = 0; i < zpn_item_array_size(); i++)
	{
		if(eClassTypes:zpn_item_get_prop(i, PROP_ITEM_REGISTER_TEAM) == item_team)
			count++
	}
	return count
}

count_class(const eClassTypes:class_type)
{
	new count
	for(new i = 0; i < zpn_class_array_size(); i++)
	{
		if(zpn_class_get_prop(i, PROP_CLASS_REGISTER_TYPE) == class_type
		&& !zpn_class_get_prop(i, PROP_CLASS_REGISTER_HIDE_MENU))
			count++
	}
	return count
}

format_number_point(const number)
{
	new str[16], count
	static output[24]
	output[0] = EOS
	num_to_str(number, str, charsmax(str))
	new len = strlen(str)
	for(new i = 0; i < len; i++)
	{
		if(i > 0 && str[i - 1] != '-' && (len - i) % 3 == 0)
			output[count++] = '.'
		output[count++] = str[i]
	}
	output[count] = EOS
	return output
}
