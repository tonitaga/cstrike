from pathlib import Path
import re
from json import dumps

from build_newyear_skins import model_filename, OUTPUT, ROOT, TIERS, VARIANT_TIERS
from preview_newyear_skins import png, render

# Order matches the case drop API, not the skin build order.
WEAPONS = ("m4a1", "ak47", "glock18", "deagle", "awp", "usp", "knife")


def main():
    source = (ROOT / "cstrike/addons/amxmodx/scripting/incom_newyear_gifts.sma").read_text(encoding="utf-8")
    names = re.findall(r'"([^"]+)"', source.split("new const SKIN_NAMES", 1)[1].split("};", 1)[0])
    extra_names = re.findall(r'"([^"]+)"', source.split("new const SKIN_EXTRA_NAMES", 1)[1].split("};", 1)[0])
    labels = re.findall(r'"([^"]+)"', source.split("new const WEAPON_NAMES", 1)[1].split("};", 1)[0])
    rarities = re.findall(r'"([^"]+)"', source.split("new const RARITY_NAMES", 1)[1].split("};", 1)[0])
    target = ROOT / "cstrike/motd/newyear"
    pictures = target / "skins"
    pictures.mkdir(parents=True, exist_ok=True)
    cards = []
    case_skin_ids = []
    for weapon_index, weapon in enumerate(WEAPONS):
        folder = "butterfly" if weapon == "knife" else weapon
        ids = []
        for rarity, tier in enumerate(TIERS):
            index = weapon_index * len(TIERS) + rarity
            model = OUTPUT / folder / tier / model_filename("v",weapon,tier=rarity)
            card = f"skins/{index}.png"
            png(target / card, 480, 224, render(model.read_bytes(), 480, 224, idle=True))
            cards.append({"weapon": labels[weapon_index], "name": names[index],
                          "rarity": rarities[rarity], "tier": tier, "image": card})
            ids.append(index)
        if weapon != "knife":
            case_skin_ids.append(ids)

    knife_ids = list(range(len(names) - len(TIERS),len(names)))
    for weapon_index, weapon in enumerate(WEAPONS[:-1]):
        for variant, rarity in enumerate(VARIANT_TIERS, 1):
            index = len(cards)
            model = OUTPUT / weapon / TIERS[rarity] / model_filename("v",weapon,variant)
            card = f"skins/{index}.png"
            png(target / card, 480, 224, render(model.read_bytes(), 480, 224, idle=True))
            name = extra_names[weapon_index * len(VARIANT_TIERS) + variant - 1]
            cards.append({"weapon": labels[weapon_index], "name": name, "rarity": rarities[rarity],
                          "tier": TIERS[rarity], "image": card})
            case_skin_ids[weapon_index].append(index)
        case_skin_ids[weapon_index].extend(knife_ids)
    (target / "catalog.js").write_text("var caseCards = " + dumps(cards, ensure_ascii=False)
                                      + ";\nvar caseSkinIds = " + dumps(case_skin_ids) + ";\n", encoding="utf-8")



if __name__ == "__main__":
    main()
