# Fetch a pinned Chrome Web Store CRX and unpack it for --load-extension, with its
# signing key written into manifest.json so the extension keeps its ID.
{
  lib,
  fetchurl,
  runCommand,
  unzip,
  writers,
}: let
  # Finds the DER key in the CRX3 header whose SHA-256 (hex mapped to a-p) matches
  # the extension ID, and writes it into manifest.json.
  crx-key-inject = writers.writePython3Bin "crx-key-inject" {} (builtins.readFile ./crx-key-inject.py);
in
  # A CRX is a protobuf header followed by a zip. The fetchurl name keeps the
  # URL's "?" and "&" out of the store path.
  {
    name,
    id,
    version,
    hash,
  }:
    runCommand "helium-extension-${name}" {} ''
      mkdir -p $out
      crx="${
        fetchurl {
          name = "${name}-${version}.crx";
          url = "https://clients2.google.com/service/update2/crx?response=redirect&os=linux&arch=x64&os_arch=x86-64&nacl_arch=x86-64&prod=chromiumcrx&prodchannel=unknown&prodversion=152.0.0.0&acceptformat=crx2,crx3&x=id%3D${id}%26uc";
          inherit hash;
        }
      }"
      header_len=$(od -A n -t u4 -j 8 -N 4 "$crx" | tr -d ' ')
      dd if="$crx" of=payload.zip bs=1 skip=$((12 + header_len)) status=none
      ${lib.getExe' unzip "unzip"} -q payload.zip -d $out
      ${crx-key-inject}/bin/crx-key-inject "$crx" ${id} $out
    ''
