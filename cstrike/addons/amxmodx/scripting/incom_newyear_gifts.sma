#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <nvault>
#include <reapi>
#include <incom_newyear_gifts>
#include <incom_case_reveal>

#define MAX_GIFTS 24
#define MAX_GIFT_POINTS 128
#define AUTO_POINT_LIFETIME 120.0
#define AUTO_POINT_SPACING 84.0
#define MAX_FLOOR_SHIFT 64.0
#define CASE_STOCK_MAX 50
#define PROFILE_SIZE ((GIFT_COLLECTION_SIZE + 1) * 7 + sizeof CASE_TYPES * (CASE_STOCK_MAX + 1) + 1)
#define MIN_POINT_DISTANCE 48.0
#define TASK_CASE_REVEAL 7100
#define CASE_BOX_OPEN_TIME 0.90
#define CASE_BATCH_MAX 5

enum
{
    CASE_EVENT_NEW_YEAR
};

enum _:CaseType
{
    CaseEvent,
    CaseName[32],
    bool:CaseAvailable
};

new const CASE_EVENTS[][] = {"Новый год"};
// Type positions match the drop API and stored queue order. Append future types.
new const CASE_TYPES[CASE_TYPE_COUNT][CaseType] = {
    {CASE_EVENT_NEW_YEAR, "M4A1", false},
    {CASE_EVENT_NEW_YEAR, "AK-47", false},
    {CASE_EVENT_NEW_YEAR, "Glock", false},
    {CASE_EVENT_NEW_YEAR, "Deagle", false},
    {CASE_EVENT_NEW_YEAR, "AWP", false},
    {CASE_EVENT_NEW_YEAR, "USP", false},
    {CASE_EVENT_NEW_YEAR, "Спецназ", true},
    {CASE_EVENT_NEW_YEAR, "Террорист", true},
    {CASE_EVENT_NEW_YEAR, "Снайпер", true}
};
new const CASE_ALPHABET[] = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN";

new const GIFT_CLASS[] = "incom_newyear_gift";
new const GIFT_MODELS[][] = {"models/incom/newyear/gift.mdl", "models/incom/newyear/gift_rare.mdl"};
new const GIFT_SPARKS[][] = {"sprites/incom/newyear/gift_spark.spr", "sprites/incom/newyear/gift_spark_rare.spr"};
new const GIFT_CHIME[] = "incom/newyear/gift_wave.wav";
new const CASE_TICK[] = "incom/newyear/case_tick.wav";
new const SKIN_NAMES[CASE_WEAPON_BUTTERFLY + 1][CASE_RARITY_COUNT][] = {
    {"Хвойная гравировка", "Северная вязь", "Ледяная геометрия", "Бархатный подарок"},
    {"Медные шишки", "Морозная рябина", "Еловые огни", "Зимняя жар-птица"},
    {"Мятная звезда", "Карамельная трость", "Праздничные лампочки", "Парад конфетти"},
    {"Кобальтовый иней", "Пряничный городок", "Стеклянные игрушки", "Ледяной витраж"},
    {"Альпийский снег", "Подарки под ёлкой", "Северное сияние", "Ледяные куранты"},
    {"Остролист", "Сахарная глазурь", "Серебряные сосульки", "Изумрудная ёлка"},
    {"Морозная гравировка", "Карамельная бабочка", "Ледяные узоры", "Полярный экспресс"}
};
new const SKIN_EXTRA_NAMES[CASE_WEAPON_COUNT][GIFT_EXTRA_SKINS][] = {
    {"Еловая гравюра", "Морозные перья", "Бечёвка", "Северный свитер", "Мятный кристалл", "Медные колокола", "Ледяной дворец", "Бархатные розетки", "Изумрудный бант"},
    {"Меловой снег", "Медный бор", "Зимняя рябина", "Бумажные снежинки", "Серебряная хвоя", "Латунная гирлянда", "Лиловая мишура", "Алый фейерверк", "Медная шкатулка"},
    {"Мятные звёзды", "Бирюзовый иней", "Мятные леденцы", "Карамельные полосы", "Стеклянные звёзды", "Еловые фонарики", "Розовый серпантин", "Сахарные кристаллы", "Зимний фарфор"},
    {"Синий фарфор", "Звёздный календарь", "Имбирное печенье", "Пряничная улица", "Золотые подвески", "Бордовые веера", "Аметистовые шары", "Серебряный механизм", "Бой курантов"},
    {"Горная хвоя", "Ледяные контуры", "Снег над елями", "Алые коробки", "Полярная лента", "Кобальтовые сосульки", "Звёздное сияние", "Серебряная метель", "Фонари в зимнем лесу"},
    {"Листья падуба", "Имбирная глазурь", "Снежный вечер", "Алые бубенцы", "Сахарные звёздочки", "Кобальтовые игрушки", "Изумрудный атлас", "Ленты в полночь", "Позолоченные игрушки"}
};
new const KNIFE_EXTRA_NAMES[][] = {
    "Ледяной штрих", "Морозный олень", "Аметистовый снег", "Парад щелкунчика",
    "Снежная сталь", "Зимняя хвоя", "Леденцовая лента", "Медная шишка",
    "Звёздный аметист", "Полярное стекло", "Зелёная аврора", "Механика праздника",
    "Ледяная пыль", "Хвойный венок", "Карамельный завиток", "Медный зимний лес",
    "Фиолетовый иней", "Бирюзовый витраж", "Хрустальная сакура", "Перо жар-птицы"
};
new const KNIFE_NAMES[][] = {"Бабочка", "Skeleton", "Karambit"};
new const KNIFE_FOLDERS[][] = {"butterfly", "skeleton", "karambit"};
new g_SkinNames[GIFT_COLLECTION_SIZE][72];
new g_CaseMotdUrl, g_CaseSceneSerial;
new bool:g_Revealing[MAX_PLAYERS + 1];
new g_RevealStep[MAX_PLAYERS + 1];
new g_RevealCount[MAX_PLAYERS + 1];
new g_RevealReward[MAX_PLAYERS + 1][CASE_BATCH_MAX], g_RevealCredit[MAX_PLAYERS + 1][CASE_BATCH_MAX];
new g_RevealName[MAX_PLAYERS + 1][32];
new Float:g_RevealDeadline[MAX_PLAYERS + 1];
new const WEAPON_NAMES[][] = {"M4A1", "AK-47", "Glock", "Deagle", "AWP", "USP", "Ножи"};
new const RARITY_NAMES[][] = {"Обычный", "Редкий", "Эпический", "Легендарный"};

new g_Vault = INVALID_HANDLE;
new g_Enable, g_Interval, g_WaveMin, g_WaveMax, g_MinPlayers, g_ActiveMax, g_Lifetime;
new g_RewardMin, g_RewardMax, g_KillReward, g_KillCooldown, g_CasePrice;
new g_RareChance, g_RareMultiplier, g_GiftCaseChance;
new Float:g_LastWave;
new Float:g_Points[MAX_GIFT_POINTS][3], g_PointCount;
new Float:g_AutoPoints[MAX_GIFT_POINTS][3], Float:g_AutoSeen[MAX_GIFT_POINTS];
new g_AutoNext;
new g_Gifts[MAX_GIFTS], g_GiftPoint[MAX_GIFTS], g_GiftSpark[sizeof GIFT_SPARKS];
new bool:g_RareGift[MAX_GIFTS];
new Float:g_GiftExpires[MAX_GIFTS];
new g_PointFile[160];
new const SKIN_FOLDERS[][] = {"m4a1", "ak47", "glock18", "deagle", "awp", "usp", "butterfly"};
new const SKIN_TIERS[][] = {"common", "rare", "epic", "legendary"};
new const SKIN_WEAPONS[] = {CSW_M4A1, CSW_AK47, CSW_GLOCK18, CSW_DEAGLE, CSW_AWP, CSW_USP, CSW_KNIFE};
new g_View[GIFT_COLLECTION_SIZE][96], g_Player[GIFT_COLLECTION_SIZE][96];
new g_Selected[MAX_PLAYERS + 1][CASE_WEAPON_BUTTERFLY + 1];
new bool:g_SelectionLoaded[MAX_PLAYERS + 1];
new g_LastSkinWeapon[MAX_PLAYERS + 1];
new g_OldView[MAX_PLAYERS + 1][128], g_OldPlayer[MAX_PLAYERS + 1][128];
new Float:g_LastKill[MAX_PLAYERS + 1][MAX_PLAYERS + 1];

