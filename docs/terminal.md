# Terminal Environment & Multiplexing

This guide provides an overview of the terminal stack managed by `nix-nexus`, focusing on practical usage of `tmux`, `herdr`, `kitty`, and `bash` for day-to-day engineering tasks.

---

## 🔳 Tmux: The Multiplexer

Tmux allows you to manage multiple terminal sessions within a single window and, most importantly, keeps your processes running even if your connection drops.

### Core Concepts: Sessions, Windows, and Panes
- **Session**: A collection of windows. You can detach from a session and re-attach later.
- **Window**: A full-screen view within a session (like a browser tab).
- **Pane**: A division of a window (split vertically or horizontally).

### The Prefix Key
To execute any `tmux` command, you first press the **Prefix** key. 
In this configuration, the Prefix is **`Ctrl + a`** (standardized for ergonomics). In the tables below, `Prefix` refers to this key combination.

---

### 🚀 Session Management
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

### 🪟 Working with Windows & Panes
Navigation and layout are handled through these primary bindings.

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

> **Tip:** Our configuration ensures that new panes and windows always open in the **same directory** as your active pane.

---

### 📋 Copy Mode & Buffers
Copy mode allows you to scroll back through history and copy text without using a mouse.

1. **Enter Copy Mode**: Press `Prefix` + `[`.
2. **Navigate**: Use arrow keys or Vim motions (`j`, `k`, `h`, `l`, `Ctrl-u`, `Ctrl-d`).
3. **Start Selection**: Press `Space` or `v`.
4. **Copy to Buffer**: Press `Enter` or `y`.
5. **Paste**: Press `Prefix` + `]`.

#### Mouse & System Clipboard Integration
The mouse is enabled: the scroll wheel or trackpad scrolls the pane's scrollback (entering copy mode automatically, and leaving it once you reach the bottom), and full-screen programs like `less` and `vim` still receive scroll events themselves. Right-click pastes the tmux buffer.

Copies — whether from `y` in copy mode or a mouse drag-selection — are sent to your **system clipboard** via OSC 52, so the terminal emulator receives them even when tmux is running on a remote host over SSH.

To bypass tmux and use the terminal emulator's own selection instead, hold `Shift` while dragging. This works in both Kitty and Ghostty.

#### Saving History to a File
If you need to capture a large amount of logs from a pane:
1. `Prefix` + `:` (enters command mode).
2. Type `capture-pane -S -10000` (captures last 10,000 lines).
3. Type `save-buffer output.log` followed by `Enter`.

---

### 🤝 Session Sharing (Pair Programming)
Because Tmux runs as a server, multiple users (or the same user from different machines) can attach to the same session.

- **To Share**: Simply have the second user SSH into the same machine and run `tmux attach -t <name>`.
- **Observer Mode**: If you want to join a session without interfering with the primary user's window size, use:
  ```bash
  tmux attach -t <name> -r  # Read-only (optional)
  ```

---

## 🐑 Herdr: The Agent Multiplexer

`herdr` is a second multiplexer, used when the panes are running **coding agents**
rather than shells. It has the same shape as tmux — a leader key, persistent
sessions you detach from and re-attach to — but it also recognises Claude Code,
Codex, opencode and pi in a pane and shows what each one is doing.

Use tmux for ordinary terminal work; reach for herdr when you are running more
than one agent at once. They are alternatives, **not layers** — both take
`Ctrl + a`, so the inner one never sees the leader.

### Concepts

| Herdr | tmux equivalent |
|:--- |:--- |
| **Workspace** | Session — one per repo, task, or investigation. |
| **Tab** | Window. |
| **Pane** | Pane. |

### Keybindings

The bindings come from `lib/keymap.nix`, the same file tmux renders from, so
everything below behaves identically in both.

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
> *and* `Shift + ←/→`. Herdr allows only one binding per action, so it gets the
> `Shift + arrow` form and `Prefix` + `p`/`n` do nothing there.

### Agents

Every pane running a recognised agent appears in the sidebar with a live state:
`working`, `blocked`, `done`, or `idle`. Claude Code is wired up declaratively —
a `SessionStart` hook reports its session id — so after `herdr server stop` the
pane resumes the same conversation rather than starting fresh.

Agents can also drive herdr themselves over its socket API, which is what makes
it useful for running several at once:

```bash
herdr agent list                          # what is running, and its state
herdr agent prompt <name> "..." --wait    # send work to another agent, block until done
herdr agent wait <name> --until done
herdr pane read <id> --source recent      # read another pane's output
herdr worktree create --branch feat/x     # branch -> its own workspace
herdr integration status                  # which agent integrations are installed
```

Inside a herdr pane `HERDR_ENV=1` is set, which is how an agent knows it can use
any of the above.

### Configuration

`~/.config/herdr/config.toml` is generated by Nix from
`modules/user/herdr-home.nix` and is read-only. Colours follow the terminal
palette, so herdr inherits whatever the host's theme already sets. Edit the Nix
module and rebuild rather than the file — and note that `herdr.dev`'s
documentation runs ahead of the packaged version, so options copied from the
website should be run through `herdr config check` first.

---

## 🎨 Kitty Terminal
Kitty is the underlying terminal emulator. While Tmux handles the multiplexing, Kitty handles the rendering.

- **Standard Copy/Paste**: Use `Ctrl+Shift+c` and `Ctrl+Shift+v`.
- **Scrollback Search**: Use `Ctrl+Shift+h` to open the entire scrollback in a pager (useful for searching large outputs).
- **Ligatures**: Enabled by default for cleaner code rendering (e.g., `->` becomes an arrow).

---

## 🐚 Bash Environment
The shell prompt is designed to keep you informed about your environment.

### Prompt Breakdown
`[14:30] user@host ~/path (branch *) ➜`
- **`[14:30]`**: Current time (useful for log correlation).
- **`(branch *)`**: Shows your current Git branch. The `*` indicates uncommitted changes.
- **`➜`**: Turns **Green** if the last command succeeded, **Red** if it failed.

### Common Aliases
- `ll` / `lrt`: Long-format list sorted by time (newest at bottom).
- `tup` / `tstatus`: Tailscale management for secure cluster access.
- `tv`: Fuzzy finder for files and command history.
