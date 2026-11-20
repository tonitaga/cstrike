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
#define MAX_FLOOR_SHIFT 64.0
#define PROFILE_SIZE 320
#define MIN_POINT_DISTANCE 48.0
#define TASK_CASE_REVEAL 7100
#define CASE_BOX_OPEN_TIME 0.90

new const GIFT_CLASS[] = "incom_newyear_gift";
new const GIFT_MODEL[] = "models/incom/newyear/gift.mdl";
new const GIFT_CHIME[] = "incom/newyear/gift_wave.wav";
new const CASE_TICK[] = "incom/newyear/case_tick.wav";
new const SKIN_NAMES[CASE_WEAPON_BUTTERFLY + 1][CASE_RARITY_COUNT][] = {
    {"Хвойная лента", "Карамельная обёртка", "Морозное тиснение", "Подарочная лента"},
    {"Ёлочный дозор", "Хвойные огни", "Вечерняя гирлянда", "Полночный салют"},
    {"Ёлочная звезда", "Праздничный леденец", "Зелёная гирлянда", "Парад конфетти"},
    {"Хвойный орнамент", "Зимние ёлки", "Лиловая гирлянда", "Полночный салют"},
    {"Звёздная нить", "Заснеженный леденец", "Зелёные огни", "Парад конфетти"},
    {"Еловая снежинка", "Сахарная лента", "Ледяное тиснение", "Подарочная лента"},
    {"Морозная гравировка", "Карамельная бабочка", "Ледяные узоры", "Салют на клинке"}
};
new bool:g_WebReveal[MAX_PLAYERS + 1];
new g_CaseMotdUrl, g_CaseSceneSerial;
new bool:g_Revealing[MAX_PLAYERS + 1];
new g_RevealStep[MAX_PLAYERS + 1];
new g_RevealReward[MAX_PLAYERS + 1], g_RevealCredit[MAX_PLAYERS + 1], g_RevealName[MAX_PLAYERS + 1][32];
new Float:g_RevealDeadline[MAX_PLAYERS + 1];
new const WEAPON_NAMES[][] = {"M4A1", "AK-47", "Glock", "Deagle", "AWP", "USP", "Бабочка"};
new const RARITY_NAMES[][] = {"Обычный", "Редкий", "Эпический", "Легендарный"};

new g_Vault = INVALID_HANDLE;
new g_Enable, g_Interval, g_WaveMin, g_WaveMax, g_ActiveMax, g_Lifetime;
new g_RewardMin, g_RewardMax, g_KillReward, g_KillCooldown, g_CasePrice;
new Float:g_LastWave;
new Float:g_Points[MAX_GIFT_POINTS][3], g_PointCount;
new g_Gifts[MAX_GIFTS], g_GiftPoint[MAX_GIFTS];
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
    precache_model(GIFT_MODEL);
    precache_sound(GIFT_CHIME);
    precache_sound(CASE_TICK);
    for (new weapon = 0; weapon < sizeof SKIN_WEAPONS; weapon++)
    {
        new filename[12];
        copy(filename, charsmax(filename), weapon == CASE_WEAPON_BUTTERFLY ? "knife" : SKIN_FOLDERS[weapon]);
        for (new rarity = 0; rarity < CASE_RARITY_COUNT; rarity++)
        {
            new index = GiftSkinIndex(weapon, rarity);
            formatex(g_View[index], charsmax(g_View[]), "models/incom/newyear/%s/%s/v_%s.mdl",
                     SKIN_FOLDERS[weapon], SKIN_TIERS[rarity], filename);
            precache_model(g_View[index]);
            if (weapon != CASE_WEAPON_BUTTERFLY)
            {
                formatex(g_Player[index], charsmax(g_Player[]), "models/incom/newyear/%s/%s/p_%s.mdl",
                         SKIN_FOLDERS[weapon], SKIN_TIERS[rarity], filename);
                precache_model(g_Player[index]);
            }
        }
    }
}

