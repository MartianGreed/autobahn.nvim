# VCS Module

Version control system abstraction layer that supports both Git and Jujutsu (jj).

## Architecture

```
vcs/
├── init.lua    # VCS abstraction interface
├── git.lua     # Git worktree backend
└── jj.lua      # Jujutsu workspace backend
```

## Usage

```lua
local vcs = require("autobahn.vcs")

-- Auto-detect VCS type
local vcs_type = vcs.detect()  -- Returns "git", "jj", or nil

-- Create isolated workspace
local workspace_path = vcs.create_workspace({
  branch = "feature/my-task",
})

-- Remove workspace
vcs.remove_workspace(workspace_path)

-- List all workspaces
local workspaces = vcs.list_workspaces()

-- Get all branches
local branches = vcs.get_branches()

-- Get repository root
local root = vcs.get_root()
```

## Backend Interface

Each backend (`git.lua`, `jj.lua`) implements:

### `is_available() -> boolean`
Check if VCS command is available on the system.

### `is_repo(path) -> boolean`
Check if path is a valid repository.

### `get_root(path) -> string|nil`
Get repository root path.

### `create_workspace(opts) -> string|nil`
Create an isolated workspace.

**Options:**
- `branch` (string, optional): Branch/bookmark name
- `rev` (string, optional, jj only): Revision to base workspace on

**Returns:** Workspace path or nil on failure

### `remove_workspace(workspace_path) -> boolean`
Remove a workspace and clean up.

### `list_workspaces() -> table`
List all workspaces/worktrees.

**Returns:** Array of `{ path: string, branch?: string }`

### `get_branches() -> table`
Get all branches/bookmarks.

**Returns:** Array of branch names

## Git Backend

Uses `git worktree` for workspace isolation:

- Creates worktrees in `.autobahn/<branch-name>`
- Automatically creates new branches
- Uses `git worktree add` and `git worktree remove`
- Supports force removal of modified worktrees

## Jujutsu Backend

Uses `jj workspace` for workspace isolation:

- Creates workspaces in `.autobahn/<workspace-name>`
- Uses `jj workspace add` and `jj workspace forget`
- Supports revision-based workspace creation
- Manually cleans up workspace directories

## Configuration

VCS type is configured in the main autobahn setup:

```lua
require("autobahn").setup({
  vcs = "auto",  -- "auto", "git", or "jj"
})
```

When set to `"auto"`, the module detects the VCS type by checking for:
1. Jujutsu repository (if `jj status` succeeds)
2. Git repository (if `git rev-parse` succeeds)
