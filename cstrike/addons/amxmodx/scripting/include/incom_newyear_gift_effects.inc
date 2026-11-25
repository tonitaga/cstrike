#define TASK_GIFT_EFFECT 7300

enum
{
    GIFT_EFFECT_NONE,
    GIFT_EFFECT_JUMP,
    GIFT_EFFECT_SPEED,
    GIFT_EFFECT_COCOA,
    GIFT_EFFECT_ICE_TREADS,
    GIFT_EFFECT_WARM_GLOVES,
    GIFT_EFFECT_COUNT
};

new const GIFT_EFFECT_NAMES[][] =
{
    "", "Высокий прыжок", "Скорость +25%", "Горячий какао", "Ледоступы", "Тёплые перчатки"
};

new g_GiftEffectChance, g_GiftEffectDuration;
new Float:g_GiftEffectEnd[MAX_PLAYERS + 1][GIFT_EFFECT_COUNT];
new Float:g_CocoaNextHeal[MAX_PLAYERS + 1];
new bool:g_GiftJumpGrounded[MAX_PLAYERS + 1];
new Float:g_GiftHealthBefore[MAX_PLAYERS + 1], Float:g_GiftArmorBefore[MAX_PLAYERS + 1];
new Float:g_GiftSlowBefore[MAX_PLAYERS + 1];

InitGiftEffects()
{
    g_GiftEffectChance = register_cvar("incom_newyear_gifts_effect_chance", "20");
    g_GiftEffectDuration = register_cvar("incom_newyear_gifts_effect_duration", "20");
    RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "GiftEffectSpeedPost", true);
    RegisterHookChain(RG_PM_Jump, "GiftEffectJumpPre");
    RegisterHookChain(RG_PM_Jump, "GiftEffectJumpPost", true);
    RegisterHookChain(RG_CBasePlayer_TakeDamage, "GiftEffectDamagePre");
    RegisterHookChain(RG_CBasePlayer_TakeDamage, "GiftEffectDamagePost", true);
    RegisterHookChain(RG_CBasePlayer_Killed, "GiftEffectKilledPost", true);
    RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "GiftEffectReload");
    RegisterHookChain(RG_CBasePlayerWeapon_DefaultShotgunReload, "GiftEffectShotgunReload");
}

bool:GiftEffectActive(id, effect)
{
    return id >= 1 && id <= MaxClients && get_pcvar_num(g_Enable)
        && get_pcvar_num(g_GiftEffectDuration) > 0 && get_gametime() < g_GiftEffectEnd[id][effect];
}

ClearGiftEffect(id, bool:restoreSpeed)
{
    new bool:hadSpeed = g_GiftEffectEnd[id][GIFT_EFFECT_SPEED] > 0.0;
    arrayset(g_GiftEffectEnd[id], 0, GIFT_EFFECT_COUNT);
    g_GiftJumpGrounded[id] = false;
    remove_task(TASK_GIFT_EFFECT + id);
    if (restoreSpeed && hadSpeed && is_user_alive(id))
        rg_reset_maxspeed(id);
}

TryGiftEffect(id)
{
    new duration = clamp(get_pcvar_num(g_GiftEffectDuration), 0, 300);
    if (!duration || !GiftChance(g_GiftEffectChance))
        return;

    ApplyGiftEffect(id, random_num(GIFT_EFFECT_JUMP, GIFT_EFFECT_COUNT - 1), duration);
}

ApplyGiftEffect(id, effect, duration)
{
    new Float:now = get_gametime();
    new bool:first = g_GiftEffectEnd[id][effect] == 0.0;
    g_GiftEffectEnd[id][effect] = now + float(duration);
    if (effect == GIFT_EFFECT_COCOA && first)
        g_CocoaNextHeal[id] = now + 1.0;
    if (effect == GIFT_EFFECT_SPEED && first)
        GiftEffectSpeedPost(id);

    if (!task_exists(TASK_GIFT_EFFECT + id))
        set_task(0.2, "GiftEffectTick", TASK_GIFT_EFFECT + id, .flags = "b");
    client_print_color(id, print_team_blue, "^4[Новый год]^1 Эффект: ^3%s^1. На ^4%d сек.^1.",
        GIFT_EFFECT_NAMES[effect], duration);
}

