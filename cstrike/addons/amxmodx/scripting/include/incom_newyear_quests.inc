#define QUEST_PERIODS 3
#define QUEST_SLOTS 3
#define QUEST_WEAPONS 7
#define QUEST_PAID (QUEST_WEAPONS + 1)
#define QUEST_OTHER (QUEST_WEAPONS + 2)
#define QUEST_STATE (QUEST_WEAPONS + 3)
#define QUEST_ALL ((1 << QUEST_WEAPONS) - 1)

enum { QUEST_MAP, QUEST_DAY, QUEST_WEEK };
enum { QUEST_TOTAL, QUEST_EACH, QUEST_ANY };
enum _:QuestRule { QuestMask, QuestMode, QuestAmount, QuestKinds, QuestSnow, QuestCases };

new const QUEST_KILLS[][] = {"m4a1", "ak47", "awp", "deagle", "glock18", "usp", "knife"};
new const QUEST_NAMES[][] = {"M4A1", "AK-47", "AWP", "Deagle", "Glock", "USP", "Нож"};
new const QUEST_GROUPS[][] = {"На карту", "На день", "На неделю"};
// Keep positions stable so a deployed catalogue update preserves active assignments.
new const QUEST_RULES[][QuestRule] = {
    {1, QUEST_TOTAL, 12, 1, 30, 0}, {2, QUEST_TOTAL, 12, 1, 30, 0},
    {4, QUEST_TOTAL, 12, 1, 30, 0}, {8, QUEST_TOTAL, 12, 1, 30, 0},
    {16, QUEST_TOTAL, 12, 1, 30, 0}, {32, QUEST_TOTAL, 12, 1, 30, 0},
    {64, QUEST_TOTAL, 12, 1, 30, 0}, {3, QUEST_TOTAL, 25, 1, 30, 0},
    {56, QUEST_TOTAL, 20, 1, 25, 0}, {3, QUEST_EACH, 10, 2, 35, 0},
    {48, QUEST_EACH, 8, 2, 35, 0}, {12, QUEST_EACH, 7, 2, 40, 2},
    {QUEST_ALL, QUEST_ANY, 5, 3, 35, 2}, {QUEST_ALL, QUEST_TOTAL, 40, 1, 45, 3}
};
new g_QuestsEnabled, g_QuestMapEpoch, g_QuestMapMask;

InitQuests()
{
    g_QuestsEnabled = register_cvar("incom_newyear_quests_enabled", "1");
    register_clcmd("say /quests", "ShowQuests");
    register_clcmd("say_team /quests", "ShowQuests");
    g_QuestMapEpoch = get_systime() ^ random_num(1, 2147483647);
    g_QuestMapEpoch &= 2147483647;
    if (!g_QuestMapEpoch)
        g_QuestMapEpoch = 1;

    new map[64];
    get_mapname(map, charsmax(map));
    g_QuestMapMask = QUEST_ALL;
    if (containi(map, "35hp") == 0 || containi(map, "ka_") == 0)
        g_QuestMapMask = 64;
    else if (containi(map, "aim_usp") == 0)
        g_QuestMapMask = 32 | 64;
    else if (containi(map, "aim_deagle") == 0)
        g_QuestMapMask = 8 | 64;
    else if (containi(map, "awp_") == 0)
        g_QuestMapMask = 4 | 64;
}

bool:QuestsEnabled()
{
    return get_pcvar_num(g_Enable) != 0 && get_pcvar_num(g_QuestsEnabled) != 0;
}

QuestEpochs(epochs[QUEST_PERIODS])
{
    new now = get_systime(), value[12];
    epochs[QUEST_MAP] = g_QuestMapEpoch;
    format_time(value, charsmax(value), "%Y%m%d", now);
    epochs[QUEST_DAY] = str_to_num(value);
    format_time(value, charsmax(value), "%w", now);
    new monday = (str_to_num(value) + 6) % 7;
    format_time(value, charsmax(value), "%Y%m%d", now - monday * 86400);
    epochs[QUEST_WEEK] = str_to_num(value);
}

LoadQuests(const key[], questState[QUEST_PERIODS][QUEST_STATE])
{
    new record[PROFILE_SIZE], epochs[QUEST_PERIODS], offset, end;
    nvault_get(g_Vault, key, record, charsmax(record));
    offset = contain(record, QUEST_MARKER);
    if (offset >= 0)
        offset += strlen(QUEST_MARKER);
    QuestEpochs(epochs);
    for (new period; period < QUEST_PERIODS; period++)
    {
        for (new field; field < QUEST_OTHER && offset >= 0; field++)
        {
            questState[period][field] = strtol(record[offset], end, 10);
            if (!end)
                offset = -1;
            else
                offset += end;
        }
    }
    // Optional extra counters follow the legacy fields for all periods.
    for (new period; period < QUEST_PERIODS && offset >= 0; period++)
    {
        questState[period][QUEST_OTHER] = strtol(record[offset], end, 10);
        offset = end ? offset + end : -1;
    }
    for (new period; period < QUEST_PERIODS; period++)
    {
        if (questState[period][0] != epochs[period])
        {
            arrayset(questState[period], 0, QUEST_STATE);
            questState[period][0] = epochs[period];
        }
    }
}

