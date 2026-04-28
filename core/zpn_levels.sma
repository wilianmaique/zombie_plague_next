#include <amxmodx>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

#define MIN_LEVEL 1

enum _:eCvars
{
	Float:CVAR_DAMAGE_REQUIRED,
	CVAR_DAMAGE_REWARD,
	CVAR_INFECT_REWARD,
	Float:CVAR_XP_MULTIPLIER,
	CVAR_XP_BASE,
	CVAR_XP_PER_LEVEL,
	CVAR_XP_RANK_STEP,
	CVAR_ANNOUNCE,
}

enum _:eForwards
{
	FW_XP_CHANGED_POST,
	FW_LEVEL_CHANGED_POST,
}

new const xRankNames[][] =
{
	"Recruta",
	"Soldado",
	"Soldado Primeira Classe",
	"Cabo",
	"Cabo Veterano",
	"Sargento",
	"Sargento de Elite",
	"Subtenente",
	"Aspirante",
	"Segundo Tenente",
	"Primeiro Tenente",
	"Capitao",
	"Major",
	"Tenente-Coronel",
	"Coronel",
	"General de Brigada",
	"General de Divisao",
	"General de Exercito",
	"Comandante",
	"Comandante Tatico",
	"Executor",
	"Vanguarda",
	"Guardiao",
	"Predador",
	"Ceifador",
	"Carrasco",
	"Dominador",
	"Lenda",
	"Mito",
	"Apocalipse"
}

new xCvars[eCvars]
new xForwards[eForwards], xForwardReturn

new xUserLevel[33]
new xUserXp[33]
new Float:xUserDamage[33]

public plugin_precache()
{
	bind_pcvar_float(create_cvar("zpn_level_dmg_reached", "100.0", .has_min = true, .min_val = 10.0, .has_max = true, .max_val = 10000.0), xCvars[CVAR_DAMAGE_REQUIRED])
	bind_pcvar_num(create_cvar("zpn_level_dmg_xp", "8", .has_min = true, .min_val = 1.0, .has_max = true, .max_val = 10000.0), xCvars[CVAR_DAMAGE_REWARD])
	bind_pcvar_num(create_cvar("zpn_level_infect_xp", "250", .has_min = true, .min_val = 1.0, .has_max = true, .max_val = 100000.0), xCvars[CVAR_INFECT_REWARD])
	bind_pcvar_float(create_cvar("zpn_level_multiplier", "1.0", .has_min = true, .min_val = 0.1, .has_max = true, .max_val = 100.0), xCvars[CVAR_XP_MULTIPLIER])
	bind_pcvar_num(create_cvar("zpn_level_xp_base", "120", .has_min = true, .min_val = 1.0, .has_max = true, .max_val = 1000000.0), xCvars[CVAR_XP_BASE])
	bind_pcvar_num(create_cvar("zpn_level_xp_per_level", "18", .has_min = true, .min_val = 1.0, .has_max = true, .max_val = 100000.0), xCvars[CVAR_XP_PER_LEVEL])
	bind_pcvar_num(create_cvar("zpn_level_xp_rank_step", "75", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 100000.0), xCvars[CVAR_XP_RANK_STEP])
	bind_pcvar_num(create_cvar("zpn_level_announce", "1", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_ANNOUNCE])
}

