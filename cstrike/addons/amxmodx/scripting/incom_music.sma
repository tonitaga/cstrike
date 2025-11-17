#include <amxmodx>
#include <cromchat>

#define PLUGIN  "Incomsystem music"
#define VERSION "3.1"
#define AUTHOR  "Tonitaga"

#define KEY_ENABLE "amx_incom_music_enable"
#define KEY_TYPE   "amx_incom_music_type"

#define DEFAULT_ENABLE "1"
#define DEFAULT_TYPE   "1"

new const MUSIC_TYPE_DEFAULT = 1
new const MUSIC_TYPE_XMAS    = 2

new g_Enable;
new g_Type;

#define ADMIN_FLAG ADMIN_IMMUNITY

#define MUSIC_COMMAND_SAY           "say /music"
#define MUSIC_COMMAND_SAY_TEAM      "say_team /music"
#define MUSIC_STOP_COMMAND_SAY      "say /stop_music"
#define MUSIC_STOP_COMMAND_SAY_TEAM "say_team /stop_music"

new const g_Sounds[][] =
{
    "incom/greeting",
    "incom/greeting_xmas",
    "incom/greeting_xmas_let_it_snow",

    "incom/roundend1_v2",
    "incom/roundend2_v2",
    "incom/roundend3_v2",
    "incom/roundend4_v2",
    "incom/roundend5_v2",
    "incom/roundend6_v2",
    "incom/roundend7_v2",
    "incom/roundend8_v2",
    "incom/roundend9_v2",

    "incom/roundend1_xmas_v2",
    "incom/roundend2_xmas",
    "incom/roundend3_xmas",
    "incom/roundend4_xmas",
    "incom/roundend5_xmas",
    "incom/roundend6_xmas",
    "incom/roundend7_xmas",
    "incom/roundend8_xmas"
};

#define SOUND_OFFSET_GREETING 0  // g_Sounds[0]
#define SOUND_OFFSET_DEFAULT  3  // g_Sounds[3]
#define SOUND_OFFSET_XMAS     12 // g_Sounds[12]

public plugin_init() 
{ 
    register_plugin(PLUGIN, VERSION, AUTHOR)
    
    register_logevent("round_end", 2, "1=Round_End")

    register_clcmd("joinclass", "OnAgentChoose");

    register_clcmd(MUSIC_COMMAND_SAY, "ShowMusicMenu")
    register_clcmd(MUSIC_COMMAND_SAY_TEAM, "ShowMusicMenu")
    register_clcmd(MUSIC_STOP_COMMAND_SAY, "StopSound")
    register_clcmd(MUSIC_STOP_COMMAND_SAY_TEAM, "StopSound")
}

public plugin_cfg()
{
	g_Enable = create_cvar(KEY_ENABLE, DEFAULT_ENABLE, _, "Статус плагина^n0 - Отключен^n1 - Включен", true, 0.0, true, 1.0);
	g_Type   = create_cvar(KEY_TYPE, DEFAULT_TYPE, _, "Тип музыки^n1 - Incomsystem [Default]^n2 - Incomsystem [XMas]", true, 1.0, true, 2.0);

	AutoExecConfig(true, "incom_music");
}

public plugin_precache()
{
    new sound[64];
    for (new i; i < sizeof g_Sounds; ++i)
    {
        formatex(sound, charsmax(sound), "%s.wav", g_Sounds[i]);
        precache_sound(sound);
    }

    return PLUGIN_CONTINUE
}

public client_connect(playerId)
{
    if (get_pcvar_num(g_Enable))
    {
        client_cmd(playerId, "stopsound")

        new type = get_pcvar_num(g_Type)
        if (type == MUSIC_TYPE_DEFAULT)
        {
            PlaySound(SOUND_OFFSET_GREETING + 0);
        }
        else if (type == MUSIC_TYPE_XMAS)
        {
            PlaySound(SOUND_OFFSET_GREETING + 1);
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
            set_task(0.1, "PlayCommonSound")
        }
        else if (type == MUSIC_TYPE_XMAS)
        {
            set_task(0.1, "PlayXMasSound")
        }
    }
}

public PlayCommonSound()
{
    new rand = random_num(0,8)
    PlaySound(SOUND_OFFSET_DEFAULT + rand);
}

public PlayXMasSound()
{
    new rand = random_num(0,7)
    PlaySound(SOUND_OFFSET_XMAS + rand);
}

public PlaySound(soundId)
{
    new sound[64];
    formatex(sound, charsmax(sound), "spk %s", g_Sounds[soundId]);

    client_cmd(0, sound);
}

public StopSound(playerId)
{
    if (get_user_flags(playerId) & ADMIN_FLAG)
    {
        client_cmd(0, "stopsound")
    }
}

public ShowMusicMenu(playerId)
{
    if (get_user_flags(playerId) & ADMIN_FLAG)
    {
        new menu = menu_create("\y>>>>> \rIncomsystem Music Menu \y<<<<<^n \dby >>\rTonitaga\d<<", "MenuCase")

        new data[8], menuItem[32];
        for (new i = 0; i < sizeof g_Sounds; ++i)
        {
            num_to_str(i, data, charsmax(data));
            formatex(menuItem, charsmax(menuItem), "\y%s", g_Sounds[i]);
    
            menu_additem(menu, menuItem, data, 0)
        }
        
        menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
        menu_display(playerId, menu, 0)
    }
}

public MenuCase(playerId, menu, item) 
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new data[6], name[128];
	new access, callback;

	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback)
	new soundId = str_to_num(data)

	client_cmd(0, "stopsound")
	PlaySound(soundId);

	get_user_name(playerId, name, charsmax(name));
	CC_SendMessage(0, "ADMIN &x07%s&x01 requested sound &x04#%d&x01", name, soundId + 1);

	menu_destroy(menu)
	return PLUGIN_HANDLED
}
