#include <amxmodx>
#include <nvault>
#include <time>

new       demo_recorder_max_value;
new Float:demo_recorder_delay;
new       demo_recorder_name[96];

new g_pHostName;
new g_hVault, g_szMapName[64];

new const PLUGIN[]  = "Demo Recorder";
new const VERSION[] = "1.3";
new const AUTHOR[]  = "mx?! + Tonitaga"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	bind_pcvar_num(
		create_cvar(
			"demo_recorder_max_value", "3",
			.has_min = true, .min_val = 1.0,
			.description = "Макс. кол-во демо на каждую карту"
		),
		demo_recorder_max_value
	);

	bind_pcvar_float(
		create_cvar(
			"demo_recorder_delay", "10",
			.has_min = true, .min_val = 1.0,
			.description = "Задержка записи при входе на сервер"
		),
		demo_recorder_delay
	);

	bind_pcvar_string(
		create_cvar(
			"demo_recorder_name", "mydemo",
			.description = "Имя демофайла (после подставляется название карты и номер демо)"
		),
		demo_recorder_name, charsmax(demo_recorder_name)
	);

	AutoExecConfig();

	register_dictionary("demo_recorder.txt");

	g_pHostName = get_cvar_pointer("hostname")

	get_mapname(g_szMapName, charsmax(g_szMapName))

	g_hVault = nvault_open("demorecorder_data")
	nvault_prune(g_hVault, 0, get_systime() - (SECONDS_IN_DAY * 7))
}

public client_putinserver(playerId)
{
	if(!is_user_bot(playerId) && !is_user_hltv(playerId))
	{
		set_task(demo_recorder_delay, "func_InitRecord", playerId)
	}
}


public client_disconnected(playerId)
{
	remove_task(playerId)
}

public func_InitRecord(playerId)
{
	client_cmd(playerId, "stop")
	set_task(0.2, "task_StartRecord", playerId)
}

public task_StartRecord(playerId)
{
	static szBuffer[128], szAuthID[MAX_AUTHID_LENGTH], iValue

	get_user_authid(playerId, szAuthID, charsmax(szAuthID))
	iValue = max(1, nvault_get(g_hVault, szAuthID))

	formatex(szBuffer, charsmax(szBuffer), "%s_%s_%i", demo_recorder_name, g_szMapName, iValue)

	if(++iValue > demo_recorder_max_value)
	{
		iValue = 1
	}

	nvault_set(g_hVault, szAuthID, fmt("%i", iValue))

	client_cmd(playerId, "record %s", szBuffer)
	set_task(1.0, "task_PrintInfo", playerId, szBuffer, sizeof(szBuffer))
}

public task_PrintInfo(const szDemoName[], playerId)
{
	client_print_color(playerId, print_team_default, "[%L] %L", LANG_PLAYER, "MODE_NAME", LANG_PLAYER, "DEMO_RECORD", szDemoName)

	new hostname[64], time[64]
	get_pcvar_string(g_pHostName, hostname, charsmax(hostname))

	get_time("%d.%m.%Y - %H:%M:%S", time, charsmax(time))
	client_print_color(playerId, print_team_default, "[%L] %s [^3%s^1]^4 %n", LANG_PLAYER, "MODE_NAME", hostname, time, playerId)
}