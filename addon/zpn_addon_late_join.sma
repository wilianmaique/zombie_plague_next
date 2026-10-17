#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

const TASK_LATE_JOIN = 1000

new gAllowedModes[512]
new Float:gRespawnDelay
new bool:gFirstJoin[33]

public plugin_init()
{
	register_plugin("[ZPN] Addon: Late Join Zombie", "1.1", "Wilian M.")

	if(!is_regamedll())
	{
		set_fail_state("[ZPN] Late Join Zombie requer ReGameDLL_CS.")
		return
	}

	RegisterHookChain(RG_CBasePlayer_GetIntoGame, "CBasePlayer_GetIntoGame_Post", true)
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false)

	bind_pcvar_string(create_cvar("zpn_late_join_modes", "gm_infection gm_escape", .description = "Modos que revivem atrasados como zombie, separados por espacos (ex.: gm_infection gm_escape). Vazio desativa."), gAllowedModes, charsmax(gAllowedModes))
	bind_pcvar_float(create_cvar("zpn_late_join_delay", "3.0", .description = "Segundos de espera para reviver apos concluir a entrada em jogo.", .has_min = true, .min_val = 0.1), gRespawnDelay)
	AutoExecConfig(true, "zpn_addon_late_join", FOLDER_CVARS_CONFIG)
}

public client_putinserver(id)
{
	remove_task(id + TASK_LATE_JOIN)
	gFirstJoin[id] = !is_user_hltv(id)
}

public client_disconnected(id)
{
	remove_task(id + TASK_LATE_JOIN)
	gFirstJoin[id] = false
}

public zpn_user_spawn_post(const id)
{
	remove_task(id + TASK_LATE_JOIN)
	gFirstJoin[id] = false
}

public CSGameRules_RestartRound_Pre()
{
	for(new id = 1; id <= MaxClients; id++)
		remove_task(id + TASK_LATE_JOIN)
}

public CBasePlayer_GetIntoGame_Post(const this)
{
	if(!gFirstJoin[this] || !is_user_connected(this))
		return HC_CONTINUE

	if(!IsReapiHookOriginalWasCalled(RG_CBasePlayer_GetIntoGame)
	|| !GetHookChainReturn(ATYPE_BOOL) || get_member(this, m_iJoiningState) != JOINED)
		return HC_CONTINUE

	new TeamName:team = get_member(this, m_iTeam)
	if(team != TEAM_TERRORIST && team != TEAM_CT)
		return HC_CONTINUE

	gFirstJoin[this] = false

	if(is_user_alive(this) || !is_allowed_round())
		return HC_CONTINUE

	new data[2]
	data[0] = get_user_userid(this)
	data[1] = zpn_get_current_gamemode()
	set_task_ex(gRespawnDelay, "respawn_late_join", this + TASK_LATE_JOIN, data, sizeof(data))

	return HC_CONTINUE
}

public respawn_late_join(const data[], task_id)
{
	new id = task_id - TASK_LATE_JOIN
	if(id < 1 || id > MaxClients || !is_user_connected(id)
	|| get_user_userid(id) != data[0] || is_user_alive(id)
	|| get_member(id, m_iJoiningState) != JOINED)
		return

	new TeamName:team = get_member(id, m_iTeam)
	if((team != TEAM_TERRORIST && team != TEAM_CT)
	|| !is_allowed_round() || zpn_get_current_gamemode() != data[1])
		return

	new bool:was_zombie = zpn_is_user_zombie(id)

	zpn_player_data_set_prop(id, PROP_PD_REGISTER_IS_ZOMBIE, true)
	rg_round_respawn(id)

	if(is_user_connected(id) && !is_user_alive(id))
		zpn_player_data_set_prop(id, PROP_PD_REGISTER_IS_ZOMBIE, was_zombie)
}

bool:is_allowed_round()
{
	if(!zpn_is_round_started() || get_member_game(m_bRoundTerminating))
		return false

	new gamemode = zpn_get_current_gamemode()
	if(gamemode < 0 || gamemode >= zpn_gamemode_array_size())
		return false

	new name[32], mode[sizeof(gAllowedModes)], pos
	zpn_gamemode_get_prop(gamemode, PROP_GAMEMODE_REGISTER_FIND_NAME, name, charsmax(name))

	while((pos = argparse(gAllowedModes, pos, mode, charsmax(mode))) != -1)
	{
		if(equal(mode, name))
			return true
	}

	return false
}