public plugin_precache()
{
    for (new kind; kind < sizeof GIFT_MODELS; kind++)
    {
        precache_model(GIFT_MODELS[kind]);
        g_GiftSpark[kind] = precache_model(GIFT_SPARKS[kind]);
    }
    precache_sound(GIFT_CHIME);
    precache_sound(CASE_TICK);
    for (new weapon = 0; weapon < sizeof SKIN_WEAPONS; weapon++)
    {
        new filename[12];
        copy(filename, charsmax(filename), weapon == CASE_WEAPON_BUTTERFLY ? "knife" : SKIN_FOLDERS[weapon]);
        for (new variant = 0; variant < GiftVariantCount(weapon); variant++)
        {
            new index = GiftVariantIndex(weapon, variant);
            new rarity = GiftSkinRarity(index);
            new suffix[8];
            if (weapon == CASE_WEAPON_BUTTERFLY && variant >= CASE_RARITY_COUNT)
            {
                formatex(g_View[index], charsmax(g_View[]), "models/incom/newyear/%s/%s/v_knife_k%02d%s.mdl",
                         KNIFE_FOLDERS[variant / 8], SKIN_TIERS[rarity], variant,
                         rarity == CASE_RARITY_LEGENDARY ? "b" : "");
                copy(g_SkinNames[index], charsmax(g_SkinNames[]), KNIFE_EXTRA_NAMES[variant - CASE_RARITY_COUNT]);
                precache_model(g_View[index]);
                continue;
            }
            if (variant < CASE_RARITY_COUNT)
            {
                if (rarity == CASE_RARITY_LEGENDARY && (weapon == CASE_WEAPON_DEAGLE || weapon == CASE_WEAPON_BUTTERFLY))
                    copy(suffix, charsmax(suffix), weapon == CASE_WEAPON_BUTTERFLY ? "r15" : "r14");
                else
                    copy(suffix, charsmax(suffix), weapon == CASE_WEAPON_BUTTERFLY ? "r11" : "r13");
                copy(g_SkinNames[index], charsmax(g_SkinNames[]), SKIN_NAMES[weapon][variant]);
            }
            else
            {
                new bool:reworked = rarity == CASE_RARITY_LEGENDARY
                    && (weapon == CASE_WEAPON_AK47 || weapon == CASE_WEAPON_GLOCK || weapon == CASE_WEAPON_AWP);
                formatex(suffix, charsmax(suffix), "n%02d%s", variant - CASE_RARITY_COUNT + 1, reworked ? (weapon == CASE_WEAPON_AK47 ? "h" : "g") : "f");
                copy(g_SkinNames[index], charsmax(g_SkinNames[]), SKIN_EXTRA_NAMES[weapon][variant - CASE_RARITY_COUNT]);
            }
            formatex(g_View[index], charsmax(g_View[]), "models/incom/newyear/%s/%s/v_%s_%s.mdl",
                     SKIN_FOLDERS[weapon], SKIN_TIERS[rarity], filename, suffix);
            precache_model(g_View[index]);
            if (weapon != CASE_WEAPON_BUTTERFLY)
            {
                formatex(g_Player[index], charsmax(g_Player[]), "models/incom/newyear/%s/%s/p_%s_%sp%s.mdl",
                         SKIN_FOLDERS[weapon], SKIN_TIERS[rarity], filename, suffix, weapon == CASE_WEAPON_AWP ? "2" : "");
                precache_model(g_Player[index]);
            }
        }
    }
}

public plugin_init()
{
    register_plugin("INCOM New Year Gifts", "1.2", "INCOMSYSTEM");
    g_Enable = register_cvar("incom_newyear_gifts_enabled", "1");
    g_Interval = register_cvar("incom_newyear_gifts_interval", "60");
    g_MinPlayers = register_cvar("incom_newyear_gifts_min_players", "4");
    g_WaveMin = register_cvar("incom_newyear_gifts_wave_min", "2");
    g_WaveMax = register_cvar("incom_newyear_gifts_wave_max", "5");
    g_ActiveMax = register_cvar("incom_newyear_gifts_active_max", "5");
    g_Lifetime = register_cvar("incom_newyear_gifts_lifetime", "55");
    g_RewardMin = register_cvar("incom_newyear_gifts_reward_min", "15");
    g_RewardMax = register_cvar("incom_newyear_gifts_reward_max", "21");
    g_RareChance = register_cvar("incom_newyear_gifts_rare_chance", "10");
    g_RareMultiplier = register_cvar("incom_newyear_gifts_rare_multiplier", "2.0");
    g_GiftCaseChance = register_cvar("incom_newyear_gifts_case_chance", "5");
    g_KillReward = register_cvar("incom_newyear_gifts_kill_reward", "2");
    g_KillCooldown = register_cvar("incom_newyear_gifts_kill_cooldown", "20");
    g_CasePrice = register_cvar("incom_newyear_gifts_case_price", "60");
    g_CaseMotdUrl = register_cvar("incom_newyear_gifts_case_motd_url", "");

    register_touch(GIFT_CLASS, "player", "GiftTouch");
    register_think(GIFT_CLASS, "GiftExpire");
    // Loaded after the ordinary skin plugins, so an equipped seasonal skin takes precedence.
    register_event("CurWeapon", "ApplyCurrentSkin", "be", "1=1");
    register_event("DeathMsg", "OnDeath", "a", "1>0");
    register_clcmd("say /case", "OpenCaseMenu");
    register_clcmd("say_team /case", "OpenCaseMenu");
    register_clcmd("say /snowflakes", "ShowBalance");
    register_clcmd("say /skins", "ShowCollection");
    register_clcmd("say_team /skins", "ShowCollection");
    register_concmd("amx_gift_add", "AddPoint", ADMIN_CFG, "- add a gift point at your feet");
    register_concmd("amx_gift_remove", "RemovePoint", ADMIN_CFG, "- remove the nearest gift point");
    register_concmd("amx_gift_wave", "ForceWave", ADMIN_CFG, "- spawn a gift wave now");

    g_Vault = nvault_open("incom_newyear_gifts");
    if (g_Vault == INVALID_HANDLE)
        set_fail_state("Unable to open the snowflake wallet");
}

public plugin_cfg()
{
    new configs[96], map[48];
    get_configsdir(configs, charsmax(configs));
    get_mapname(map, charsmax(map));
    server_cmd("exec ^"%s/incom_newyear_gifts.cfg^"", configs);
    server_exec();

    formatex(g_PointFile, charsmax(g_PointFile), "%s/incom_gift_points", configs);
    if (!dir_exists(g_PointFile))
        mkdir(g_PointFile);
    format(g_PointFile, charsmax(g_PointFile), "%s/%s.ini", g_PointFile, map);
    LoadPoints();
    server_print("[New Year] %d gift points loaded for %s", g_PointCount, map);
    g_LastWave = get_gametime();
    set_task(1.0, "CheckWaves", .flags = "b");
}

public plugin_end()
{
    if (g_Vault != INVALID_HANDLE)
        nvault_close(g_Vault);
}

LoadPoints()
{
    new file = fopen(g_PointFile, "rt");
    if (!file)
        return;

    new line[128], x[24], y[24], z[24];
    while (g_PointCount < MAX_GIFT_POINTS && fgets(file, line, charsmax(line)))
    {
        trim(line);
        if (!line[0] || line[0] == ';' || parse(line, x, charsmax(x), y, charsmax(y), z, charsmax(z)) != 3)
            continue;
        new Float:position[3];
        position[0] = str_to_float(x);
        position[1] = str_to_float(y);
        position[2] = str_to_float(z);
        if (NearPoint(position, MIN_POINT_DISTANCE) < 0)
            CopyPoint(g_Points[g_PointCount++], position);
    }
    fclose(file);
}

bool:SavePoints()
{
    new temporary[172], backup[172];
    formatex(temporary, charsmax(temporary), "%s.tmp", g_PointFile);
    formatex(backup, charsmax(backup), "%s.bak", g_PointFile);
    new file = fopen(temporary, "wt");
    if (!file)
        return false;
    for (new i = 0; i < g_PointCount; i++)
        fprintf(file, "%.2f %.2f %.2f^n", g_Points[i][0], g_Points[i][1], g_Points[i][2]);
    fclose(file);

    new bool:hadFile = file_exists(g_PointFile) != 0;
    if (hadFile && !rename_file(g_PointFile, backup, 1))
    {
        delete_file(temporary);
        return false;
    }
    if (rename_file(temporary, g_PointFile, 1))
    {
        if (hadFile)
            delete_file(backup);
        return true;
    }
    if (hadFile && !rename_file(backup, g_PointFile, 1))
        log_amx("Gift point backup could not be restored: %s", backup);
    delete_file(temporary);
    return false;
}

