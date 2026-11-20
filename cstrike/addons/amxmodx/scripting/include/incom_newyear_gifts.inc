#if defined _incom_newyear_gifts_included
    #endinput
#endif
#define _incom_newyear_gifts_included

#include <incom_case_drops>

#define GIFT_MAX_BALANCE 999999
#define GIFT_COLLECTION_SIZE 28

stock GiftWaveSize(requested, active, cap, freePoints)
{
    return min(requested, min(max(0, cap - active), freePoints));
}

stock GiftAddBalance(balance, amount)
{
    return min(GIFT_MAX_BALANCE, balance + amount);
}

stock GiftSkinIndex(weapon, rarity)
{
    return weapon * CASE_RARITY_COUNT + rarity;
}
