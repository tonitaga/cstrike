#include <amxmodx>
#include <cstrike>
#include <cromchat>

new const PLUGIN[]  = "Incomsystem version";
new const VERSION[] = "1.0";
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

    AutoExecConfig(true, "incom_version");
}

public ShowVersion(playerId)
{
    if (get_pcvar_num(g_Enable))
    {
        CC_SendMessage(playerId, "INCOMSYSTEM [&x07DEV ZONE&x01]&x01 v&x07%L&x01. By Tonitaga", playerId, "VERSION_MESSAGE");
    }
}