CopyPoint(Float:destination[3], const Float:source[3])
{
    for (new axis = 0; axis < 3; axis++)
        destination[axis] = source[axis];
}

NearPoint(const Float:position[3], Float:distance)
{
    new nearest = -1;
    for (new i = 0; i < g_PointCount; i++)
    {
        new Float:gap = get_distance_f(position, g_Points[i]);
        if (gap < distance)
        {
            distance = gap;
            nearest = i;
        }
    }
    return nearest;
}

bool:FindFloor(const Float:point[3], Float:result[3], bool:staticFloor = false)
{
    new Float:start[3], Float:finish[3], Float:fraction, Float:normal[3];
    CopyPoint(start, point);
    CopyPoint(finish, point);
    start[2] += 16.0;
    finish[2] -= 96.0;
    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, start, finish, IGNORE_MONSTERS, 0, trace);
    get_tr2(trace, TR_flFraction, fraction);
    get_tr2(trace, TR_vecPlaneNormal, normal);
    get_tr2(trace, TR_vecEndPos, result);
    new bool:valid = fraction < 1.0 && !get_tr2(trace, TR_StartSolid) && normal[2] >= 0.65;
    new hit = get_tr2(trace, TR_pHit);
    if (valid && staticFloor && hit > 0)
    {
        new classname[32];
        pev(hit, pev_classname, classname, charsmax(classname));
        valid = equal(classname, "func_wall") != 0;
    }
    free_tr2(trace);
    result[2] += 1.0;
    if (!valid || engfunc(EngFunc_PointContents, result) != CONTENTS_EMPTY)
        return false;

    for (new x = -13; x <= 13; x += 26)
        for (new y = -13; y <= 13; y += 26)
            for (new z = 3; z <= 27; z += 24)
            {
                new Float:corner[3];
                corner[0] = result[0] + float(x);
                corner[1] = result[1] + float(y);
                corner[2] = result[2] + float(z);
                if (engfunc(EngFunc_PointContents, corner) != CONTENTS_EMPTY)
                    return false;
            }
    return true;
}

public AddPoint(id, flags, command)
{
    if (!cmd_access(id, flags, command, 1) || !id || !is_user_alive(id))
        return PLUGIN_HANDLED;

    new Float:origin[3], Float:floor[3];
    pev(id, pev_origin, origin);
    if (g_PointCount == MAX_GIFT_POINTS || !FindFloor(origin, floor) || NearPoint(floor, MIN_POINT_DISTANCE) >= 0)
    {
        console_print(id, "[New Year] Invalid floor, point too close, or point limit reached.");
        return PLUGIN_HANDLED;
    }

    CopyPoint(g_Points[g_PointCount++], floor);
    if (!SavePoints())
    {
        g_PointCount--;
        console_print(id, "[New Year] Could not save the gift point.");
        return PLUGIN_HANDLED;
    }
    console_print(id, "[New Year] Gift point saved. Points on this map: %d.", g_PointCount);
    return PLUGIN_HANDLED;
}

public RemovePoint(id, flags, command)
{
    if (!cmd_access(id, flags, command, 1) || !id || !is_user_alive(id))
        return PLUGIN_HANDLED;

    new Float:position[3], Float:removed[3];
    pev(id, pev_origin, position);
    new point = NearPoint(position, 120.0);
    if (point < 0)
    {
        console_print(id, "[New Year] No gift point within 120 units.");
        return PLUGIN_HANDLED;
    }

    CopyPoint(removed, g_Points[point]);
    new last = --g_PointCount;
    CopyPoint(g_Points[point], g_Points[last]);
    if (!SavePoints())
    {
        CopyPoint(g_Points[last], g_Points[point]);
        CopyPoint(g_Points[point], removed);
        g_PointCount++;
        console_print(id, "[New Year] Could not save the updated gift points.");
        return PLUGIN_HANDLED;
    }
    for (new i = 0; i < MAX_GIFTS; i++)
    {
        if (!g_Gifts[i])
            continue;
        if (g_GiftPoint[i] == point)
            RemoveGift(i);
        else if (g_GiftPoint[i] == last)
            g_GiftPoint[i] = point;
    }
    console_print(id, "[New Year] Gift point removed. Points on this map: %d.", g_PointCount);
    return PLUGIN_HANDLED;
}

// Automatic points come from routes players have actually walked this map.
SampleGiftRoutes(Float:now)
{
    new players[MAX_PLAYERS], count;
    get_players(players, count, "ach");
    for (new i = 0; i < count; i++)
    {
        new id = players[i], Float:origin[3], Float:floor[3];
        if (!(pev(id, pev_flags) & FL_ONGROUND) || pev(id, pev_movetype) != MOVETYPE_WALK)
            continue;
        pev(id, pev_origin, origin);
        if (!FindFloor(origin, floor, true) || origin[2] - floor[2] > 40.0
            || NearPoint(floor, MIN_POINT_DISTANCE) >= 0)
            continue;

        new nearby = -1;
        for (new point = 0; point < MAX_GIFT_POINTS; point++)
        {
            if (g_AutoSeen[point] && get_distance_f(floor, g_AutoPoints[point]) < AUTO_POINT_SPACING)
            {
                nearby = point;
                break;
            }
        }
        if (nearby >= 0)
        {
            g_AutoSeen[nearby] = now;
            continue;
        }
        // Active gifts retain their point ID until picked up or expired.
        for (new attempt = 0; attempt < MAX_GIFT_POINTS; attempt++)
        {
            new point = g_AutoNext;
            g_AutoNext = (g_AutoNext + 1) % MAX_GIFT_POINTS;
            new bool:occupied;
            for (new slot = 0; slot < MAX_GIFTS; slot++)
            {
                if (g_Gifts[slot] && g_GiftPoint[slot] == MAX_GIFT_POINTS + point)
                {
                    occupied = true;
                    break;
                }
            }
            if (occupied)
                continue;
            CopyPoint(g_AutoPoints[point], floor);
            g_AutoSeen[point] = now;
            break;
        }
    }
}

public CheckWaves()
{
    new Float:now = get_gametime();
    if (!get_pcvar_num(g_Enable))
    {
        g_LastWave = now;
        for (new i = 0; i < MAX_GIFTS; i++)
            RemoveGift(i);
        return;
    }
    SampleGiftRoutes(now);
    if (now - g_LastWave >= float(max(1, get_pcvar_num(g_Interval))))
    {
        g_LastWave = now;
        SpawnWave();
    }
}

public ForceWave(id, flags, command)
{
    if (!cmd_access(id, flags, command, 1))
        return PLUGIN_HANDLED;
    new count = get_pcvar_num(g_Enable) ? SpawnWave() : 0;
    if (count)
        g_LastWave = get_gametime();
    console_print(id, "[New Year] Gift wave spawned %d (configured points: %d).", count, g_PointCount);
    return PLUGIN_HANDLED;
}

