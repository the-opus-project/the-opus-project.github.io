# OPUS@Home for Mac

OPUS@Home is a menu bar app that contributes to The OPUS Project with your own Codex or Claude Code subscription. Turn it on, and while your Mac is charging it runs your agent in the background. Each run handles one piece of work from [AGENTS.md](../AGENTS.md), such as a new transcription attempt, a reconciliation, or a work from `wanted.txt`, and opens a pull request from your GitHub account.

## Install

1. Open Terminal and run:

   ```sh
   curl -fsSL https://the-opus-project.github.io/mac/install.sh | sh
   ```

   This downloads the [latest build](https://github.com/the-opus-project/the-opus-project.github.io/releases/tag/opus-at-home-latest), puts **OPUS@Home** in Applications and opens it. Run it again to update.
2. Or install by hand: download `OPUS-at-Home.zip` from the latest build, unzip it and move **OPUS@Home** to Applications. The app is not notarized yet, so macOS blocks the first launch of a browser download. Open **System Settings > Privacy & Security** and click **Open Anyway**.
3. Click the music note in the menu bar. In **Settings → Agent**, choose **Codex** or **Claude Code**.
4. Under **Setup needed**, choose **Run setup…** to install missing tools in Terminal, or **Copy setup prompt** to give the whole task to a local coding agent. Both use the same checks. Setup guides you through the selected agent’s sign-in and requests GitHub sign-in when pull requests are enabled. Complete any browser sign-in or macOS installer dialog that opens.
5. When setup passes, switch OPUS@Home on in the menu.

macOS 14 or later is required.

## Screenshots

These screenshots were captured on a macOS runner with simulated agent sign-in and usage.

| Menu bar | Settings |
| --- | --- |
| [First launch](screenshots/01-menu-first-launch.png) | [First launch](screenshots/02-settings-first-launch-top.png) · [Setup checks](screenshots/02-settings-first-launch-bottom.png) |
| [Saving weekly quota](screenshots/03-menu-saving-quota.png) | [Ready](screenshots/04-settings-ready-top.png) · [Tools](screenshots/04-settings-ready-bottom.png) |
| [Too close to reset](screenshots/05-menu-reset-too-close.png) | [Weekly cap](screenshots/08-settings-anytime-top.png) · [Tools](screenshots/08-settings-anytime-bottom.png) |
| [Running](screenshots/06-menu-running.png) · [After a run](screenshots/07-menu-after-run.png) | [Claude Code](screenshots/10-claude-ready-top.png) · [Tools](screenshots/10-claude-ready-bottom.png) |
| [Claude Code setup](screenshots/09-claude-setup.png) | |

## When it runs

All conditions can be changed in **Settings**:

- **Only while charging** (on by default). If you unplug, the current run stops and its partial work is discarded.
- **Only after N minutes idle** (off by default).
- **Usage limits.** By default it uses only quota that would otherwise go unused: it starts only in the last 5 hours before your weekly reset and keeps starting new runs, one pull request each, until the weekly or 5-hour limit reaches 98%. Alternatively, it can run any time up to a weekly cap you choose, such as 50%, and pause when the 5-hour limit reaches its own cap (90% by default).

It reads your remaining usage from Codex (`codex app-server`) or from Claude Code's sign-in, and checks again every 5 minutes during a run. A run stops when weekly usage reaches 98% (or your cap in "any time" mode), when the 5-hour limit reaches its cap, or when the agent reports its limit is reached. That way it never moves on to paid Codex credits or extra usage. Usage-based API keys report no weekly limit, so use the "any time" mode with them.

Nothing runs past a weekly reset: a run ends 2 minutes before the reset, and no run starts in the last 15 minutes. Each run also has a time limit (120 minutes by default). After a run that produced no pull request, it waits 10 minutes before trying again. While a run is active, the Mac does not go to sleep.

Everything OPUS@Home keeps is in one folder, `~/Library/Application Support/OPUS@Home` (the **Folder** button opens it): `repo` (its clone), `work` (scans, rendered PDFs and other scratch files, emptied before each run), `logs`, `settings.json` and `history.json`. Codex and Claude Code still keep their own session transcripts in their usual places.

## What a run does

1. Updates its own copy of the repository in `~/Library/Application Support/OPUS@Home/repo`. Your other clones are never touched.
2. Lists pieces that already have open pull requests, or that you worked on before, and tells the agent to skip them. Steps 1, 2 and 3 must come from different contributors.
3. Runs the agent without supervision:
   - **Codex:** `codex exec --sandbox workspace-write` with network access, so it can download scans.
   - **Claude Code:** `claude -p --permission-mode bypassPermissions`. Claude Code runs commands without asking, so use it only on a Mac where that is acceptable.
4. Keeps only LilyPond files and `metadata.json` under `pieces/`, plus `wanted.txt` and the regenerated `catalog.json`, so pull requests contain scores only. It checks that the agent wrote the `Source`, `Step` and `Model` lines.
5. Commits the work, pushes it to your fork (created on the first run), and opens a pull request. GitHub runs the full score check.

The **Log** button opens the latest run's full transcript. Recent runs and their pull requests are listed in the menu.

## Command line

The app binary also works from Terminal, which is useful for testing:

```sh
"/Applications/OPUS@Home.app/Contents/MacOS/OPUSAtHome" --setup-prompt --agent claude
"/Applications/OPUS@Home.app/Contents/MacOS/OPUSAtHome" --setup --agent claude
"/Applications/OPUS@Home.app/Contents/MacOS/OPUSAtHome" --status
"/Applications/OPUS@Home.app/Contents/MacOS/OPUSAtHome" --run-once --no-pr --agent codex
```

`--status` shows setup, power state, current usage, and whether a run would start now. `--run-once` ignores the schedule. With `--no-pr`, the work is committed only on a local branch.

## Build

On a Mac with Xcode or the Command Line Tools:

```sh
mac/build.sh
```

This produces `mac/dist/OPUS-at-Home.zip`, a universal app signed with an ad-hoc signature. The `opus-at-home` workflow builds, tests and screenshots the app on every change. On `main`, it publishes the `opus-at-home-latest` release.
