#if defined _incom_case_reveal_included
    #endinput
#endif
#define _incom_case_reveal_included

#include <incom_case_drops>

#define CASE_MOTD_START 2
#define CASE_MOTD_TARGET 30
#define CASE_MOTD_ITEMS 35
#define CASE_MOTD_SPIN_MS 6960

stock CaseRevealItem(position, target, decoy, reward)
{
    if (position == target)
        return reward;
    return decoy >= reward ? decoy + 1 : decoy;
}

stock Float:CaseMotdEase(Float:progress)
{
    new Float:left = 1.0 - progress;
    return 0.14 * progress + 0.86 * (1.0 - left * left * left);
}

stock bool:CaseRevealIsPublic(rarity)
{
    return rarity >= CASE_RARITY_EPIC && rarity <= CASE_RARITY_LEGENDARY;
}