SpawnWave()
{
    new minimum = clamp(get_pcvar_num(g_MinPlayers), 0, MaxClients);
    if (minimum)
    {
        new players[MAX_PLAYERS], count, playing;
        get_players(players, count, "ch");
        for (new i = 0; i < count; i++)
        {
            new CsTeams:team = cs_get_user_team(players[i]);
            if (team == CS_TEAM_T || team == CS_TEAM_CT)
                playing++;
        }
        if (playing < minimum)
            return 0;
    }

    new candidates[MAX_GIFT_POINTS * 2], bool:occupied[MAX_GIFT_POINTS * 2], active, freeCount;
    new cap = clamp(get_pcvar_num(g_ActiveMax), 0, MAX_GIFTS);
    for (new i = 0; i < MAX_GIFTS; i++)
    {
        if (IsGiftEntity(g_Gifts[i]))
        {
            occupied[g_GiftPoint[i]] = true;
            active++;
        }
        else
            g_Gifts[i] = 0;
    }
    for (new i = 0; i < g_PointCount; i++)
    {
        if (!occupied[i])
            candidates[freeCount++] = i;
    }
    new manualCount = freeCount;
    new Float:now = get_gametime();
    for (new i = 0; i < MAX_GIFT_POINTS; i++)
    {
        if (!occupied[MAX_GIFT_POINTS + i] && g_AutoSeen[i] && now - g_AutoSeen[i] <= AUTO_POINT_LIFETIME)
            candidates[freeCount++] = MAX_GIFT_POINTS + i;
    }
    new upper = clamp(get_pcvar_num(g_WaveMax), 0, MAX_GIFTS);
    new lower = clamp(get_pcvar_num(g_WaveMin), 0, upper);
    new target = GiftWaveSize(random_num(lower, upper), active, cap, freeCount);
    new spawned, rareCount;
    while (spawned < target && freeCount)
    {
        new take = random_num(0, (manualCount ? manualCount : freeCount) - 1);
        new point = candidates[take];
        if (manualCount)
        {
            candidates[take] = candidates[--manualCount];
            take = manualCount;
        }
        candidates[take] = candidates[--freeCount];
        new bool:rare = GiftChance(g_RareChance);
        if (SpawnGift(point, rare))
        {
            spawned++;
            rareCount += rare ? 1 : 0;
        }
    }
    if (spawned)
    {
        if (rareCount)
        {
            set_hudmessage(110, 210, 255, -1.0, 0.22, 0, 0.0, 5.0, 0.1, 0.2, -1);
            show_hudmessage(0, "Подарков: %d, редких: %d^nПодойди к коробке, чтобы подобрать её.", spawned, rareCount);
        }
        else
        {
            set_hudmessage(255, 200, 75, -1.0, 0.22, 0, 0.0, 5.0, 0.1, 0.2, -1);
            show_hudmessage(0, "Подарки на карте: +%d!^nПодойди к коробке, чтобы подобрать её.", spawned);
        }
        new players[MAX_PLAYERS], count;
        get_players(players, count, "ch");
        for (new i = 0; i < count; i++)
            rh_emit_sound2(players[i], players[i], CHAN_ITEM, GIFT_CHIME, VOL_NORM, ATTN_NONE);
    }
    return spawned;
}

bool:GiftChance(cvar)
{
    new weight = floatround(floatclamp(get_pcvar_float(cvar), 0.0, 100.0) * 100.0);
    return random_num(0, 9999) < weight;
}

bool:SpawnGift(point, bool:rare)
{
    new Float:floor[3], Float:location[3];
    new bool:automatic = point >= MAX_GIFT_POINTS;
    if (automatic)
        CopyPoint(location, g_AutoPoints[point - MAX_GIFT_POINTS]);
    else
        CopyPoint(location, g_Points[point]);
    if (!FindFloor(location, floor, automatic)
        || get_distance_f(location, floor) > (automatic ? 5.0 : MAX_FLOOR_SHIFT))
        return false;

    new players[MAX_PLAYERS], count;
    get_players(players, count, "a");
    for (new i = 0; i < count; i++)
    {
        new Float:origin[3];
        pev(players[i], pev_origin, origin);
        if (get_distance_f(origin, floor) < 50.0)
            return false;
    }

    for (new i = 0; i < MAX_GIFTS; i++)
    {
        if (!IsGiftEntity(g_Gifts[i]))
            continue;
        new Float:origin[3];
        pev(g_Gifts[i], pev_origin, origin);
        if (get_distance_f(origin, floor) < MIN_POINT_DISTANCE)
            return false;
    }

    new slot;
    while (slot < MAX_GIFTS && g_Gifts[slot])
        slot++;
    if (slot == MAX_GIFTS)
        return false;

    new gift = create_entity("info_target");
    if (!gift)
        return false;
    entity_set_string(gift, EV_SZ_classname, GIFT_CLASS);
    entity_set_model(gift, GIFT_MODELS[rare ? 1 : 0]);
    entity_set_int(gift, EV_INT_movetype, MOVETYPE_NONE);
    entity_set_int(gift, EV_INT_solid, SOLID_TRIGGER);
    if (rare)
        entity_set_size(gift, Float:{-10.4, -10.4, 0.0}, Float:{10.4, 10.4, 21.6});
    else
        entity_set_size(gift, Float:{-13.0, -13.0, 0.0}, Float:{13.0, 13.0, 27.0});
    g_RareGift[slot] = rare;
    entity_set_origin(gift, floor);
    g_GiftExpires[slot] = get_gametime() + float(max(1, get_pcvar_num(g_Lifetime)));
    entity_set_float(gift, EV_FL_nextthink, get_gametime() + 0.1);
    g_GiftPoint[slot] = point;
    g_Gifts[slot] = gift;
    return true;
}

FindGiftSlot(gift)
{
    for (new i = 0; i < MAX_GIFTS; i++)
        if (g_Gifts[i] == gift)
            return i;
    return -1;
}

bool:IsGiftEntity(entity)
{
    if (!entity || !is_valid_ent(entity))
        return false;
    new classname[32];
    entity_get_string(entity, EV_SZ_classname, classname, charsmax(classname));
    return equal(classname, GIFT_CLASS) != 0;
}

RemoveGift(slot)
{
    new gift = g_Gifts[slot];
    g_Gifts[slot] = 0;
    if (IsGiftEntity(gift))
        remove_entity(gift);
}

public GiftExpire(gift)
{
    new slot = FindGiftSlot(gift);
    if (slot < 0)
        return;
    new Float:now = get_gametime();
    if (now >= g_GiftExpires[slot])
    {
        RemoveGift(slot);
        return;
    }

    new Float:origin[3];
    pev(gift, pev_origin, origin);
    // Local sparks leave the box and nearby map textures at their normal lighting.
    new bool:rare = g_RareGift[slot];
    new Float:angle = now * (rare ? 5.0 : 3.0) + float(slot);
    new Float:radius = rare ? 12.0 : 15.0;
    origin[0] += radius * floatcos(angle);
    origin[1] += radius * floatsin(angle);
    origin[2] += rare ? random_float(10.0, 25.0) : random_float(16.0, 29.0);

    message_begin_f(MSG_PVS, SVC_TEMPENTITY, origin);
    write_byte(TE_SPRITE);
    write_coord_f(origin[0]);
    write_coord_f(origin[1]);
    write_coord_f(origin[2]);
    write_short(g_GiftSpark[rare ? 1 : 0]);
    write_byte(3); // 0.3 model scale
    write_byte(rare ? 195 : 155);
    message_end();
    entity_set_float(gift, EV_FL_nextthink, floatmin(now + (rare ? 0.26 : 0.38), g_GiftExpires[slot]));
}

public GiftTouch(gift, player)
{
    if (!get_pcvar_num(g_Enable) || !is_user_alive(player))
        return;
    new slot = FindGiftSlot(gift);
    if (slot < 0)
        return;
    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1];
    if (!GetPlayerKey(player, key, charsmax(key)))
        return;
    LoadProfile(key, balance, inventory, cases);
    new bool:rare = g_RareGift[slot];
    new award = GiftSnowflakeReward(rare);
    new total = GiftAddBalance(balance, award);
    new caseType = -1;
    if (GiftChance(g_GiftCaseChance))
        caseType = QueueGiftCase(CASE_EVENT_NEW_YEAR, cases);
    SaveProfile(key, total, inventory, cases);
    RemoveGift(slot);
    client_print_color(player, print_team_blue, "^4[Новый год]^1 %s ^4+%d^1 снежинок. Баланс: ^3%d^1.",
                       rare ? "Редкий подарок" : "Подарок", total-balance, total);
    if (caseType >= 0)
        client_print_color(player, print_team_blue, "^4[Новый год]^1 Бонус: ^3[%s] %s^1. Открыть: ^4/case^1.",
                           CASE_EVENTS[CASE_TYPES[caseType][CaseEvent]], CASE_TYPES[caseType][CaseName]);
}

GiftSnowflakeReward(bool:rare)
{
    new upper = clamp(get_pcvar_num(g_RewardMax), 0, GIFT_MAX_BALANCE);
    new lower = clamp(get_pcvar_num(g_RewardMin), 0, upper);
    new award = random_num(lower, upper);
    if (!rare)
        return award;

    new Float:multiplier = floatmax(1.0, get_pcvar_float(g_RareMultiplier));
    return floatround(floatmin(float(GIFT_MAX_BALANCE), float(award) * multiplier));
}

QueueGiftCase(event, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1])
{
    new eligible[sizeof CASE_TYPES], count;
    for (new type; type < sizeof CASE_TYPES; type++)
    {
        if (CASE_TYPES[type][CaseEvent] == event && CASE_TYPES[type][CaseAvailable]
            && strlen(cases[type]) < CASE_STOCK_MAX)
            eligible[count++] = type;
    }
    if (!count)
        return -1;
    new type = eligible[random_num(0, count - 1)];
    return QueueCaseRewards(type, 1, cases[type], strlen(cases[type])) ? type : -1;
}

