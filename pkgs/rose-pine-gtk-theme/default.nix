# Dropped from nixpkgs in 2026-08; vendored with only the GTK3/GTK4 assets.
{
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "rose-pine-gtk-theme";
  version = "2.2.0";

  src = fetchFromGitHub {
    owner = "rose-pine";
    repo = "gtk";
    tag = "v${finalAttrs.version}";
    hash = "sha256-vCWs+TOVURl18EdbJr5QAHfB+JX9lYJ3TPO6IklKeFE=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    for n in rose-pine rose-pine-dawn rose-pine-moon; do
      mkdir -p "$out/share/themes/$n/gtk-4.0"
      cp -r "$src/gtk3/$n-gtk"/* "$out/share/themes/$n"
      cp -r "$src/gtk4/$n.css" "$out/share/themes/$n/gtk-4.0/gtk.css"
    done

    runHook postInstall
  '';

  meta.description = "Rosé Pine theme for GTK";
})
