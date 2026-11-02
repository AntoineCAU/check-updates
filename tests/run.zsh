#!/bin/zsh
# Tests des sources avec des sorties d'outils enregistrées : chaque outil est simulé par une
# fonction du même nom. Vérifie aussi qu'un format inconnu fait échouer la source.
# Les changements de format réels (nouveau macOS, nouvelle version de brew…) sont détectés
# par « check-updates doctor », que la CI lance chaque semaine.
cd "${0:A:h}/.."
LIB=$PWD/libexec/check-updates T=$'\t'
typeset -A M
source "$LIB/messages.zsh"
m() { printf -- "${M[$1]}" "${@:2}" }
helper() { /usr/bin/python3 -I "$LIB/helpers.py" "$@" }
echecs=0

teste() { # nom, source, simulation (code zsh), sortie attendue (dernière ligne : [code N])
  local obtenu
  obtenu=$( eval "$3"; source "$LIB/sources/$2"; src_check 2>/dev/null; print "[code $?]" )
  if [[ "$obtenu" == "$4" ]]; then
    print -P "%F{green}ok%f   $1"
  else
    print -P "%F{red}FAIL%f $1"; print -r -- "  expected: ${(q+)4}"$'\n'"  got:      ${(q+)obtenu}"
    (( echecs++ ))
  fi
}

REGLAGES="open x-apple.systempreferences:com.apple.Software-Update-Settings.extension"

teste "macos: two updates" 10-macos.zsh 'softwareupdate() { cat <<"EOF"
Software Update Tool

Finding available software
Software Update found the following new or updated software:
* Label: Safari27.2TahoeAuto-27.2
	Title: Safari, Version: 27.2, Size: 250130KiB, Recommended: YES,
* Label: macOS Tahoe 26.7.2-25G332
	Title: macOS Tahoe 26.7.2, Version: 26.7.2, Size: 3868257KiB, Recommended: YES, Action: restart,
EOF
}' "Safari 27.2 (System Settings)$T$REGLAGES
macOS Tahoe 26.7.2 (System Settings)$T$REGLAGES
[code 0]"

teste "macos: nothing new" 10-macos.zsh 'softwareupdate() { print "No new software available." }' "[code 0]"

teste "macos: unknown format fails" 10-macos.zsh 'softwareupdate() { print "* Label: Foo-1.0\n\tName = Foo; Version = 1.0" }' "[code 3]"

teste "brew: formulae and casks" 20-brew.zsh 'brew() { [[ $1 == update ]] && return 0; cat <<"EOF"
{"formulae":[{"name":"gh","installed_versions":["2.60.0"],"current_version":"2.61.0","pinned":false},
{"name":"node","installed_versions":["22.1.0"],"current_version":"23.0.0","pinned":true}],
"casks":[{"name":"ngrok","installed_versions":"3.1.0","current_version":"3.2.0"}]}
EOF
}' "gh 2.60.0 → 2.61.0${T}brew upgrade gh
ngrok 3.1.0 → 3.2.0 (cask)${T}brew upgrade --cask ngrok
[code 0]"

teste "brew: unknown format fails" 20-brew.zsh 'brew() { [[ $1 == update ]] && return 0; print "{\"packages\": []}" }' "[code 3]"

teste "brew: update failure is a note" 20-brew.zsh 'brew() { [[ $1 == update ]] && { print -u2 "Error: homebrew/cask-fonts does not exist!"; return 1 }; print "{\"formulae\":[],\"casks\":[]}" }' \
  "#$T${M[brew_update_failed]} Error: homebrew/cask-fonts does not exist!
[code 0]"

teste "mas: outdated apps" 30-mas.zsh 'commands[mas]=/bin/true; mas() { print "497799835 Xcode (15.0 -> 15.1)\n 409183694  Keynote  (13.1 -> 14.0)" }' \
  "Xcode 15.0 → 15.1${T}mas upgrade 497799835
Keynote 13.1 → 14.0${T}mas upgrade 409183694
[code 0]"

teste "npm: outdated globals" 51-npm.zsh 'npm() { [[ $1 == prefix ]] && { print /tmp; return }; print "{\"npm\":{\"current\":\"11.6.1\",\"wanted\":\"11.21.1\",\"latest\":\"11.21.1\"}}"; return 1 }' \
  "npm 11.6.1 → 11.21.1${T}sudo npm install -g npm@latest
[code 0]"

teste "pnpm: crash is reported" 52-pnpm.zsh 'pnpm() { print " ERROR  ref.startsWith is not a function"; return 1 }' "[code 3]"

