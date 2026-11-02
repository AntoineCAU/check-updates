# check-updates

Finds everything that is out of date on a Mac — macOS, apps, command-line tools — and lets you pick what to update from a checklist. Failed updates are reported, with an optional AI diagnosis.

## Install

```sh
brew install antoinecau/tap/check-updates
```

Run `check-updates` whenever you want. It checks every source in parallel, shows its progress, then opens a checklist in two groups:

- **Automatic** (ticked by default, except major versions): installed right away in your terminal, so you can follow them and type your password when needed;
- **Up to you**: macOS and apps that update themselves — each has an **Open** button for System Settings, the app or its website.

Major versions are tagged **major**, and updates Apple labels as security fixes are tagged **security**. **Ignore** hides a version until a newer one comes out (`check-updates ignored` lists them, `check-updates unignore <name>` brings one back). The daily check only opens the window when something new showed up since the last list.

If an update fails, you get a summary with buttons to open the log or ask an AI CLI (Claude Code, Codex, Gemini…) to diagnose it.

## What it checks

Only what is installed on the Mac is checked.

| Source | How |
|---|---|
| macOS, Safari, Command Line Tools | `softwareupdate --list` (installed from System Settings) |
| Homebrew formulae and casks | `brew outdated --json=v2` |
| Apps installed without Homebrew | version compared with the public [Homebrew cask catalog](https://formulae.brew.sh), otherwise with the app's Sparkle feed |
| App Store | [`mas`](https://github.com/mas-cli/mas), if installed |
| Node.js (nvm), npm and pnpm globals | `nvm`, `npm outdated -g`, `pnpm outdated -g` |
| Python tools | `pipx`, `uv tool` (compared with PyPI) |
| Rust | `rustup check`, `cargo install` binaries (compared with crates.io) |
| Ruby gems, mise, Composer, Oh My Zsh | `gem outdated`, `mise outdated`, `composer`, git |

Nothing is ever installed without you ticking it.

## Commands

```
check-updates                      check now, write the report, then offer the updates
check-updates --list               reopen the list from the last check
check-updates --quiet              check and write the report, no window
check-updates doctor               make sure every part still works on this Mac
check-updates schedule on [HH:MM]  check every day (default 9:30)
check-updates schedule off         stop the daily check
check-updates schedule             show whether the daily check is on
check-updates ignored              list the updates you chose to ignore
check-updates unignore <name>      show an ignored update again (--all for every one)
```

The daily check is off until you turn it on.

Reports are written to `~/Library/Logs/check-updates/latest.md`, settings live in `~/.config/check-updates/config` (terminal, AI CLI, sources to skip).

## Staying reliable

Each parser rejects output it does not recognise: a source whose format changed is reported as **failed** instead of silently showing “up to date”.

- `check-updates doctor` tests every part on your Mac (Python, the checklist window, the cask catalog, each source) — run it after a macOS or Homebrew upgrade.
- CI runs the parser tests and `doctor` against real tools on GitHub's macOS runners every Monday, to catch upstream changes early.

## Adding a source

Drop a file in `libexec/check-updates/sources/NN-name.zsh` defining:

- `src_available` — exit 0 if the tool is installed;
- `src_check` — print one `label<TAB>command` line per update (`#<TAB>text` for a note), exit non-zero if the check failed.

Add a `title_name` entry in `libexec/check-updates/messages.zsh` and a test in `tests/run.zsh`.

## Releasing

Bump `VERSION` in `bin/check-updates`, then push a tag:

```sh
git tag v0.2.0 && git push origin main v0.2.0
```

Within the hour, the tap's workflow copies `packaging/homebrew/check-updates.rb` to the tap with the new archive URL and sha256 (run it right away with `gh workflow run update-check-updates.yml -R AntoineCAU/homebrew-tap`).

## License

MIT