public GiftEffectTick(task)
{
    new id = task - TASK_GIFT_EFFECT;
    if (!is_user_alive(id) || !get_pcvar_num(g_Enable) || get_pcvar_num(g_GiftEffectDuration) <= 0)
    {
        ClearGiftEffect(id, true);
        return;
    }

    new Float:now = get_gametime(), bool:any;
    for (new effect = GIFT_EFFECT_JUMP; effect < GIFT_EFFECT_COUNT; effect++)
    {
        if (!g_GiftEffectEnd[id][effect])
            continue;
        if (now < g_GiftEffectEnd[id][effect])
        {
            any = true;
            continue;
        }
        g_GiftEffectEnd[id][effect] = 0.0;
        if (effect == GIFT_EFFECT_SPEED)
            rg_reset_maxspeed(id);
    }
    if (!any)
    {
        remove_task(task);
        return;
    }

    if (!GiftEffectActive(id, GIFT_EFFECT_COCOA) || now < g_CocoaNextHeal[id])
        return;
    g_CocoaNextHeal[id] = now + 1.0;
    new Float:health = get_entvar(id, var_health);
    if (health < 100.0)
        set_entvar(id, var_health, floatmin(100.0, health + 2.0));
}

public GiftEffectSpeedPost(id)
{
    if (!GiftEffectActive(id, GIFT_EFFECT_SPEED))
        return HC_CONTINUE;

    new Float:speed = get_entvar(id, var_maxspeed);
    // Keep the game's freeze and immobilisation speed.
    if (speed > 10.0)
        set_entvar(id, var_maxspeed, speed * 1.25);
    return HC_CONTINUE;
}

public GiftEffectJumpPre(id)
{
    if (GiftEffectActive(id, GIFT_EFFECT_JUMP))
        g_GiftJumpGrounded[id] = get_pmove(pm_onground) >= 0
            && get_pmove(pm_waterlevel) < 2 && get_pmove(pm_movetype) == MOVETYPE_WALK;
    return HC_CONTINUE;
}

public GiftEffectJumpPost(id)
{
    if (!GiftEffectActive(id, GIFT_EFFECT_JUMP) || !g_GiftJumpGrounded[id])
        return HC_CONTINUE;

    g_GiftJumpGrounded[id] = false;
    if (get_pmove(pm_onground) < 0)
    {
        new Float:velocity[3];
        get_pmove(pm_velocity, velocity);
        if (velocity[2] > 0.0)
        {
            velocity[2] *= 1.12;
            set_pmove(pm_velocity, velocity);
        }
    }
    return HC_CONTINUE;
}

public GiftEffectDamagePre(id)
{
    if (GiftEffectActive(id, GIFT_EFFECT_COCOA) || GiftEffectActive(id, GIFT_EFFECT_ICE_TREADS))
    {
        g_GiftHealthBefore[id] = get_entvar(id, var_health);
        g_GiftArmorBefore[id] = get_entvar(id, var_armorvalue);
        g_GiftSlowBefore[id] = get_member(id, m_flVelocityModifier);
    }
    return HC_CONTINUE;
}

public GiftEffectDamagePost(id, inflictor, attacker, Float:damage, damageType)
{
    if (!GiftEffectActive(id, GIFT_EFFECT_COCOA) && !GiftEffectActive(id, GIFT_EFFECT_ICE_TREADS))
        return HC_CONTINUE;
    if (Float:get_entvar(id, var_health) >= g_GiftHealthBefore[id]
        && Float:get_entvar(id, var_armorvalue) >= g_GiftArmorBefore[id])
        return HC_CONTINUE;

    if (GiftEffectActive(id, GIFT_EFFECT_COCOA))
        g_CocoaNextHeal[id] = get_gametime() + 3.0;
    if (GiftEffectActive(id, GIFT_EFFECT_ICE_TREADS) && attacker != id && attacker >= 1
        && attacker <= MaxClients && (damageType & (DMG_BULLET | DMG_SLASH)))
    {
        new Float:modifier = get_member(id, m_flVelocityModifier);
        if (modifier < g_GiftSlowBefore[id])
            set_member(id, m_flVelocityModifier, modifier + (g_GiftSlowBefore[id] - modifier) * 0.30);
    }
    return HC_CONTINUE;
}

public GiftEffectKilledPost(id)
{
    ClearGiftEffect(id, false);
    return HC_CONTINUE;
}

public GiftEffectReload(weapon, clipSize, animation, Float:delay)
{
    if (GiftEffectActive(get_member(weapon, m_pPlayer), GIFT_EFFECT_WARM_GLOVES))
        SetHookChainArg(4, ATYPE_FLOAT, delay * 0.5);
    return HC_CONTINUE;
}

public GiftEffectShotgunReload(weapon, animation, startAnimation, Float:delay, Float:startDelay)
{
    if (GiftEffectActive(get_member(weapon, m_pPlayer), GIFT_EFFECT_WARM_GLOVES))
    {
        SetHookChainArg(4, ATYPE_FLOAT, delay * 0.5);
        SetHookChainArg(5, ATYPE_FLOAT, startDelay * 0.5);
    }
    return HC_CONTINUE;
}
