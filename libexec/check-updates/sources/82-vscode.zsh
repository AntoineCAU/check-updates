# Extensions de Visual Studio Code (comparées au Marketplace)
code_cli() {
  local app="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  if (( $+commands[code] )); then print -r -- $commands[code]; elif [[ -x "$app" ]]; then print -r -- "$app"; fi
}
src_available() { [[ -n "$(code_cli)" ]] }
src_check() {
  local cli=$(code_cli) version liste
  version=$("$cli" --version 2>&1 | head -1)
  [[ "$version" == <->.<->* ]] || { print -u2 -r -- "code --version: $version"; return 3 }
  liste=$("$cli" --list-extensions --show-versions 2>&1) || { print -u2 -r -- "$liste"; return 1 }
  print -r -- "$liste" | CU_CODE=$cli CU_CODE_VERSION=$version helper vscode
}
