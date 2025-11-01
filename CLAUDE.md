# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

autobahn.nvim is a Neovim plugin that manages multi-agent coding sessions. It spawns coding agents (like Claude Code CLI) in isolated VCS workspaces (git worktrees or jujutsu workspaces) and manages their lifecycle from within Neovim.

**Primary Dependency**: snacks.nvim (for modern UI and pickers). Legacy nui.nvim support available via `ui = "nui"` config.

## Architecture

### Core Flow
1. User creates session → VCS backend creates isolated workspace → Agent process spawns in workspace → Output streams to Neovim buffer
2. Session state persists to `~/.local/share/nvim/autobahn-sessions.json`
3. Each session has independent buffer, job process, and workspace

### Key Modules

**UI Layer** (`lua/autobahn/ui/`):
- `snacks.lua`: Modern dashboard using snacks.nvim's win API (default)
- `form.lua`: Session creation form using snacks picker + vim.ui.input
- `popup.lua`: Legacy UI using nui.nvim (fallback)
- `dashboard.lua`: Split dashboard view (legacy)
- Session history renders as interactive list with virtual text metadata
- Uses `Snacks.win()` with custom `autobahn_history` style
- Form uses `Snacks.picker.pick()` for selections (branch, mode, auto-accept)

**Session Management** (`lua/autobahn/session.lua`):
- In-memory state store with sessions dictionary
- Session lifecycle: IDLE → RUNNING → COMPLETED/ERROR
- Persistence layer saves/loads state from JSON
- Does NOT manage VCS or processes directly

**Agent Process** (`lua/autobahn/agent/process.lua`):
- Spawns agent CLI via `vim.fn.jobstart` with stdout/stderr handlers
- Parses stream-json output format to extract session IDs, costs, messages
- Interactive mode: waits for `claude_session_id` from first response, then uses `--resume` flag for subsequent messages
- One-shot mode: uses `-p` flag for single task execution
- Buffer management: creates/updates readonly buffers with agent output

**VCS Abstraction** (`lua/autobahn/vcs/`):
- Auto-detects git or jujutsu
- Git backend: creates worktrees in `.autobahn/<branch>` using `git worktree add`
- JJ backend: creates workspaces using `jj workspace add`
- Both: cleanup removes workspace and deletes files

**Output Parser** (`lua/autobahn/agent/parser.lua`):
- Parses stream-json lines from agent stdout
- Extracts: session_id (for resume), total_cost_usd, message content, tool_use events
- Formats output for buffer display

## Session Modes

**One-shot** (default): Agent executes task with `-p` flag and exits. For single tasks.

**Interactive**: Agent runs continuously. After first response, extracts `claude_session_id`, then spawns new processes with `--resume <session_id>` for each message. Requires `output_format = "stream-json"`.

## Development Commands

No test suite or build commands currently exist.

## UI System

**Snacks Integration** (`lua/autobahn/ui/snacks.lua`):
- Two-pane layout: main window (session list) + preview window (output)
- Main window created via `snacks.win({ style = "autobahn_history" })`
- Preview window created via `nvim_open_win` positioned adjacent to main window
- Style config in `config.snacks.styles.autobahn_history`
- Registered during integrations setup in `integrations/init.lua`
- Each session rendered as single line with extmarks for metadata (cost, duration, ID)
- Visual selection indicator: `▶` prefix on current line
- Preview updates on cursor movement: shows buffer_id content or output array
- Toggle preview pane with `p` key (stores state in `config.ui_show_preview`)
- Keymaps: j/k navigation, Enter view, d delete, m message, n new, p toggle preview, q close

**Legacy UI** (`lua/autobahn/ui/popup.lua`, `dashboard.lua`):
- Uses nui.nvim Popup and Split components
- Enabled by setting `ui = "nui"` in config
- Box-drawing borders with embedded session list

## Key Configuration

UI and agent config in `lua/autobahn/config.lua`:
```lua
ui = "snacks"  -- or "nui" for legacy
snacks = {
  styles = {
    autobahn_history = {
      border = "rounded",
      width = 0.7,
      height = 0.6,
      title = " Autobahn Sessions ",
      wo = { cursorline = true },
    }
  }
}
agents = {
  ["claude-code"] = {
    cmd = "claude",
    auto_accept = false,
    auto_accept_flag = "--dangerously-skip-permissions",
    max_cost_usd = 1.0,
    output_format = "stream-json",
  }
}
```

## Critical Implementation Details

**Two-Pane Layout** (`lua/autobahn/ui/snacks.lua`):
- Main window width: 0.9 (90% of editor) when preview enabled, 0.7 when disabled
- List pane: 40% of main window width
- Preview pane: remaining width (minus 1 for border)
- Preview positioned at `col = main_col + list_width + 1`
- Both windows closed via `close_all()` function
- BufLeave autocmd cleans up preview window
- Preview renders from `session.buffer_id` (if valid) or `session.output` array

**Interactive Session Resume Flow**:
1. First spawn: `claude -p "task" --output-format stream-json --verbose`
2. Parser extracts `session_id` from system message with `type: "system", subtype: "init"`
3. Stores as `session.claude_session_id`
4. Next message: `claude -p "new message" --resume <session_id> --output-format stream-json --verbose`
5. Continues indefinitely until session deleted

**Job Management**:
- Sessions store `job_id` from jobstart
- Must check `vim.fn.jobwait({job_id}, 0)[1] == -1` to verify still running
- Interactive sessions block new messages while job is running
- On exit: clears job_id, updates status, emits events

**Buffer Safety**:
- All buffer modifications wrapped in `modifiable = true` → modify → `modifiable = false`
- Buffers are `nofile` type with unique names: `autobahn://<session_id>`
- Reused across messages in interactive mode

**VCS Workspace Paths**:
- Git: `<repo_root>/.autobahn/<branch_name>`
- JJ: `<repo_root>/.autobahn/<workspace_name>`
- Agent spawns with `cwd = workspace_path`