public client_disconnected(id)
{
    remove_task(TASK_CASE_REVEAL + id);
    if (g_Revealing[id])
    {
        g_Revealing[id] = false;
        for (new i = 0; i < g_RevealCount[id]; i++)
            AnnounceCaseDrop(id, g_RevealReward[id][i]);
    }
    g_RevealCount[id] = 0;
    g_SelectionLoaded[id] = false;
    arrayset(g_Selected[id], 0, sizeof g_Selected[]);
    ResetSkinFallback(id);
    for (new other = 1; other <= MaxClients; other++)
    {
        g_LastKill[id][other] = 0.0;
        g_LastKill[other][id] = 0.0;
    }
}

public OnDeath()
{
    if (!get_pcvar_num(g_Enable))
        return;

    new killer = read_data(1), victim = read_data(2);
    if (killer == victim || !is_user_connected(killer) || !is_user_connected(victim)
        || is_user_bot(victim) || is_user_hltv(victim))
        return;

    new CsTeams:team = cs_get_user_team(killer);
    new CsTeams:enemy = cs_get_user_team(victim);
    if (!((team == CS_TEAM_T && enemy == CS_TEAM_CT) || (team == CS_TEAM_CT && enemy == CS_TEAM_T)))
        return;

    new Float:now = get_gametime();
    if (g_LastKill[killer][victim] && now-g_LastKill[killer][victim] < float(max(0, get_pcvar_num(g_KillCooldown))))
        return;

    new award = clamp(get_pcvar_num(g_KillReward), 0, GIFT_MAX_BALANCE);
    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1];
    if (!award || !GetPlayerKey(killer, key, charsmax(key)))
        return;

    LoadProfile(key, balance, inventory, cases);
    SaveProfile(key, GiftAddBalance(balance, award), inventory, cases);
    g_LastKill[killer][victim] = now;
}

bool:GetPlayerKey(id, key[], length)
{
    if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id) || g_Vault == INVALID_HANDLE)
        return false;
    get_user_authid(id, key, length);
    return (equali(key, "STEAM_", 6) || equali(key, "VALVE_", 6))
        && contain(key, ":") >= 0 && !equali(key, "STEAM_ID_PENDING");
}

LoadProfile(const key[], &balance, inventory[GIFT_COLLECTION_SIZE], cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1])
{
    new record[PROFILE_SIZE], offset;
    nvault_get(g_Vault, key, record, charsmax(record));
    new tail = contain(record, "|");
    if (tail >= 0)
        record[tail++] = 0;
    balance = clamp(str_to_num(record), 0, GIFT_MAX_BALANCE);
    for (new i = 0; i < GIFT_COLLECTION_SIZE; i++)
    {
        while (record[offset] && record[offset] != ' ')
            offset++;
        if (record[offset])
            offset++;
        inventory[i] = clamp(str_to_num(record[offset]), 0, GIFT_MAX_BALANCE);
    }
    for (new type = 0; type < sizeof CASE_TYPES; type++)
    {
        new length;
        if (tail > 0)
        {
            while (record[tail] && record[tail] != '|')
            {
                if (length < CASE_STOCK_MAX && CaseStoredSkin(type, record[tail]) >= 0)
                    cases[type][length++] = record[tail];
                tail++;
            }
            if (record[tail] == '|')
                tail++;
        }
        cases[type][length] = 0;
    }
}

SaveProfile(const key[], balance, const inventory[GIFT_COLLECTION_SIZE], const cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1])
{
    new record[PROFILE_SIZE];
    new length = num_to_str(balance, record, charsmax(record));
    for (new i = 0; i < GIFT_COLLECTION_SIZE; i++)
        length += formatex(record[length], charsmax(record) - length, " %d", inventory[i]);
    for (new type = 0; type < sizeof CASE_TYPES; type++)
        length += formatex(record[length], charsmax(record) - length, "|%s", cases[type]);
    nvault_set(g_Vault, key, record);
}

public ShowBalance(id)
{
    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1];
    if (GetPlayerKey(id, key, charsmax(key)))
    {
        LoadProfile(key, balance, inventory, cases);
        client_print_color(id, print_team_blue, "^4[Новый год]^1 Баланс: ^3%d^1 снежинок.", balance);
    }
    else
        client_print_color(id, print_team_red, "^4[Новый год]^1 Баланс доступен ^3после авторизации^1.");
    return PLUGIN_HANDLED;
}

CreateWinterMenu(const title[], const handler[])
{
    new menu = menu_create(title, handler);
    menu_setprop(menu, MPROP_BACKNAME, "Пред. страница");
    menu_setprop(menu, MPROP_NEXTNAME, "След. страница");
    menu_setprop(menu, MPROP_EXITNAME, "Закрыть");
    return menu;
}

public OpenCaseMenu(id)
{
    if (!get_pcvar_num(g_Enable))
        return PLUGIN_HANDLED;
    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1];
    if (!GetPlayerKey(id, key, charsmax(key)))
        return ShowBalance(id);

    LoadProfile(key, balance, inventory, cases);
    new stored;
    for (new type; type < sizeof CASE_TYPES; type++)
        stored += strlen(cases[type]);

    new label[72];
    new menu = CreateWinterMenu("\yКейсы", "SelectCaseAction");
    menu_additem(menu, "\wКупить кейсы", "buy");
    formatex(label, charsmax(label), "\wОткрыть кейсы \y[%d]", stored);
    menu_additem(menu, label, "open");
    menu_additem(menu, "\wМои скины", "skins");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

bool:ReadCaseMenuItem(menu, item, data[], length)
{
    new access, callback;
    new bool:valid = item >= 0 && menu_item_getinfo(menu, item, access, data, length, .callback = callback);
    menu_destroy(menu);
    return valid && get_pcvar_num(g_Enable) != 0;
}

public SelectCaseAction(id, menu, item)
{
    new data[8];
    if (!ReadCaseMenuItem(menu, item, data, charsmax(data)))
        return PLUGIN_HANDLED;
    if (equal(data, "open"))
        return ShowCaseStorage(id);
    if (equal(data, "skins"))
        return ShowCollection(id);

    return SelectCaseEvents(id);
}

public SelectCaseEvent(id, menu, item)
{
    new data[8];
    if (!ReadCaseMenuItem(menu, item, data, charsmax(data)))
        return PLUGIN_HANDLED;
    if (equal(data, "back"))
        return OpenCaseMenu(id);
    return ShowEventCases(id, str_to_num(data));
}

ShowEventCases(id, event)
{
    if (event < 0 || event >= sizeof CASE_EVENTS)
        return PLUGIN_HANDLED;

    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1];
    if (!GetPlayerKey(id, key, charsmax(key)))
        return ShowBalance(id);
    LoadProfile(key, balance, inventory, cases);

    new title[148], label[104], data[8];
    if (event == CASE_EVENT_NEW_YEAR)
    {
        new cost = clamp(get_pcvar_num(g_CasePrice), 1, GIFT_MAX_BALANCE);
        formatex(title, charsmax(title), "\yМагазин · %s^n\wСнежинки: \y%d \w| за кейс: \y%d", CASE_EVENTS[event], balance, cost);
    }
    else
    {
        formatex(title, charsmax(title), "\yМагазин · %s", CASE_EVENTS[event]);
    }
    new menu = CreateWinterMenu(title, "SelectCasePurchase");
    for (new type = 0; type < sizeof CASE_TYPES; type++)
    {
        if (CASE_TYPES[type][CaseEvent] != event || !CASE_TYPES[type][CaseAvailable])
            continue;
        num_to_str(type, data, charsmax(data));
        new first = CaseFirearm(type, 0), second = CaseFirearm(type, 1);
        if (second >= 0)
            formatex(label, charsmax(label), "\y[%s] \w%s \d· %s / %s / ножи", CASE_EVENTS[event],
                     CASE_TYPES[type][CaseName], WEAPON_NAMES[first], WEAPON_NAMES[second]);
        else
            formatex(label, charsmax(label), "\y[%s] \w%s \d· %s / ножи", CASE_EVENTS[event],
                     CASE_TYPES[type][CaseName], WEAPON_NAMES[first]);
        menu_additem(menu, label, data);
    }
    menu_additem(menu, "\dНазад", "back");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public SelectCasePurchase(id, menu, item)
{
    new data[8];
    if (!ReadCaseMenuItem(menu, item, data, charsmax(data)))
        return PLUGIN_HANDLED;
    if (equal(data, "back"))
        return SelectCaseEvents(id);
    return ShowCaseQuantity(id, str_to_num(data), true);
}

