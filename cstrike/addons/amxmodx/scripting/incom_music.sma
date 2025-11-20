#include <amxmodx>
#include <incom_print>

#define PLUGIN  "Incomsystem music"
#define VERSION "3.2"
#define AUTHOR  "Tonitaga"

#define KEY_ENABLE          "amx_incom_music_enable"
#define KEY_TYPE            "amx_incom_music_type"
#define KEY_REQUEST_ENABLE  "amx_incom_music_request_enable"
#define KEY_REQUEST_TIMEOUT "amx_incom_music_request_timeout"

#define DEFAULT_ENABLE          "1"
#define DEFAULT_TYPE            "1"
#define DEFAULT_REQUEST_ENABLE  "1"
#define DEFAULT_REQUEST_TIMEOUT "60"

new const MUSIC_TYPE_DEFAULT = 1
new const MUSIC_TYPE_XMAS    = 2

new g_Enable;
new g_Type;
new g_RequestEnable;
new g_RequestTimeout;

#define ADMIN_FLAG ADMIN_IMMUNITY

#define MUSIC_COMMAND_SAY           "say /music"
#define MUSIC_COMMAND_SAY_TEAM      "say_team /music"
#define MUSIC_STOP_COMMAND_SAY      "say /stop_music"
#define MUSIC_STOP_COMMAND_SAY_TEAM "say_team /stop_music"

new g_SongRequested = false;
new g_SongRequestCounter = 0;
new g_SongRequestMenuOnHud = 0;

new const g_SondRequestTaskId = 20000;
new const g_MenuDestroyTaskId = 20500;

