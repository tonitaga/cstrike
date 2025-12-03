#include <amxmodx>
#include <reapi>

#define PLUGIN  "e6a_bhop"
#define VERSION "1.0"
#define AUTHOR  "e6aluga"
#define BHOP_MUSIC "e6a_bhop/bhop_round.wav"

new amx_e6a_bhop_enable;
new amx_e6a_bhop_chance;
new amx_e6a_bhop_music;
new Float:g_fBhopPower;
new bool:g_bBhopActive;

public plugin_precache() 
{
    precache_sound(BHOP_MUSIC);
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    RegisterHookChain(RG_CBasePlayer_Jump, "OnPlayerJump", false);
    RegisterHookChain(RG_CSGameRules_RestartRound, "OnRestartRound", true);
}

public plugin_cfg()
{
    bind_pcvar_num(
        create_cvar(
            "amx_e6a_bhop_enable", "1",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 1.0,
            .description = "0 - Плагин отключен^n\
                            1 - Плагин включен"
        ),
        amx_e6a_bhop_enable
    );

    bind_pcvar_num(
        create_cvar(
            "amx_e6a_bhop_chance", "5",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 100.0,
            .description = "Шанс активации (0-100%)"
        ),
        amx_e6a_bhop_chance
    );

    bind_pcvar_num(
        create_cvar(
            "amx_e6a_bhop_music", "1",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 1.0,
            .description = "0 - Музыка отключена^n\
                            1 - Музыка включена"
        ),
        amx_e6a_bhop_music
    );

    bind_pcvar_float(
        create_cvar(
            "amx_e6a_bhop_power", "1.15",
            .has_min = true, .min_val = 1.0,
            .has_max = true, .max_val = 2.0,
            .description = "Множитель скорости"
        ),
        g_fBhopPower
    );

    AutoExecConfig();
}

public OnRestartRound()
{
    if (!amx_e6a_bhop_enable)
    {
        g_bBhopActive = false;
        return;
    }
    
    new iChance = amx_e6a_bhop_chance;
    new iRandom = random_num(1, 100);
    
    if (iRandom <= iChance)
    {
        g_bBhopActive = true;
        if (amx_e6a_bhop_music)
        {
            play_bhop_music_for_all();
        }
        client_print_color(0, print_team_default, "^4[e6a_bhop] ^1BunnyHop round ^3ENABLED!");
    }
    else
    {
        g_bBhopActive = false;
    }
}

public OnPlayerJump(id)
{
    if (!g_bBhopActive)
        return HC_CONTINUE;
        
    if (!is_user_alive(id))
        return HC_CONTINUE;

    if (get_entvar(id, var_flags) & FL_ONGROUND)
    {
        new Float:velocity[3];
        get_entvar(id, var_velocity, velocity);
        
        velocity[2] = 250.0;
        velocity[0] *= g_fBhopPower;
        velocity[1] *= g_fBhopPower;

        set_entvar(id, var_velocity, velocity);
        set_entvar(id, var_gaitsequence, 6);
        set_entvar(id, var_frame, 0.0);
    }
    return HC_CONTINUE;
}

public play_bhop_music_for_all()
{
    rg_send_audio(0, BHOP_MUSIC, PITCH_NORM);
}