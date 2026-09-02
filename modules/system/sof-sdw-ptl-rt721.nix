# Speaker, headset and internal mic on this Panther Lake laptop.
#
# The BIOS declares an rt722 on SoundWire link 3 alongside the rt721 and
# rt1320 that are actually fitted. The kernel has no match-table entry for
# rt721, so it falls back to the generic SDCA machine driver, wires the jack
# and speaker onto the absent rt722, and every non-HDMI PCM fails with -ENOLINK.
# See sof-sdw-ptl-rt721.patch for the full write-up.
#
# The fix is a data-only change to snd-soc-acpi-intel-match, which is a module
# (CONFIG_SND_SOC_ACPI_INTEL_MATCH=m), so it is rebuilt on its own against the
# packaged kernel's build tree rather than via boot.kernelPatches. That keeps
# the kernel itself on cache.nixos.org; this derivation takes seconds to build.
#
# Dropped once the entry lands upstream: the build fails loudly if the patch
# stops applying, which is the wanted behaviour on a kernel bump.
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

    # Only sound/soc/intel/common is needed; unpacking the whole tree would
    # cost a gigabyte of I/O for two dozen files.
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

    # The in-tree Makefile is reused as-is: an external module build reads the
    # kernel's auto.conf, so obj-$(CONFIG_SND_SOC_ACPI_INTEL_MATCH) resolves to
    # obj-m and a future kernel adding another -match.c is picked up for free.
    buildPhase = ''
      runHook preBuild
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M="$PWD/sound/soc/intel/common" modules
      runHook postBuild
    '';

    # "updates/" outranks "kernel/" in depmod's default search order, so this
    # shadows the stock module without colliding with it in the buildEnv that
    # aggregateModules uses to assemble /run/current-system/kernel-modules.
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

  # alsa-ucm-conf 1.2.16.1 ships ucm2/sof-soundwire/rt721+rt1320.conf but not the
  # ucm2/codecs/rt721+rt1320/init.conf that sof-soundwire.conf includes for a
  # combined speaker codec name, so UCM fails to import with -ENOENT and
  # WirePlumber falls back to the raw "Pro" profile. Supply the missing file via
  # ALSA_CONFIG_UCM2 rather than an overlay, which would rebuild alsa-lib and
  # every one of its dependents from source.
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

  # The HiFi verb exposes one sink per display-audio PCM whether or not a
  # display is attached. Nothing on this machine outputs over them.
  services.pipewire.wireplumber.extraConfig."51-sof-sdw-no-hdmi" = {
    "monitor.alsa.rules" = [
      {
        matches = [{"node.name" = "~alsa_output\\..*\\.HiFi__HDMI[0-9]+__sink";}];
        actions.update-props."node.disabled" = true;
      }
    ];
  };
}
