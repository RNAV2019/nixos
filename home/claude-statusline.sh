# Claude Code status line.
#
# Mirrors the starship prompt from shell.nix (directory, branch, git status),
# then appends the model, context-window usage as a bar, and the 5h/7d rate
# limits, in the same Rose Pine palette.

input=$(cat)
q() { printf '%s' "$input" | jq -r "$1"; }

cwd=$(q '.workspace.current_dir // .cwd // ""')
model=$(q '.model.display_name // ""')
[ -n "$cwd" ] || cwd=$PWD

# Rose Pine (Moon).
love=$'\033[38;2;235;111;146m'
gold=$'\033[38;2;246;193;119m'
foam=$'\033[38;2;156;207;216m'
iris=$'\033[38;2;196;167;231m'
muted=$'\033[38;2;110;106;134m'
subtle=$'\033[38;2;144;140;170m'
# Starship's own prompt styles.
dir_style=$'\033[1;36m'
in_style=$'\033[1;37m'
branch_style=$'\033[1;35m'
r=$'\033[0m'

sep="${muted} · ${r}"
out=""

# append SEGMENT -- joins segments with the dot separator
append() {
  [ -n "$1" ] || return 0
  [ -n "$out" ] && out+="$sep"
  out+="$1"
}

# Green below 50%, amber below 80%, red above.
severity() {
  if [ "$1" -ge 80 ]; then
    printf '%s' "$love"
  elif [ "$1" -ge 50 ]; then
    printf '%s' "$gold"
  else
    printf '%s' "$foam"
  fi
}

# bar PERCENT WIDTH
bar() {
  local pct=$1 width=$2 filled i acc=""
  filled=$((pct * width / 100))
  # Never show an empty bar for non-zero usage.
  if [ "$pct" -gt 0 ] && [ "$filled" -lt 1 ]; then filled=1; fi
  [ "$filled" -gt "$width" ] && filled=$width
  acc="$(severity "$pct")"
  for ((i = 0; i < filled; i++)); do acc+="▰"; done
  acc+="$muted"
  for ((i = filled; i < width; i++)); do acc+="▱"; done
  printf '%s%s' "$acc" "$r"
}

# --- directory, branch, git status -------------------------------------------

dir=${cwd/#$HOME/\~}
IFS='/' read -ra parts <<<"$dir"
n=${#parts[@]}
# starship: truncation_length = 3
if [ "$n" -gt 3 ]; then
  dir="${parts[n - 3]}/${parts[n - 2]}/${parts[n - 1]}"
fi

prompt="${dir_style}${dir}${r}"

if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
  [ -n "$branch" ] || branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null || true)
  [ -n "$branch" ] && prompt+="${in_style} in ${r}${branch_style}${branch}${r}"

  ahead=0 behind=0 staged=0 modified=0 deleted=0 untracked=0 renamed=0 conflicted=0
  while IFS= read -r entry; do
    case "$entry" in
      '##'*)
        [[ $entry =~ ahead\ ([0-9]+) ]] && ahead=${BASH_REMATCH[1]}
        [[ $entry =~ behind\ ([0-9]+) ]] && behind=${BASH_REMATCH[1]}
        continue
        ;;
    esac
    x=${entry:0:1} y=${entry:1:1}
    if [ "$x$y" = "??" ]; then
      untracked=$((untracked + 1))
      continue
    fi
    if [[ "$x$y" =~ (U|AA|DD) ]]; then
      conflicted=$((conflicted + 1))
      continue
    fi
    case "$x" in
      R) renamed=$((renamed + 1)) ;;
      D) deleted=$((deleted + 1)) ;;
      [MAC]) staged=$((staged + 1)) ;;
    esac
    case "$y" in
      D) deleted=$((deleted + 1)) ;;
      M) modified=$((modified + 1)) ;;
    esac
  done < <(git -C "$cwd" status --porcelain=v1 --branch 2>/dev/null || true)

  gs=""
  [ "$ahead" -gt 0 ] && gs+="${foam}⇡${ahead}${r}"
  [ "$behind" -gt 0 ] && gs+="${gold}⇣${behind}${r}"
  [ "$conflicted" -gt 0 ] && gs+="${love}!${r}"
  [ "$staged" -gt 0 ] && gs+="${foam}+${staged}${r} "
  [ "$deleted" -gt 0 ] && gs+="${love}✗${deleted}${r} "
  [ "$modified" -gt 0 ] && gs+="${gold}!${modified}${r} "
  [ "$renamed" -gt 0 ] && gs+="${iris}»${renamed}${r} "
  [ "$untracked" -gt 0 ] && gs+="${muted}?${untracked}${r} "
  [ -n "$gs" ] && prompt+=" ${gs% }"
fi

append "$prompt"

# --- model, context window, rate limits --------------------------------------

[ -n "$model" ] && append "${subtle}${model}${r}"

ctx=$(q '.context_window.used_percentage // empty')
if [ -n "$ctx" ]; then
  append "${subtle}ctx${r} $(bar "$ctx" 10) $(severity "$ctx")${ctx}%${r}"
fi

# limit LABEL JQ_KEY -> "5h 3%"
limit() {
  local label=$1 key=$2 pct
  pct=$(q ".rate_limits.${key}.used_percentage // empty")
  [ -n "$pct" ] || return 0
  printf '%s%s%s %s%s%%%s' "$subtle" "$label" "$r" "$(severity "$pct")" "$pct" "$r"
}

for pair in "5h:five_hour" "7d:seven_day"; do
  append "$(limit "${pair%%:*}" "${pair##*:}")"
done

printf '%s\n' "$out"
