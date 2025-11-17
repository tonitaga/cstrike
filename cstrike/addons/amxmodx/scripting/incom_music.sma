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

new g_SongRequested = false;
new const g_SondRequestTaskId = 14839;

new const g_Sounds[][] =
{
    ///> Greeting sounds
    "incom/greeting",

    ///> Greeting sounds [XMas]
    "incom/greeting_xmas",
    "incom/greeting_xmas_let_it_snow",
    "incom/greeting_xmas_rocking_around",
    "incom/greeting_xmas_last_christmas",

    ///> Incomsystem [Default]
    "incom/roundend1_v2",
    "incom/roundend2_v2",
    "incom/roundend3_v2",
    "incom/roundend4_v2",
    "incom/roundend5_v2",
    "incom/roundend6_v2",
    "incom/roundend7_v2",
    "incom/roundend8_v2",
    "incom/roundend9_v2",

    ///> Incomsystem [XMas]
    "incom/roundend1_xmas_v2",
    "incom/roundend2_xmas",
    "incom/roundend3_xmas",
    "incom/roundend4_xmas",
    "incom/roundend5_xmas",
    "incom/roundend6_xmas",
    "incom/roundend7_xmas",
    "incom/roundend8_xmas"
};

///> Для отображения имени в меню
///> Если строка пустая, то отображаться будет название из массива g_Sounds
new const g_SoundsNames[][] =
{
    ///> Greeting sounds
    "Incom Greeting",

    ///> Greeting sounds [XMas]
    "Incom XMas Greeting",
    "Let It Snow!",
    "Rockin Around The Christmas Tree",
    "Wham! Last Christmas",

    ///> Incomsystem [Default]
    "Roundend #1",
    "Roundend #2",
    "Roundend #3",
    "Roundend #4",
    "Roundend #5",
    "Roundend #6",
    "Roundend #7",
    "Roundend #8",
    "Roundend #9",

    ///> Incomsystem [XMas]
    "Roundend XMas #1",
    "Roundend XMas #2",
    "Roundend XMas #3",
    "Roundend XMas #4",
    "Roundend XMas #5",
    "Roundend XMas #6",
    "Roundend XMas #7",
    "Roundend XMas #8"
};

#define SOUND_OFFSET_GREETING      0  // g_Sounds[0]
#define SOUND_OFFSET_GREETING_XMAS 1  // g_Sounds[0]
#define SOUND_OFFSET_DEFAULT       5  // g_Sounds[5]
#define SOUND_OFFSET_XMAS          14 // g_Sounds[14]

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
        Wrapper_SetSongRequested(false);

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
        Wrapper_SetSongRequested(false);
    }
}

stock IsSongAlreadyRequested()
{
    return g_SongRequested;
}

stock Wrapper_SetSongRequested(value)
{
    new data[1];

    data[0] = value;
    SetSongRequested(data);
}

public SetSongRequested(data[])
{
    new value = data[0];
    if (value == g_SongRequested)
    {
        return;
    }

    g_SongRequested = value;
    if (task_exists(g_SondRequestTaskId))
    {
        remove_task(g_SondRequestTaskId);
    }

    if (value)
    {
        data[0] = false;
        set_task(90.0, "SetSongRequested", g_SondRequestTaskId, data, 1);
        return;
    }

    CC_SendMessage(0, "[&x07Incomsystem music&x01] Song request &x04available&x01. Try &x07/anew&x01!");
}

public pointBonus_RequestSong(playerId)
{
    if (!IsSongAlreadyRequested())
    {
        ShowMusicRequestMenu(playerId);
        Wrapper_SetSongRequested(true);
        return true;
    }

    CC_SendMessage(playerId, "[&x07Incomsystem music&x01] Song &x04already&x01 requested. Try again &x07later&x01!");
    return false;
}

public ShowMenu(playerId, soundIndexLhs, soundIndexRhs, const callback[])
{
    new menu = menu_create("\y>>>>> \rIncomsystem Music Menu \y<<<<<^n \dby >>\rTonitaga\d<<", callback)

    new data[8], menuItem[64];
    for (new i = soundIndexLhs; i < soundIndexRhs; ++i)
    {
        num_to_str(i, data, charsmax(data));
    
        if (equal(g_SoundsNames[i], ""))
        {
            formatex(menuItem, charsmax(menuItem), "\y%s", g_Sounds[i]);
        }
        else
        {
            formatex(menuItem, charsmax(menuItem), "\y%s", g_SoundsNames[i]);
        }

        menu_additem(menu, menuItem, data, 0)
    }
    
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_display(playerId, menu, 0)
}

public ShowMusicMenu(playerId)
{
    if (get_user_flags(playerId) & ADMIN_FLAG)
    {
        ShowMenu(playerId, 0, sizeof g_Sounds, "MenuCase");
    }
}

public MenuCase(playerId, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	Wrapper_SetSongRequested(true); ///> Админовская команда, проверять на наличие выставленного флага не будем
	return CommonMenuCase(playerId, menu, item);
}

public ShowMusicRequestMenu(playerId)
{
    new lhsIndex = SOUND_OFFSET_GREETING;
    new rhsIndex = SOUND_OFFSET_GREETING_XMAS;

    new type = get_pcvar_num(g_Type)
    if (type == MUSIC_TYPE_XMAS)
    {
        lhsIndex = SOUND_OFFSET_GREETING_XMAS;
        rhsIndex = SOUND_OFFSET_DEFAULT;
    }

    ShowMenu(playerId, lhsIndex, rhsIndex, "RequestMenuCase");
}

public RequestMenuCase(playerId, menu, item)
{
    if(item == MENU_EXIT)
    {
    	menu_destroy(menu);
        Wrapper_SetSongRequested(false);
    	return PLUGIN_HANDLED;
    }

    return CommonMenuCase(playerId, menu, item);
}

public CommonMenuCase(playerId, menu, item)
{
	new data[6], name[128];
	new access, callback;

	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback)
	new soundId = str_to_num(data)

	client_cmd(0, "stopsound")
	PlaySound(soundId);

	get_user_name(playerId, name, charsmax(name));

	if (equal(g_SoundsNames[soundId], ""))
	{
	    CC_SendMessage(0, "[&x07Incomsystem music&x01] &x04%s&x01 requested song &x07#%d&x01", name, soundId);
	}
	else
	{
	    CC_SendMessage(0, "[&x07Incomsystem music&x01] &x04%s&x01 requested song &x07%s&x01", name, g_SoundsNames[soundId]);
	}

	menu_destroy(menu)
	return PLUGIN_HANDLED
}