public plugin_init()
{
	register_plugin("[ZPN] Core: Levels", "1.0", "Wilian M.")

	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre", false)
	RegisterHookChain(RG_RoundEnd, "RoundEnd_Pre", false)

	register_clcmd("say /level", "clcmd_level")
	register_clcmd("say_team /level", "clcmd_level")
	register_clcmd("say /xp", "clcmd_level")
	register_clcmd("say_team /xp", "clcmd_level")
	register_clcmd("say /rank", "clcmd_level")
	register_clcmd("say_team /rank", "clcmd_level")
	register_clcmd("zpn_level", "clcmd_level")

	xForwards[FW_XP_CHANGED_POST] = CreateMultiForward("zpn_level_user_xp_changed", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL)
	xForwards[FW_LEVEL_CHANGED_POST] = CreateMultiForward("zpn_level_user_level_changed", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
}

public plugin_natives()
{
	register_library("zombie_plague_next_levels")

	register_native("zpn_level_get_user_level", "_zpn_level_get_user_level")
	register_native("zpn_level_set_user_level", "_zpn_level_set_user_level")
	register_native("zpn_level_get_user_xp", "_zpn_level_get_user_xp")
	register_native("zpn_level_set_user_xp", "_zpn_level_set_user_xp")
	register_native("zpn_level_add_user_xp", "_zpn_level_add_user_xp")
	register_native("zpn_level_get_required_xp", "_zpn_level_get_required_xp")
	register_native("zpn_level_get_user_required_xp", "_zpn_level_get_user_required_xp")
	register_native("zpn_level_get_rank_index", "_zpn_level_get_rank_index")
	register_native("zpn_level_get_user_rank_name", "_zpn_level_get_user_rank_name")
	register_native("zpn_level_get_rank_name", "_zpn_level_get_rank_name")
}

public client_putinserver(id)
{
	reset_user_level(id)
}

public client_disconnected(id)
{
	reset_user_level(id)
}

public CBasePlayer_TakeDamage_Pre(const victim, pevInflictor, attacker, Float:flDamage, bitsDamageType)
{
	if(victim == attacker || flDamage <= 0.0 || !zpn_is_valid_player_alive(attacker) || !zpn_is_valid_player_alive(victim))
		return HC_CONTINUE

	if(zpn_is_user_zombie(attacker) || !zpn_is_user_zombie(victim))
		return HC_CONTINUE

	new Float:health
	get_entvar(victim, var_health, health)

	if(health > 0.0 && flDamage > health)
		flDamage = health

	reward_damage(attacker, flDamage)

	return HC_CONTINUE
}

public RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event, Float:delay)
{
	for(new id = 1; id <= MaxClients; id++)
	{
		if(is_user_connected(id))
			xUserDamage[id] = 0.0
	}
}

public zpn_user_infected_post(const this, const infector, const class_id)
{
	if(this == infector || !zpn_is_valid_player_connected(infector))
		return

	if(!zpn_is_user_zombie(infector))
		return

	add_user_xp(infector, xCvars[CVAR_INFECT_REWARD], ZPN_LEVEL_XP_CHANGE_INFECT_REWARD)
}

public clcmd_level(id)
{
	if(!zpn_is_valid_player_connected(id))
		return PLUGIN_HANDLED

	new rankName[32], xp[16], requiredXp[16]

	get_user_rank_name(id, rankName, charsmax(rankName))
	format_number_point(xUserXp[id], xp, charsmax(xp))
	format_number_point(get_required_xp(xUserLevel[id]), requiredXp, charsmax(requiredXp))

	if(xUserLevel[id] >= MAX_LEVEL)
		zpn_print_color(id, print_team_default, "^3Level: ^4%d ^1| ^3Patente: ^4%s ^1| ^3XP: ^4MAX", xUserLevel[id], rankName)
	else
		zpn_print_color(id, print_team_default, "^3Level: ^4%d ^1| ^3Patente: ^4%s ^1| ^3XP: ^4%s^1/^4%s", xUserLevel[id], rankName, xp, requiredXp)

	return PLUGIN_HANDLED
}

public _zpn_level_get_user_level(plugin_id, param_nums)
{
	if(param_nums != 1)
		return 0

	return get_user_level(get_param(1))
}

public bool:_zpn_level_set_user_level(plugin_id, param_nums)
{
	if(param_nums != 2)
		return false

	return set_user_level(get_param(1), get_param(2))
}

public _zpn_level_get_user_xp(plugin_id, param_nums)
{
	if(param_nums != 1)
		return 0

	return get_user_xp(get_param(1))
}

