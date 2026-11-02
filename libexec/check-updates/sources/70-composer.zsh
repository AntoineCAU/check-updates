# Composer (PHP) : l'exécutable lui-même et les paquets globaux
src_available() { (( $+commands[composer] )) }
src_check() {
  local exe=$commands[composer] actuel dernier prefixe=""
  composer() { php -d error_reporting=0 -d display_errors=0 "$exe" "$@" }

  # Installé hors Homebrew (sinon « brew outdated » s'en charge)
  if [[ "${exe:A}" != */Cellar/* ]]; then
    actuel=$(composer --version 2>/dev/null | sed -n 's/^Composer version \([^ ]*\).*/\1/p')
    dernier=$(curl -fsS --max-time 10 https://getcomposer.org/versions | /usr/bin/python3 -I -c 'import json,sys; print(json.load(sys.stdin)["stable"][0]["version"])') \
      || { print -u2 "getcomposer.org/versions: unreachable or unexpected format"; return 3 }
    [[ -w "${exe:A:h}" ]] || prefixe="sudo " # self-update remplace le fichier dans son dossier
    [[ -n "$actuel" && "$actuel" != "$dernier" ]] && print -r -- "composer $actuel → $dernier${T}${prefixe}composer self-update"
  fi

  [[ -f "$(composer global config home 2>/dev/null)/composer.json" ]] || return 0
  composer global outdated --direct --format=json 2>/dev/null | helper composer
}
