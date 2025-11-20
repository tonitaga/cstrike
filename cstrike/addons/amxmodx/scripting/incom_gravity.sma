#include <amxmodx>
#include <cstrike>
#include <incom_print>

new const PLUGIN[]  = "Incomsystem Gravity";
new const VERSION[] = "1.0";
new const AUTHOR[]  = "Tonitaga"

new gravity_changed = false;

new Float:gravity_default;

new       amx_incom_gravity_enable;
new Float:amx_incom_gravity_change_percent;
new Float:amx_incom_gravity_change_value;
new Float:amx_incom_gravity_max_duration;

new const force_restore_gravity_task_id = 14500;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_event("HLTV", "OnRoundStart", "a", "1=0", "2=0");
	register_logevent("OnRoundEnd", 2, "1=Round_End");

    register_dictionary("incom_gravity.txt")

    gravity_default = get_cvar_float("sv_gravity");
}

public plugin_cfg()
{
    bind_pcvar_num(
        create_cvar(
            "amx_incom_gravity_enable", "1",
            .has_min = true, .min_val = 0.0,
            .has_max = true, .max_val = 1.0,
            .description = "0 - Плагин отключен^n\
                            1 - Плагин включен"
        ),
        amx_incom_gravity_enable
    );

    bind_pcvar_float(
        create_cvar(
            "amx_incom_gravity_change_percent", "1",
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

    bind_pcvar_float(
        create_cvar(
            "amx_incom_gravity_max_duration", "120.0",
            .has_min = true, .min_val = 10.0,
            .has_max = true, .max_val = 600.0,
            .description = "Максимальная длительность изменения гравитации"
        ),
        amx_incom_gravity_max_duration
    );

    AutoExecConfig();
}

public OnRoundStart()
{
    if (!amx_incom_gravity_enable)
    {
        return;
    }

    new Float:rand = random_float(0.0, 100.0);
    if (rand < amx_incom_gravity_change_percent)
    {
        ChangeGravityToCustom();
        CreateForceRestoreGravityOperation();
    }
}

public OnRoundEnd()
{
    if (gravity_changed)
    {
        RemoveForceRestoreGravityOperation();
        ChangeGravityToDefault();
    }
}

stock ChangeGravity(Float:value)
{
    new command[32];
    formatex(command, charsmax(command), "sv_gravity %f", value);

    server_cmd(command);
}

stock ChangeGravityToCustom()
{
    gravity_changed = true;
    ChangeGravity(amx_incom_gravity_change_value);

    IncomPrint_Client(0, "[%L] %L", 0, "INCOM_GRAVITY", 0, "GRAVITY_CHANGED", amx_incom_gravity_change_value, amx_incom_gravity_max_duration);
}

stock ChangeGravityToDefault()
{
    gravity_changed = false;
    ChangeGravity(gravity_default);

    IncomPrint_Client(0, "[%L] %L", 0, "INCOM_GRAVITY", 0, "GRAVITY_CHANGED_TO_DEF");
}

stock CreateForceRestoreGravityOperation()
{
    set_task(amx_incom_gravity_max_duration, "ForceRestoreGravity", force_restore_gravity_task_id);
}

stock RemoveForceRestoreGravityOperation()
{
    remove_task(force_restore_gravity_task_id);
}

public ForceRestoreGravity()
{
    if (gravity_changed)
    {
        ChangeGravityToDefault();
    }
}