#include <amxmodx>
#include <reapi>

#define PLUGIN  "Incomsystem TTS"
#define VERSION "1.0"
#define AUTHOR  "Tonitaga"

#define REQUEST_FILE "addons/amxmodx/data/incom_tts/request.txt"
#define STATUS_FILE  "addons/amxmodx/data/incom_tts/status.txt"
#define SOUND_FILE   "sound/incom_tts/voice.wav"

#define TASK_POLL     31000
#define POLL_INTERVAL 0.2
#define POLL_MAX      50

new amx_incom_tts_enable;
new amx_incom_tts_cooldown;

new g_Busy;
new g_PollCount;
new g_LastUse;
new g_RequestPlayer;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_clcmd("say", "OnSay");
    register_clcmd("say_team", "OnSay");

    register_dictionary("incom_tts.txt");

    mkdir("addons/amxmodx/data/incom_tts");
    mkdir("sound/incom_tts");
}

public plugin_precache()
{
    mkdir("sound/incom_tts");
}

public plugin_cfg()
{
    bind_pcvar_num(
        create_cvar(
            "amx_incom_tts_enable", "1",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 1.0,
            .description = "Статус плагина^n\
                            0 - Отключен^n\
                            1 - Включен"
        ),
        amx_incom_tts_enable
    );

    bind_pcvar_num(
        create_cvar(
            "amx_incom_tts_cooldown", "10",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 120.0,
            .description = "Минимальное время между запросами /voice в секундах"
        ),
        amx_incom_tts_cooldown
    );

    AutoExecConfig();
}

public plugin_end()
{
    if (task_exists(TASK_POLL))
    {
        remove_task(TASK_POLL);
    }
}

public client_disconnected(playerId)
{
    if (g_RequestPlayer == playerId)
    {
        g_RequestPlayer = 0;
    }
}

public OnSay(playerId)
{
    new said[192];
    read_args(said, charsmax(said));
    remove_quotes(said);
    trim(said);

    if (!equali(said, "/voice", 6) || (said[6] != ' ' && said[6] != EOS))
    {
        return PLUGIN_CONTINUE;
    }

    if (!amx_incom_tts_enable)
    {
        client_print_color(playerId, print_team_default, "[%L] %L", LANG_PLAYER, "INCOM_TTS", LANG_PLAYER, "TTS_DISABLED");
        return PLUGIN_HANDLED;
    }

    if (!has_vtc())
    {
        client_print_color(playerId, print_team_default, "[%L] %L", LANG_PLAYER, "INCOM_TTS", LANG_PLAYER, "TTS_FAIL");
        return PLUGIN_HANDLED;
    }

    if (!is_user_connected(playerId))
    {
        return PLUGIN_HANDLED;
    }

    if (g_Busy)
    {
        client_print_color(playerId, print_team_default, "[%L] %L", LANG_PLAYER, "INCOM_TTS", LANG_PLAYER, "TTS_BUSY");
        return PLUGIN_HANDLED;
    }

    new now = get_systime();
    new elapsed = now - g_LastUse;
    if (g_LastUse && elapsed < amx_incom_tts_cooldown)
    {
        client_print_color(playerId, print_team_default, "[%L] %L", LANG_PLAYER, "INCOM_TTS", LANG_PLAYER, "TTS_COOLDOWN", amx_incom_tts_cooldown - elapsed);
        return PLUGIN_HANDLED;
    }

    new text[192];
    if (said[6] == ' ')
    {
        copy(text, charsmax(text), said[7]);
    }

    replace_string(text, charsmax(text), "^n", " ");
    replace_string(text, charsmax(text), "^r", " ");
    trim(text);

    if (text[0] == EOS)
    {
        client_print_color(playerId, print_team_default, "[%L] %L", LANG_PLAYER, "INCOM_TTS", LANG_PLAYER, "TTS_USAGE");
        return PLUGIN_HANDLED;
    }

    if (!WriteRequest(text))
    {
        client_print_color(playerId, print_team_default, "[%L] %L", LANG_PLAYER, "INCOM_TTS", LANG_PLAYER, "TTS_FAIL");
        return PLUGIN_HANDLED;
    }

    g_Busy = true;
    g_PollCount = 0;
    g_RequestPlayer = playerId;
    set_task(POLL_INTERVAL, "PollTtsStatus", TASK_POLL, .flags = "b");

    return PLUGIN_HANDLED;
}

public PollTtsStatus()
{
    g_PollCount++;

    if (file_exists(STATUS_FILE))
    {
        new line[64];
        new file = fopen(STATUS_FILE, "rt");
        if (file)
        {
            fgets(file, line, charsmax(line));
            fclose(file);
        }

        delete_file(STATUS_FILE);
        FinishRequest();
        trim(line);

        if (equal(line, "OK", 2) && (line[2] == EOS || line[2] == ' '))
        {
            PlayTtsToAll();
            g_LastUse = get_systime();

            new name[32];
            if (g_RequestPlayer && is_user_connected(g_RequestPlayer))
            {
                get_user_name(g_RequestPlayer, name, charsmax(name));
            }
            else
            {
                copy(name, charsmax(name), "-");
            }

            client_print_color(0, print_team_default, "[%L] %L", LANG_PLAYER, "INCOM_TTS", LANG_PLAYER, "TTS_PLAYING", name);
        }
        else if (g_RequestPlayer && is_user_connected(g_RequestPlayer))
        {
            client_print_color(g_RequestPlayer, print_team_default, "[%L] %L", LANG_PLAYER, "INCOM_TTS", LANG_PLAYER, "TTS_FAIL");
        }

        return;
    }

    if (g_PollCount >= POLL_MAX)
    {
        FinishRequest();

        if (g_RequestPlayer && is_user_connected(g_RequestPlayer))
        {
            client_print_color(g_RequestPlayer, print_team_default, "[%L] %L", LANG_PLAYER, "INCOM_TTS", LANG_PLAYER, "TTS_HELPER");
        }
    }
}

stock FinishRequest()
{
    g_Busy = false;

    if (task_exists(TASK_POLL))
    {
        remove_task(TASK_POLL);
    }
}

stock PlayTtsToAll()
{
    if (!has_vtc())
    {
        return;
    }

    new players[MAX_PLAYERS], num;
    get_players(players, num, "ch");

    for (new i = 0; i < num; i++)
    {
        VTC_PlaySound(players[i], SOUND_FILE);
    }
}

stock bool:WriteRequest(const text[])
{
    if (file_exists(STATUS_FILE))
    {
        delete_file(STATUS_FILE);
    }

    if (file_exists(REQUEST_FILE))
    {
        delete_file(REQUEST_FILE);
    }

    new file = fopen(REQUEST_FILE, "wt");
    if (!file)
    {
        return false;
    }

    fputs(file, text);
    fclose(file);
    return true;
}
