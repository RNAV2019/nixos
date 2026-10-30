{...}: {
  # Face unlock for the Quickshell lock screen, and nothing else.
  #
  # Howdy's NixOS module defaults security.pam.howdy.enable to services.howdy.enable, and
  # every PAM service (login, sudo, polkit, quickshell-password) inherits that. Switching it
  # off here and opting one service in below is what keeps the face out of everything else.
  services.howdy = {
    enable = true;
    settings = {
      video = {
        # The IR camera ("Integrated Camera: Integrated I", video2/video3). By-path survives
        # the video nodes being renumbered.
        device_path = "/dev/v4l/by-path/pci-0000:00:14.0-usb-0:4:1.2-video-index0";
        # Howdy's default is 3.5; lower is stricter. 3.0 trades a few more misses for fewer
        # false accepts, which suits a lock that falls back to the password anyway.
        certainty = 3.0;
        # Seconds before Howdy gives up; the lock then shows "Not recognised".
        timeout = 5;
      };
      core = {
        # The lock draws its own ring and notice.
        detection_notice = false;
        timeout_notice = false;
        # "off": Howdy never asks for the password itself, so the face conversation stays
        # separate from the password one.
        workaround = "off";
      };
    };
  };
  security.pam.howdy.enable = false;

  # Used only by the shell's second PamContext (home/quickshell/Lock/FaceUnlock.qml). Face
  # alone is "sufficient"; when it fails nothing else in the stack can succeed, so the
  # password conversation (quickshell-password, untouched) is the only other way in.
  security.pam.services.quickshell-face = {
    unixAuth = false;
    nodelay = true;
    howdy = {
      enable = true;
      control = "sufficient";
    };
  };

  # Turns the IR emitter on at boot and after every resume, using the configuration that
  # `sudo linux-enable-ir-emitter configure --no-gui` saves (see README). Until that has run
  # once, the service only logs that the camera is unconfigured. The unit also owns
  # /var/lib and /var/log/linux-enable-ir-emitter, where configure saves and logs.
  services.linux-enable-ir-emitter = {
    enable = true;
    # The IR camera's capture node ("Integrated Camera: Integrated I"); video3 is its metadata.
    device = "video2";
  };
}