SelectCaseEvents(id)
{
    new data[8], menu = CreateWinterMenu("\yМагазин кейсов^n\wВыбери событие", "SelectCaseEvent");
    for (new event = 0; event < sizeof CASE_EVENTS; event++)
    {
        num_to_str(event, data, charsmax(data));
        menu_additem(menu, CASE_EVENTS[event], data);
    }
    menu_additem(menu, "\dНазад", "back");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

ShowCaseStorage(id)
{
    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1];
    if (!GetPlayerKey(id, key, charsmax(key)))
        return ShowBalance(id);
    LoadProfile(key, balance, inventory, cases);

    new menu = CreateWinterMenu("\yМои кейсы^n\wВыбери, что открыть", "SelectStoredCase");
    menu_setprop(menu, MPROP_PERPAGE, 5);
    new data[8], label[96], listed;
    for (new type = 0; type < sizeof CASE_TYPES; type++)
    {
        new count = strlen(cases[type]);
        if (!count)
            continue;
        num_to_str(type, data, charsmax(data));
        formatex(label, charsmax(label), "\y[%s] \w%s \y×%d%s", CASE_EVENTS[CASE_TYPES[type][CaseEvent]],
                 CASE_TYPES[type][CaseName], count, CASE_TYPES[type][CaseAvailable] ? "" : " \d(прежний)");
        menu_additem(menu, label, data);
        listed++;
    }
    if (!listed)
        menu_addtext2(menu, "\dВ хранилище пока пусто.");
    menu_additem(menu, "\wВ магазин", "shop");
    menu_additem(menu, "\dНазад", "back");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public SelectStoredCase(id, menu, item)
{
    new data[8];
    if (!ReadCaseMenuItem(menu, item, data, charsmax(data)))
        return PLUGIN_HANDLED;
    if (equal(data, "back"))
        return OpenCaseMenu(id);
    if (equal(data, "shop"))
        return SelectCaseEvents(id);
    return ShowCaseQuantity(id, str_to_num(data), false);
}

ShowCaseQuantity(id, type, bool:purchase)
{
    if (type < 0 || type >= sizeof CASE_TYPES || (purchase && !CASE_TYPES[type][CaseAvailable]))
        return PLUGIN_HANDLED;

    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1];
    if (!GetPlayerKey(id, key, charsmax(key)))
        return ShowBalance(id);
    LoadProfile(key, balance, inventory, cases);
    new stored = strlen(cases[type]);
    new limit = min(CASE_BATCH_MAX, purchase ? CASE_STOCK_MAX - stored : stored);
    if (!limit)
    {
        if (purchase)
        {
            client_print_color(id, print_team_red, "^4[Кейсы]^1 Хранилище этого типа заполнено: ^3%d^1.", CASE_STOCK_MAX);
            return ShowCaseStorage(id);
        }
        return ShowCaseStorage(id);
    }

    new title[160], label[80], data[16];
    if (purchase)
        formatex(title, charsmax(title), "\yКупить «%s»^n\wСнежинки: \y%d \w| В наличии: \y%d",
                 CASE_TYPES[type][CaseName], balance, stored);
    else
        formatex(title, charsmax(title), "\yОткрыть «%s»^n\wВ наличии: \y%d",
                 CASE_TYPES[type][CaseName], stored);
    new menu = CreateWinterMenu(title, purchase ? "BuyCaseQuantity" : "OpenCaseQuantity");
    new cost = clamp(get_pcvar_num(g_CasePrice), 1, GIFT_MAX_BALANCE);
    for (new count = 1; count <= limit; count++)
    {
        formatex(data, charsmax(data), "%d %d", type, count);
        if (purchase && balance >= count * cost)
            formatex(label, charsmax(label), "\w%d шт. — \y%d \wснежинок", count, cost * count);
        else if (purchase)
            formatex(label, charsmax(label), "\d%d шт. — %d (не хватает)", count, cost * count);
        else
            formatex(label, charsmax(label), "\wОткрыть \y%d \wшт.", count);
        menu_additem(menu, label, data);
    }
    formatex(data, charsmax(data), "%d 0", type);
    menu_additem(menu, "\dНазад", data);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

bool:ReadCaseQuantity(menu, item, &type, &count)
{
    new data[16], typeText[6], countText[6];
    if (!ReadCaseMenuItem(menu, item, data, charsmax(data)))
        return false;

    parse(data, typeText, charsmax(typeText), countText, charsmax(countText));
    type = str_to_num(typeText);
    count = str_to_num(countText);
    return type >= 0 && type < sizeof CASE_TYPES && count >= 0 && count <= CASE_BATCH_MAX;
}

CaseStoredSkin(type, code)
{
    new slot = code >= '0' && code <= '9' ? code - '0'
        : (code >= 'a' && code <= 'z' ? code - 'a' + 10 : code - 'A' + 36);
    if (slot < 0 || slot >= sizeof CASE_ALPHABET - 1 || CASE_ALPHABET[slot] != code)
        return -1;
    if (slot < GIFT_WEAPON_VARIANTS)
        return GiftVariantIndex(CaseFirearm(type, 0), slot);
    if (slot < GIFT_WEAPON_VARIANTS + GIFT_KNIFE_VARIANTS)
        return GiftVariantIndex(CASE_WEAPON_BUTTERFLY, slot - GIFT_WEAPON_VARIANTS);

    new second = CaseFirearm(type, 1);
    if (second < 0)
        return -1;
    return GiftVariantIndex(second, slot - GIFT_WEAPON_VARIANTS - GIFT_KNIFE_VARIANTS);
}

CaseSkinCode(type, skin)
{
    new weapon = GiftSkinWeapon(skin), slot = GiftSkinVariant(skin);
    if (weapon == CASE_WEAPON_BUTTERFLY)
        slot += GIFT_WEAPON_VARIANTS;
    else if (weapon == CaseFirearm(type, 1))
        slot += GIFT_WEAPON_VARIANTS + GIFT_KNIFE_VARIANTS;
    return CASE_ALPHABET[slot];
}

public BuyCaseQuantity(id, menu, item)
{
    new type, count;
    if (!ReadCaseQuantity(menu, item, type, count) || !CASE_TYPES[type][CaseAvailable])
        return PLUGIN_HANDLED;
    if (!count)
        return ShowEventCases(id, CASE_TYPES[type][CaseEvent]);

    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1];
    if (!GetPlayerKey(id, key, charsmax(key)))
        return ShowBalance(id);
    LoadProfile(key, balance, inventory, cases);
    new total = clamp(get_pcvar_num(g_CasePrice), 1, GIFT_MAX_BALANCE) * count;
    if (balance < total)
    {
        client_print_color(id, print_team_red, "^4[Кейсы]^1 Не хватает ^3%d^1 снежинок.", total - balance);
        return ShowCaseQuantity(id, type, true);
    }
    new stored = strlen(cases[type]);
    if (count > CASE_STOCK_MAX - stored)
    {
        client_print_color(id, print_team_red, "^4[Кейсы]^1 Лимит хранилища: ^3%d^1 одного типа.", CASE_STOCK_MAX);
        return ShowCaseStorage(id);
    }
    if (!QueueCaseRewards(type, count, cases[type], stored))
        return PLUGIN_HANDLED;
    SaveProfile(key, balance - total, inventory, cases);
    client_print_color(id, print_team_blue, "^4[Кейсы]^1 «%s»: куплено ^4%d^1, потрачено ^3%d^1 снежинок.",
                       CASE_TYPES[type][CaseName], count, total);
    return ShowCaseReceipt(id, type, stored + count, balance - total);
}