public plugin_init()
{
    register_plugin("INCOM New Year Gifts", "1.2", "INCOMSYSTEM");
    g_Enable = register_cvar("incom_gifts_enabled", "1");
    g_Interval = register_cvar("incom_gifts_interval", "60");
    g_WaveMin = register_cvar("incom_gifts_wave_min", "2");
    g_WaveMax = register_cvar("incom_gifts_wave_max", "5");
    g_ActiveMax = register_cvar("incom_gifts_active_max", "5");
    g_Lifetime = register_cvar("incom_gifts_lifetime", "55");
    g_RewardMin = register_cvar("incom_gifts_reward_min", "15");
    g_RewardMax = register_cvar("incom_gifts_reward_max", "21");
    g_KillReward = register_cvar("incom_gifts_kill_reward", "2");
    g_KillCooldown = register_cvar("incom_gifts_kill_cooldown", "20");
    g_CasePrice = register_cvar("incom_gifts_case_price", "60");
    g_CaseMotdUrl = register_cvar("incom_gifts_case_motd_url", "");

    register_touch(GIFT_CLASS, "player", "GiftTouch");
    register_think(GIFT_CLASS, "GiftExpire");
    // Loaded after the ordinary skin plugins, so an equipped seasonal skin takes precedence.
    register_event("CurWeapon", "ApplyCurrentSkin", "be", "1=1");
    register_event("DeathMsg", "OnDeath", "a", "1>0");
    register_clcmd("say /newyear", "OpenCaseMenu");
    register_clcmd("say_team /newyear", "OpenCaseMenu");
    register_clcmd("say /snowflakes", "ShowBalance");
    register_clcmd("say /wintercollection", "ShowCollection");
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

bool:FindFloor(const Float:point[3], Float:result[3])
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
    new candidates[MAX_GIFT_POINTS], bool:occupied[MAX_GIFT_POINTS], active, freeCount;
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
    new upper = clamp(get_pcvar_num(g_WaveMax), 0, MAX_GIFTS);
    new lower = clamp(get_pcvar_num(g_WaveMin), 0, upper);
    new target = GiftWaveSize(random_num(lower, upper), active, cap, freeCount);
    new spawned;
    while (spawned < target && freeCount)
    {
        new take = random_num(0, freeCount - 1);
        new point = candidates[take];
        candidates[take] = candidates[--freeCount];
        if (SpawnGift(point))
            spawned++;
    }
    if (spawned)
    {
        set_hudmessage(255, 200, 75, -1.0, 0.22, 0, 0.0, 5.0, 0.1, 0.2, -1);
        show_hudmessage(0, "Подарки на карте: +%d!^nПодойди к коробке, чтобы подобрать её.", spawned);
        new players[MAX_PLAYERS], count;
        get_players(players, count, "ch");
        for (new i = 0; i < count; i++)
            rh_emit_sound2(players[i], players[i], CHAN_ITEM, GIFT_CHIME, VOL_NORM, ATTN_NONE);
    }
    return spawned;
}

bool:SpawnGift(point)
{
    new Float:floor[3];
    if (!FindFloor(g_Points[point], floor) || get_distance_f(g_Points[point], floor) > MAX_FLOOR_SHIFT)
        return false;

    new slot;
    while (slot < MAX_GIFTS && g_Gifts[slot])
        slot++;
    if (slot == MAX_GIFTS)
        return false;

    new gift = create_entity("info_target");
    if (!gift)
        return false;
    entity_set_string(gift, EV_SZ_classname, GIFT_CLASS);
    entity_set_model(gift, GIFT_MODEL);
    entity_set_int(gift, EV_INT_movetype, MOVETYPE_NONE);
    entity_set_int(gift, EV_INT_solid, SOLID_TRIGGER);
    entity_set_size(gift, Float:{-13.0, -13.0, 0.0}, Float:{13.0, 13.0, 27.0});
    entity_set_origin(gift, floor);
    entity_set_float(gift, EV_FL_nextthink, get_gametime() + float(max(1, get_pcvar_num(g_Lifetime))));
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
    if (slot >= 0)
        RemoveGift(slot);
}

