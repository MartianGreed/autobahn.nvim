# autobahn.nvim

Multi-agent coding session manager for Neovim. Run multiple coding agents in isolated workspaces and manage them from within Neovim.

## Features

- **Workspace Isolation**: Each agent runs in a separate git worktree or jj workspace
- **Multi-VCS Support**: Auto-detects and supports both git and jujutsu
- **Session Management**: Create, view, delete, and restore agent sessions
- **Real-time Monitoring**: Stream agent output in dedicated buffers
- **Cost Tracking**: Track API costs per session
- **Configurable Autonomy**: Run agents with or without auto-accept
- **Optional Integrations**: Enhanced UI with Telescope and git-worktree.nvim

## Requirements

- Neovim >= 0.9.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [snacks.nvim](https://github.com/folke/snacks.nvim) - Modern UI framework (dashboard, pickers)
- Git or Jujutsu (jj) installed
- Claude Code CLI (or other supported agent)

### Optional Dependencies

- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) - Legacy dashboard UI (if using `ui = "nui"`)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Enhanced pickers
- [git-worktree.nvim](https://github.com/ThePrimeagen/git-worktree.nvim) - Worktree integration

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-name/autobahn.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
    -- Optional
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim",
    "ThePrimeagen/git-worktree.nvim",
  },
  config = function()
    require("autobahn").setup({
      default_agent = "claude-code",
      vcs = "auto",
      ui = "snacks",
      persist = true,
      restore_on_startup = false,
      max_concurrent_sessions = 10,
      agents = {
        ["claude-code"] = {
          cmd = "claude",
          auto_accept = false,
          max_cost_usd = 1.0,
          output_format = "stream-json",
        },
      },
    })
  end,
  keys = {
    { "<leader>a", "<cmd>Autobahn<cr>", desc = "Autobahn Sessions" },
    { "<leader>ad", "<cmd>AutobahnDashboard<cr>", desc = "Autobahn Dashboard" },
    { "<leader>al", "<cmd>Autobahn last<cr>", desc = "Last Session" },
    { "<leader>ar", "<cmd>Autobahn running<cr>", desc = "Running Sessions" },
    { "<leader>ae", "<cmd>Autobahn errors<cr>", desc = "Error Sessions" },
    { "<leader>an", "<cmd>AutobahnNew<cr>", desc = "New Session" },
  },
}
```

## Usage

### UI Modes

**Snacks UI** (default):
- Modern interface powered by [snacks.nvim](https://github.com/folke/snacks.nvim)
- Built-in fuzzy filtering by task, branch, or ID
- Live preview of session output as you navigate
- Rich metadata display (cost, duration, session ID)
- Integrated picker for session creation (branch selection, mode, auto-accept)
- Customizable actions: view, delete, send message, new session
- Filter views: all, last, running, errors
- Access with `:Autobahn` or `:AutobahnDashboard`

**Legacy UI** (optional):
- Set `ui = "nui"` in config to use the legacy nui.nvim-based popup
- Requires [nui.nvim](https://github.com/MunifTanjim/nui.nvim) dependency

**Split Dashboard** (legacy):
- Traditional split view for persistent session monitoring
- Access with `:AutobahnDashboardSplit`

### Session Modes

**One-shot Mode** (default):
- Agent executes the task and exits
- Uses `-p` flag for non-interactive execution
- Fast and efficient for single tasks
- Session completes when task is done

**Interactive Mode**:
- Agent stays running after initial response
- Allows continuous conversation via `m` key or `:AutobahnSend`
- Uses stream-json input/output for real-time communication
- Session stays active until manually stopped
- Perfect for iterative development and back-and-forth discussions

### Commands

**Main Commands:**
- `:Autobahn` or `:Autobahn all` - Show all sessions in a popup
- `:Autobahn last` - Show the most recent session
- `:Autobahn running` - Show only running sessions
- `:Autobahn errors` - Show only failed sessions
- `:AutobahnDashboard` - Show all sessions (same as `:Autobahn`)

**Other Commands:**
- `:AutobahnNew` - Create a new agent session
- `:AutobahnSend [session_id]` - Send a message to an interactive session
- `:AutobahnDashboardSplit` - Open the split dashboard (legacy view)
- `:AutobahnRestore` - Restore saved sessions from disk
- `:AutobahnClear` - Clear all saved session state

### Dashboard Keybindings

The Snacks UI (`:Autobahn`/`:AutobahnDashboard`) supports:

- Type to filter sessions by task, branch, or ID (fuzzy matching)
- `j`/`k` or `<Up>`/`<Down>` - Navigate sessions (updates preview in real-time)
- `<Enter>` - View session output in full window
- `d` - Delete session and refresh
- `m` - Send message to session (interactive sessions only)
- `n` - New session
- `<Esc>` or `q` - Close

The split dashboard (`:AutobahnDashboardSplit`) supports:

- `<Enter>` - View session output
- `d` - Delete session
- `n` - New session
- `m` - Send message to session
- `r` - Refresh
- `q` - Close

### Telescope Integration

If Telescope is installed, you can use:

```vim
:Telescope autobahn sessions
```

Or in Lua:

```lua
require("telescope").extensions.autobahn.sessions()
```

### Programmatic API

```lua
local autobahn = require("autobahn")

-- Create a one-shot session
local session = autobahn.create_session({
  task = "Implement user authentication",
  branch = "feature/auth",
  auto_accept = false,
  interactive = false,
  start_immediately = true,
})

