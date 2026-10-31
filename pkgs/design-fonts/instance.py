# Cut one static weight from a variable font and name it as its own face of the family. Axes
# other than wght are pinned to their defaults.
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

STYLES = {300: "Light", 400: "Regular", 500: "Medium", 600: "SemiBold", 700: "Bold"}

src, family, weight, italic, dst = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4] == "italic", sys.argv[5]
font = TTFont(src)
location = {axis.axisTag: axis.defaultValue for axis in font["fvar"].axes}
location["wght"] = weight
font = instancer.instantiateVariableFont(font, location)

style = STYLES[weight]
if italic:
    style = "Italic" if style == "Regular" else f"{style} Italic"
ribbi = style in ("Regular", "Bold", "Italic", "Bold Italic")
name = font["name"]
for rec in list(name.names):
    if rec.nameID in (1, 2, 3, 4, 6, 16, 17, 25):
        name.removeNames(nameID=rec.nameID)
postscript = f"{family.replace(' ', '')}-{style.replace(' ', '')}"
name.setName(family if ribbi else f"{family} {style.removesuffix(' Italic')}", 1, 3, 1, 0x409)
name.setName(style if ribbi else ("Italic" if italic else "Regular"), 2, 3, 1, 0x409)
name.setName(postscript, 3, 3, 1, 0x409)
name.setName(f"{family} {style}", 4, 3, 1, 0x409)
name.setName(postscript, 6, 3, 1, 0x409)
name.setName(family, 16, 3, 1, 0x409)
name.setName(style, 17, 3, 1, 0x409)
font["OS/2"].usWeightClass = weight
if italic:
    font["OS/2"].fsSelection |= 1
    font["head"].macStyle |= 2
font.save(dst)
