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
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- Git or Jujutsu (jj) installed
- Claude Code CLI (or other supported agent)

### Optional Dependencies

- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Enhanced pickers
- [git-worktree.nvim](https://github.com/ThePrimeagen/git-worktree.nvim) - Worktree integration

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-name/autobahn.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    -- Optional
    "nvim-telescope/telescope.nvim",
    "ThePrimeagen/git-worktree.nvim",
  },
  config = function()
    require("autobahn").setup({
      default_agent = "claude-code",
      vcs = "auto",
      dashboard_position = "right",
      dashboard_size = "30%",
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
    { "<leader>ad", "<cmd>AutobahnDashboard<cr>", desc = "Autobahn Dashboard" },
    { "<leader>an", "<cmd>AutobahnNew<cr>", desc = "New Autobahn Session" },
    { "<leader>ar", "<cmd>AutobahnRestore<cr>", desc = "Restore Autobahn Sessions" },
  },
}
```

## Usage

### Commands

- `:AutobahnDashboard` - Open the dashboard to view all sessions
- `:AutobahnNew` - Create a new agent session
- `:AutobahnRestore` - Restore saved sessions from disk
- `:AutobahnClear` - Clear all saved session state

### Dashboard Keybindings

- `<Enter>` - View session output
- `d` - Delete session
- `n` - New session
- `r` - Refresh dashboard
- `q` - Close dashboard

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

-- Create a session
local session = autobahn.create_session({
  task = "Implement user authentication",
  branch = "feature/auth",
  auto_accept = false,
  start_immediately = true,
})

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
  dashboard_position = "right",  -- "left", "right", "top", "bottom"
  dashboard_size = "30%",
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
}
```

### Adding Custom Agents

```lua
require("autobahn").setup({
  agents = {
    ["aider"] = {
      cmd = "aider",
      auto_accept = true,
      max_cost_usd = 0.5,
    },
    ["custom-agent"] = {
      cmd = "/path/to/custom-agent",
      auto_accept = false,
      max_cost_usd = 2.0,
    },
  },
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
