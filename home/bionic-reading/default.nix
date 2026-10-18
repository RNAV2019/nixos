# Bionic reading for Helium: bolds the first letters of every word on web pages, and opens
# PDFs in a bundled PDF.js whose text rendering does the same. The toolbar button (Alt+B)
# toggles it everywhere at once. Loaded through --load-extension in ../packages.nix.
{
  pkgs,
  lib,
}: let
  # The public key fixes the extension ID, which keeps its settings across rebuilds and is
  # the origin the PDF.js viewer must accept. Checked at build time.
  id = "pjpjghngicboedaobhkjdhalhadjiobi";
  key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo4NWEXAaLyBEpy1jmbaSgWC/kJSqipvzd4F3bSBi4D2ojzNfTdnaZaqdKhS+JaEJq3b/KcyRWWqcjr6LCbXJLWwrJNQwUZCgUK5zVlTS+C4TAp4BOL7JILrLHzlbwHApJVkd4nXNjF9Yu7DBqBVTt/u0rTfLuZxA8is5ek4imJW8McBXh5dzBzfd8s7bQGLRwQwovoFZytBdLPBfnGrVeCX8t51v36HHLI9qm52MTGI5VGjGrA2Im4UCD6MkTJCy3RT3RT3l+eg/YFfGSrjZ0ARyVaCgDohK9W74qJYV7AVCb+Z5yJfKZcYNBP8LfnsZkvtjRew7/IQRIE9G81bWhwIDAQAB";

  manifest = {
    manifest_version = 3;
    name = "Bionic Reading";
    description = "Bolds the start of every word on web pages and in PDFs.";
    version = "1.0.0";
    inherit key;
    icons = {
      "16" = "icons/on-16.png";
      "32" = "icons/on-32.png";
      "128" = "icons/on-128.png";
    };
    action = {
      default_title = "Bionic reading: off (Alt+B)";
      default_icon = {
        "16" = "icons/off-16.png";
        "32" = "icons/off-32.png";
      };
    };
    commands._execute_action.suggested_key.default = "Alt+B";
    background.service_worker = "background.js";
    permissions = ["storage" "declarativeNetRequestWithHostAccess" "webNavigation"];
    host_permissions = ["<all_urls>"];
    content_scripts = [
      {
        matches = ["<all_urls>"];
        js = ["fixation.js" "content.js"];
        run_at = "document_idle";
        all_frames = true;
        match_about_blank = true;
        match_origin_as_fallback = true;
      }
    ];
    # PDFs embedded in pages are redirected to the viewer inside their frame.
    web_accessible_resources = [
      {
        resources = ["pdfjs/web/viewer.html"];
        matches = ["<all_urls>"];
      }
    ];
    # PDF.js decodes JPEG 2000 and colour profiles with WebAssembly.
    content_security_policy.extension_pages = "script-src 'self' 'wasm-unsafe-eval'; object-src 'self'";
  };

  pdfjs = "${pkgs.pdfjs}/share/pdf.js";

  # Toolbar icon: a filled iris tile when on, an outline when off.
  icon = state: size: let
    r = size / 8.0;
    inset = size / 16.0;
    tile =
      if state == "on"
      then "-fill '#c4a7e7' -stroke none"
      else "-fill none -stroke '#908caa' -strokewidth ${toString (size / 16.0)}";
    text =
      if state == "on"
      then "#191724"
      else "#908caa";
  in ''
    magick -size ${toString size}x${toString size} xc:none \
      ${tile} -draw "roundrectangle ${toString inset},${toString inset} ${toString (size - inset - 1)},${toString (size - inset - 1)} ${toString r},${toString r}" \
      -font ${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans-Bold.ttf -fill '${text}' -stroke none \
      -pointsize ${toString (size * 0.72)} -gravity center -annotate +0+0 B \
      -define png:exclude-chunks=date,time $out/icons/${state}-${toString size}.png
  '';
in
  pkgs.runCommand "helium-bionic-reading" {nativeBuildInputs = [pkgs.imagemagick];} ''
    derived="$(echo ${key} | base64 -d | sha256sum | cut -c1-32 | tr 0-9a-f a-p)"
    if [ "$derived" != ${id} ]; then
      echo "helium-bionic-reading: key gives ID $derived, not ${id}" >&2
      exit 1
    fi

    mkdir -p $out/icons
    cp ${pkgs.writeText "manifest.json" (builtins.toJSON manifest)} $out/manifest.json
    cp ${./background.js} $out/background.js
    cp ${./content.js} $out/content.js
    cp ${./fixation.js} $out/fixation.js
    cp ${./viewer-hook.js} $out/viewer-hook.js
    ${lib.concatMapStrings (state: lib.concatMapStrings (icon state) [16 32 128]) ["on" "off"]}

    cp -r ${pdfjs} $out/pdfjs
    chmod -R u+w $out/pdfjs
    find $out/pdfjs -name '*.map' -delete
    rm $out/pdfjs/web/compressed.tracemonkey-pldi-09.pdf

    # The viewer loads the hook first, and accepts PDFs from any origin (local files included),
    # since the extension's host permissions let it fetch them.
    substituteInPlace $out/pdfjs/web/viewer.html --replace-fail \
      '<script src="../build/pdf.mjs" type="module"></script>' \
      '<script src="../../fixation.js"></script>
    <script src="../../viewer-hook.js"></script>
    <script src="../build/pdf.mjs" type="module"></script>'
    substituteInPlace $out/pdfjs/web/viewer.html --replace-fail \
      'connect-src * blob: data:;' 'connect-src * blob: data: file:;'
    substituteInPlace $out/pdfjs/web/viewer.mjs --replace-fail \
      'const HOSTED_VIEWER_ORIGINS = new Set(["null",' \
      'const HOSTED_VIEWER_ORIGINS = new Set(["chrome-extension://${id}", "null",'
    # Leave Ctrl+S to Helium, which uses it to collapse the tab sidebar; the toolbar button
    # still downloads.
    substituteInPlace $out/pdfjs/web/viewer.mjs --replace-fail \
      '      case 83:
            eventBus.dispatch("download", {
              source: window
            });
            handled = true;
            break;
    ' ""

    # Text rendering: ask the hook which glyphs of each run to bold, and stroke those in the
    # fill colour after filling them. Vertical text is left alone.
    substituteInPlace $out/pdfjs/build/pdf.mjs \
      --replace-fail \
        '    let x = 0,' \
        '    const bionicMarks = vertical ? null : globalThis.bionic?.marks(ctx, glyphs, fontSize / fontSizeScale) ?? null;
        let x = 0,' \
      --replace-fail \
        '          ctx.fillText(character, scaledX, scaledY);' \
        '          ctx.fillText(character, scaledX, scaledY);
              if (bionicMarks?.[i]) globalThis.bionic.embolden(ctx, character, scaledX, scaledY, fontSize / fontSizeScale);' \
      --replace-fail \
        '          this.paintChar(opIdx, character, scaledX, scaledY, patternFillTransform, patternStrokeTransform);' \
        '          this.bionicBold = !!bionicMarks?.[i];
              this.paintChar(opIdx, character, scaledX, scaledY, patternFillTransform, patternStrokeTransform);
              this.bionicBold = false;' \
      --replace-fail \
        '        ctx.fillText(character, x, y);' \
        '        ctx.fillText(character, x, y);
            if (this.bionicBold) globalThis.bionic.embolden(ctx, character, x, y, fontSize);' \
      --replace-fail \
        '          ctx.fill(path);' \
        '          ctx.fill(path);
              if (this.bionicBold) globalThis.bionic.emboldenPath(ctx, path);' \
      --replace-fail \
        '      current.x += x * textHScale;' \
        '      globalThis.bionic?.ended(ctx, x / fontSizeScale);
          current.x += x * textHScale;'
  ''
