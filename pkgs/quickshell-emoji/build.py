"""Flatten emoji-test.txt and the CLDR English annotations into the launcher's TSV.

One line per fully-qualified emoji, in Unicode's order:
    emoji <TAB> name <TAB> group <TAB> keywords (comma-separated)
Skin-tone variants are dropped: the picker offers the base emoji only.
"""

import sys
import xml.etree.ElementTree as ET

emoji_test, annotations, derived, out = sys.argv[1:5]

TONES = {0x1F3FB, 0x1F3FC, 0x1F3FD, 0x1F3FE, 0x1F3FF}


def load_keywords(path, into):
    for node in ET.parse(path).getroot().iter("annotation"):
        if node.get("type") == "tts" or not node.text:
            continue
        into[node.get("cp")] = [k.strip() for k in node.text.split("|") if k.strip()]


keywords = {}
load_keywords(annotations, keywords)
load_keywords(derived, keywords)

rows = []
group = ""
with open(emoji_test, encoding="utf-8") as f:
    for line in f:
        if line.startswith("# group:"):
            group = line.split(":", 1)[1].strip()
            continue
        if line.startswith("#") or ";" not in line:
            continue
        codes, rest = line.split(";", 1)
        if not rest.strip().startswith("fully-qualified"):
            continue
        points = [int(c, 16) for c in codes.split()]
        if any(p in TONES for p in points):
            continue
        char = "".join(chr(p) for p in points)
        # "# 😀 E1.0 grinning face": the name follows the version.
        name = rest.split("#", 1)[1].strip().split(" ", 2)[2]
        # CLDR keys most emoji without the U+FE0F presentation selector.
        kw = keywords.get(char) or keywords.get(char.replace("️", "")) or []
        words = set(name.lower().replace(":", " ").replace(",", " ").split())
        kw = [k for k in kw if k.lower() not in words and k.lower() != name.lower()]
        rows.append("\t".join([char, name, group, ", ".join(kw)]))

with open(out, "w", encoding="utf-8") as f:
    f.write("\n".join(rows) + "\n")
