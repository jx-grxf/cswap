<div align="center">

<img src="Sources/CSwapBar/Resources/AppLogo.png" alt="CSwap app icon" width="112">

# CSwap

A macOS menu bar app and the `cswap` command for running several Claude Code accounts on one Mac. Each account stays logged in, shows its live usage, and a running session moves to another account with `/swap`.

[![CI](https://github.com/jx-grxf/cswap/actions/workflows/ci.yml/badge.svg)](https://github.com/jx-grxf/cswap/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/jx-grxf/cswap?label=release)](https://github.com/jx-grxf/cswap/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-111111)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[Download](https://github.com/jx-grxf/cswap/releases/latest) · [Release notes](release-notes/) · [Contributing](CONTRIBUTING.md)

</div>

> [!TIP]
> Built for the moment the 5-hour limit hits in the middle of a task and you have a second account with quota left. Type `/swap`, and two seconds later the same conversation continues on the other account in the same terminal tab.

## What it does

**Accounts**

- Every account gets its own Claude Code configuration folder (`CLAUDE_CONFIG_DIR`), the setup Anthropic [documents for multiple accounts](https://code.claude.com/docs/en/authentication#log-in-with-multiple-accounts). Each one logs in once and stays logged in.
- Accounts run side by side: work in one terminal, private in another.
- Settings, skills, plugins, hooks, agents, commands, memory and transcripts are shared with your normal `~/.claude`. User MCP servers and per-project trust follow every account.
- Remote Control and claude.ai connectors work in every account, because each one uses a normal claude.ai login.
- CSwap never writes, refreshes or copies a login. It only reads the current access token to ask for usage.

**Switching**

- `/swap` inside a running session ends it and resumes the same conversation (`--resume`) with another account, in the same tab. It works when the current account is already out of quota, because the command runs before anything reaches the model.
- **Move to …** next to a session in the menu bar does the same from outside.
- `cswap use work` or a click in the menu bar sets the account that new `claude` sessions start with.
- When the default account hits its 5-hour or weekly limit, new sessions start with the account that has the most quota left. You can turn this off.

**Menu bar app**

- 5-hour, weekly and per-model usage for every account, with reset times.
- Running sessions per account, busy or idle, with their project folder.
- Add an account, log one in again, open Claude Code with it, or show its folder in Finder.
- Optional: the 5-hour usage and the default account's name next to the menu bar icon.
- A warning when two accounts are logged in to the same claude.ai account.
- Follows `cswap` live. A new account, default, login or session shows up within a second.
- Starts at login, updates itself through Sparkle, with a Stable and a Beta channel.

## Install

1. Download `CSwap-<version>.zip` from the [latest release](https://github.com/jx-grxf/cswap/releases/latest), unzip it and move **CSwap.app** to `/Applications`. The app is signed with a Developer ID and notarized.
2. Open it. A gauge icon appears in the menu bar.
3. Click **Set Up** in the popover, or run the guided setup in a terminal:

   ```sh
   /Applications/CSwap.app/Contents/MacOS/cswap setup
   ```

   Setup links `cswap` into `~/.local/bin`, adds one line to your shell startup file, installs the `/swap` command into `~/.claude/commands` and walks you through logging in your accounts.
4. Open a new terminal tab so the shell picks up the change.

**Requirements:** macOS 14 or later, [Claude Code](https://code.claude.com) installed, zsh or bash (including the bash 3.2 macOS ships). New windows open in Ghostty when it is installed, Terminal.app otherwise.

### Upgrading from Claude Swap Bar 1.x

Your `~/.claude` login becomes the `main` account. Add other accounts again with `cswap add`; the 1.x account list isn't imported. Run `cswap setup` once and delete the old `ClaudeSwapBar.app`. Setups that used `cseat` keep working: `cswap setup` migrates the shell line and keeps `cseat` as an alias.

## Using the CLI

Your normal `~/.claude` login is the `main` account. Add a second one:

```sh
cswap add work --email you@company.com
```

This creates the account and opens Claude Code's login screen. The browser authorizes whichever claude.ai account it is signed in to, so switch accounts there first or paste the link into a private window. `cswap` warns when the login doesn't match `--email`.

Then run `cswap` without arguments to see every account:

```text
$ cswap
  main     you@example.com Pro
           5h ████░░░░░░░░░░░░░░░░  18%  resets in 3h 54m
           7d █████████████████░░░  83%  resets in 2d 7h
● work     you@company.com Max  default  2 running
           5h ██████████████░░░░░░  71%  resets in 1h 12m
           7d ███████████░░░░░░░░░  57%  resets in 4d 3h
```

The dot marks the default account, the one plain `claude` starts.

### Commands

| Command | What it does |
|---|---|
| `cswap` | Show every account with its usage |
| `cswap work [args…]` | Start Claude Code with the `work` account; arguments pass through to `claude` |
| `cswap work --bp` | Same, with `--dangerously-skip-permissions` |
| `claude [args…]` | Start the default account |
| `cswap add <name> [--email a]` | Create an account and log it in |
| `cswap login <name>` | Log an account in again |
| `cswap use <name>` | Make it the default for new sessions |
| `cswap best` | Make the account with the most quota left the default |
| `cswap remove <name>` | Delete an account and its login; shared data stays |
| `/swap [account]` | Inside a session: continue it with another account |
| `cswap sessions` | List running sessions per account |
| `cswap move <name> --pid <pid>` | Move a running session from outside it |
| `cswap setup` | One-time guided setup; safe to run again |
| `cswap doctor` | Check the setup and every account |
| `cswap sync` | Re-link shared settings, skills and memory |
| `cswap version` | Print the version |

`/swap` without an account continues on the default account, or, if the session already runs there, on the logged-in account with the most quota left.

> [!IMPORTANT]
> Don't use `/login` inside a session to change accounts. It replaces the login of the account that session belongs to. Use `/swap`.

## Using the menu bar app

Click the gauge icon to open the popover.

- **Click an account** to make it the default for new sessions. **Best Quota** picks the account with the most quota left.
- **Right-click an account** to open Claude Code with it, log it in again, show its folder or remove it.
- **Move to …** next to a running session continues it on another account.
- **＋** adds an account and opens its login.
- **Settings** (gear icon) sets the refresh interval, the automatic default switch, launch at login, what the menu bar icon shows and the update channel.

## How it works

Accounts other than `main` live in `~/.cswap/<name>`, and `cswap <name>` starts Claude Code with `CLAUDE_CONFIG_DIR` pointing there. Claude Code then stores that account's login in its own Keychain item, so logins never collide.

| | Shared with `~/.claude` (symlink) | Own per account |
|---|---|---|
| Files | `settings.json`, `keybindings.json`, `statusline.sh`, top-level `*.md` | `.claude.json`, `history.jsonl` |
| Folders | `projects`, `skills`, `plugins`, `hooks`, `agents`, `commands`, `plans`, `tasks`, `todos`, `themes`, `file-history`, `output-styles` | `sessions`, caches, logs |
| Login | — | Keychain item `Claude Code-credentials-<hash>` |

On every start, new shared items are linked, and `mcpServers` plus per-project trust, allowed tools and MCP servers from the main `.claude.json` are merged in. The merge takes Claude Code's own advisory lock.

**`/swap` and Move.** The shell integration wraps `claude` and `cswap <account>` in a small loop. `/swap` runs `cswap move` while Claude Code expands the command. It leaves a note for the loop and ends the session's process, and the loop resumes the conversation in the other account. Transcripts are shared, so nothing is lost. A session started without the shell integration continues in a new terminal window in the same project folder.

**Usage.** CSwap reads each account's access token from the Keychain and asks Anthropic's usage endpoint. That endpoint allows roughly 30 requests per hour per account, so the app and `cswap` share one cache, poll every 5 minutes by default and back off on rate limits. An account whose token has expired shows as idle until Claude Code uses it again. Refreshing the token from outside would spend Claude Code's single-use refresh token and log the account out, which is why CSwap leaves it alone.

**Why no hot-swap of one login.** Tools that copy one shared login back and forth eventually log you out: Claude Code's refresh tokens are single-use, so a copied login goes stale the moment a running session refreshes it. Separate folders avoid that entirely.

Claude Desktop and claude.ai in the browser aren't affected. Use separate browser profiles for those.

## Uninstall

```sh
cswap remove <name>          # for each extra account; removes its login
rm ~/.local/bin/cswap
rm -rf ~/.cswap
```

Then delete the `cswap` lines from your shell startup file, `~/.claude/commands/swap.md` and `/Applications/CSwap.app`. Your `~/.claude` stays as it was.

## Development

```sh
git clone https://github.com/jx-grxf/cswap.git
cd cswap
swift build                          # compile everything
./script/build_and_run.sh            # build CSwap.app and launch it
./build-app.sh                       # ad-hoc signed; set SIGN_IDENTITY for Developer ID
```

[CONTRIBUTING.md](CONTRIBUTING.md) covers the layout, testing without touching your real accounts, and the release process. Issues and pull requests are welcome.

## License

[MIT](LICENSE) © Johannes Grof

CSwap is an independent project, not affiliated with or endorsed by Anthropic. Claude and Claude Code are trademarks of Anthropic, PBC.
