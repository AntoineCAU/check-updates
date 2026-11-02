# User-facing texts (printf formats)
M=(
  locale "en_US.UTF-8"

  report_title "Available updates"
  up_to_date "_Up to date._"
  report_ignored "(ignored)"
  up_to_date_short "up to date"
  check_failed_short "check failed"
  checking "Checking for updates…"
  still_checking "%s Still checking:"
  count_one "1 update"
  count_many "%d updates"
  available_one "1 update available"
  available_many "%d updates available"
  check_incomplete "Some checks failed"
  check_failed "Check failed (exit code %s)"
  all_good_title "Everything is up to date"
  all_good "Nothing to update."
  sources_failed "Could not check: %s"
  doctor_hint "Run “check-updates doctor” for details."

  later "Later"
  ok "OK"
  open_report "Open Report"
  opening_list "Opening the list…"
  nothing_selected "Nothing selected. Reopen the list any time: check-updates --list"
  nothing_new "Nothing new since the last list. See it again: check-updates --list"
  now_ignored "Ignored: %s (undo: check-updates unignore <name>)\n"
  ignored_title "Ignored updates (they come back when a newer version is out):"
  ignored_none "No ignored updates."
  unignored "No longer ignored: %s\n"
  unignored_all "No more ignored updates."
  unignore_usage "Usage: check-updates unignore <name> | --all\n"
  close "Close"
  pick_hint "Select the updates to install."
  pick_hint_manual "Open each one to update it."
  update_btn "Update"
  done_btn "Done"
  open_btn "Open"
  opened "Opened"
  ignore_btn "Ignore"
  ignored_btn "Ignored"
  nothing_pending "No pending updates."
  group_auto "Automatic"
  group_auto_hint "installed in a terminal"
  group_manual "Up to you"
  group_manual_hint "update them in System Settings, the app or its website"

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
  run_all_ok "Done: %d installed."
  run_some_failed "%d installed, %d failed:"
  open_log "Open log"
  ask_ai "Diagnose with %s"
  ai_prompt "Some updates run by check-updates failed on my Mac (macOS %s). Here are the failed steps and the end of their output (home folder, user and machine names, and secrets are masked):

%s
Explain the likely cause of each failure and suggest a fix. Do not run any command without my approval."
  ai_confirm_title "Send the error to %s?"
  ai_confirm_text "%s will receive the end of the output of the failed steps, nothing else. Your home folder, user name, machine name and known secret formats (passwords, tokens, keys, credentials in URLs) are masked first — an unusual secret could still get through, so check it if in doubt."
  ai_show "Show What's Sent"
  ai_send "Send"
  cancel "Cancel"
  done "Done, you can close this window."

  installed "Daily check on, every day at %02d:%02d.\nTurn it off with: check-updates schedule off\n"
  uninstalled "Daily check off.\nCheck any time with: check-updates\nTurn it back on with: check-updates schedule on [HH:MM]\n"
  schedule_on "Daily check on, every day at %02d:%02d.\n"
  schedule_off "Daily check off. Turn it on with: check-updates schedule on [HH:MM]"
  bad_time "Invalid time: %s (expected HH:MM, e.g. 9:30 or 18:00)\n"

  doctor_env "Environment"
  doctor_picker "Windows (AppleScript / AppKit)"
  doctor_catalog "Homebrew app catalog and parsers"
  doctor_sources "Sources"
  doctor_absent "not installed"
  doctor_skipped "skipped (SKIP in settings)"
  doctor_schedule "Schedule"
  doctor_agent_ok "checks every day at %02d:%02d"
  doctor_agent_ko "last run failed (exit code %s), see %s"
  doctor_not_installed "daily check off (turn it on: check-updates schedule on [HH:MM])"
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
  check-updates schedule on [HH:MM]  check every day (default 9:30)
  check-updates schedule off         stop the daily check
  check-updates schedule             show whether the daily check is on
  check-updates ignored              list the updates you chose to ignore
  check-updates unignore <name>      show an ignored update again (--all for every one)

Reports: ~/Library/Logs/check-updates/latest.md
Settings: ~/.config/check-updates/config"
)