SerializeQuests(const questState[QUEST_PERIODS][QUEST_STATE], data[QUEST_DATA])
{
    new length = copy(data, QUEST_DATA - 1, QUEST_MARKER);
    for (new period; period < QUEST_PERIODS; period++)
        for (new field; field < QUEST_OTHER; field++)
            length += formatex(data[length], QUEST_DATA - 1 - length, " %d", questState[period][field]);
    for (new period; period < QUEST_PERIODS; period++)
        length += formatex(data[length], QUEST_DATA - 1 - length, " %d", questState[period][QUEST_OTHER]);
}

QuestSeed(const key[], epoch, period)
{
    new value = epoch ^ ((period + 1) * 104729);
    for (new i; key[i]; i++)
        value = (value * 31) ^ key[i];
    return value & 2147483647;
}

QuestAssignments(const key[], epoch, period, picks[QUEST_SLOTS])
{
    new pool[sizeof QUEST_RULES + QUEST_WEAPONS * 2], count;
    if (period == QUEST_MAP)
    {
        for (new weapon; weapon < QUEST_WEAPONS; weapon++)
            if (g_QuestMapMask & (1 << weapon))
                pool[count++] = weapon;
    }
    else
    {
        for (new rule; rule < sizeof QUEST_RULES; rule++)
            pool[count++] = rule;
    }

    new seed = QuestSeed(key, epoch, period);
    new slot;
    while (slot < QUEST_SLOTS && count)
    {
        seed = (seed * 1664525 + 1013904223) & 2147483647;
        new index = seed % count;
        picks[slot++] = pool[index];
        pool[index] = pool[--count];
    }
    // Single-weapon maps still offer three distinct goals.
    for (new base; slot < QUEST_SLOTS; slot++, base++)
        picks[slot] = picks[base] + QUEST_WEAPONS;
}

QuestGoal(period, rule, &mask, &mode, &amount, &kinds, &snow, &cases)
{
    if (period == QUEST_MAP)
    {
        mask = 1 << (rule % QUEST_WEAPONS);
        mode = QUEST_TOTAL;
        amount = 3 + (rule / QUEST_WEAPONS) * 3;
        kinds = 1;
        snow = 7 + (rule / QUEST_WEAPONS) * 4;
        cases = 0;
        return;
    }
    new multiplier = period == QUEST_WEEK ? 5 : 1;
    mask = QUEST_RULES[rule][QuestMask];
    mode = QUEST_RULES[rule][QuestMode];
    amount = QUEST_RULES[rule][QuestAmount] * multiplier;
    kinds = QUEST_RULES[rule][QuestKinds];
    cases = period == QUEST_WEEK ? QUEST_RULES[rule][QuestCases] : 0;
    snow = QUEST_RULES[rule][QuestSnow] * multiplier - cases * 60;
}

QuestScore(const questState[QUEST_STATE], mask, mode, amount, kinds)
{
    new progress, best[QUEST_WEAPONS], used;
    for (new weapon; weapon < QUEST_WEAPONS; weapon++)
    {
        if (!(mask & (1 << weapon)))
            continue;
        new value = questState[weapon + 1];
        if (mode == QUEST_TOTAL)
            progress += value;
        else if (mode == QUEST_EACH)
            progress += min(value, amount);
        else
        {
            new index = used++;
            while (index > 0 && best[index - 1] < value)
            {
                best[index] = best[index - 1];
                index--;
            }
            best[index] = value;
        }
    }
    if (mode == QUEST_TOTAL && mask == QUEST_ALL)
        progress += questState[QUEST_OTHER];
    if (mode == QUEST_ANY)
        for (new i; i < kinds; i++)
            progress += min(best[i], amount);
    return min(progress, amount * kinds);
}

QuestWeapon()
{
    new name[24];
    read_data(4, name, charsmax(name));
    if (equal(name, "glock"))
        return 4;
    for (new weapon; weapon < QUEST_WEAPONS; weapon++)
        if (equal(name, QUEST_KILLS[weapon]))
            return weapon;
    if (!name[0] || equal(name, "world") || equal(name, "worldspawn")
        || contain(name, "trigger_") == 0 || contain(name, "func_") == 0)
        return -1;
    return QUEST_WEAPONS;
}

