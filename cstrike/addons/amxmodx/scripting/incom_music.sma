#include <amxmodx>

#define PLUGIN  "Incomsystem music"
#define VERSION "2.3"
#define AUTHOR  "Tonitaga"

#define KEY_ENABLE "amx_incom_music_enable"
#define KEY_TYPE   "amx_incom_music_type"

#define DEFAULT_ENABLE "1"
#define DEFAULT_TYPE   "1"

new const MUSIC_TYPE_DEFAULT = 1
new const MUSIC_TYPE_XMAS    = 2

new g_Enable;
new g_Type;

public plugin_init() 
{ 
    register_plugin(PLUGIN, VERSION, AUTHOR)
    
    register_logevent("round_end", 2, "1=Round_End")

    register_clcmd("joinclass", "OnAgentChoose");
}

public plugin_cfg()
{
	g_Enable = create_cvar(KEY_ENABLE, DEFAULT_ENABLE, _, "Статус плагина^n0 - Отключен^n1 - Включен", true, 0.0, true, 1.0);
	g_Type   = create_cvar(KEY_TYPE, DEFAULT_TYPE, _, "Тип музыки^n1 - Incomsystem [Default]^n2 - Incomsystem [XMas]", true, 1.0, true, 2.0);

	AutoExecConfig(true, "incom_music");
}

public client_connect(playerId)
{
    if (get_pcvar_num(g_Enable))
    {
        client_cmd(playerId, "stopsound")

        new type = get_pcvar_num(g_Type)
        if (type == MUSIC_TYPE_DEFAULT)
        {
            client_cmd(playerId, "spk incom/greeting");
        }
        else if (type == MUSIC_TYPE_XMAS)
        {
            client_cmd(playerId, "spk incom/greeting_xmas")
        }
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
        client_cmd(0, "stopsound")

        new type = get_pcvar_num(g_Type)
        if (type == MUSIC_TYPE_DEFAULT)
        {
            set_task(0.5, "PlayCommonSound")
        }
        else if (type == MUSIC_TYPE_XMAS)
        {
            set_task(0.5, "PlayXMasSound")
        }
    }
}

public PlayCommonSound()
{
    new rand = random_num(1,10)
    switch(rand)
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

public PlayXMasSound()
{
    new rand = random_num(1,1)
    switch(rand)
    {
        case 1: client_cmd(0,"spk incom/roundend1_xmas")
    }
}

public plugin_precache()
{
    precache_sound("incom/greeting.wav")
    precache_sound("incom/greeting_xmas.wav")

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

    precache_sound("incom/roundend1_xmas.wav")
    
    return PLUGIN_CONTINUE
}