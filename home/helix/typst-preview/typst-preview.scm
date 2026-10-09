(require "helix/editor.scm")
(require "notify/notify.scm")

(provide preview)

;; must match --data-plane-host in the tinymist config (editors.nix)
(define *preview-url* "http://127.0.0.1:23635")

(define (preview-error msg)
  (notify msg #:severity 'error #:title "preview"))

(define (preview-typst-buffer?)
  (let ([path (editor-document->path (editor->doc-id (editor-focus)))])
    (and path (ends-with? path ".typ"))))

;; tinymist starts the server with the language server, so it can lag the buffer
(define (preview-server-up?)
  (let ([proc (~> (command "curl" (list "-s" "-o" "/dev/null" "-w" "%{http_code}"
                                        "--max-time" "1" *preview-url*))
                  with-stdout-piped
                  with-stderr-piped
                  spawn-process)])
    (and (Ok? proc)
         (not (string=? (trim (read-port-to-string (child-stdout (Ok->value proc)))) "000")))))

;;@doc
;; Toggle a Helium window on tinymist's live preview of this Typst buffer.
;; The window closes when Helix exits.
(define (preview)
  (cond
    [(not (preview-typst-buffer?)) (preview-error "Not a Typst buffer")]
    [(not (preview-server-up?)) (preview-error (string-append "No tinymist preview at " *preview-url*))]
    ;; detached through sh so the browser never writes over the TUI, and
    ;; setsid so closing the terminal can't SIGHUP the watcher before cleanup;
    ;; $PPID is this Helix, which the window's lifetime is tied to
    [else (~> (command "sh" (list "-c" (string-append "setsid -f typst-preview-window '" *preview-url*
                                                      "' \"$PPID\" >/dev/null 2>&1")))
              with-stdout-piped
              with-stderr-piped
              spawn-process)
          void]))
