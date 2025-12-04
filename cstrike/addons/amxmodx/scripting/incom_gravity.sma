#include <amxmodx>
#include <cstrike>

new const PLUGIN[]  = "Incomsystem Gravity";
new const VERSION[] = "1.1";
new const AUTHOR[]  = "Tonitaga"

new gravity_changed = false;

new Float:gravity_default;

new       amx_incom_gravity_enable;
new Float:amx_incom_gravity_change_percent;
new Float:amx_incom_gravity_change_value;
new Float:amx_incom_gravity_max_duration;

new pcvar_amx_incom_gravity_enable;
new pcvar_amx_incom_gravity_max_duration;

new const GRAVITY_TASKID = 14500;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_event("HLTV", "OnRoundStart", "a", "1=0", "2=0");

	register_dictionary("incom_gravity.txt");

	gravity_default = get_cvar_float("sv_gravity");
}

public plugin_cfg()
{
	pcvar_amx_incom_gravity_enable = create_cvar(
		"amx_incom_gravity_enable", "1",
		.has_min = true, .min_val = 0.0,
		.has_max = true, .max_val = 1.0,
		.description = "0 - Плагин отключен^n\
						1 - Плагин включен"
	);

	bind_pcvar_num(pcvar_amx_incom_gravity_enable, amx_incom_gravity_enable);

	bind_pcvar_float(
		create_cvar(
			"amx_incom_gravity_change_percent", "1.0",
			.has_min = true, .min_val = 0.0,
			.has_max = true, .max_val = 100.0,
			.description = "Шанс (%) на изменение гравитации в начале раунда"
		),
		amx_incom_gravity_change_percent
	);

	bind_pcvar_float(
		create_cvar(
			"amx_incom_gravity_change_value", "300.0",
			.has_min = true, .min_val = 100.0,
			.has_max = true, .max_val = 2000.0,
			.description = "Значение гравитации при сработке шанса"
		),
		amx_incom_gravity_change_value
	);

	pcvar_amx_incom_gravity_max_duration = 	create_cvar(
		"amx_incom_gravity_max_duration", "120.0",
		.has_min = true, .min_val = 10.0,
		.has_max = true, .max_val = 600.0,
		.description = "Максимальная длительность изменения гравитации"
	);
		
	bind_pcvar_float(pcvar_amx_incom_gravity_max_duration, amx_incom_gravity_max_duration);

	hook_cvar_change(pcvar_amx_incom_gravity_enable, "OnGravityVariableChange");
	hook_cvar_change(pcvar_amx_incom_gravity_max_duration, "OnGravityVariableChange");

	AutoExecConfig();
}

public OnGravityVariableChange(cvar, const old_value[], const new_value[])
{
	if (cvar == pcvar_amx_incom_gravity_enable)
	{
		if (new_value[0] == '0')
		{
			ChangeGravityToDefault();
		}
		else
		{
			ProcessGravity();
		}
	}
	else if (cvar == pcvar_amx_incom_gravity_max_duration)
	{
		ReplaceProcessGravityTask();
	}
}

public ProcessGravity()
{
	if (!amx_incom_gravity_enable)
	{
		return;
	}

	ChangeGravityToDefault();

	new Float:rand = random_float(0.0, 100.0);
	if (rand < amx_incom_gravity_change_percent)
	{
		ChangeGravityToCustom();
	}
}

public OnRoundStart()
{
	ProcessGravity();
	StartProcessGravityTaskOnce();
}

stock ChangeGravity(Float:value)
{
	new command[32];
	formatex(command, charsmax(command), "sv_gravity %f", value);

	server_cmd(command);
}

stock ChangeGravityToCustom()
{
	if (gravity_changed)
	{
		return;
	}

	gravity_changed = true;
	ChangeGravity(amx_incom_gravity_change_value);

	client_print_color(0, print_team_default, "[%L] %L", LANG_PLAYER, "INCOM_GRAVITY", LANG_PLAYER, "GRAVITY_CHANGED", amx_incom_gravity_change_value, amx_incom_gravity_max_duration);
}

stock ChangeGravityToDefault()
{
	if (!gravity_changed)
	{
		return;
	}

	gravity_changed = false;
	ChangeGravity(gravity_default);

	client_print_color(0, print_team_default, "[%L] %L", LANG_PLAYER, "INCOM_GRAVITY", LANG_PLAYER, "GRAVITY_CHANGED_TO_DEF");
}

stock ReplaceProcessGravityTask()
{
	if (task_exists(GRAVITY_TASKID))
	{
		remove_task(GRAVITY_TASKID);
	}

	StartProcessGravityTask();
}

stock StartProcessGravityTaskOnce()
{
	if (!task_exists(GRAVITY_TASKID))
	{
		StartProcessGravityTask();
	}
}

stock StartProcessGravityTask()
{
	set_task(amx_incom_gravity_max_duration, "ProcessGravity", GRAVITY_TASKID, .flags = "b");
}
