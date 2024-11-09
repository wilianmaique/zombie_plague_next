#include <amxmodx>
#include <fakemeta>
#include <reapi>

new Array:xSpawnPoints, xLastSpawnId

public plugin_precache()
{
    register_plugin("[ZPN] Addon: Spawn Spot Fix Prevent", "1.0", "BRUN0")

    xSpawnPoints = ArrayCreate(1, 0)
    xLastSpawnId = 0
}

public plugin_init()
{
    RegisterHookChain(RG_CSGameRules_RestartRound, "@CSGameRules_RestartRound_Post", true)
    RegisterHookChain(RG_CSGameRules_GetPlayerSpawnSpot, "@CSGameRules_GetPlayerSpawnSpot_Pre", false)
    ForceLevelInitialize()
}

@CSGameRules_RestartRound_Post() ForceLevelInitialize();

public plugin_end()
{
    ArrayDestroy(xSpawnPoints)
}

ForceLevelInitialize()
{
    if(!ArraySize(xSpawnPoints))
    {
        AddSpawnPoints("info_player_start")
        AddSpawnPoints("info_player_deathmatch")
    }

    new spawnPointsNum = ArraySize(xSpawnPoints)

    set_member_game(m_iSpawnPointCount_Terrorist, spawnPointsNum)
    set_member_game(m_iSpawnPointCount_CT, spawnPointsNum)
}

AddSpawnPoints(const entityClass[])
{
    new ent = NULLENT

    while((ent = rg_find_ent_by_class(ent, entityClass, true)))
        ArrayPushCell(xSpawnPoints, ent)
}

@CSGameRules_GetPlayerSpawnSpot_Pre(const id)
{
    new TeamName:team = get_member(id, m_iTeam)

    if(team != TEAM_TERRORIST && team != TEAM_CT)
        return HC_CONTINUE

    new spot = EntSelectSpawnPoint(id)

    if(is_nullent(spot))
        return HC_CONTINUE

    new Float:vecOrigin[3], Float:vecAngles[3]

    get_entvar(spot, var_origin, vecOrigin)
    get_entvar(spot, var_angles, vecAngles)

    vecOrigin[2] += 1.0

    set_entvar(id, var_origin, vecOrigin)
    set_entvar(id, var_angles, vecAngles)
    set_entvar(id, var_fixangle, 1)

    SetHookChainReturn(ATYPE_INTEGER, spot)

    return HC_SUPERCEDE
}

EntSelectSpawnPoint(const id)
{
    new spawnPointsNum = ArraySize(xSpawnPoints)

    if(!spawnPointsNum)
        return 0

    new spotId = xLastSpawnId
    new spot, Float:vecOrigin[3]

    for(new i = 0; i < spawnPointsNum; i++) 
    {
        spotId = (spotId + 1) % spawnPointsNum
        spot = ArrayGetCell(xSpawnPoints, spotId)

        if(is_nullent(spot))
            continue

        get_entvar(spot, var_origin, vecOrigin)

        if(IsHullVacant(id, vecOrigin, HULL_HUMAN))
            break
    }

    if(is_nullent(spot))
        return 0

    xLastSpawnId = spotId

    return spot
}

bool:IsHullVacant(id, Float:vecOrigin[3], hull)
{
	engfunc(EngFunc_TraceHull, vecOrigin, vecOrigin, 0, hull, id, 0)

	if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
		return false

	return true
}