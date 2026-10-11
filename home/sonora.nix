# Sonora, the native music streaming client from sonorahq.org. Settings are left to
# the app: anything set here is re-merged into settings.json on every launch.
{sonora, ...}: {
  imports = [sonora.homeManagerModules.default];

  programs.sonora.enable = true;
}
