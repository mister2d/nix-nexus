# Terminal Environment & Multiplexing

This guide covers the terminal stack managed by `nix-nexus`. It shows how to
use `tmux`, `herdr`, `kitty`, and `bash` for daily engineering tasks.

---

## Tmux: The Multiplexer

Tmux manages multiple terminal sessions in one window. Your processes keep
running even if your connection drops.

### Core Concepts: Sessions, Windows, and Panes
- **Session**: A collection of windows. You can detach from a session and re-attach later.
- **Window**: A full-screen view within a session (like a browser tab).
- **Pane**: A division of a window (split vertically or horizontally).

### The Prefix Key
To run any `tmux` command, first press the **Prefix** key.
In this configuration, the Prefix is **`Ctrl + a`**. The tables below use
`Prefix` to mean this key combination.

---

### Session Management
Sessions are the top-level container for your work.

| Task | Command / Keybinding | Description |
|:--- |:--- |:--- |
| **Start New Session** | `tmux new -s <name>` | Starts a named session. |
| **List Sessions** | `tmux ls` | Shows all active sessions. |
| **Attach to Session** | `tmux attach -t <name>` | Re-enters a specific session. |
| **Detach** | `Prefix` + `d` | Leaves the session running in the background. |
| **Rename Session** | `Prefix` + `$` | Give the current session a descriptive name. |
| **Kill Session** | `tmux kill-session -t <name>` | Terminates the session and all its processes. |

---

### Working with Windows & Panes
These bindings handle navigation and layout.

| Task | Keybinding | Notes |
|:--- |:--- |:--- |
| **Horizontal Split** | `Prefix` + `|` | Creates a new pane to the right. |
| **Vertical Split** | `Prefix` + `-` | Creates a new pane below. |
| **Navigate Panes** | `Prefix` + `h/j/k/l` | Move focus (Left, Down, Up, Right). |
| **Swap Panes** | `Prefix` + `H/J/K/L` | Move the current pane in that direction. |
| **Switch Windows** | `Shift + ←/→` | Cycle through windows (tabs) instantly. |
| **New Window** | `Prefix` + `c` | Creates a fresh window in the same session. |
| **Close Pane** | `Ctrl + d` or `exit` | Closes the current pane/shell. |
| **Zoom Pane** | `Prefix` + `z` | Toggles the current pane to full-screen. |

> **Tip:** New panes and windows always open in the **same directory** as
> your active pane.

---

### Copy Mode & Buffers
Copy mode lets you scroll back through history and copy text without a mouse.

1. **Enter Copy Mode**: Press `Prefix` + `[`.
2. **Navigate**: Use arrow keys or Vim motions (`j`, `k`, `h`, `l`, `Ctrl-u`, `Ctrl-d`).
3. **Start Selection**: Press `Space` or `v`.
4. **Copy to Buffer**: Press `Enter` or `y`.
5. **Paste**: Press `Prefix` + `]`.

#### Mouse & System Clipboard Integration
The mouse is enabled. The scroll wheel or trackpad scrolls the pane's
scrollback. This enters copy mode automatically and leaves it once you reach
the bottom. Full-screen programs like `less` and `vim` still receive scroll
events directly. Right-click pastes the tmux buffer.

Copies go to your **system clipboard** through OSC 52. This applies to `y` in
copy mode and to a mouse drag-selection alike. The terminal emulator
receives them even when tmux runs on a remote host over SSH.

To bypass tmux and use the terminal emulator's own selection, hold `Shift`
while dragging. This works in both Kitty and Ghostty.

#### Saving History to a File
To capture a large amount of logs from a pane:
1. `Prefix` + `:` (enters command mode).
2. Type `capture-pane -S -10000` (captures last 10,000 lines).
3. Type `save-buffer output.log` followed by `Enter`.

---

### Session Sharing (Pair Programming)
Tmux runs as a server. Multiple users, or the same user from different
machines, can attach to the same session.

- **To Share**: Have the second user SSH into the same machine and run `tmux attach -t <name>`.
- **Observer Mode**: To join a session without changing the primary user's window size, use:
  ```bash
  tmux attach -t <name> -r  # Read-only (optional)
  ```

---

## Herdr: The Agent Multiplexer

`herdr` is a second multiplexer. Use it when the panes run **coding agents**
instead of shells. It has the same shape as tmux, with a leader key and
persistent sessions you detach from and re-attach to. It also recognizes
Claude Code, Codex, opencode, and pi in a pane and shows what each one is
doing.

