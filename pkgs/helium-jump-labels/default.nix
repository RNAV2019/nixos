# Helix's gw jump labels for Helium: g then w labels the links, controls and text blocks in
# view, and typing a label focuses it; j and k scroll smoothly. Labels take the colours of the
# live desktop theme.
# Loaded through --load-extension in home/packages.nix.
{
  lib,
  runCommand,
  writeText,
  replaceVars,
}: let
  # Labels are base on the accent, like Helix's ui.virtual.jump-label, in whichever theme
  # Helium wears. Helium's theme extensions are named after the palette label.
  palettes = import ../../home/themes/palettes.nix;
  themes = lib.mapAttrs' (_: p:
    lib.nameValuePair p.label {
      bg = p.accent;
      fg = p.base;
    })
  palettes;

  # The public key fixes the extension ID, which keeps "Allow access to file URLs" across
  # rebuilds. Checked at build time.
  id = "doiabniphbbdjpgckmljbibnbkjffllf";
  key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA670KDMD8tGpA2AA8hgShnHIqC+NJ56iv+iSrsZC3bQ+E3al+IeUDCftINtIsQ2tx6TRBN2m/lsWp85wRtCFaWNkKC6XCa3L7OMjyx9ibz1axHFCN3EgEVmEHSmO86P5hyMp2r5+rhhdjHmQWVvhO3QZsbM5+XojU3sFMY8r/prNYKM+YCX7UKtNZCG3FV4ZrQ+rfP3IkULD1E2PR1lJoG2S0iTF+0iiIkWiJZE3R8miwLE0O8036DiFASY9aKYPsnhQ57fgpCKMXTHKoIAKIAtEt1UfbOoW3FoNhWPUqoxLVWpq1x4VgnEK9jSqvAfIVRWLQ2iwGanE9v6IXGOXmUQIDAQAB";

  manifest = {
    manifest_version = 3;
    name = "Jump Labels";
    description = "Helix-style gw: label what's in view, type a label to focus it. j and k scroll.";
    version = "1.0.0";
    inherit key;
    # management: to see which theme extension is enabled.
    permissions = ["storage" "management"];
    background.service_worker = "background.js";
    content_scripts = [
      {
        matches = ["<all_urls>"];
        js = ["content.js"];
        # Early, so its key listener runs before the page's own.
        run_at = "document_start";
        all_frames = true;
        match_about_blank = true;
        match_origin_as_fallback = true;
      }
    ];
  };
in
  runCommand "helium-jump-labels" {} ''
    derived="$(echo ${key} | base64 -d | sha256sum | cut -c1-32 | tr 0-9a-f a-p)"
    if [ "$derived" != ${id} ]; then
      echo "helium-jump-labels: key gives ID $derived, not ${id}" >&2
      exit 1
    fi

    mkdir $out
    cp ${writeText "manifest.json" (builtins.toJSON manifest)} $out/manifest.json
    cp ${./background.js} $out/background.js
    cp ${replaceVars ./content.js {
      themes = builtins.toJSON themes;
      defaultTheme = builtins.toJSON palettes.rose-pine.label;
    }} $out/content.js
  ''
