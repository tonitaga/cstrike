#include <amxmodx>
#include <incom_case_drops>

public plugin_init()
{
    register_plugin("INCOM Case Drop Tests", "1.0", "INCOMSYSTEM");

    new counts[CASE_WEAPON_COUNT + 1][CASE_RARITY_COUNT];
    new weapon, rarity;
    for (new caseId = 0; caseId < CASE_WEAPON_COUNT; caseId++)
    {
        for (new w = 0; w <= CASE_WEAPON_COUNT; w++)
            arrayset(counts[w], 0, CASE_RARITY_COUNT);

        for (new roll = 0; roll < 10000; roll++)
        {
            if (!CaseDropResolve(caseId, roll, weapon, rarity))
                set_fail_state("Missing case outcome");
            counts[weapon][rarity]++;
        }

        for (new w = 0; w <= CASE_WEAPON_COUNT; w++)
        {
            new const main[] = {7500, 1950, 300, 50};
            new const knife[] = {120, 60, 18, 2};
            for (new r = 0; r < CASE_RARITY_COUNT; r++)
            {
                new expected = w == CASE_WEAPON_COUNT ? knife[r] : (w == caseId ? main[r] : 0);
                if (counts[w][r] != expected)
                    set_fail_state("Incorrect case odds");
            }
        }
    }

    if (CaseDropResolve(-1, 0, weapon, rarity)
        || CaseDropResolve(CASE_WEAPON_COUNT, 0, weapon, rarity)
        || CaseDropResolve(0, -1, weapon, rarity)
        || CaseDropResolve(0, 10000, weapon, rarity))
        set_fail_state("Accepted invalid case or roll");

    new const weaponCredit[] = {4, 17, 116, 700};
    new const knifeCredit[] = {291, 583, 1944, 17500};
    for (new r = 0; r < CASE_RARITY_COUNT; r++)
    {
        if (CaseDuplicateValue(CASE_WEAPON_AK47, CASE_WEAPON_AK47, r) != weaponCredit[r]
            || CaseDuplicateValue(CASE_WEAPON_AK47, CASE_WEAPON_BUTTERFLY, r) != knifeCredit[r]
            || CaseDuplicateValue(CASE_WEAPON_AK47, CASE_WEAPON_DEAGLE, r) != 0)
            set_fail_state("Case duplicate sale price is wrong");
    }

    weapon = -1;
    rarity = -1;
    if (incom_case_roll(-1, weapon, rarity) || weapon != -1 || rarity != -1)
        set_fail_state("Native accepted invalid case");

    for (new caseId = 0; caseId < CASE_WEAPON_COUNT; caseId++)
    {
        if (!incom_case_roll(caseId, weapon, rarity) || (weapon != caseId && weapon != CASE_WEAPON_BUTTERFLY)
            || rarity < 0 || rarity >= CASE_RARITY_COUNT)
            set_fail_state("Invalid native case outcome");
    }

    server_print("INCOM case drops: 60000 outcomes verified");
}
