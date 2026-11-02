# TeX Live (MacTeX, BasicTeX) : paquets en retard, ou nouvelle édition annuelle à installer
src_available() { (( $+commands[tlmgr] )) }
src_check() {
  local sortie annee prefixe=""
  # …/texlive/2025/bin/universal-darwin/tlmgr : sudo si l'installation appartient à root
  [[ -n "$commands[tlmgr]" && -w "${commands[tlmgr]:A:h:h:h}" ]] || prefixe="sudo "
  annee=$(tlmgr --version 2>/dev/null | sed -nE 's/.*version ([0-9]{4}).*/\1/p' | head -1)
  sortie=$(tlmgr --machine-readable update --list 2>&1)
  if [[ "$sortie" =~ 'Local TeX Live \(([0-9]+)\) is older than remote repository \(([0-9]+)\)' ]]; then
    print -r -- "TeX Live $match[1] → $match[2] (${M[open_site]})${T}open https://www.tug.org/mactex/"
    return 0
  fi
  print -r -- "$sortie" | CU_PREFIX=$prefixe helper tlmgr "${annee:-?}"
}
