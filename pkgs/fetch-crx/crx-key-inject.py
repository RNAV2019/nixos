import base64
import hashlib
import json
import struct
import sys

crx_path, expected_id, out_dir = sys.argv[1:4]


def to_id(der):
    digest = hashlib.sha256(der).hexdigest()[:32]
    table = "abcdefghijklmnopabcdefghijklmnop"
    return "".join(table[int(c, 16)] for c in digest)


buf = open(crx_path, "rb").read()
assert buf[:4] == b"Cr24", "not a CRX"
assert struct.unpack("<I", buf[4:8])[0] == 3, "not a CRX3"
hlen = struct.unpack("<I", buf[8:12])[0]
header = buf[12:12 + hlen]

key = None
for i in range(len(header)):
    if header[i] != 0x30:  # DER SEQUENCE
        continue
    b = header[i + 1]
    if b < 0x80:
        length = 2 + b
    elif b & 0x7F in (1, 2):
        n = b & 0x7F
        length = 2 + n + int.from_bytes(header[i + 2:i + 2 + n], "big")
    else:
        continue
    if length < 32 or i + length > len(header):
        continue
    candidate = header[i:i + length]
    if to_id(candidate) == expected_id:
        key = candidate
        break
if key is None:
    sys.exit(f"no signing key producing ID {expected_id} found in {crx_path}")

manifest_path = out_dir + "/manifest.json"
manifest = json.load(open(manifest_path))
manifest["key"] = base64.b64encode(key).decode()
assert to_id(base64.b64decode(manifest["key"])) == expected_id
with open(manifest_path, "w") as f:
    json.dump(manifest, f, indent=2)
