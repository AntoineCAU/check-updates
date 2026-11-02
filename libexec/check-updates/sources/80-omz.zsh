# Oh My Zsh
src_available() { [[ -d "${ZSH:-$HOME/.oh-my-zsh}/.git" ]] }
src_check() {
  local dossier="${ZSH:-$HOME/.oh-my-zsh}" retard
  git -C "$dossier" fetch --quiet origin || return 1
  retard=$(git -C "$dossier" rev-list --count 'HEAD..@{u}') || return 1
  (( retard > 0 )) && print -r -- "$(m omz_behind $retard)${T}ZSH=${(q)dossier} zsh ${(q)dossier}/tools/upgrade.sh"
  return 0
}