teste "rustup: toolchain and self" 63-rustup.zsh 'rustup() { cat <<"EOF"
stable-aarch64-apple-darwin - Update available : 1.80.0 (051478957 2024-07-21) -> 1.81.0 (eeb90cda1 2024-09-04)
nightly-aarch64-apple-darwin - Up to date : 1.83.0-nightly (1bc403daa 2024-10-11)
rustup - Update available : 1.27.0 -> 1.27.1
EOF
}' "stable-aarch64-apple-darwin 1.80.0 → 1.81.0${T}rustup update stable-aarch64-apple-darwin
rustup 1.27.0 → 1.27.1${T}rustup self update
[code 0]"

teste "uv: tools" 61-uv.zsh 'uv() { print "ruff v0.0.1\n- ruff\nzzz-not-on-pypi-check-updates v1.0.0\n- zzz" }' \
  "ruff 0.0.1 → $(curl -fsS --max-time 10 https://pypi.org/pypi/ruff/json | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["info"]["version"])')${T}uv tool upgrade ruff
[code 0]"

teste "omz: behind" 80-omz.zsh 'git() { [[ $3 == rev-list ]] && print 51; return 0 }' \
  "Oh My Zsh (51 commits behind)${T}ZSH=$HOME/.oh-my-zsh zsh $HOME/.oh-my-zsh/tools/upgrade.sh
[code 0]"

for json attendu in \
  '[]' '[code 0]' \
  'PHP Deprecated: foo
{"installed":[{"name":"laravel/installer","version":"v5.0.0","latest":"v5.9.0"}]}' "laravel/installer v5.0.0 → v5.9.0${T}composer global update laravel/installer -W
[code 0]" \
  '{"locked":[]}' '[code 3]'; do
  obtenu=$(print -r -- "$json" | helper composer 2>/dev/null; print "[code $?]")
  [[ "$obtenu" == "$attendu" ]] && print -P "%F{green}ok%f   composer: ${json[1,20]//$'\n'/ }…" || { print -P "%F{red}FAIL%f composer: $json → $obtenu"; (( echecs++ )) }
done

# Fonctions du script principal (chargé sans lancer de commande)
egal() { # nom, attendu, obtenu
  if [[ "$3" == "$2" ]]; then print -P "%F{green}ok%f   $1"
  else print -P "%F{red}FAIL%f $1"; print -r -- "  expected: ${(q+)2}"$'\n'"  got:      ${(q+)3}"; (( echecs++ )); fi
}
vrai() { if eval "$2"; then egal "$1" vrai vrai; else egal "$1" vrai faux; fi }
faux() { if eval "$2"; then egal "$1" faux vrai; else egal "$1" faux faux; fi }
(
  echecs=0
  source bin/check-updates
  egal "split: versions and generic hint" "Docker${T}4.83.0 → 4.97.0" "$(decouper "Docker 4.83.0 → 4.97.0 (${M[open_app]})")"
  egal "split: specific note kept" "Node${T}v24.11.0 → v24.22.2 · same major" "$(decouper "Node v24.11.0 → v24.22.2 (same major)")"
  egal "split: version without arrow" "macOS Tahoe${T}26.7.2" "$(decouper "macOS Tahoe 26.7.2 (${M[settings]})")"
  egal "key: name and target version" "Docker 4.97.0" "$(cle "Docker 4.83.0 → 4.97.0 (${M[open_app]})")"
  egal "key: macOS" "macOS 27.2" "$(cle "macOS 27.2 (${M[settings]})")"
  vrai "major: 23 → 26" 'majeure "DBeaver 23.2.1 → 26.2.4"'
  faux "major: 4.83 → 4.97" 'majeure "Docker 4.83.0 → 4.97.0"'
  faux "major: v24 → v24" 'majeure "Node v24.11.0 → v24.22.2 (same major)"'
  vrai "major: macOS above the installed one" 'majeure "macOS 999.1 (${M[settings]})"'
  faux "major: macOS same as installed" 'majeure "macOS $(sw_vers -productVersion) (${M[settings]})"'
  egal "tag: security" security "$(etiquette "Background Security Improvement 26.5.1 (${M[settings]})" "open x")"
  egal "tag: major for automatic updates" major "$(etiquette "node 22.1.0 → 24.0.0" "brew upgrade node")"
  egal "tag: none for self-updating apps" "" "$(etiquette "Firefox 157.0.1 → 159.0 (${M[open_app]})" "open -a Firefox")"
  exit $echecs
) || (( echecs += $? ))

if helper selftest >/dev/null; then print -P "%F{green}ok%f   helpers selftest (versions, Sparkle, cask catalog)"; else print -P "%F{red}FAIL%f helpers selftest"; (( echecs++ )); fi

print
(( echecs )) && { print -P "%F{red}$echecs test(s) failed%f"; exit 1 }
print -P "%F{green}All tests passed%f"
