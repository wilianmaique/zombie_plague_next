#include <amxmodx>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new const sounds[][] =
{
    "zpn/return1.wav",
    "zpn/return2.wav",
    "zpn/return3.wav"
}

new Float:g_flLastSoundTime

public plugin_precache()
{
    register_plugin("[ZPN] Addon: Return Zombie Sounds ", "1.0", "BRUN0")

    new i; for (i = 0; i < sizeof(sounds); i++) { precache_sound(sounds[i]); }
}

public plugin_init()
{
    RegisterHookChain(RG_CBasePlayer_Spawn, "RG_CBasePlayer_Spawn_Post", true)
}

public zpn_user_infected_post(const id, const infector, const class_id)
{
    play_sound(id)
}

public RG_CBasePlayer_Spawn_Post(const id)
{
    play_sound(id)
}

play_sound(id)
{
    if(!zpn_is_user_zombie(id) || !is_user_alive(id))
        return

    if(g_flLastSoundTime > get_gametime())
        return

    rg_send_audio(0, sounds[random_num(0, sizeof(sounds) - 1)])
    g_flLastSoundTime = get_gametime() + 2.0
}