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

// Returns one weapon and rarity. A false return leaves both outputs untouched.
native bool:incom_case_roll(caseId, &weapon, &rarity);

// Each case uses the same two rows: its own weapon and the butterfly.
// Values are outcomes out of CASE_DROP_ROLL_COUNT.
new const CASE_DROP_WEIGHTS[2][CASE_RARITY_COUNT] = {
    {6650, 2185, 570, 95},
    {300, 150, 45, 5}
};

stock CaseDuplicateValue(caseId, weapon, rarity)
{
    if (caseId < 0 || caseId >= CASE_WEAPON_COUNT || rarity < 0 || rarity >= CASE_RARITY_COUNT
        || (weapon != caseId && weapon != CASE_WEAPON_BUTTERFLY))
        return 0;

    // 3.5 / (weight / 10000), rounded down with integer arithmetic.
    return 35000 / CASE_DROP_WEIGHTS[weapon == CASE_WEAPON_BUTTERFLY ? 1 : 0][rarity];
}

stock bool:CaseDropResolve(caseId, roll, &weapon, &rarity)
{
    if (caseId < 0 || caseId >= CASE_WEAPON_COUNT || roll < 0 || roll >= CASE_DROP_ROLL_COUNT)
        return false;

    for (new group = 0; group < sizeof CASE_DROP_WEIGHTS; group++)
    {
        for (new tier = 0; tier < CASE_RARITY_COUNT; tier++)
        {
            if (roll < CASE_DROP_WEIGHTS[group][tier])
            {
                weapon = group ? CASE_WEAPON_BUTTERFLY : caseId;
                rarity = tier;
                return true;
            }
            roll -= CASE_DROP_WEIGHTS[group][tier];
        }
    }

    return false;
}
