# App Store, via mas (https://github.com/mas-cli/mas)
src_available() { (( $+commands[mas] )) || [[ -n $(print -l /Applications/*.app/Contents/_MASReceipt(N[1])) ]] }
src_check() {
  if (( ! $+commands[mas] )); then print -r -- "#$T${M[mas_hint]}"; return 0; fi
  local sortie
  sortie=$(mas outdated 2>&1) || { print -u2 -r -- "$sortie"; return 1 }
  # « 497799835 Xcode (15.0 -> 15.1) »
  print -r -- "$sortie" | sed -nE "s/^ *([0-9]+) +(.*[^ ]) +\((.*) -> (.*)\)$/\2 \3 → \4${T}mas upgrade \1/p"
  return 0
}
