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

stock bool:CaseDropResolve(caseId, roll, &weapon, &rarity)
{
    if (caseId < 0 || caseId >= CASE_WEAPON_COUNT || roll < 0 || roll >= CASE_DROP_ROLL_COUNT)
        return false;

    // Unconditional weights in hundredths of a percent.
    static const weights[][] = {
        {5180, 1702, 444, 74},
        {350, 115, 30, 5},
        {60, 30, 9, 1}
    };

    for (new candidate = 0; candidate <= CASE_WEAPON_BUTTERFLY; candidate++)
    {
        new group = candidate == CASE_WEAPON_BUTTERFLY ? 2 : (candidate == caseId ? 0 : 1);
        for (new tier = 0; tier < CASE_RARITY_COUNT; tier++)
        {
            if (roll < weights[group][tier])
            {
                weapon = candidate;
                rarity = tier;
                return true;
            }
            roll -= weights[group][tier];
        }
    }

    return false;
}
