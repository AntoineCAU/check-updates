# Extensions de GitHub CLI (gh extension install …)
src_available() { (( $+commands[gh] )) && [[ -n "$(gh extension list 2>/dev/null)" ]] }
src_check() {
  local sortie
  sortie=$(gh extension upgrade --all --dry-run 2>&1) || { print -u2 -r -- "$sortie"; return 1 }
  print -r -- "$sortie" | helper gh
}
