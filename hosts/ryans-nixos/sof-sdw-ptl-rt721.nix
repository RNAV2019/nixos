# Kernel lacks an rt721+rt1320 match entry (see patch), breaking speaker/headset/mic.
# Only this module rebuilds; drop once upstream or the build fails when the patch stops applying.
{
  config,
  lib,
  pkgs,
  ...
}: let
  kernel = config.boot.kernelPackages.kernel;

  snd-soc-acpi-intel-match-rt721 = pkgs.stdenv.mkDerivation {
    pname = "snd-soc-acpi-intel-match-rt721";
    inherit (kernel) version;
    src = kernel.src;

    nativeBuildInputs = kernel.moduleBuildDependencies;
    hardeningDisable = ["pic" "format"];
    enableParallelBuilding = true;

    # Only unpack sound/soc/intel/common, not the whole tree.
    unpackPhase = ''
      runHook preUnpack
      mkdir source
      if [ -d "$src" ]; then
        cp -r "$src"/sound/soc/intel/common source/sound-soc-intel-common
        mkdir -p source/sound/soc/intel
        mv source/sound-soc-intel-common source/sound/soc/intel/common
      else
        tar -xf "$src" -C source --strip-components=1 \
          --wildcards '*/sound/soc/intel/common/*'
      fi
      chmod -R u+w source
      cd source
      runHook postUnpack
    '';

    patches = [./sof-sdw-ptl-rt721.patch];

    # Reuses the in-tree Makefile; the kernel's auto.conf makes it build as obj-m.
    buildPhase = ''
      runHook preBuild
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M="$PWD/sound/soc/intel/common" modules
      runHook postBuild
    '';

    # depmod prefers updates/ over kernel/, so this shadows the stock module.
    installPhase = ''
      runHook preInstall
      install -Dm444 sound/soc/intel/common/snd-soc-acpi-intel-match.ko \
        "$out/lib/modules/${kernel.modDirVersion}/updates/snd-soc-acpi-intel-match.ko"
      runHook postInstall
    '';

    meta = {
      description = "Intel ACPI match tables patched for rt721+rt1320 SoundWire on Panther Lake";
      license = lib.licenses.gpl2Only;
      platforms = ["x86_64-linux"];
    };
  };

  # alsa-ucm-conf 1.2.16.1 lacks codecs/rt721+rt1320/init.conf, so UCM fails and
  # WirePlumber falls back to "Pro"; injected via ALSA_CONFIG_UCM2, avoiding an alsa-lib rebuild.
  ucm2 = pkgs.runCommand "alsa-ucm-conf-rt721-rt1320" {} ''
    cp -r ${pkgs.alsa-ucm-conf}/share/alsa/ucm2 "$out"
    chmod -R u+w "$out"
    mkdir -p "$out/codecs/rt721+rt1320"
    cat > "$out/codecs/rt721+rt1320/init.conf" <<'EOF'
    # rt721 (companion amp) + rt1320 (smart amp) on one SoundWire link.
    Include.rt721.File "/codecs/rt721/init.conf"
    Include.rt1320.File "/codecs/rt1320/init.conf"
    EOF
  '';
in {
  boot.extraModulePackages = [snd-soc-acpi-intel-match-rt721];

  environment.sessionVariables.ALSA_CONFIG_UCM2 = "${ucm2}";
  systemd.user.services.pipewire.environment.ALSA_CONFIG_UCM2 = "${ucm2}";
  systemd.user.services.wireplumber.environment.ALSA_CONFIG_UCM2 = "${ucm2}";

  # Hide the always-present, unused HDMI sinks.
  services.pipewire.wireplumber.extraConfig."51-sof-sdw-no-hdmi" = {
    "monitor.alsa.rules" = [
      {
        matches = [{"node.name" = "~alsa_output\\..*\\.HiFi__HDMI[0-9]+__sink";}];
        actions.update-props."node.disabled" = true;
      }
    ];
  };
}