ShowCaseReceipt(id, type, stored, balance)
{
    new title[148], data[16];
    formatex(title, charsmax(title), "\yПокупка · «%s»^n\wВ наличии: \y%d \w| Снежинки: \y%d",
             CASE_TYPES[type][CaseName], stored, balance);
    new menu = CreateWinterMenu(title, "SelectCaseReceipt");
    new const labels[][] = {"\yОткрыть этот тип", "\wКупить ещё", "\wМои кейсы"};
    for (new action; action < sizeof labels; action++)
    {
        formatex(data, charsmax(data), "%d %d", type, action);
        menu_additem(menu, labels[action], data);
    }
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public SelectCaseReceipt(id, menu, item)
{
    new type, action;
    if (!ReadCaseQuantity(menu, item, type, action))
        return PLUGIN_HANDLED;
    if (action == 2)
        return ShowCaseStorage(id);
    return ShowCaseQuantity(id, type, action == 1);
}

bool:QueueCaseRewards(type, count, queue[CASE_STOCK_MAX + 1], stored)
{
    for (new i = 0; i < count; i++)
    {
        new weapon, rarity;
        if (!incom_case_roll(type, weapon, rarity))
            return false;
        queue[stored + i] = CaseSkinCode(type, GiftRollSkin(weapon, rarity));
    }
    queue[stored + count] = 0;
    return true;
}

public OpenCaseQuantity(id, menu, item)
{
    new type, count;
    if (!ReadCaseQuantity(menu, item, type, count))
        return PLUGIN_HANDLED;
    if (!count)
        return ShowCaseStorage(id);
    if (g_Revealing[id])
    {
        client_print_color(id, print_team_red, "^4[Кейсы]^1 Дождись окончания ^3текущей рулетки^1.");
        return PLUGIN_HANDLED;
    }

    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1];
    if (!GetPlayerKey(id, key, charsmax(key)))
        return ShowBalance(id);
    LoadProfile(key, balance, inventory, cases);
    new stored = strlen(cases[type]);
    if (stored < count)
        return ShowCaseStorage(id);

    if (!DeliverStoredCases(id, type, count, cases[type], stored, balance, inventory))
        return PLUGIN_HANDLED;
    SaveProfile(key, balance, inventory, cases);
    g_RevealCount[id] = count;
    StartCaseReveal(id, type, balance);
    return PLUGIN_HANDLED;
}

bool:DeliverStoredCases(id, type, count, queue[CASE_STOCK_MAX + 1], stored, &balance,
                        inventory[GIFT_COLLECTION_SIZE])
{
    for (new i = 0; i < count; i++)
    {
        new reward = CaseStoredSkin(type, queue[i]);
        if (reward < 0)
            return false;
        g_RevealReward[id][i] = reward;
        g_RevealCredit[id][i] = 0;
        if (inventory[reward])
        {
            new sale = CaseDuplicateValue(type, GiftSkinWeapon(reward), GiftSkinRarity(reward));
            new updated = GiftAddBalance(balance, sale);
            g_RevealCredit[id][i] = updated - balance;
            balance = updated;
        }
        else
            inventory[reward] = 1;
    }

    for (new i = 0; i <= stored - count; i++)
        queue[i] = queue[i + count];
    return true;
}

bool:ShowCaseScene(id, caseId, balance)
{
    new url[256];
    get_pcvar_string(g_CaseMotdUrl, url, charsmax(url));
    trim(url);
    if (!url[0])
    {
        get_cvar_string("sv_downloadurl", url, charsmax(url));
        trim(url);
        if (!url[0] || strlen(url) > charsmax(url) - 25)
            return false;
        if (url[strlen(url) - 1] != '/')
            add(url, charsmax(url), "/");
        add(url, charsmax(url), "motd/newyear/index.html");
    }
    if ((!equali(url, "http://", 7) && !equali(url, "https://", 8)) || contain(url, "#") >= 0)
        return false;

    // Use case-local skin IDs to keep five full rails within the MOTD URL limit.
    new encoded[CASE_BATCH_MAX * (CASE_MOTD_ITEMS + 1) + 1], credits[CASE_BATCH_MAX * 8 + 1];
    new length, creditLength;
    for (new row = 0; row < g_RevealCount[id]; row++)
    {
        if (row)
            encoded[length++] = ',';
        for (new i = 0; i < CASE_MOTD_ITEMS; i++)
        {
            new item = g_RevealReward[id][row];
            if (i != CASE_MOTD_TARGET)
            {
                new weapon, rarity;
                if (!CaseDropResolve(caseId, random_num(0, CASE_DROP_ROLL_COUNT - 1), weapon, rarity))
                    return false;
                item = GiftRollSkin(weapon, rarity);
            }
            encoded[length++] = CaseSkinCode(caseId, item);
        }
        creditLength += formatex(credits[creditLength], charsmax(credits) - creditLength,
                                 "%s%d", row ? "," : "", g_RevealCredit[id][row]);
    }
    new address[511];
    if (strlen(url) + length + creditLength + 70 >= charsmax(address))
        return false;
    formatex(address, charsmax(address), "%s%ccaseview=13&turn=%d-%d#%s;%d;%d;%d;%d;%s;%d",
             url, contain(url, "?") >= 0 ? '&' : '?', get_systime(), ++g_CaseSceneSerial, encoded,
             CASE_MOTD_START, CASE_MOTD_TARGET, balance, CASE_MOTD_SPIN_MS, credits, caseId);
    show_motd(id, address, "Новогодние кейсы");
    return true;
}

StartCaseReveal(id, caseId, balance)
{
    g_Revealing[id] = true;
    get_user_name(id, g_RevealName[id], charsmax(g_RevealName[]));
    g_RevealStep[id] = -1;
    g_RevealDeadline[id] = get_gametime() + CASE_BOX_OPEN_TIME + float(CASE_MOTD_SPIN_MS) / 1000.0;
    if (ShowCaseScene(id, caseId, balance))
        set_task(CASE_BOX_OPEN_TIME, "CaseMotdTick", TASK_CASE_REVEAL + id);
    else
        set_task(CASE_BOX_OPEN_TIME + float(CASE_MOTD_SPIN_MS) / 1000.0,
                 "CaseTextResult", TASK_CASE_REVEAL + id);
}

public CaseTextResult(taskId)
{
    new id = taskId - TASK_CASE_REVEAL;
    if (g_Revealing[id] && is_user_connected(id))
        FinishCaseReveal(id);
}

public CaseMotdTick(taskId)
{
    new id = taskId - TASK_CASE_REVEAL;
    if (!g_Revealing[id] || !is_user_connected(id))
        return;

    new Float:remaining = g_RevealDeadline[id] - get_gametime();
    if (remaining <= 0.0)
    {
        FinishCaseReveal(id);
        return;
    }

    new Float:duration = float(CASE_MOTD_SPIN_MS) / 1000.0;
    new position = floatround(CaseMotdEase(floatclamp(1.0 - remaining / duration, 0.0, 1.0))
                              * float(CASE_MOTD_TARGET - CASE_MOTD_START));
    if (position != g_RevealStep[id])
    {
        g_RevealStep[id] = position;
        rh_emit_sound2(id, id, CHAN_ITEM, CASE_TICK, 0.65, ATTN_NONE);
    }
    set_task(0.1, "CaseMotdTick", taskId);
}

FinishCaseReveal(id)
{
    g_Revealing[id] = false;
    for (new i = 0; i < g_RevealCount[id]; i++)
    {
        new reward = g_RevealReward[id][i];
        new rarity = GiftSkinRarity(reward), weaponName[24];
        SkinWeaponLabel(reward, weaponName, charsmax(weaponName));
        new sale[64];
        if (g_RevealCredit[id][i])
            formatex(sale, charsmax(sale), " · Дубликат ^4+%d^1.", g_RevealCredit[id][i]);
        client_print_color(id, WinterRarityColor(rarity), "^4[Кейсы]^1 #%d ^3[%s]^1 %s · ^4%s^1%s",
                           i + 1, RARITY_NAMES[rarity], weaponName, g_SkinNames[reward], sale);
        AnnounceCaseDrop(id, reward);
    }
    g_RevealCount[id] = 0;
}

AnnounceCaseDrop(id, reward)
{
    new rarity = GiftSkinRarity(reward);
    if (!CaseRevealIsPublic(rarity))
        return;

    new weaponName[24];
    SkinWeaponLabel(reward, weaponName, charsmax(weaponName));
    new players[MAX_PLAYERS], count;
    get_players(players, count, "ch");
    for (new i = 0; i < count; i++)
    {
        if (players[i] == id)
            continue;
        client_print_color(players[i], WinterRarityColor(rarity),
                       "^4[Новый год]^1 ^4%s^1 получил ^3[%s]^1 %s · ^4%s^1.",
                       g_RevealName[id], RARITY_NAMES[rarity], weaponName, g_SkinNames[reward]);
    }
}

WinterRarityColor(rarity)
{
    new const colors[CASE_RARITY_COUNT] = {print_team_grey, print_team_blue, print_team_blue, print_team_red};
    return colors[rarity];
}

