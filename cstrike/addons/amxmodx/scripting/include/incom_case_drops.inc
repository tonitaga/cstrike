#if defined _incom_case_drops_included
    #endinput
#endif
#define _incom_case_drops_included

#define CASE_DROP_ROLL_COUNT 10000

enum
{
    CASE_WEAPON_M4A1,
    CASE_WEAPON_AK47,
    CASE_WEAPON_GLOCK,
    CASE_WEAPON_DEAGLE,
    CASE_WEAPON_AWP,
    CASE_WEAPON_USP,
    CASE_WEAPON_COUNT,
    CASE_WEAPON_BUTTERFLY = CASE_WEAPON_COUNT
};

enum
{
    CASE_RARITY_COMMON,
    CASE_RARITY_RARE,
    CASE_RARITY_EPIC,
    CASE_RARITY_LEGENDARY,
    CASE_RARITY_COUNT
};

enum
{
    CASE_TYPE_CT = CASE_WEAPON_COUNT,
    CASE_TYPE_T,
    CASE_TYPE_SNIPER,
    CASE_TYPE_COUNT
};

new const CASE_GROUP_WEAPONS[][2] = {
    {CASE_WEAPON_M4A1, CASE_WEAPON_USP},
    {CASE_WEAPON_AK47, CASE_WEAPON_GLOCK},
    {CASE_WEAPON_AWP, CASE_WEAPON_DEAGLE}
};

stock CaseFirearm(caseId, position)
{
    if (caseId < 0 || caseId >= CASE_TYPE_COUNT || position < 0 || position > 1)
        return -1;
    if (caseId < CASE_WEAPON_COUNT)
        return position == 0 ? caseId : -1;
    return CASE_GROUP_WEAPONS[caseId - CASE_WEAPON_COUNT][position];
}

// Returns one weapon and rarity. A false return leaves both outputs untouched.
native bool:incom_case_roll(caseId, &weapon, &rarity);

// The firearm row is split evenly between the weapons in a grouped case.
// Values are outcomes out of CASE_DROP_ROLL_COUNT.
new const CASE_DROP_WEIGHTS[2][CASE_RARITY_COUNT] = {
    {7500, 1950, 300, 50},
    {120, 60, 18, 2}
};

stock CaseDropWeight(caseId, weapon, rarity)
{
    if (caseId < 0 || caseId >= CASE_TYPE_COUNT || rarity < 0 || rarity >= CASE_RARITY_COUNT)
        return 0;
    if (weapon == CASE_WEAPON_BUTTERFLY)
        return CASE_DROP_WEIGHTS[1][rarity];
    if (weapon < 0 || (weapon != CaseFirearm(caseId, 0) && weapon != CaseFirearm(caseId, 1)))
        return 0;
    return CASE_DROP_WEIGHTS[0][rarity] / (caseId < CASE_WEAPON_COUNT ? 1 : 2);
}

stock CaseDuplicateValue(caseId, weapon, rarity)
{
    new weight = CaseDropWeight(caseId, weapon, rarity);
    // 3.5 / (weight / 10000), rounded down.
    return weight ? 35000 / weight : 0;
}

stock bool:CaseDropResolve(caseId, roll, &weapon, &rarity)
{
    if (caseId < 0 || caseId >= CASE_TYPE_COUNT || roll < 0 || roll >= CASE_DROP_ROLL_COUNT)
        return false;

    new groups[3];
    groups[0] = CaseFirearm(caseId, 0);
    groups[1] = CaseFirearm(caseId, 1);
    groups[2] = CASE_WEAPON_BUTTERFLY;
    for (new group = 0; group < sizeof groups; group++)
    {
        if (groups[group] < 0)
            continue;
        for (new tier = 0; tier < CASE_RARITY_COUNT; tier++)
        {
            new weight = CaseDropWeight(caseId, groups[group], tier);
            if (roll < weight)
            {
                weapon = groups[group];
                rarity = tier;
                return true;
            }
            roll -= weight;
        }
    }

    return false;
}
