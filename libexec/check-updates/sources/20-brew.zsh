# Homebrew : formules et casks installés par brew
src_available() { (( $+commands[brew] )) }
src_check() {
  local json erreur code nom commande
  if ! erreur=$(brew update --quiet 2>&1 >/dev/null); then
    print -r -- "#$T${M[brew_update_failed]} $(print -r -- "$erreur" | grep -m1 '^Error:')"
  fi
  json=$(brew outdated --json=v2) || return 1
  # Descriptions et dépendances des formules installées, pour dire dans la liste à quoi
  # sert chacune (facultatif : sans elles, la liste n'a simplement pas de description)
  print -r -- "$json" | helper brew <(brew info --json=v2 --installed 2>/dev/null)
  code=$?
  # Formules et casks des taps non approuvés : brew outdated les saute sans rien dire, on
  # le signale plutôt que de les laisser passer pour à jour (facultatif, comme brew info)
  helper brew_untrusted <(brew tap-info --installed --json 2>/dev/null) <(brew trust --json=v1 2>/dev/null) \
    <(brew list --formula --full-name 2>/dev/null) <(brew list --cask --full-name 2>/dev/null) 2>/dev/null |
    while IFS=$T read -r nom commande; do
      print -r -- "#$T$(m brew_untrusted "${nom:t}" "$commande")"
    done
  return $code
}
