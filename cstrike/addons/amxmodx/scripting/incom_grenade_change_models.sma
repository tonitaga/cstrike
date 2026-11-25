#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#define GRENADE_MODEL_PATH 64

enum { MODEL_VIEW, MODEL_PLAYER, MODEL_WORLD };

new const GrenadeNames[][] = { "hegrenade", "flashbang", "smokegrenade" };
new const GrenadeClasses[][] = { "weapon_hegrenade", "weapon_flashbang", "weapon_smokegrenade" };
new const GrenadeIds[] = { CSW_HEGRENADE, CSW_FLASHBANG, CSW_SMOKEGRENADE };
new const ModelPrefix[] = "vpw";

new g_Enabled;
new g_Model[sizeof GrenadeNames][sizeof ModelPrefix - 1][GRENADE_MODEL_PATH];
new g_Stock[sizeof GrenadeNames][sizeof ModelPrefix - 1][GRENADE_MODEL_PATH];
new bool:g_ReplacingWorld;

public plugin_precache()
{
    g_Enabled = register_cvar("incom_grenade_change_enabled", "1");
    new cvars[sizeof GrenadeNames][sizeof ModelPrefix - 1];
    new key[64], path[GRENADE_MODEL_PATH];
    for (new grenade; grenade < sizeof GrenadeNames; grenade++)
    {
        for (new role; role < sizeof ModelPrefix - 1; role++)
        {
            formatex(key, charsmax(key), "incom_grenade_change_%s_%c", GrenadeNames[grenade], ModelPrefix[role]);
            formatex(path, charsmax(path), "models/incom/grenade_change/newyear/%c_%s.mdl", ModelPrefix[role], GrenadeNames[grenade]);
            cvars[grenade][role] = register_cvar(key, path);
            formatex(g_Stock[grenade][role], GRENADE_MODEL_PATH - 1, "models/%c_%s.mdl", ModelPrefix[role], GrenadeNames[grenade]);
        }
    }

    new configs[128];
    get_configsdir(configs, charsmax(configs));
    server_cmd("exec ^"%s/incom_grenade_change_models.cfg^"", configs);
    server_exec();

    // Keep the models precached so the enable switch can take effect mid-map.
    for (new grenade; grenade < sizeof GrenadeNames; grenade++)
    {
        for (new role; role < sizeof ModelPrefix - 1; role++)
        {
            get_pcvar_string(cvars[grenade][role], path, charsmax(path));
            if (!path[0] || equal(path, g_Stock[grenade][role]))
                continue;
            if (!equal(path, "models/", 7) || !file_exists(path) || !equal(path[max(0, strlen(path) - 4)], ".mdl"))
            {
                log_amx("Ignoring invalid grenade model: %s", path);
                continue;
            }
            precache_model(path);
            copy(g_Model[grenade][role], GRENADE_MODEL_PATH - 1, path);
        }
    }
}

public plugin_init()
{
    register_plugin("Incomsystem Grenade Model Change", "1.0", "Tonitaga");
    for (new grenade; grenade < sizeof GrenadeClasses; grenade++)
        RegisterHam(Ham_Item_Deploy, GrenadeClasses[grenade], "GrenadeDeployPost", 1);
    register_forward(FM_SetModel, "GrenadeSetModelPost", 1);
}

public GrenadeDeployPost(entity)
{
    if (!get_pcvar_num(g_Enabled) || !pev_valid(entity))
        return HAM_IGNORED;
    new player = get_member(entity, m_pPlayer);
    if (player < 1 || player > MaxClients || !is_user_alive(player))
        return HAM_IGNORED;

    new grenade;
    new weapon = get_member(entity, m_iId);
    while (grenade < sizeof GrenadeIds && GrenadeIds[grenade] != weapon)
        grenade++;
    if (grenade == sizeof GrenadeIds)
        return HAM_IGNORED;

    ReplaceHeldModel(player, grenade, MODEL_VIEW, pev_viewmodel2);
    ReplaceHeldModel(player, grenade, MODEL_PLAYER, pev_weaponmodel2);
    return HAM_IGNORED;
}

ReplaceHeldModel(player, grenade, role, textField)
{
    if (!g_Model[grenade][role][0])
        return;
    new path[GRENADE_MODEL_PATH];
    pev(player, textField, path, charsmax(path));
    // Preserve the separate shield models and overrides from other plugins.
    if (equal(path, g_Stock[grenade][role]))
        set_pev(player, textField, g_Model[grenade][role]);
}

public GrenadeSetModelPost(entity, const model[])
{
    if (g_ReplacingWorld || !get_pcvar_num(g_Enabled) || !pev_valid(entity))
        return FMRES_IGNORED;

    for (new grenade; grenade < sizeof GrenadeNames; grenade++)
    {
        if (!g_Model[grenade][MODEL_WORLD][0] || !equal(model, g_Stock[grenade][MODEL_WORLD]))
            continue;
        new current[GRENADE_MODEL_PATH];
        pev(entity, pev_model, current, charsmax(current));
        if (equal(current, model))
        {
            g_ReplacingWorld = true;
            engfunc(EngFunc_SetModel, entity, g_Model[grenade][MODEL_WORLD]);
            g_ReplacingWorld = false;
        }
        break;
    }
    return FMRES_IGNORED;
}
