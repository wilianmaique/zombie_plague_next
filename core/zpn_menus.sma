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

new xForwards[eForwards] = { -1, ... }
new xMenuPrefix[32], xBuyItemCallback

public plugin_precache()
{
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
	menu_additem(menu, "\yAdministração")
	display_menu(id, menu)

	ExecuteForward(xForwards[FW_SHOW_MENU_GAME_POST], forward_return, id)
	return true
}

public _show_menu_game(id, menu, item)
{
	menu_destroy(menu)
	if(!is_menu_client(id) || item < 0)
		return PLUGIN_HANDLED

	switch(item)
	{
		case 0: select_weapon_menu(id, ZPN_WEAPON_PRIMARY)
		case 1: buy_items(id)
		case 2: select_class_type(id)
		case 3: client_print(id, print_chat, "admin")
	}

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

	display_menu(id, menu)
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
	display_menu(id, menu)

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

	display_menu(id, menu)
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

	display_menu(id, menu)
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

display_menu(const id, const menu)
{
	menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
	menu_setprop(menu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
	menu_setprop(menu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))
	menu_display(id, menu)
}

bool:read_menu_selection(const id, const menu, const item, info[], const maxlen)
{
	new bool:selected = false
	if(is_menu_client(id) && item >= 0)
		selected = bool:menu_item_getinfo(menu, item, .info = info, .infolen = maxlen)

	// Each menu is created for one display; cancellation also ends its ownership.
	menu_destroy(menu)
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
