#include <amxmodx>
#include <incom_print>
#include <reapi>

#define PLUGIN  "Incomsystem music"
#define VERSION "4.0"
#define AUTHOR  "Tonitaga"

new const MUSIC_TYPE_DEFAULT = 1
new const MUSIC_TYPE_XMAS    = 2

new amx_incom_music_enable;
new amx_incom_music_type;
new amx_incom_music_request_timeout;
new amx_incom_music_request_enable;

#define ADMIN_FLAG ADMIN_IMMUNITY

#define MUSIC_COMMAND_SAY           "say /music"
#define MUSIC_COMMAND_SAY_TEAM      "say_team /music"
#define MUSIC_STOP_COMMAND_SAY      "say /stop_music"
#define MUSIC_STOP_COMMAND_SAY_TEAM "say_team /stop_music"

new g_SongRequested = false;
new g_SongRequestCounter = 0;
new g_SongRequestMenuOnHud = false;

new const g_SondRequestTaskId = 20000;
new const g_MenuDestroyTaskId = 20500;

new const g_Sounds[][] =
{
    ///> Greeting sounds
    "incom/greeting.mp3",
    "incom/greeting_lunch_pizza.mp3",
    "incom/greeting_code_and_cs.mp3",

    ///> Greeting sounds [XMas]
    "incom/greeting_xmas_incomsystem_and_new_year.mp3",
    "incom/greeting_xmas_incom.mp3",
    "incom/greeting_xmas_incom_new_year_code.mp3",
    "incom/greeting_xmas_let_it_snow.mp3",
    "incom/greeting_xmas_rocking_around.mp3",
    "incom/greeting_xmas_last_christmas.mp3",
    "incom/greeting_xmas_avaria_new_year.mp3",
    "incom/greeting_xmas_verka_new_year.mp3",
    "incom/greeting_xmas_zima_holoda.mp3",

    ///> Incomsystem [Default]
    "incom/roundend1_v2.mp3",
    "incom/roundend2_v2.mp3",
    "incom/roundend3_v2.mp3",
    "incom/roundend4_v2.mp3",
    "incom/roundend5_v2.mp3",
    "incom/roundend6_v2.mp3",
    "incom/roundend7_v2.mp3",
    "incom/roundend8_v2.mp3",
    "incom/roundend9_v2.mp3",

    ///> Incomsystem [XMas]
    "incom/roundend1_xmas_v2.mp3",
    "incom/roundend2_xmas.mp3",
    "incom/roundend3_xmas.mp3",
    "incom/roundend4_xmas.mp3",
    "incom/roundend5_xmas.mp3",
    "incom/roundend6_xmas.mp3",
    "incom/roundend7_xmas.mp3",
    "incom/roundend8_xmas.mp3"
};

///> Для отображения имени в меню
///> Если строка пустая, то отображаться будет название из массива g_Sounds
new const g_SoundsNames[][] =
{
    ///> Greeting sounds
    "Antonk - Incomsystem Anthem",
    "Antonk - Пицца в обед",
    "Antonk - Код и Counter-Strike",

    ///> Greeting sounds [XMas]
    "Tonitaga - Инкомсистем и Новый год",
    "Tonitaga - Новогодняя",
    "Tonitaga - Новогодний Код",
    "Dean Martin - Let It Snow!",
    "Brenda Lee - Rockin Around The Christmas Tree",
    "Wham! - Last Christmas",
    "Дискотека Авария - Новогодняя",
    "Верка Сердючка - Новогодняя",
    "Андрей Губин - Зима холода",

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
#define SOUND_OFFSET_DEFAULT       12 // g_Sounds[12]
#define SOUND_OFFSET_XMAS          21 // g_Sounds[21]
#define SOUND_OFFSET_MAX           (sizeof g_SoundsNames)

public plugin_init() 
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    
    register_logevent("round_end", 2, "1=Round_End")

    register_clcmd(MUSIC_COMMAND_SAY, "ShowMusicMenu")
    register_clcmd(MUSIC_COMMAND_SAY_TEAM, "ShowMusicMenu")
    register_clcmd(MUSIC_STOP_COMMAND_SAY, "HandleStopSound")
    register_clcmd(MUSIC_STOP_COMMAND_SAY_TEAM, "HandleStopSound")

    register_dictionary("incom_music.txt")
}

