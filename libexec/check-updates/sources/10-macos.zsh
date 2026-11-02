# Mises à jour système : macOS, Safari, Command Line Tools… (installées depuis les Réglages)
src_available() { (( $+commands[softwareupdate] )) }
src_check() {
  local sortie lignes
  sortie=$(softwareupdate --list 2>&1) || { print -u2 -r -- "$sortie"; return 1 }
  lignes=$(print -r -- "$sortie" | awk -F', ' -v t="$T" -v reglages="${M[settings]}" '/Title:/ {
    titre = $1; sub(/.*Title: /, "", titre); v = $2; sub(/Version: /, "", v)
    if (index(titre, v) == 0) titre = titre " " v
    print titre " (" reglages ")" t "open x-apple.systempreferences:com.apple.Software-Update-Settings.extension" }')
  if [[ -z "$lignes" ]] && print -r -- "$sortie" | grep -q '^\* Label:'; then
    print -u2 -r -- "softwareupdate: updates listed but not parsed (format changed?)"$'\n'"$sortie"
    return 3
  fi
  [[ -n "$lignes" ]] && print -r -- "$lignes"
  return 0
}