QuestCredit(id, const key[], weapon, &balance, cases[sizeof CASE_TYPES][CASE_STOCK_MAX + 1], data[QUEST_DATA])
{
    new questState[QUEST_PERIODS][QUEST_STATE];
    LoadQuests(key, questState);
    for (new period; period < QUEST_PERIODS; period++)
    {
        new counter = weapon < QUEST_WEAPONS ? weapon + 1 : QUEST_OTHER;
        questState[period][counter] = min(200, questState[period][counter] + 1);
        new picks[QUEST_SLOTS];
        QuestAssignments(key, questState[period][0], period, picks);
        for (new slot; slot < QUEST_SLOTS; slot++)
        {
            if (questState[period][QUEST_PAID] & (1 << slot))
                continue;
            new mask, mode, amount, kinds, reward, caseCount;
            QuestGoal(period, picks[slot], mask, mode, amount, kinds, reward, caseCount);
            if (QuestScore(questState[period], mask, mode, amount, kinds) < amount * kinds)
                continue;

            new awarded;
            while (awarded < caseCount && QueueGiftCase(CASE_EVENT_NEW_YEAR, cases) >= 0)
                awarded++;
            reward += (caseCount - awarded) * 60;
            new total = GiftAddBalance(balance, reward);
            questState[period][QUEST_PAID] |= 1 << slot;
            if (awarded)
                client_print_color(id, print_team_blue, "^4[Задания]^1 Выполнено ^3«%s»^1. Награда: ^4+%d^1 снежинок. Кейсов в хранилище: ^4+%d^1.", QUEST_GROUPS[period], total - balance, awarded);
            else
                client_print_color(id, print_team_blue, "^4[Задания]^1 Выполнено ^3«%s»^1. Награда: ^4+%d^1 снежинок.", QUEST_GROUPS[period], total - balance);
            balance = total;
        }
    }
    SerializeQuests(questState, data);
}

QuestLabel(mask, mode, amount, kinds, label[], size)
{
    if (mask == QUEST_ALL && mode == QUEST_TOTAL)
    {
        copy(label, size, "Любое оружие");
        return;
    }
    if (mode == QUEST_ANY)
    {
        formatex(label, size, "%d вида × %d", kinds, amount);
        return;
    }
    new length;
    for (new weapon; weapon < QUEST_WEAPONS; weapon++)
        if (mask & (1 << weapon))
            length += formatex(label[length], size - length, "%s%s", length ? (mode == QUEST_EACH ? "+" : "/") : "", QUEST_NAMES[weapon]);
    if (mode == QUEST_EACH)
        formatex(label[length], size - length, " × %d", amount);
}

public ShowQuests(id)
{
    new key[40];
    if (!QuestsEnabled())
    {
        show_motd(id, "<meta charset=utf-8><h2>Задания</h2>Активных событий сейчас нет.", "Задания");
        return PLUGIN_HANDLED;
    }
    if (!GetPlayerKey(id, key, charsmax(key)))
        return PLUGIN_HANDLED;

    new questState[QUEST_PERIODS][QUEST_STATE], html[1536], label[60], prize[40];
    LoadQuests(key, questState);
    new length = copy(html, charsmax(html),
        "<meta charset=utf-8><style>body{margin:12px;background:#101824;color:#edf3fa;font:14px Arial}h3{color:#ffd279;margin:0 0 5px}table{width:100%;border-spacing:0 2px}th,td{padding:3px 7px;text-align:left}th{color:#a6c7f0}td{background:#1e2c40}td:nth-child(2){color:#ffd279}td:nth-child(3){width:32%}td:last-child{text-align:right}td+td{white-space:nowrap}progress{width:100%;height:9px;accent-color:#64d6b0}</style><h3>Новый год</h3><table>");
    for (new period; period < QUEST_PERIODS; period++)
    {
        length += formatex(html[length], charsmax(html) - length, "<tr><th colspan=4>%s", QUEST_GROUPS[period]);
        new picks[QUEST_SLOTS];
        QuestAssignments(key, questState[period][0], period, picks);
        for (new slot; slot < QUEST_SLOTS; slot++)
        {
            new mask, mode, amount, kinds, reward, cases;
            QuestGoal(period, picks[slot], mask, mode, amount, kinds, reward, cases);
            new progress = (questState[period][QUEST_PAID] & (1 << slot))
                ? amount * kinds : QuestScore(questState[period], mask, mode, amount, kinds);
            QuestLabel(mask, mode, amount, kinds, label, charsmax(label));
            if (cases)
                formatex(prize, charsmax(prize), "%d❄ + %d кейс.", reward, cases);
            else
                formatex(prize, charsmax(prize), "%d❄", reward);
            length += formatex(html[length], charsmax(html) - length,
                "<tr><td>%s<td>%s<td><progress value=%d max=%d></progress><td>%d/%d",
                label, prize, progress, amount * kinds, progress, amount * kinds);
        }
    }
    add(html, charsmax(html), "</table>");
    show_motd(id, html, "Задания");
    return PLUGIN_HANDLED;
}