public plugin_cfg()
{
	bind_pcvar_num(
		create_cvar(
			"amx_incom_music_enable", "1",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 1.0,
            .description = "Статус плагина^n\
                            0 - Отключен^n\
                            1 - Включен"
		),
		amx_incom_music_enable
	);

	bind_pcvar_num(
		create_cvar(
			"amx_incom_music_type", "1",
            .has_min = true, .min_val = 1.0,
            .has_max = true, .max_val = 2.0,
            .description = "Тип музыки^n\
                            1 - Incomsystem [Default]^n\
                            2 - Incomsystem [XMas]"
		),
		amx_incom_music_type
	);

	bind_pcvar_num(
		create_cvar(
			"amx_incom_music_request_timeout", "60",
            .has_min = true, .min_val = 30.0,
            .has_max = true, .max_val = 180.0,
            .description = "Максимальное время ожидания между двумя заказами песен"
		),
		amx_incom_music_request_timeout
	);

	bind_pcvar_num(
		create_cvar(
			"amx_incom_music_request_enable", "1",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 1.0,
            .description = "Возможность заказать песню^n\
                            0 - Отключен^n\
                            1 - Включен"
		),
		amx_incom_music_request_enable
	);

	AutoExecConfig();
}

public plugin_precache()
{
    for (new i; i < sizeof g_Sounds; ++i)
    {
        precache_sound(g_Sounds[i]);
    }

    return PLUGIN_CONTINUE
}

public client_connect(playerId)
{
    if (amx_incom_music_enable)
    {
        StopSound(playerId);

        new type = amx_incom_music_type;
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

public client_disconnected(playerId)
{
	StopSound(playerId);
}

public client_putinserver(playerId)
{
    StopSound(playerId);
}

public round_end()
{
    if (amx_incom_music_enable)
    {
        // Пока песня запрошена, то песни конца раунда не будет
        if (IsSongAlreadyRequested())
        {
            return;
        }

        StopSound(0);

        new type = amx_incom_music_type;
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
    static soundsCount = (SOUND_OFFSET_XMAS - SOUND_OFFSET_DEFAULT) - 1;

    new rand = random_num(0,soundsCount)
    PlaySound(0, SOUND_OFFSET_DEFAULT + rand);
}

public PlayXMasSound()
{
    static soundsCount = (SOUND_OFFSET_MAX - SOUND_OFFSET_XMAS) - 1;

    new rand = random_num(0,soundsCount)
    PlaySound(0, SOUND_OFFSET_XMAS + rand);
}

public PlaySound(playerId, soundId)
{
    new sound[128];
    formatex(sound, charsmax(sound), "mp3 play sound/%s", g_Sounds[soundId]);

    client_cmd(playerId, sound);
}

public HandleStopSound(playerId)
{
    if (get_user_flags(playerId) & ADMIN_FLAG)
    {
        StopSound(0);

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
        StopSound(playerId);
        IncomPrint_Client(0, "[%L] %L", playerId, "INCOM_MUSIC", playerId, "PLAYER_STOP_SOUND");
    }
}

stock StopSound(playerId)
{
    client_cmd(playerId, "stopsound; mp3 stop");
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
        g_SongRequestCounter = amx_incom_music_request_timeout;
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
    if (!amx_incom_music_request_enable)
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

    MakeInactiveMenuCanceler(playerId, 15.0);
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

    new type = amx_incom_music_type;
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

    StopSound(0);
	PlaySound(0, soundId);

	get_user_name(playerId, name, charsmax(name));

	IncomPrint_Client(0, "[%L] %L", playerId, "INCOM_MUSIC", playerId, "SOUND_REQUESTED", name, g_SoundsNames[soundId]);
	menu_destroy(menu)
	return PLUGIN_HANDLED
}