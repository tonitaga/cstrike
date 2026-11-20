#include <amxmodx>
#include <incom_case_drops>

public plugin_init()
{
    register_plugin("INCOM Case Drops", "1.0", "INCOMSYSTEM");
}

public plugin_natives()
{
    register_library("incom_case_drops");
    register_native("incom_case_roll", "NativeCaseRoll");
}

public NativeCaseRoll(pluginId, argc)
{
    if (argc != 3)
    {
        log_error(AMX_ERR_NATIVE, "incom_case_roll expects 3 arguments");
        return false;
    }

    new weapon, rarity;
    if (!CaseDropResolve(get_param(1), random_num(0, CASE_DROP_ROLL_COUNT - 1), weapon, rarity))
        return false;

    set_param_byref(2, weapon);
    set_param_byref(3, rarity);
    return true;
}
