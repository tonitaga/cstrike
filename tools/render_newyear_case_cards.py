from pathlib import Path
import re
from json import dumps

from build_newyear_skins import OUTPUT, ROOT, TIERS
from preview_newyear_skins import png, render

# Order matches the case drop API, not the skin build order.
WEAPONS = ("m4a1", "ak47", "glock18", "deagle", "awp", "usp", "knife")


def main():
    source = (ROOT / "cstrike/addons/amxmodx/scripting/incom_newyear_gifts.sma").read_text(encoding="utf-8")
    names = re.findall(r'"([^"]+)"', source.split("new const SKIN_NAMES", 1)[1].split("};", 1)[0])
    labels = re.findall(r'"([^"]+)"', source.split("new const WEAPON_NAMES", 1)[1].split("};", 1)[0])
    rarities = re.findall(r'"([^"]+)"', source.split("new const RARITY_NAMES", 1)[1].split("};", 1)[0])
    target = ROOT / "cstrike/motd/newyear"
    pictures = target / "skins"
    pictures.mkdir(parents=True, exist_ok=True)
    cards = []
    for weapon_index, weapon in enumerate(WEAPONS):
        folder = "butterfly" if weapon == "knife" else weapon
        for rarity, tier in enumerate(TIERS):
            index = weapon_index * len(TIERS) + rarity
            model = OUTPUT / folder / tier / f"v_{weapon}_r5.mdl"
            card = f"skins/{index}.png"
            width, height = 480, 224
            png(target / card, width, height, render(model.read_bytes(), width, height, idle=True))
            cards.append({"weapon": labels[weapon_index], "name": names[index],
                          "rarity": rarities[rarity], "tier": tier, "image": card})
    (target / "catalog.js").write_text("var caseCards = " + dumps(cards, ensure_ascii=False) + ";\n",
                                      encoding="utf-8")


if __name__ == "__main__":
    main()
