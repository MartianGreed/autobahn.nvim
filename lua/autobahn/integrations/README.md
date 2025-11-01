# Integrations Module

Optional integrations with popular Neovim plugins.

## Architecture

```
integrations/
├── init.lua       # Integration manager
├── telescope.lua  # Telescope integration
└── worktree.lua   # git-worktree.nvim integration
```

## Telescope Integration

Enhanced session picker with fuzzy search.

### Features

- Fuzzy search sessions by ID or task
- Session status indicators
- Delete sessions with `<C-d>`
- Opens session output on `<Enter>`
- Auto-refreshes after deletion

### Usage

```lua
-- Via Telescope command
:Telescope autobahn sessions

-- Programmatically
require("telescope").extensions.autobahn.sessions()

-- Direct access
require("autobahn.integrations.telescope").sessions_picker()
```

### Keybindings

- `<Enter>` - View session output
- `<C-d>` - Delete selected session (and refresh picker)
- Standard Telescope navigation keys

### Display Format

```
[running] session_1 - Fix authentication bug
[completed] session_2 - Add tests
[idle] session_3 - Refactor code
```

## git-worktree.nvim Integration

Synchronization with git-worktree.nvim for worktree management.

### Features

Listens to worktree operations and emits autobahn events:

- `worktree_created` - When new worktree is created
- `worktree_deleted` - When worktree is removed
- `worktree_switched` - When switching between worktrees

### Event Data

**worktree_created:**
```lua
{
  path = "/path/to/worktree",
  branch = "feature/branch"
}
```

**worktree_deleted:**
```lua
{
  path = "/path/to/worktree"
}
```

**worktree_switched:**
```lua
{
  path = "/path/to/worktree",
  prev_path = "/path/to/prev/worktree"
}
```

### Usage

Integration is automatic when git-worktree.nvim is installed. You can listen to events:

```lua
local events = require("autobahn.events")

events.on("worktree_created", function(data)
  print("Worktree created:", data.path)
end)
```

## Integration Manager (`init.lua`)

Automatically detects and sets up available integrations.

### Setup Process

Called during `autobahn.setup()`:

1. Check if Telescope is available
2. Load Telescope extension if available
3. Check if git-worktree.nvim is available
4. Register worktree callbacks if available

### Manual Integration Check

```lua
local integrations = require("autobahn.integrations")

-- Check availability
if integrations.telescope.is_available() then
  print("Telescope is available")
end

if integrations.worktree.is_available() then
  print("git-worktree.nvim is available")
end

-- Setup manually
integrations.telescope.setup()
integrations.worktree.setup()
```

## Dependencies

### Optional

- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Fuzzy finder
- [git-worktree.nvim](https://github.com/ThePrimeagen/git-worktree.nvim) - Git worktree management

## Adding Custom Integrations

Create a new file in `integrations/`:

```lua
-- integrations/myplugin.lua
local M = {}

function M.is_available()
  return pcall(require, "myplugin")
end

function M.setup()
  if not M.is_available() then
    return
  end

  -- Setup integration
end

return M
```

Register in `integrations/init.lua`:

```lua
M.myplugin = require("autobahn.integrations.myplugin")

function M.setup()
  -- ...
  if M.myplugin.is_available() then
    M.myplugin.setup()
  end
end
```
