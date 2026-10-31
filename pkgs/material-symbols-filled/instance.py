# Pin the variable font's axes to one static instance and give it its own family name.
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

FAMILY = "Material Symbols Rounded Filled"

src, dst = sys.argv[1], sys.argv[2]
font = instancer.instantiateVariableFont(TTFont(src), {"FILL": 1, "wght": 400, "GRAD": 0, "opsz": 24})
for rec in font["name"].names:
    if rec.nameID in (1, 4, 16):
        rec.string = FAMILY
    elif rec.nameID in (2, 17):
        rec.string = "Regular"
    elif rec.nameID == 6:
        rec.string = FAMILY.replace(" ", "") + "-Regular"
font.save(dst)
