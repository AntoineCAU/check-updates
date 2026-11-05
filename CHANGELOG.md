# Changelog

## 0.4.0

- Homebrew updates show what they are (“Mozilla CA certificate store”) right under their name.
- Dependencies, the libraries Homebrew installed for your other tools, get their own group, folded into one **Update all** line; **Show** lists each one with the tools that use it (“used by git, php”).
- Fix: clicking **Later** in a list opened by the daily check made `doctor` report that the last run failed.

## 0.3.0

- New sources: Bun and Deno (installed with their own script), TeX Live (`tlmgr`), GitHub CLI extensions and VS Code extensions (stable versions compatible with your VS Code).
- Offline: in a terminal, check-updates says so right away; the daily check waits up to 30 minutes for the network (the Mac often wakes up before the Wi-Fi), then skips that day without a window full of errors.
- Clicking a notification no longer opens Script Editor: notifications come from a small check-updates app built on your Mac, and clicking “nothing new” reopens the list. macOS asks once whether it may send notifications.
- After a Homebrew update, `brew cleanup` runs and shows the freed space (`BREW_CLEANUP=no` in the settings to turn it off).
- `check-updates history` lists what was updated and when; update logs are kept for a year.
- `doctor` also checks the notifications and the internet connection.

## 0.2.3

- AI diagnosis sends a cleaned-up copy of the failed steps only: home folder, user and machine names, and known secret formats (credentials in URLs, bearer tokens, GitHub/npm/OpenAI/Anthropic/AWS/Slack/Stripe keys, `password=`, `token=`…) are masked.
- A window says what will be sent before anything goes out, with **Show What's Sent**, **Cancel** and **Send**.

## 0.2.2

- Security: fixes a command injection through update feeds. A crafted version in a Sparkle feed (some are served over plain HTTP) could add a pre-ticked “automatic” update running its own command.
- Remote versions must look like versions, labels and commands are stripped of control characters, and only well-formed lines become actions.
- Feeds and vendor websites are limited to `http(s)`, responses are size-limited, and feeds with a DTD are refused.

## 0.2.1

- Each source shows its result as soon as it finishes, with a line listing the ones still running.

## 0.2.0

- About 3× faster: every source is checked in parallel.
- **major** tag on major versions (not ticked by default), **security** tag when Apple labels an update as a security fix.
- **Ignore** hides a version until a newer one is out (`check-updates ignored`, `check-updates unignore <name>`).
- The daily check only opens the window when something new showed up.

## 0.1.5

- The list and the failure summary are real windows: no more empty icon space, buttons at the bottom right, Return and Escape work.

## 0.1.4

- Updates you install yourself (macOS, self-updating apps) have an **Open** button instead of a checkbox; with nothing to tick, the window just shows **Done**.

## 0.1.3

- The checklist opens directly, with names and versions in columns and automatic updates ticked by default.
- Progress is shown in the terminal, and updates started from a terminal run in it.

## 0.1.2

- The daily check is explicitly optional: `check-updates schedule on [HH:MM]`, `schedule off`, `schedule`.

## 0.1.1

- Everything is in English, whatever the Mac's language.

## 0.1.0

- First release.
