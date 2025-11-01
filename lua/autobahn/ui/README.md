# UI Module

User interface components built with nui.nvim for managing agent sessions.

## Architecture

```
ui/
├── init.lua       # UI interface
├── dashboard.lua  # Session dashboard view
├── form.lua       # New session creation form
└── input.lua      # Message input prompt
```

## Usage

```lua
local ui = require("autobahn.ui")

-- Show dashboard
ui.show_dashboard()

-- Hide dashboard
ui.hide_dashboard()

-- Toggle dashboard
ui.toggle_dashboard()

-- Show new session form
ui.show_new_session_form()

-- View session output
ui.show_session_output(session_id)
```

## Dashboard (`dashboard.lua`)

Interactive session management interface.

### Layout

```
╭─ Autobahn Sessions ─────────────────────────────╮
│                                                  │
│ ● session_1  Fix authentication bug  $0.12  5m  │
│ ✓ session_2  Add tests               $0.08  1h  │
│ ○ session_3  Refactor code           $0.00  2h  │
│                                                  │
├──────────────────────────────────────────────────┤
│ <Enter> View | d Delete | n New | r Refresh     │
│ m Message    | q Quit                           │
╰──────────────────────────────────────────────────╯
```

### Status Icons
- `○` - Idle
- `●` - Running
- `✓` - Completed
- `✗` - Error
- `⏸` - Paused

### Keybindings
- `<Enter>` - View session output
- `d` - Delete selected session
- `n` - Create new session
- `m` - Send message to interactive session
- `r` - Refresh dashboard
- `q` - Close dashboard

### Features
- Auto-refresh on session events
- Sorted by creation time (newest first)
- Shows task preview, cost, and age
- Cursor navigation to select sessions

## New Session Form (`form.lua`)

Multi-step form for creating agent sessions.

### Flow

1. **Task Description**: Prompt for task
2. **Branch Selection**: Choose branch (Telescope or menu)
3. **Auto-accept**: Enable/disable auto-accept
4. **Session Mode**: One-shot or Interactive

### Branch Selection

Uses Telescope if available, falls back to nui.nvim menu:

**With Telescope:**
- Fuzzy search branches
- Preview branch info
- Default keybindings

**Without Telescope:**
- Scrollable menu
- `<Esc>` or `q` to cancel

### VCS Detection

Automatically detects repository type:
- Checks for jj repository first
- Falls back to git
- Shows error if no VCS detected

## Input Prompt (`input.lua`)

Simple input prompt for sending messages to interactive sessions.

### Usage

```lua
local input = require("autobahn.ui.input")

input.prompt_message(session_id, function(message)
  -- Handle message
end)
```

### Features
- Centered modal input
- 80 characters wide
- `<Esc>` to cancel
- Validates non-empty input

## Session Output View (`init.lua`)

Displays agent output in split window.

### Behavior
- Opens in vertical split
- Reuses existing window if already open
- Shows read-only buffer
- Auto-scrolls to latest output

### Buffer Format
See `agent/README.md` for output buffer format details.

## Configuration

Dashboard appearance is configured in main setup:

```lua
require("autobahn").setup({
  dashboard_position = "right",  -- "left", "right", "top", "bottom"
  dashboard_size = "30%",        -- Percentage or absolute value
})
```

## Dependencies

- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) - UI components
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Optional, for enhanced pickers

## Event Integration

Dashboard subscribes to events and auto-refreshes:

- `SESSION_CREATED` - New session added
- `SESSION_DELETED` - Session removed
- `STATUS_CHANGED` - Session status updated
- `SESSION_COMPLETED` - Session finished
- `SESSION_ERROR` - Session failed
