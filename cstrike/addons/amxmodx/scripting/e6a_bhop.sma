#include <amxmodx>
#include <reapi>

#define PLUGIN  "e6a_bhop"
#define VERSION "1.0"
#define AUTHOR  "e6aluga"
#define BHOP_MUSIC "e6a_bhop/bhop_round.mp3"

new amx_e6a_bhop_enable;
new amx_e6a_bhop_chance;
new amx_e6a_bhop_timer;
new amx_e6a_bhop_music;
new Float:amx_e6a_bhop_speed_multiplier;
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
	register_dictionary("e6a_bhop.txt");
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
            "amx_e6a_bhop_timer", "120",
            .has_min = true, .min_val = 0.0,
            .description = "Длительность Bhop режима в секундах" 
        ),
        amx_e6a_bhop_timer
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
            "amx_e6a_bhop_speed_multiplier", "1.15",
            .has_min = true, .min_val = 1.0,
            .has_max = true, .max_val = 2.0,
            .description = "Множитель скорости"
        ),
        amx_e6a_bhop_speed_multiplier
    );
    AutoExecConfig();
}

public OnRestartRound()
{
    g_bBhopActive = false;
    remove_task();
    
    if (!amx_e6a_bhop_enable)
        return;
    
    ActivateBhopMode();
}

public ActivateBhopMode()
{
    new iChance = amx_e6a_bhop_chance;
    new iRandom = random_num(1, 100);
    
    if (iRandom <= iChance)
    {
        g_bBhopActive = true;
        if (amx_e6a_bhop_music)
        {
            play_bhop_music_for_all();
        }
        client_print_color(0, print_team_default, "[%L] %L", LANG_PLAYER, "E6A_BHOP", LANG_PLAYER, "E6A_BHOP_START");
        
        if (iChance < 100)
        {
            set_task(float(amx_e6a_bhop_timer), "DisableBhopTimer");
        }
    }
    else
    {
        set_task(float(amx_e6a_bhop_timer), "ActivateBhopMode");
    }
}

public DisableBhopTimer()
{
    g_bBhopActive = false;
    
    if (amx_e6a_bhop_chance < 100)
    {
        set_task(float(amx_e6a_bhop_timer), "ActivateBhopMode");
    }
}

public OnPlayerJump(id)
{
    if (!amx_e6a_bhop_enable)
    {
        g_bBhopActive = false;
        return HC_CONTINUE;
    }

    if (!g_bBhopActive)
        return HC_CONTINUE;
        
    if (!is_user_alive(id))
        return HC_CONTINUE;

    if (get_entvar(id, var_flags) & FL_ONGROUND)
    {
        new Float:velocity[3];
        get_entvar(id, var_velocity, velocity);
        
        velocity[2] = 250.0;
        velocity[0] *= amx_e6a_bhop_speed_multiplier;
        velocity[1] *= amx_e6a_bhop_speed_multiplier;

        set_entvar(id, var_velocity, velocity);
        set_entvar(id, var_gaitsequence, 6);
        set_entvar(id, var_frame, 0.0);
    }
    return HC_CONTINUE;
}

public play_bhop_music_for_all()
{
    new players[32], num;
    get_players(players, num, "ch");
    
    for (new i = 0; i < num; i++)
    {
        client_cmd(players[i], "mp3 play sound/%s", BHOP_MUSIC);
    }
}