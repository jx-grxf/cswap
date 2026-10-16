# How CSwap works

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

## Claude Desktop

Claude Desktop keeps its login, chats and settings in one data folder, `~/Library/Application Support/Claude`, and only one instance runs per folder. CSwap starts further instances with Electron's `--user-data-dir` switch, one folder per account: `~/Library/Application Support/Claude-cswap-<name>`. Each folder logs in once and stays logged in. (`CLAUDE_USER_DATA_DIR` would be the documented switch, but signed builds of Claude Desktop ignore it.)

A Desktop folder belongs to the account whose claude.ai login it holds. CSwap compares the account id Claude Desktop records in `config.json` with the one Claude Code stores in each account's `.claude.json`, so your existing Desktop folder shows up under whichever account is logged in there, even if that isn't `main`.

`claude_desktop_config.json` can't be shared through a symlink: Claude Desktop replaces the file when it saves, which turns the link into a copy. A new folder starts with a copy of your normal config, and every later start merges `mcpServers` from the normal config in, while that instance is closed. Extensions are installed per folder.

Once a second instance runs, the Dock icon only brings an existing window to the front and won't start your normal profile. Open each account from CSwap or with `cswap desktop <name>` instead. Quitting from CSwap sends the same signal as Quit in the Dock.

