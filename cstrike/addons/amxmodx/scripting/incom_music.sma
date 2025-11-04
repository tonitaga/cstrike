#include <amxmodx>

#define PLUGIN  "Incomsystem music"
#define VERSION "2.2"
#define AUTHOR  "Tonitaga"

#define KEY_ENABLE     "amx_incom_music_enable"
#define DEFAULT_ENABLE "1"

new g_Enable;

public plugin_init() 
{ 
    register_plugin(PLUGIN, VERSION, AUTHOR)
    
    register_logevent("round_end", 2, "1=Round_End")

    register_clcmd("joinclass", "OnAgentChoose");
}


public plugin_cfg()
{
	g_Enable = create_cvar(KEY_ENABLE, DEFAULT_ENABLE, _, "Статус плагина^n0 - Отключен^n1 - Включен", true, 0.0, true, 1.0);

	AutoExecConfig(true, "incom_music");
}

public client_connect(playerId)
{
    if (get_pcvar_num(g_Enable))
    {
        client_cmd(playerId, "spk incom/greeting")
    }
}

public OnAgentChoose(playerId)
{
    if (get_pcvar_num(g_Enable))
    {
        client_cmd(playerId, "stopsound")
    }
}

public round_end()
{
    if (get_pcvar_num(g_Enable))
    {
        new rand = random_num(1,10)
        
        client_cmd(0, "stopsound")
        set_task(0.5, "play_round_sound", rand)
    }
}

public play_round_sound(sound_id)
{
    switch(sound_id)
    {
        case 1:  client_cmd(0,"spk incom/roundend1")
        case 2:  client_cmd(0,"spk incom/roundend2")
        case 3:  client_cmd(0,"spk incom/roundend3")
        case 4:  client_cmd(0,"spk incom/roundend4")
        case 5:  client_cmd(0,"spk incom/roundend5")
        case 6:  client_cmd(0,"spk incom/roundend6")
        case 7:  client_cmd(0,"spk incom/roundend7")
        case 8:  client_cmd(0,"spk incom/roundend8")
        case 9:  client_cmd(0,"spk incom/roundend9")
        case 10: client_cmd(0,"spk incom/roundend1_fonk_montagem_xonada")
    }
}

public plugin_precache()
{
    precache_sound("incom/greeting.wav")
    precache_sound("incom/roundend1.wav")
    precache_sound("incom/roundend2.wav")
    precache_sound("incom/roundend3.wav")
    precache_sound("incom/roundend4.wav")
    precache_sound("incom/roundend5.wav")
    precache_sound("incom/roundend6.wav")
    precache_sound("incom/roundend7.wav")
    precache_sound("incom/roundend8.wav")
    precache_sound("incom/roundend9.wav")
    precache_sound("incom/roundend1_fonk_montagem_xonada.wav")
    
    return PLUGIN_CONTINUE
}