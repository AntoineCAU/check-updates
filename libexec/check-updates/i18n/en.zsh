# English texts (printf formats)
M=(
  locale "en_US.UTF-8"

  report_title "Available updates"
  up_to_date "_Up to date._"
  check_failed "Check failed (exit code %s)"
  n_updates "%d update(s) available"
  all_good_title "Everything is up to date"
  all_good "Nothing to update."
  sources_failed "⚠ Could not check: %s"
  doctor_hint "Run “check-updates doctor” for details."

  later "Later"
  report "Report"
  show "Show"
  close "Close"
  pick_title "Available updates"
  pick_hint "Tick the ones to install:"
  update_btn "Update"
  cancel "Cancel"
  nothing_pending "No pending updates."
  group_auto "Installed automatically (in a terminal)"
  group_manual "Up to you: opens System Settings, the app or the website"
  auto_manual_count "%d automatic, %d up to you"

  settings "System Settings"
  node_same "same major, becomes the default"
  node_lts "installed alongside, default unchanged"
  open_app "opens the app so it updates itself"
  open_site "opens the vendor's website"
  mas_hint "Some apps come from the App Store: install mas (brew install mas) to check them too."
  brew_update_failed "brew update failed: the Homebrew catalog may be stale."
  omz_behind "Oh My Zsh (%s commits behind)"

  title_macos "macOS"
  title_brew "Homebrew"
  title_mas "App Store"
  title_apps "Applications"
  title_node "Node (nvm)"
  title_npm "npm (global)"
  title_pnpm "pnpm (global)"
  title_pipx "pipx"
  title_uv "uv (tools)"
  title_cargo "Cargo"
  title_rustup "Rust (rustup)"
  title_gem "RubyGems"
  title_mise "mise"
  title_composer "Composer"
  title_omz "Oh My Zsh"

  step_ok "OK"
  step_failed "Failed (exit code %d)"
  rechecking "Checking again…"
  run_all_ok "%d update(s) installed."
  run_some_failed "%d update(s) installed, %d failed:"
  open_log "Open log"
  ask_ai "Diagnose with %s"
  ai_prompt "Some updates run by check-updates failed on my Mac (macOS %s). Full log: %s

Failed steps and the end of their output:

%s
Explain the likely cause of each failure and suggest a fix. Do not run any command without my approval."
  done "Done, you can close this window."

  installed "Daily check installed at %02d:%02d.\nSettings: %s (run “check-updates install” again after editing them).\n"
  uninstalled "Daily check uninstalled.\nSettings (%s) and reports (%s) were kept.\n"

  doctor_env "Environment"
  doctor_picker "Windows (AppleScript / AppKit)"
  doctor_catalog "Homebrew app catalog and parsers"
  doctor_sources "Sources"
  doctor_absent "not installed"
  doctor_skipped "skipped (SKIP in settings)"
  doctor_found "%d update(s)"
  doctor_schedule "Schedule"
  doctor_agent_ok "checks every day at %02d:%02d"
  doctor_agent_ko "last run failed (exit code %s), see %s"
  doctor_not_installed "no daily check: run “check-updates install”"
  doctor_ai "failures diagnosed with: %s"
  doctor_no_ai "no AI CLI found (claude, codex, gemini) to diagnose failures"
  doctor_ok "Everything works."
  doctor_ko "At least one part is failing (see above)."

  unknown_cmd "Unknown command: %s (see check-updates --help)\n"
  help "check-updates — finds what is out of date on this Mac and helps you update it.

Usage:
  check-updates            check, write the report, then offer the updates
  check-updates --list     reopen the list from the last check
  check-updates --quiet    check and write the report, no window
  check-updates doctor     make sure every part still works on this Mac
  check-updates install    check every day (LaunchAgent)
  check-updates uninstall  stop the daily check

Reports: ~/Library/Logs/check-updates/latest.md
Settings: ~/.config/check-updates/config"
)