public bool:_zpn_level_set_user_xp(plugin_id, param_nums)
{
	if(param_nums != 3)
		return false

	return set_user_xp(get_param(1), get_param(2), eLevelXpChangeReasons:get_param(3))
}

public bool:_zpn_level_add_user_xp(plugin_id, param_nums)
{
	if(param_nums != 3)
		return false

	return add_user_xp(get_param(1), get_param(2), eLevelXpChangeReasons:get_param(3))
}

public _zpn_level_get_required_xp(plugin_id, param_nums)
{
	if(param_nums != 1)
		return 0

	return get_required_xp(get_param(1))
}

public _zpn_level_get_user_required_xp(plugin_id, param_nums)
{
	if(param_nums != 1)
		return 0

	new id = get_param(1)

	if(!zpn_is_valid_player_connected(id))
		return 0

	return get_required_xp(xUserLevel[id])
}

public _zpn_level_get_rank_index(plugin_id, param_nums)
{
	if(param_nums != 1)
		return 0

	return get_rank_index(get_param(1))
}

public bool:_zpn_level_get_user_rank_name(plugin_id, param_nums)
{
	if(param_nums != 3)
		return false

	new id = get_param(1)

	if(!zpn_is_valid_player_connected(id))
		return false

	set_string(2, xRankNames[get_rank_index(xUserLevel[id])], get_param(3))

	return true
}

public bool:_zpn_level_get_rank_name(plugin_id, param_nums)
{
	if(param_nums != 3)
		return false

	set_string(2, xRankNames[get_rank_index(get_param(1))], get_param(3))

	return true
}

reward_damage(const id, const Float:damage)
{
	if(xCvars[CVAR_DAMAGE_REQUIRED] <= 0.0 || xCvars[CVAR_DAMAGE_REWARD] <= 0)
		return

	new Float:damageProgress = xUserDamage[id] + damage
	new rewards = floatround(damageProgress / xCvars[CVAR_DAMAGE_REQUIRED], floatround_floor)

	if(rewards > 0)
		damageProgress -= (xCvars[CVAR_DAMAGE_REQUIRED] * rewards)

	xUserDamage[id] = damageProgress

	if(rewards > 0)
		add_user_xp(id, rewards * xCvars[CVAR_DAMAGE_REWARD], ZPN_LEVEL_XP_CHANGE_DAMAGE_REWARD)
}

bool:add_user_xp(const id, const amount, const eLevelXpChangeReasons:reason)
{
	if(amount <= 0 || !zpn_is_valid_player_connected(id) || xUserLevel[id] >= MAX_LEVEL)
		return false

	new scaledAmount = multiply_xp(amount)

	if(scaledAmount <= 0)
		return false

	new oldXp = xUserXp[id]
	new oldLevel = xUserLevel[id]

	if(scaledAmount > 2000000000 - xUserXp[id])
		scaledAmount = 2000000000 - xUserXp[id]

	xUserXp[id] += scaledAmount
	normalize_user_level(id)

	ExecuteForward(xForwards[FW_XP_CHANGED_POST], xForwardReturn, id, xUserXp[id], oldXp, scaledAmount, reason)

	if(xUserLevel[id] != oldLevel)
	{
		ExecuteForward(xForwards[FW_LEVEL_CHANGED_POST], xForwardReturn, id, xUserLevel[id], oldLevel)
		announce_level_up(id, oldLevel)
	}

	return true
}

bool:set_user_xp(const id, const amount, const eLevelXpChangeReasons:reason)
{
	if(amount < 0 || !zpn_is_valid_player_connected(id))
		return false

	new oldXp = xUserXp[id]
	new oldLevel = xUserLevel[id]

	xUserXp[id] = amount
	normalize_user_level(id)

	ExecuteForward(xForwards[FW_XP_CHANGED_POST], xForwardReturn, id, xUserXp[id], oldXp, amount - oldXp, reason)

	if(xUserLevel[id] != oldLevel)
		ExecuteForward(xForwards[FW_LEVEL_CHANGED_POST], xForwardReturn, id, xUserLevel[id], oldLevel)

	return true
}

