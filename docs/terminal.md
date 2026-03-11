# Terminal Environment & Multiplexing

This guide provides an overview of the terminal stack managed by `nix-nexus`, focusing on practical usage of `tmux`, `kitty`, and `bash` for day-to-day engineering tasks.

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

#### System Clipboard Integration
When you copy text in Tmux's copy mode, it is automatically synchronized with your **system clipboard**, allowing you to paste it into other applications (like a browser or chat) immediately.

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
