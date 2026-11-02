# Gems Ruby installées par l'utilisateur. Ni le Ruby système de macOS, ni un Ruby
# installé par Homebrew comme simple dépendance, ni les gems livrées avec Ruby.
src_available() {
  (( $+commands[gem] )) && [[ "$commands[gem]" != /usr/bin/gem ]] || return 1
  local ruby=${commands[ruby]:A}
  [[ "$ruby" == */Cellar/ruby/* ]] && ! grep -q '"installed_on_request": *true' "${ruby%/bin/ruby}/INSTALL_RECEIPT.json" 2>/dev/null && return 1
  return 0
}
src_check() {
  local sortie prefixe="" dossier=$(gem environment gemdir) livrees
  [[ -w "$dossier" ]] || prefixe="sudo "
  # Gems livrées avec Ruby (par défaut + « bundled ») : elles suivent les mises à jour de Ruby
  livrees=" ${(j: :)${${(f)$(ls "$dossier/specifications/default" 2>/dev/null)}%-*}} $(ruby -e 'require "bundled_gems"; puts Gem::BUNDLED_GEMS::SINCE.keys.join(" ")' 2>/dev/null) "
  sortie=$(gem outdated 2>&1) || { print -u2 -r -- "$sortie"; return 1 }
  # « rake (13.0.6 < 13.2.1) »
  print -r -- "$sortie" | sed -nE "s/^([^ ]+) \(([^ ]+) < ([^ ]+)\)$/\1 \2 → \3${T}${prefixe}gem update \1/p" \
    | while IFS= read -r l; do [[ "$livrees" == *" ${l%% *} "* ]] || print -r -- "$l"; done
  return 0
}