bool:set_user_level(const id, level)
{
	if(!zpn_is_valid_player_connected(id))
		return false

	level = clamp(level, MIN_LEVEL, MAX_LEVEL)

	new oldLevel = xUserLevel[id]

	if(oldLevel == level)
		return true

	xUserLevel[id] = level

	if(xUserLevel[id] >= MAX_LEVEL)
		xUserXp[id] = 0

	sync_user_level(id)
	ExecuteForward(xForwards[FW_LEVEL_CHANGED_POST], xForwardReturn, id, xUserLevel[id], oldLevel)

	return true
}

get_user_level(const id)
{
	if(!zpn_is_valid_player_connected(id))
		return 0

	return xUserLevel[id]
}

get_user_xp(const id)
{
	if(!zpn_is_valid_player_connected(id))
		return 0

	return xUserXp[id]
}

normalize_user_level(const id)
{
	new requiredXp

	while(xUserLevel[id] < MAX_LEVEL)
	{
		requiredXp = get_required_xp(xUserLevel[id])

		if(requiredXp <= 0 || xUserXp[id] < requiredXp)
			break

		xUserXp[id] -= requiredXp
		xUserLevel[id]++
	}

	if(xUserLevel[id] >= MAX_LEVEL)
		xUserXp[id] = 0

	sync_user_level(id)
}

sync_user_level(const id)
{
	if(1 <= id <= MaxClients)
		zpn_player_data_set_prop(id, PROP_PD_REGISTER_LEVEL, xUserLevel[id])
}

get_required_xp(level)
{
	level = clamp(level, MIN_LEVEL, MAX_LEVEL)

	if(level >= MAX_LEVEL)
		return 0

	new requiredXp = xCvars[CVAR_XP_BASE] + (level * xCvars[CVAR_XP_PER_LEVEL]) + (get_rank_index(level) * xCvars[CVAR_XP_RANK_STEP])

	if(requiredXp < 1)
		requiredXp = 1

	return requiredXp
}

get_rank_index(level)
{
	level = clamp(level, MIN_LEVEL, MAX_LEVEL)

	new rank = ((level - MIN_LEVEL) * sizeof(xRankNames)) / (MAX_LEVEL - MIN_LEVEL + 1)

	if(rank < 0)
		rank = 0

	if(rank >= sizeof(xRankNames))
		rank = sizeof(xRankNames) - 1

	return rank
}

get_user_rank_name(const id, rankName[], len)
{
	copy(rankName, len, xRankNames[get_rank_index(xUserLevel[id])])
}

multiply_xp(const amount)
{
	new scaledAmount = floatround(float(amount) * xCvars[CVAR_XP_MULTIPLIER], floatround_floor)

	if(scaledAmount < 1)
		scaledAmount = 1

	return scaledAmount
}

announce_level_up(const id, const oldLevel)
{
	if(!xCvars[CVAR_ANNOUNCE] || !is_user_connected(id))
		return

	new rankName[32]
	get_user_rank_name(id, rankName, charsmax(rankName))

	zpn_print_color(id, print_team_default, "^3Voce subiu do level ^4%d ^3para ^4%d ^1- ^3Patente: ^4%s^1.", oldLevel, xUserLevel[id], rankName)
}

reset_user_level(const id)
{
	if(!(1 <= id <= MaxClients))
		return

	xUserLevel[id] = MIN_LEVEL
	xUserXp[id] = 0
	xUserDamage[id] = 0.0

	sync_user_level(id)
}

format_number_point(const number, output[], len)
{
	new source[16], sourceLen, outputPos

	num_to_str(number, source, charsmax(source))
	sourceLen = strlen(source)
	output[0] = EOS

	for(new i = 0; i < sourceLen && outputPos < len; i++)
	{
		if(i != 0 && ((sourceLen - i) % 3 == 0) && outputPos < len - 1)
			output[outputPos++] = '.'

		output[outputPos++] = source[i]
	}

	output[outputPos] = EOS
}
