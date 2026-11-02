# Textes en français (formats printf)
M=(
  locale "fr_FR.UTF-8"

  report_title "Mises à jour disponibles"
  up_to_date "_À jour._"
  check_failed "Vérification impossible (code %s)"
  n_updates "%d mise(s) à jour disponible(s)"
  all_good_title "Machine à jour"
  all_good "Tout est à jour."
  sources_failed "⚠ Vérification impossible pour : %s"
  doctor_hint "Lance « check-updates doctor » pour le détail."

  later "Plus tard"
  report "Rapport"
  show "Voir"
  close "Fermer"
  pick_title "Mises à jour disponibles"
  pick_hint "Coche celles à lancer :"
  update_btn "Mettre à jour"
  cancel "Annuler"
  nothing_pending "Aucune mise à jour en attente."
  group_auto "Installées automatiquement (dans le terminal)"
  group_manual "À faire toi-même : ouvre les Réglages, l'app ou le site"
  auto_manual_count "%d automatique(s), %d à faire toi-même"

  settings "Réglages Système"
  node_same "même majeure, devient la version par défaut"
  node_lts "installée à côté, défaut inchangé"
  open_app "ouvre l'app pour qu'elle se mette à jour"
  open_site "ouvre le site de l'éditeur"
  mas_hint "Des apps viennent de l'App Store : installe mas (brew install mas) pour les vérifier aussi."
  brew_update_failed "brew update a échoué : le catalogue Homebrew n'est peut-être pas à jour."
  omz_behind "Oh My Zsh (%s commits de retard)"

  title_macos "macOS"
  title_brew "Homebrew"
  title_mas "App Store"
  title_apps "Applications"
  title_node "Node (nvm)"
  title_npm "npm (global)"
  title_pnpm "pnpm (global)"
  title_pipx "pipx"
  title_uv "uv (outils)"
  title_cargo "Cargo"
  title_rustup "Rust (rustup)"
  title_gem "RubyGems"
  title_mise "mise"
  title_composer "Composer"
  title_omz "Oh My Zsh"

  step_ok "OK"
  step_failed "Échec (code %d)"
  rechecking "Nouvelle vérification…"
  run_all_ok "%d mise(s) à jour réussie(s)."
  run_some_failed "%d mise(s) à jour réussie(s), %d en échec :"
  open_log "Ouvrir le journal"
  ask_ai "Diagnostiquer avec %s"
  ai_prompt "Des mises à jour lancées par check-updates ont échoué sur mon Mac (macOS %s). Journal complet : %s

Étapes en échec et fin de leur sortie :

%s
Explique la cause probable de chaque échec et propose une correction. Ne lance aucune commande sans mon accord."
  done "Terminé, tu peux fermer cette fenêtre."

  installed "Vérification quotidienne installée à %02dh%02d.\nRéglages : %s (relance « check-updates install » après les avoir modifiés).\n"
  uninstalled "Vérification quotidienne désinstallée.\nLa config (%s) et les rapports (%s) sont conservés.\n"

  doctor_env "Environnement"
  doctor_picker "Fenêtres (AppleScript / AppKit)"
  doctor_catalog "Catalogue des apps Homebrew et analyseurs"
  doctor_sources "Sources"
  doctor_absent "non installé"
  doctor_skipped "ignoré (SKIP dans la config)"
  doctor_found "%d mise(s) à jour"
  doctor_schedule "Planification"
  doctor_agent_ok "vérification chaque jour à %02dh%02d"
  doctor_agent_ko "dernier lancement en échec (code %s), voir %s"
  doctor_not_installed "pas de vérification quotidienne : lance « check-updates install »"
  doctor_ai "diagnostic des échecs avec : %s"
  doctor_no_ai "aucune CLI d'IA trouvée (claude, codex, gemini) pour diagnostiquer les échecs"
  doctor_ok "Tout fonctionne."
  doctor_ko "Au moins une brique est en échec (détail ci-dessus)."

  unknown_cmd "Commande inconnue : %s (voir check-updates --help)\n"
  help "check-updates — repère ce qui n'est pas à jour sur ce Mac et aide à le mettre à jour.

Usage :
  check-updates            vérifie, écrit le rapport, puis propose les mises à jour
  check-updates --list     rouvre la liste de la dernière vérification
  check-updates --quiet    vérifie et écrit le rapport, sans fenêtre
  check-updates doctor     vérifie que chaque brique fonctionne sur ce Mac
  check-updates install    lance la vérification chaque jour (LaunchAgent)
  check-updates uninstall  arrête la vérification quotidienne

Rapports : ~/Library/Logs/check-updates/latest.md
Réglages : ~/.config/check-updates/config"
)