-- Create an interactive session
local interactive_session = autobahn.create_session({
  task = "Help me refactor this code",
  branch = "feature/refactor",
  auto_accept = false,
  interactive = true,
  start_immediately = true,
})

-- Send messages to interactive sessions
autobahn.send_message(interactive_session.id, "Can you also add error handling?")

-- Or use the interactive prompt
autobahn.send_message_interactive(interactive_session.id)

-- View session output
autobahn.view_session(session.id)

-- Delete session
autobahn.delete_session(session.id)

-- List all sessions
local sessions = autobahn.list_sessions()

-- Restore sessions from disk
autobahn.restore_sessions()
```

## Configuration

### Default Configuration

```lua
{
  default_agent = "claude-code",
  vcs = "auto",  -- "auto", "git", or "jj"
  ui = "snacks",  -- "snacks" or "nui" (legacy)
  ui_show_preview = true,  -- Show preview pane in snacks UI
  dashboard_position = "right",  -- "left", "right", "top", "bottom" (split dashboard only)
  dashboard_size = "30%",  -- Split dashboard size
  persist = true,
  restore_on_startup = false,
  max_concurrent_sessions = 10,
  snacks = {
    styles = {
      autobahn_history = {
        border = "rounded",
        width = 0.7,  -- Width when preview is disabled
        height = 0.6,
        title = " Autobahn Sessions ",
        title_pos = "center",
        wo = {
          cursorline = true,
        },
      },
    },
  },
  agents = {
    ["claude-code"] = {
      cmd = "claude",
      auto_accept = false,
      auto_accept_flag = "--dangerously-skip-permissions",
      max_cost_usd = 1.0,
      output_format = "stream-json",
    },
  },
}
```

### Adding Custom Agents

```lua
require("autobahn").setup({
  agents = {
    ["aider"] = {
      cmd = "aider",
      auto_accept = true,
      auto_accept_flag = "--yes",  -- Aider uses --yes for auto-accept
      max_cost_usd = 0.5,
    },
    ["custom-agent"] = {
      cmd = "/path/to/custom-agent",
      auto_accept = false,
      auto_accept_flag = { "--auto", "--no-confirm" },  -- Can be a table for multiple flags
      max_cost_usd = 2.0,
    },
  },
})
```

#### Agent Configuration Options

- `cmd` (string, required): Command to execute the agent
- `auto_accept` (boolean, default: false): Whether to auto-accept by default for this agent
- `auto_accept_flag` (string or table): Flag(s) to pass when auto_accept is enabled
  - String: Single flag (e.g., `"--yes"`)
  - Table: Multiple flags (e.g., `{ "--auto", "--no-confirm" }`)
  - If not specified, defaults to `"--dangerously-skip-permissions"`
- `max_cost_usd` (number): Maximum cost limit per session
- `output_format` (string): Output format for the agent (e.g., `"stream-json"`)

### UI Customization

**Snacks UI**:

Customize the session history window through the `snacks.styles.autobahn_history` config:

```lua
require("autobahn").setup({
  ui_show_preview = true,  -- Enable/disable preview pane (toggle with 'p')
  snacks = {
    styles = {
      autobahn_history = {
        border = "rounded",  -- Border style
        width = 0.8,  -- Width (0-1 for percentage, >1 for absolute)
        height = 0.7,  -- Height (0-1 for percentage, >1 for absolute)
        title = " My Sessions ",
        title_pos = "center",  -- "left", "center", "right"
        wo = {
          cursorline = true,
          winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
        },
      },
    },
  },
})
```

**Legacy UI**:

To use the original nui.nvim-based UI, set `ui = "nui"`:

```lua
require("autobahn").setup({
  ui = "nui",
})
```

## How It Works

1. **Session Creation**: When you create a new session, autobahn:
   - Creates a new git worktree or jj workspace in `.autobahn/<branch-name>`
   - Spawns the agent process in that workspace
   - Creates a buffer to stream the agent's output

2. **Process Management**: Agents run as job processes with stdout/stderr captured and parsed

3. **State Persistence**: Session state is saved to `~/.local/share/nvim/autobahn-sessions.json`

4. **Cleanup**: When you delete a session, autobahn:
   - Stops the agent process if running
   - Removes the git worktree or jj workspace
   - Cleans up buffers and state

## Architecture

```
autobahn.nvim/
├── lua/autobahn/
│   ├── init.lua              # Main API
│   ├── config.lua            # Configuration
│   ├── session.lua           # Session state management
│   ├── events.lua            # Event system
│   ├── vcs/
│   │   ├── init.lua          # VCS abstraction
│   │   ├── git.lua           # Git worktree backend
│   │   └── jj.lua            # JJ workspace backend
│   ├── agent/
│   │   ├── init.lua          # Agent interface
│   │   ├── process.lua       # Process management
│   │   └── parser.lua        # Output parsing
│   ├── ui/
│   │   ├── init.lua          # UI interface
│   │   ├── dashboard.lua     # Dashboard view
│   │   └── form.lua          # Session creation form
│   └── integrations/
│       ├── init.lua          # Integration manager
│       ├── telescope.lua     # Telescope integration
│       └── worktree.lua      # git-worktree.nvim integration
└── plugin/
    └── autobahn.lua          # Auto-loading commands
```

## Inspiration

- [claude-squad](https://github.com/smtg-ai/claude-squad) - Multi-agent coordination CLI
- [conductor.build](https://conductor.build/) - Agent orchestration platform

## License

MIT
