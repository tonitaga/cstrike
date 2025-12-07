#include <amxmodx>
#include <cstrike>
#include <cromchat>

new const PLUGIN[]  = "Incomsystem version";
new const VERSION[] = "1.1";
new const AUTHOR[]  = "Tonitaga"

#define KEY_ENABLE     "amx_incom_version_enable"
#define DEFAULT_ENABLE "1"

new g_Enable;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("say /version",      "ShowVersion");
	register_clcmd("say_team /version", "ShowVersion");

	register_dictionary("incom_version.txt");
}

public plugin_cfg()
{
    g_Enable = create_cvar(KEY_ENABLE, DEFAULT_ENABLE, _, "Статус плагина^n0 - Отключен^n1 - Включен", true, 0.0, true, 1.0);

    AutoExecConfig();
}

public ShowVersion(playerId)
{
    if (get_pcvar_num(g_Enable))
    {
        client_print_color(playerId, print_team_default, "[%L] %L", LANG_PLAYER, "INCOM_VERSION", LANG_PLAYER, "VERSION_MESSAGE");
    }
}