#if defined _incom_newyear_gifts_included
    #endinput
#endif
#define _incom_newyear_gifts_included

#include <incom_case_drops>

#define GIFT_MAX_BALANCE 999999
#define GIFT_BASE_SKINS 28
#define GIFT_EXTRA_SKINS 9
#define GIFT_WEAPON_VARIANTS 13
#define GIFT_COLLECTION_SIZE (GIFT_BASE_SKINS + CASE_WEAPON_COUNT * GIFT_EXTRA_SKINS)

new const GIFT_EXTRA_TIERS[GIFT_EXTRA_SKINS] = {0, 0, 0, 1, 1, 1, 2, 2, 3};

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

stock GiftVariantCount(weapon)
{
    if (weapon == CASE_WEAPON_BUTTERFLY)
        return CASE_RARITY_COUNT;
    return GIFT_WEAPON_VARIANTS;
}

stock GiftVariantIndex(weapon, variant)
{
    if (variant < CASE_RARITY_COUNT)
        return GiftSkinIndex(weapon, variant);
    return GIFT_BASE_SKINS + weapon * GIFT_EXTRA_SKINS + variant - CASE_RARITY_COUNT;
}

stock GiftSkinWeapon(index)
{
    return index < GIFT_BASE_SKINS ? index / CASE_RARITY_COUNT
        : (index - GIFT_BASE_SKINS) / GIFT_EXTRA_SKINS;
}

stock GiftSkinVariant(index)
{
    return index < GIFT_BASE_SKINS ? index % CASE_RARITY_COUNT
        : CASE_RARITY_COUNT + (index - GIFT_BASE_SKINS) % GIFT_EXTRA_SKINS;
}

stock GiftSkinRarity(index)
{
    new variant = GiftSkinVariant(index);
    return variant < CASE_RARITY_COUNT ? variant : GIFT_EXTRA_TIERS[variant - CASE_RARITY_COUNT];
}

stock GiftRollSkin(weapon, rarity)
{
    if (weapon == CASE_WEAPON_BUTTERFLY)
        return GiftSkinIndex(weapon, rarity);

    new variants[GIFT_WEAPON_VARIANTS], count = 1;
    variants[0] = rarity;
    for (new i = 0; i < GIFT_EXTRA_SKINS; i++)
        if (GIFT_EXTRA_TIERS[i] == rarity)
            variants[count++] = i + CASE_RARITY_COUNT;
    return GiftVariantIndex(weapon, variants[random_num(0, count - 1)]);
}