public GiftTouch(gift, player)
{
    if (!get_pcvar_num(g_Enable) || !is_user_alive(player))
        return;
    new slot = FindGiftSlot(gift);
    if (slot < 0)
        return;
    new key[40], inventory[GIFT_COLLECTION_SIZE], balance;
    if (!GetPlayerKey(player, key, charsmax(key)))
        return;
    LoadProfile(key, balance, inventory);
    new upper = clamp(get_pcvar_num(g_RewardMax), 0, GIFT_MAX_BALANCE);
    new lower = clamp(get_pcvar_num(g_RewardMin), 0, upper);
    new total = GiftAddBalance(balance, random_num(lower, upper));
    SaveProfile(key, total, inventory);
    RemoveGift(slot);
    client_print_color(player, print_team_default, "^4[Новый год]^1 Подарок: ^3+%d^1 снежинок. Баланс: ^3%d^1.", total-balance, total);
}

public client_disconnected(id)
{
    remove_task(TASK_CASE_REVEAL + id);
    if (g_Revealing[id])
    {
        g_Revealing[id] = false;
        AnnounceCaseDrop(id, g_RevealReward[id]);
    }
    g_WebReveal[id] = false;
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
    new key[40], inventory[GIFT_COLLECTION_SIZE], balance;
    if (!award || !GetPlayerKey(killer, key, charsmax(key)))
        return;

    LoadProfile(key, balance, inventory);
    SaveProfile(key, GiftAddBalance(balance, award), inventory);
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

LoadProfile(const key[], &balance, inventory[GIFT_COLLECTION_SIZE])
{
    new record[PROFILE_SIZE], offset;
    nvault_get(g_Vault, key, record, charsmax(record));
    balance = clamp(str_to_num(record), 0, GIFT_MAX_BALANCE);
    for (new i = 0; i < GIFT_COLLECTION_SIZE; i++)
    {
        while (record[offset] && record[offset] != ' ')
            offset++;
        if (record[offset])
            offset++;
        inventory[i] = clamp(str_to_num(record[offset]), 0, GIFT_MAX_BALANCE);
    }
}

SaveProfile(const key[], balance, const inventory[GIFT_COLLECTION_SIZE])
{
    new record[PROFILE_SIZE];
    new length = num_to_str(balance, record, charsmax(record));
    for (new i = 0; i < GIFT_COLLECTION_SIZE; i++)
        length += formatex(record[length], charsmax(record) - length, " %d", inventory[i]);
    nvault_set(g_Vault, key, record);
}

public ShowBalance(id)
{
    new key[40], inventory[GIFT_COLLECTION_SIZE], balance;
    if (GetPlayerKey(id, key, charsmax(key)))
    {
        LoadProfile(key, balance, inventory);
        client_print_color(id, print_team_default, "^4[Новый год]^1 Баланс: ^3%d^1 снежинок.", balance);
    }
    else
        client_print(id, print_chat, "[Новый год] Баланс доступен после авторизации.");
    return PLUGIN_HANDLED;
}

public OpenCaseMenu(id)
{
    if (!get_pcvar_num(g_Enable))
        return PLUGIN_HANDLED;

    new key[40], inventory[GIFT_COLLECTION_SIZE], balance;
    if (!GetPlayerKey(id, key, charsmax(key)))
        return ShowBalance(id);

    LoadProfile(key, balance, inventory);
    new title[128], item[64], info[4];
    formatex(title, charsmax(title), "Новогодние кейсы^nСнежинок: %d", balance);
    new menu = menu_create(title, "BuyCase");
    new cost = clamp(get_pcvar_num(g_CasePrice), 1, GIFT_MAX_BALANCE);
    for (new i = 0; i < CASE_WEAPON_COUNT; i++)
    {
        num_to_str(i, info, charsmax(info));
        formatex(item, charsmax(item), "%s — %d снежинок", WEAPON_NAMES[i], cost);
        menu_additem(menu, item, info);
    }
    menu_additem(menu, "Моя коллекция", "collection");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public BuyCase(id, menu, item)
{
    new info[16], access, callback;
    if (item >= 0)
        menu_item_getinfo(menu, item, access, info, charsmax(info), .callback = callback);
    menu_destroy(menu);
    if (item < 0 || !get_pcvar_num(g_Enable))
        return PLUGIN_HANDLED;
    if (equal(info, "collection"))
        return ShowCollection(id);
    if (g_Revealing[id])
    {
        client_print(id, print_chat, "[Новый год] Дождись окончания раскрутки.");
        return PLUGIN_HANDLED;
    }

    new key[40], inventory[GIFT_COLLECTION_SIZE], balance, weapon, rarity;
    if (!GetPlayerKey(id, key, charsmax(key)))
        return ShowBalance(id);
    LoadProfile(key, balance, inventory);

    new cost = clamp(get_pcvar_num(g_CasePrice), 1, GIFT_MAX_BALANCE);
    if (balance < cost)
    {
        client_print(id, print_chat, "[Новый год] Для кейса нужно ещё %d снежинок.", cost-balance);
        return PLUGIN_HANDLED;
    }
    new caseId = str_to_num(info);
    if (!incom_case_roll(caseId, weapon, rarity))
        return PLUGIN_HANDLED;

    new reward = GiftSkinIndex(weapon, rarity);
    new sale = CaseDuplicateValue(caseId, weapon, rarity);
    if (reward < 0 || reward >= GIFT_COLLECTION_SIZE || !sale)
        return PLUGIN_HANDLED;

    new remainder = balance-cost;
    new updated = remainder;
    if (inventory[reward])
        updated = GiftAddBalance(remainder, sale);
    else
        inventory[reward] = 1;

    SaveProfile(key, updated, inventory);
    StartCaseReveal(id, caseId, reward, updated, updated-remainder);
    return PLUGIN_HANDLED;
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

    new bracket[160], length, reward = g_RevealReward[id];
    new rewardSlot = reward % CASE_RARITY_COUNT;
    if (reward / CASE_RARITY_COUNT == CASE_WEAPON_BUTTERFLY)
        rewardSlot += CASE_RARITY_COUNT;

    for (new i = 0; i < CASE_MOTD_ITEMS; i++)
    {
        new slot = CaseRevealItem(i, CASE_MOTD_TARGET, random_num(0, CASE_RARITY_COUNT * 2 - 2), rewardSlot);
        new weapon = slot < CASE_RARITY_COUNT ? caseId : CASE_WEAPON_BUTTERFLY;
        new item = GiftSkinIndex(weapon, slot % CASE_RARITY_COUNT);
        length += formatex(bracket[length], charsmax(bracket)-length, "%s%d", i == 0 ? "" : ",", item);
    }
    new address[440];
    formatex(address, charsmax(address), "%s%ccaseview=4&turn=%d-%d#%s;%d;%d;%d;%d;%d;%d",
             url, contain(url, "?") >= 0 ? '&' : '?', get_systime(), ++g_CaseSceneSerial, bracket, CASE_MOTD_START,
             CASE_MOTD_TARGET, reward, balance, CASE_MOTD_SPIN_MS, g_RevealCredit[id]);
    show_motd(id, address, "Новогодний кейс");
    return true;
}

StartCaseReveal(id, caseId, reward, balance, credit)
{
    g_Revealing[id] = true;
    g_RevealReward[id] = reward;
    g_RevealCredit[id] = credit;
    get_user_name(id, g_RevealName[id], charsmax(g_RevealName[]));
    g_WebReveal[id] = ShowCaseScene(id, caseId, balance);
    g_RevealStep[id] = -1;
    g_RevealDeadline[id] = get_gametime() + CASE_BOX_OPEN_TIME + float(CASE_MOTD_SPIN_MS) / 1000.0;
    if (g_WebReveal[id])
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
    new reward = g_RevealReward[id];
    new bool:usedWeb = g_WebReveal[id];
    g_Revealing[id] = false;
    g_WebReveal[id] = false;
    new weapon = reward / CASE_RARITY_COUNT, rarity = reward % CASE_RARITY_COUNT;
    if (CaseRevealIsPublic(rarity))
        AnnounceCaseDrop(id, reward);
    else if (!usedWeb)
        client_print_color(id, print_team_default, "^4[Новый год]^1 Выпал скин ^3«%s | %s»^1 (%s).",
                           WEAPON_NAMES[weapon], SKIN_NAMES[weapon][rarity], RARITY_NAMES[rarity]);
    if (g_RevealCredit[id])
        client_print_color(id, print_team_default, "^4[Новый год]^1 Дубликат продан. Начислено ^3+%d^1 снежинок.",
                           g_RevealCredit[id]);
}

AnnounceCaseDrop(id, reward)
{
    new rarity = reward % CASE_RARITY_COUNT;
    if (!CaseRevealIsPublic(rarity))
        return;

    new weapon = reward / CASE_RARITY_COUNT;
    client_print_color(0, rarity == CASE_RARITY_EPIC ? print_team_blue : print_team_red,
                       "^4[Новый год]^1 Игроку ^3%s^1 выпал скин ^4«%s | %s»^1. Редкость: ^3%s^1.",
                       g_RevealName[id], WEAPON_NAMES[weapon], SKIN_NAMES[weapon][rarity], RARITY_NAMES[rarity]);
}

public ShowCollection(id)
{
    new key[40], inventory[GIFT_COLLECTION_SIZE], balance;
    if (!GetPlayerKey(id, key, charsmax(key)))
        return ShowBalance(id);

    LoadProfile(key, balance, inventory);
    LoadSelections(id);
    new menu = menu_create("Коллекция: выбрать или снять скин", "SelectCollectionSkin");
    new name[120], info[5], count;
    for (new i = 0; i < GIFT_COLLECTION_SIZE; i++)
    {
        if (!inventory[i])
            continue;
        new weapon = i / CASE_RARITY_COUNT, rarity = i % CASE_RARITY_COUNT;
        formatex(name, charsmax(name), "%s | %s [%s] x%d%s", WEAPON_NAMES[weapon],
                 SKIN_NAMES[weapon][rarity], RARITY_NAMES[rarity], inventory[i], g_Selected[id][weapon] == rarity + 1 ? " [экипирован]" : "");
        num_to_str(i, info, charsmax(info));
        menu_additem(menu, name, info);
        count++;
    }
    if (!count)
        menu_addtext(menu, "Открой кейс, чтобы получить первый скин.");
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

    new key[40], inventory[GIFT_COLLECTION_SIZE], balance;
    if (!GetPlayerKey(id, key, charsmax(key)))
        return PLUGIN_HANDLED;

    new index = str_to_num(info);
    if (index < 0 || index >= GIFT_COLLECTION_SIZE)
        return PLUGIN_HANDLED;
    LoadProfile(key, balance, inventory);
    if (!inventory[index])
        return PLUGIN_HANDLED;

    LoadSelections(id);
    new weapon = index / CASE_RARITY_COUNT, rarity = index % CASE_RARITY_COUNT;
    new bool:removing = g_Selected[id][weapon] == rarity + 1;
    g_Selected[id][weapon] = removing ? 0 : rarity + 1;
    new vaultKey[56], record[CASE_WEAPON_BUTTERFLY + 2];
    formatex(vaultKey, charsmax(vaultKey), "equip:%s", key);
    for (new i = 0; i < sizeof g_Selected[]; i++)
        record[i] = '0' + g_Selected[id][i];
    nvault_set(g_Vault, vaultKey, record);

    if (is_user_alive(id) && get_user_weapon(id) == SKIN_WEAPONS[weapon])
        ApplySkin(id, SKIN_WEAPONS[weapon]);
    client_print_color(id, print_team_default, "^4[Новый год]^1 %s: %s / %s.",
                       removing ? "Скин снят" : "Скин экипирован", WEAPON_NAMES[weapon], RARITY_NAMES[rarity]);
    return ShowCollection(id);
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
            g_Selected[id][i] = clamp(record[i] - '0', 0, CASE_RARITY_COUNT);
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

    new index = GiftSkinIndex(weapon, g_Selected[id][weapon] - 1);
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