SkinWeaponLabel(index, label[], size)
{
    new weapon = GiftSkinWeapon(index);
    if (weapon == CASE_WEAPON_BUTTERFLY)
        copy(label, size, KNIFE_NAMES[GiftSkinVariant(index) / 8]);
    else
        copy(label, size, WEAPON_NAMES[weapon]);
}

public ShowCollection(id)
{
    if (!get_pcvar_num(g_Enable))
        return PLUGIN_HANDLED;

    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1];
    if (!GetPlayerKey(id, key, charsmax(key)))
        return ShowBalance(id);

    LoadProfile(key, balance, inventory, cases);
    new menu = CreateWinterMenu("\yМои скины^n\wВыбери оружие", "SelectCollectionWeapon");
    menu_setprop(menu, MPROP_PERPAGE, 0);
    new info[5], count;
    for (new weapon = 0; weapon < sizeof SKIN_WEAPONS; weapon++)
    {
        for (new variant = 0; variant < GiftVariantCount(weapon); variant++)
        {
            if (!inventory[GiftVariantIndex(weapon, variant)])
                continue;
            num_to_str(weapon, info, charsmax(info));
            menu_additem(menu, WEAPON_NAMES[weapon], info);
            count++;
            break;
        }
    }
    if (!count)
        menu_addtext2(menu, "Открой кейс, чтобы получить первый скин.");
    menu_additem(menu, "Кейсы", "cases");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public SelectCollectionWeapon(id, menu, item)
{
    new info[8], access, callback;
    new bool:valid = item >= 0 && menu_item_getinfo(menu, item, access, info, charsmax(info), .callback = callback);
    menu_destroy(menu);
    if (!valid)
        return PLUGIN_HANDLED;
    if (equal(info, "cases"))
        return OpenCaseMenu(id);
    return ShowCollectionWeapon(id, str_to_num(info));
}

ShowCollectionWeapon(id, weapon)
{
    if (!get_pcvar_num(g_Enable) || weapon < 0 || weapon >= sizeof SKIN_WEAPONS)
        return PLUGIN_HANDLED;

    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1];
    if (!GetPlayerKey(id, key, charsmax(key)))
        return PLUGIN_HANDLED;
    LoadProfile(key, balance, inventory, cases);
    LoadSelections(id);
    new title[80];
    formatex(title, charsmax(title), "\yСкины · %s", WEAPON_NAMES[weapon]);
    new menu = CreateWinterMenu(title, "SelectCollectionSkin");
    menu_setprop(menu, MPROP_PERPAGE, weapon == CASE_WEAPON_BUTTERFLY ? 3 : 4);
    new const colors[CASE_RARITY_COUNT][] = {"\d", "\w", "\r", "\y"};
    new name[120], info[5], count;
    for (new tier = CASE_RARITY_COUNT - 1; tier >= 0; tier--)
    {
        for (new variant = 0; variant < GiftVariantCount(weapon); variant++)
        {
            new index = GiftVariantIndex(weapon, variant);
            new rarity = GiftSkinRarity(index);
            if (rarity != tier || !inventory[index])
                continue;
            new label[24];
            if (weapon == CASE_WEAPON_BUTTERFLY)
                SkinWeaponLabel(index, label, charsmax(label));
            formatex(name, charsmax(name), "%s[%s]\w %s%s%s%s", colors[rarity], RARITY_NAMES[rarity],
                     label, label[0] ? " · " : "", g_SkinNames[index],
                     g_Selected[id][weapon] == variant + 1 ? " \y[+]" : "");
            num_to_str(index, info, charsmax(info));
            menu_additem(menu, name, info);
            count++;
        }
    }
    if (!count)
    {
        menu_destroy(menu);
        return ShowCollection(id);
    }
    menu_additem(menu, "\dНазад", "back");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public SelectCollectionSkin(id, menu, item)
{
    new info[5], access, callback;
    new bool:valid = item >= 0 && menu_item_getinfo(menu, item, access, info, charsmax(info), .callback = callback);
    menu_destroy(menu);
    if (!valid || !get_pcvar_num(g_Enable))
        return PLUGIN_HANDLED;
    if (equal(info, "back"))
        return ShowCollection(id);

    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1];
    if (!GetPlayerKey(id, key, charsmax(key)))
        return PLUGIN_HANDLED;

    new index = str_to_num(info);
    if (index < 0 || index >= GIFT_COLLECTION_SIZE)
        return PLUGIN_HANDLED;
    LoadProfile(key, balance, inventory, cases);
    if (!inventory[index])
        return PLUGIN_HANDLED;

    LoadSelections(id);
    new weapon = GiftSkinWeapon(index), rarity = GiftSkinRarity(index), variant = GiftSkinVariant(index);
    new bool:removing = g_Selected[id][weapon] == variant + 1;
    g_Selected[id][weapon] = removing ? 0 : variant + 1;
    new vaultKey[56], record[CASE_WEAPON_BUTTERFLY + 2];
    formatex(vaultKey, charsmax(vaultKey), "equip:%s", key);
    for (new i = 0; i < sizeof g_Selected[]; i++)
        record[i] = '0' + g_Selected[id][i];
    nvault_set(g_Vault, vaultKey, record);

    if (is_user_alive(id) && get_user_weapon(id) == SKIN_WEAPONS[weapon])
        ApplySkin(id, SKIN_WEAPONS[weapon]);
    new label[24];
    SkinWeaponLabel(index, label, charsmax(label));
    client_print_color(id, WinterRarityColor(rarity), "^4[Скины]^1 %s ^3[%s]^1 %s · ^4%s^1.",
                       removing ? "Снят" : "Экипирован", RARITY_NAMES[rarity], label, g_SkinNames[index]);
    return ShowCollectionWeapon(id, weapon);
}

bool:LoadSelections(id)
{
    if (g_SelectionLoaded[id])
        return true;
    new key[40], vaultKey[56], record[CASE_WEAPON_BUTTERFLY + 2];
    if (!GetPlayerKey(id, key, charsmax(key)))
        return false;
    formatex(vaultKey, charsmax(vaultKey), "equip:%s", key);
    new length = nvault_get(g_Vault, vaultKey, record, charsmax(record));
    if (length)
    {
        for (new i = 0; i < sizeof g_Selected[] && record[i]; i++)
        {
            new selection = record[i] - '0';
            g_Selected[id][i] = selection >= 1 && selection <= GiftVariantCount(i) ? selection : 0;
        }
    }
    g_SelectionLoaded[id] = true;
    return true;
}

public ApplyCurrentSkin(id)
{
    ApplySkin(id, read_data(2));
}

ApplySkin(id, weaponId)
{
    if (g_LastSkinWeapon[id] != weaponId)
    {
        ResetSkinFallback(id);
        g_LastSkinWeapon[id] = weaponId;
    }

    new weapon = -1;
    for (new i = 0; i < sizeof SKIN_WEAPONS; i++)
    {
        if (SKIN_WEAPONS[i] == weaponId)
        {
            weapon = i;
            break;
        }
    }
    if (weapon < 0 || !LoadSelections(id))
        return;

    new view[128], player[128];
    pev(id, pev_viewmodel2, view, charsmax(view));
    pev(id, pev_weaponmodel2, player, charsmax(player));
    new bool:isSeasonalView = equal(view, "models/incom/newyear/", 21) != 0;
    new bool:isSeasonalPlayer = equal(player, "models/incom/newyear/", 21) != 0;

    if (!get_pcvar_num(g_Enable) || !g_Selected[id][weapon])
    {
        if (isSeasonalView && g_OldView[id][0])
            set_pev(id, pev_viewmodel2, g_OldView[id]);
        if (isSeasonalPlayer && g_OldPlayer[id][0])
            set_pev(id, pev_weaponmodel2, g_OldPlayer[id]);
        return;
    }

    if (!isSeasonalView)
        copy(g_OldView[id], charsmax(g_OldView[]), view);
    if (!isSeasonalPlayer)
        copy(g_OldPlayer[id], charsmax(g_OldPlayer[]), player);

    new index = GiftVariantIndex(weapon, g_Selected[id][weapon] - 1);
    if (!equal(view, g_View[index]))
        set_pev(id, pev_viewmodel2, g_View[index]);
    if (g_Player[index][0] && !equal(player, g_Player[index]))
        set_pev(id, pev_weaponmodel2, g_Player[index]);
}

ResetSkinFallback(id)
{
    g_LastSkinWeapon[id] = 0;
    g_OldView[id][0] = 0;
    g_OldPlayer[id][0] = 0;
}