new const g_Sounds[][] =
{
    ///> Greeting sounds
    "incom/greeting",
    "incom/greeting_lunch_pizza",
    "incom/greeting_code_and_cs",

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
    "Lunch Pizza",
    "Code & Counter-Strike",

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
#define SOUND_OFFSET_GREETING_XMAS 3  // g_Sounds[3]
#define SOUND_OFFSET_DEFAULT       7  // g_Sounds[7]
#define SOUND_OFFSET_XMAS          16 // g_Sounds[16]

public plugin_init() 
{ 
    register_plugin(PLUGIN, VERSION, AUTHOR)
    
    register_logevent("round_end", 2, "1=Round_End")

    register_clcmd("joinclass", "OnAgentChoose");

    register_clcmd(MUSIC_COMMAND_SAY, "ShowMusicMenu")
    register_clcmd(MUSIC_COMMAND_SAY_TEAM, "ShowMusicMenu")
    register_clcmd(MUSIC_STOP_COMMAND_SAY, "StopSound")
    register_clcmd(MUSIC_STOP_COMMAND_SAY_TEAM, "StopSound")

    register_dictionary("incom_music.txt")
}

public plugin_cfg()
{
	g_Enable         = create_cvar(KEY_ENABLE, DEFAULT_ENABLE, _, "Статус плагина^n0 - Отключен^n1 - Включен", true, 0.0, true, 1.0);
	g_Type           = create_cvar(KEY_TYPE, DEFAULT_TYPE, _, "Тип музыки^n1 - Incomsystem [Default]^n2 - Incomsystem [XMas]", true, 1.0, true, 2.0);
	g_RequestTimeout = create_cvar(KEY_REQUEST_TIMEOUT, DEFAULT_REQUEST_TIMEOUT, _, "Максимальное время ожидания между двумя заказами песен", true, 30.0, true, 180.0);
	g_RequestEnable  = create_cvar(KEY_REQUEST_ENABLE, DEFAULT_REQUEST_ENABLE, _, "Возможность заказать песню ^n0 - Отключен^n1 - Включен", true, 0.0, true, 1.0);

	AutoExecConfig();
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
            PlaySound(playerId, SOUND_OFFSET_GREETING + 0);
        }
        else if (type == MUSIC_TYPE_XMAS)
        {
            PlaySound(playerId, SOUND_OFFSET_GREETING_XMAS + 0);
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
        // Пока песня запрошена, то песни конца раунда не будет
        if (IsSongAlreadyRequested())
        {
            return;
        }

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
    PlaySound(0, SOUND_OFFSET_DEFAULT + rand);
}

public PlayXMasSound()
{
    new rand = random_num(0,7)
    PlaySound(0, SOUND_OFFSET_XMAS + rand);
}

public PlaySound(playerId, soundId)
{
    new sound[64];
    formatex(sound, charsmax(sound), "spk %s", g_Sounds[soundId]);

    client_cmd(playerId, sound);
}

public StopSound(playerId)
{
    if (get_user_flags(playerId) & ADMIN_FLAG)
    {
        client_cmd(0, "stopsound")

        if (!IsSongAlreadyRequested())
        {
            return;
        }

        SetSongRequested(false);

        new name[128];
        get_user_name(playerId, name, charsmax(name));

        IncomPrint_Client(0, "[%L] %L", playerId, "INCOM_MUSIC", playerId, "ADMIN_STOP_SOUND", name);
    }
    else
    {
        client_cmd(playerId, "stopsound")
        IncomPrint_Client(0, "[%L] %L", playerId, "INCOM_MUSIC", playerId, "PLAYER_STOP_SOUND");
    }
}

stock IsSongRequestMenuOnHud()
{
    return g_SongRequestMenuOnHud;
}

stock SongRequestMenuOnHud(value)
{
    g_SongRequestMenuOnHud = value;
}

stock IsSongAlreadyRequested()
{
    return g_SongRequested;
}

stock SetSongRequested(value)
{
    new data[1];

    data[0] = value;
    SetSongRequestedData(data);
}

public SetSongRequestedData(data[])
{
    new value = data[0];

    g_SongRequested = value;
    if (task_exists(g_SondRequestTaskId))
    {
        remove_task(g_SondRequestTaskId);
    }

    if (value)
    {
        g_SongRequestCounter = get_pcvar_num(g_RequestTimeout);
        set_task(1.0, "PollSongRequest", g_SondRequestTaskId, .flags="b");
        return;
    }
}

public PollSongRequest()
{
    --g_SongRequestCounter;
    if (g_SongRequestCounter <= 0)
    {
        IncomPrint_Client(0, "[%L] %L", 0, "INCOM_MUSIC", 0, "SOUND_AVAILABLE");
        SetSongRequested(false);
        return;
    }
}

public pointBonus_RequestSong(playerId)
{
    if (!get_pcvar_num(g_RequestEnable))
    {
        IncomPrint_Client(playerId, "[%L] %L", playerId, "INCOM_MUSIC", playerId, "REQUEST_DISABLED");
        return false;
    }

    if (IsSongAlreadyRequested())
    {
        IncomPrint_Client(playerId, "[%L] %L", playerId, "INCOM_MUSIC", playerId, "SOUND_NOT_AVAILABLE", g_SongRequestCounter);
        return false;
    }

    if (IsSongRequestMenuOnHud())
    {
        IncomPrint_Client(playerId, "[%L] %L", playerId, "INCOM_MUSIC", playerId, "SOMEONE_SELECTING_SOUND");
        return false;
    }

    ShowMusicRequestMenu(playerId);
    return true;
}

stock MakeInactiveMenuCanceler(playerId, Float:timeout)
{
    set_task(timeout, "InactiveMenuCanceler", g_MenuDestroyTaskId + playerId)
}

stock RemoveInvactiveMenuCanceler(playerId)
{
    remove_task(g_MenuDestroyTaskId + playerId);
}

public InactiveMenuCanceler(taskId)
{
    new playerId = taskId - g_MenuDestroyTaskId;

    menu_cancel(playerId);
    show_menu(playerId, 0, "^n", 1);

    SongRequestMenuOnHud(false);

    IncomPrint_Client(0, "[%L] %L", playerId, "INCOM_MUSIC", playerId, "SOUND_AVAILABLE");
}

public ShowMenu(playerId, soundIndexLhs, soundIndexRhs, const callback[])
{
    SongRequestMenuOnHud(true);

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

    MakeInactiveMenuCanceler(playerId, 10.0);
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
	SongRequestMenuOnHud(false);
    RemoveInvactiveMenuCanceler(playerId);
	
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

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
    SongRequestMenuOnHud(false);
    RemoveInvactiveMenuCanceler(playerId);

    if(item == MENU_EXIT)
    {
    	menu_destroy(menu);
    	return PLUGIN_HANDLED;
    }

    return CommonMenuCase(playerId, menu, item);
}

public CommonMenuCase(playerId, menu, item)
{
	SetSongRequested(true);

	new data[6], name[128];
	new access, callback;

	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback)
	new soundId = str_to_num(data)

	client_cmd(0, "stopsound")
	PlaySound(0, soundId);

	get_user_name(playerId, name, charsmax(name));

	IncomPrint_Client(0, "[%L] %L", playerId, "INCOM_MUSIC", playerId, "SOUND_REQUESTED", name, g_SoundsNames[soundId]);
	menu_destroy(menu)
	return PLUGIN_HANDLED
}