Use tmux for ordinary terminal work. Reach for herdr when you run more than
one agent at once. They are alternatives, **not layers**. Both take
`Ctrl + a`, so the inner one never sees the leader.

### Concepts

| Herdr | tmux equivalent |
|:--- |:--- |
| **Workspace** | Session — one per repo, task, or investigation. |
| **Tab** | Window. |
| **Pane** | Pane. |

### Keybindings

The bindings come from `lib/keymap.nix`, the same file tmux renders from. Every
binding below behaves identically in both.

| Task | Keybinding | Notes |
|:--- |:--- |:--- |
| **Horizontal Split** | `Prefix` + `\|` | New pane to the right. |
| **Vertical Split** | `Prefix` + `-` | New pane below. |
| **Navigate Panes** | `Prefix` + `h/j/k/l` | Move focus. |
| **Swap Panes** | `Prefix` + `H/J/K/L` | Move the current pane. |
| **Switch Tabs** | `Shift + ←/→` | Cycle tabs. |
| **Jump to Tab** | `Prefix` + `1`…`9` | |
| **New Tab** | `Prefix` + `c` | |
| **Rename Tab** | `Prefix` + `,` | |
| **Close Pane** | `Prefix` + `x` | |
| **Zoom Pane** | `Prefix` + `z` | |
| **Copy Mode** | `Prefix` + `[` | |
| **Detach** | `Prefix` + `d` | Session keeps running; `herdr` re-attaches. |
| **Toggle Sidebar** | `Prefix` + `b` | The agent status panel. Herdr-only. |
| **New Worktree** | `Prefix` + `Shift + g` | Git worktree as a workspace. Herdr-only. |

> **One binding per action.** tmux binds window navigation twice — `Prefix` + `p`/`n`
> and `Shift + ←/→`. Herdr allows only one binding per action, so it uses the
> `Shift + arrow` form. `Prefix` + `p`/`n` do nothing there.

### Agents

Every pane running a recognized agent appears in the sidebar with a live
state: `working`, `blocked`, `done`, or `idle`. Claude Code is wired up
declaratively. A `SessionStart` hook reports its session id, so after
`herdr server stop` the pane resumes the same conversation instead of
starting fresh.

Agents can also drive herdr themselves over its socket API. This is what
makes herdr useful for running several agents at once:

```bash
herdr agent list                          # what is running, and its state
herdr agent prompt <name> "..." --wait    # send work to another agent, block until done
herdr agent wait <name> --until done
herdr pane read <id> --source recent      # read another pane's output
herdr worktree create --branch feat/x     # branch -> its own workspace
herdr integration status                  # which agent integrations are installed
```

Inside a herdr pane, `HERDR_ENV=1` is set. This tells an agent it can use any
of the commands above.

### Configuration

`~/.config/herdr/config.toml` is generated by Nix from
`modules/user/herdr-home.nix` and is read-only. Colors follow the terminal
palette, so herdr inherits whatever theme the host already sets. Edit the
Nix module and rebuild rather than the file. Note that `herdr.dev`'s
documentation runs ahead of the packaged version. Run options copied from
the website through `herdr config check` first.

---

## Kitty Terminal
Kitty is the underlying terminal emulator. Tmux handles the multiplexing.
Kitty handles the rendering.

- **Standard Copy/Paste**: Use `Ctrl+Shift+c` and `Ctrl+Shift+v`.
- **Scrollback Search**: Use `Ctrl+Shift+h` to open the entire scrollback in a pager (useful for searching large outputs).
- **Ligatures**: Enabled by default for cleaner code rendering (e.g., `->` becomes an arrow).

---

## Bash Environment
The shell prompt keeps you informed about your environment.

### Prompt Breakdown
`[14:30] user@host ~/path (branch *) ➜`
- **`[14:30]`**: Current time (useful for log correlation).
- **`(branch *)`**: Shows your current Git branch. The `*` indicates uncommitted changes.
- **`➜`**: Turns **Green** if the last command succeeded, **Red** if it failed.

### Common Aliases
- `ll` / `lrt`: Long-format list sorted by time (newest at bottom).
- `tup` / `tstatus`: Tailscale management for secure cluster access.
- `tv`: Fuzzy finder for files and command history.
