# Handy, offline speech-to-text that types into the focused window. Its grab can't
# reach Wayland windows, so Hyprland drives it through `dictate` (see desktop.nix).
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Parakeet Unified EN 0.6B, pinned to the revision and checksum in Handy's model
  # catalog. Handy looks in the shared Hugging Face cache, so the file is linked
  # into it under that revision and counts as downloaded.
  model = rec {
    repo = "handy-computer/parakeet-unified-en-0.6b-gguf";
    revision = "7e948f21b7bdbac698d3318db9d350f1096f3b6c";
    file = "parakeet-unified-en-0.6b-Q8_0.gguf";
    id = "${repo}/${file}";
    src = pkgs.fetchurl {
      url = "https://huggingface.co/${repo}/resolve/${revision}/${file}";
      sha256 = "4b50b6dd862bf6e346929aaf4f5eaacec003bfa3f56462d6c874b41ef2f38795";
    };
    cacheDir = ".cache/huggingface/hub/models--${lib.replaceStrings ["/"] ["--"] repo}";
  };

  # Merged into Handy's settings store before each start, so these win over the
  # settings window and everything else stays the app's to change.
  settings = {
    onboarding_completed = true;
    selected_model = model.id;
    app_language = "en-GB";
    log_level = "info";

    # systemd starts it and Nix updates it.
    start_hidden = true;
    autostart_enabled = false;
    update_checks_enabled = false;
    show_whats_new_on_update = false;

    # Handy's own shortcuts can only grab through XWayland, where the defaults
    # (Ctrl+Space, Ctrl+Shift+Space) would be stolen from X11 apps; keys nobody
    # presses keep them harmless (an empty binding resets to the default).
    bindings.transcribe.current_binding = "ctrl+alt+shift+f12";
    bindings.transcribe_with_post_process.current_binding = "ctrl+alt+shift+f11";

    # SUPER+SHIFT+D's dictation is cleaned up by an OpenRouter model with Handy's
    # stock prompt (punctuation, numbers as digits, fillers out, no rewording);
    # SUPER+D's never is. The key is merged in from sops at start; see seedSettings.
    # Mercury 3 was the one cheap model clean on every test case at under a second;
    # DeepSeek V4 Flash, gen-commit's model, dropped or ignored whole transcripts.
    post_process_enabled = true;
    post_process_provider_id = "openrouter";
    post_process_models.openrouter = "inception/mercury-3";
    post_process_selected_prompt_id = "default_improve_transcriptions";

    # Handed to dictate-type below. The overlay can take focus from the window
    # being typed into, and the island's mic mark already shows a recording.
    paste_method = "external_script";
    external_script_path = lib.getExe dictateType;
    overlay_style = "none";
  };

  # Types the transcript with wtype, except into Ghostty. wtype gives the nth
  # distinct character keycode n, and Ghostty reads some of those as the physical
  # key (the 15th as Tab, the 29th as Ctrl), so there it pastes instead and then
  # puts the clipboard back. --sensitive keeps both out of cliphist. The
  # post-processing model sometimes answers with a leading space, so that goes.
  dictateType = pkgs.writeShellApplication {
    name = "dictate-type";
    runtimeInputs = with pkgs; [coreutils hyprland jq wl-clipboard wtype];
    text = ''
      text=$1
      text=''${text#"''${text%%[![:space:]]*}"}
      if ! hyprctl activewindow -j | jq -e '.class // "" | startswith("com.mitchellh.ghostty")' >/dev/null; then
        exec wtype -- "$text"
      fi

      saved=$(mktemp)
      trap 'rm -f "$saved"' EXIT
      type=$(wl-paste --list-types 2>/dev/null | head -n1) || true
      if [[ -n $type ]]; then
        wl-paste --no-newline --type "$type" >"$saved" 2>/dev/null || type=""
      fi

      printf '%s' "$text" | wl-copy --sensitive
      hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "CTRL SHIFT", key = "V" })' >/dev/null
      # Ghostty asks for the selection asynchronously; restoring too soon would
      # paste the old clipboard instead.
      sleep 0.3
      if [[ -n $type ]]; then
        wl-copy --sensitive --type "$type" <"$saved"
      else
        wl-copy --clear
      fi
    '';
  };

  dataDir = "${config.xdg.dataHome}/com.pais.handy";

  # gen-commit's OpenRouter key, decrypted by sops-nix (modules/system/secrets.nix).
  openrouterKey = "${config.xdg.configHome}/gen-commit/api-key";

  # Handy keeps API keys in its store in plain text, so the key is read at start
  # rather than written into the Nix store, and the store is kept private.
  seedSettings = pkgs.writeShellApplication {
    name = "handy-seed-settings";
    runtimeInputs = [pkgs.coreutils pkgs.jq];
    text = ''
      store=${dataDir}/settings_store.json
      mkdir -p ${dataDir}
      [[ -s $store ]] || echo '{"settings": {}}' >"$store"
      key=""
      if [[ -r ${openrouterKey} ]]; then
        key=$(<${openrouterKey})
      else
        echo "handy-seed-settings: ${openrouterKey} not readable, post-processing has no key" >&2
      fi
      umask 077
      jq --slurpfile s ${pkgs.writeText "handy-settings.json" (builtins.toJSON settings)} --arg key "$key" \
        '.settings *= $s[0] | if $key != "" then .settings.post_process_api_keys.openrouter = $key else . end' \
        "$store" >"$store.tmp"
      mv "$store.tmp" "$store"
    '';
  };

  # Tap to start and tap again to stop, or hold and talk and let go. --post-process
  # picks Handy's cleaned-up action for press and release alike, since Handy only
  # stops a recording from the action that started it. A press always toggles; a
  # release after a hold stops only if Handy is capturing, so a press that stopped a
  # recording doesn't start another on release, and nothing can drift out of step
  # with Handy's own state.
  dictate = pkgs.writeShellApplication {
    name = "dictate";
    runtimeInputs = with pkgs; [coreutils handy jq pipewire];
    text = ''
      hold_ms=350
      stamp="''${XDG_RUNTIME_DIR:-/tmp}/dictate-press"

      capturing() {
        pw-dump | jq -e '
          any(.[]; .type == "PipeWire:Interface:Node"
            and .info.props["media.class"] == "Stream/Input/Audio"
            and (.info.props["application.name"] // "" | test("handy"))
            and .info.state == "running")' >/dev/null
      }

      toggle=--toggle-transcription
      if [[ ''${2:-} == --post-process ]]; then
        toggle=--toggle-post-process
      fi

      case "''${1:-}" in
        press)
          date +%s%3N >"$stamp"
          handy "$toggle"
          ;;
        release)
          [[ -f $stamp ]] || exit 0
          held=$(($(date +%s%3N) - $(<"$stamp")))
          rm -f "$stamp"
          if ((held >= hold_ms)) && capturing; then
            handy "$toggle"
          fi
          ;;
        *)
          echo "usage: dictate press|release [--post-process]" >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  home.packages = [pkgs.handy dictate];

  # hf-hub resolves refs/<revision> to a commit, then reads snapshots/<commit>/<file>.
  # The ref is the bare commit with no trailing newline.
  home.file = {
    "${model.cacheDir}/refs/${model.revision}".text = model.revision;
    "${model.cacheDir}/snapshots/${model.revision}/${model.file}".source = model.src;
  };

  # Hidden at login; the window opens from the launcher. There is no tray host, so
  # the icon Handy asks for never shows.
  systemd.user.services.handy = {
    Unit = {
      Description = "Handy speech-to-text";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target" "pipewire.service"];
    };

    Service = {
      ExecStartPre = lib.getExe seedSettings;
      ExecStart = "${lib.getExe pkgs.handy} --start-hidden";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = ["graphical-session.target"];
  };
}
