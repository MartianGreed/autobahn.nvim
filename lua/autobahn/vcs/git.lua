local M = {}

function M.is_available()
  local result = vim.fn.system({ "git", "--version" })
  return vim.v.shell_error == 0
end

function M.is_repo(path)
  path = path or vim.fn.getcwd()
  local result = vim.fn.systemlist({ "git", "-C", path, "rev-parse", "--git-dir" })
  return vim.v.shell_error == 0
end

function M.get_root(path)
  path = path or vim.fn.getcwd()
  local result = vim.fn.systemlist({ "git", "-C", path, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error == 0 and #result > 0 then
    return vim.trim(result[1])
  end
  return nil
end

function M.create_workspace(opts)
  local root = M.get_root()
  if not root then
    vim.notify("Not a git repository", vim.log.levels.ERROR)
    return nil
  end

  local branch_name = opts.branch or ("autobahn/" .. os.date("%Y%m%d-%H%M%S"))
  local workspace_path = root .. "/.autobahn/" .. branch_name

  if vim.fn.isdirectory(workspace_path) == 1 then
    local existing = vim.fn.system({ "git", "worktree", "list", "--porcelain" })
    if existing:match(vim.pesc(workspace_path)) then
      return workspace_path
    end
  end

  vim.fn.mkdir(vim.fn.fnamemodify(workspace_path, ":h"), "p")

  local result = vim.fn.system({
    "git",
    "worktree",
    "add",
    workspace_path,
    "-b",
    branch_name,
  })

  if vim.v.shell_error ~= 0 then
    if result:match("already exists") then
      return workspace_path
    end
    vim.notify(
      string.format("Failed to create git worktree: %s", vim.trim(result)),
      vim.log.levels.ERROR
    )
    return nil
  end

  local parent_claude_md = root .. "/CLAUDE.md"
  local parent_claude_dir = root .. "/.claude"

  if vim.fn.filereadable(parent_claude_md) == 1 then
    vim.fn.system({ "ln", "-sf", parent_claude_md, workspace_path .. "/CLAUDE.md" })
  end

  if vim.fn.isdirectory(parent_claude_dir) == 1 then
    vim.fn.system({ "ln", "-sf", parent_claude_dir, workspace_path .. "/.claude" })
  end

  return workspace_path
end

function M.remove_workspace(workspace_path)
  if not workspace_path or workspace_path == "" then
    return false
  end

  local result = vim.fn.system({ "git", "worktree", "remove", workspace_path, "--force" })

  if vim.v.shell_error ~= 0 then
    vim.notify(
      string.format("Failed to remove git worktree: %s", vim.trim(result)),
      vim.log.levels.WARN
    )
    return false
  end

  return true
end

function M.list_workspaces()
  local result = vim.fn.system({ "git", "worktree", "list", "--porcelain" })

  if vim.v.shell_error ~= 0 then
    return {}
  end

  local workspaces = {}
  local current = {}

  for line in result:gmatch("[^\r\n]+") do
    if line:match("^worktree ") then
      if current.path then
        table.insert(workspaces, current)
      end
      current = { path = line:match("^worktree (.+)") }
    elseif line:match("^branch ") then
      current.branch = line:match("^branch (.+)")
    end
  end

  if current.path then
    table.insert(workspaces, current)
  end

  return workspaces
end

function M.get_branches()
  local result = vim.fn.system({ "git", "branch", "-a", "--format=%(refname:short)" })

  if vim.v.shell_error ~= 0 then
    vim.notify(
      string.format("Git branch command failed: %s", vim.trim(result)),
      vim.log.levels.DEBUG
    )
    return {}
  end

  local branches = {}
  for branch in result:gmatch("[^\r\n]+") do
    local trimmed = vim.trim(branch)
    if trimmed ~= "" then
      table.insert(branches, trimmed)
    end
  end

  return branches
end

return M
