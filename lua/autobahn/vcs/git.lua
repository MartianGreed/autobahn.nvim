local M = {}

function M.is_available()
  local result = vim.fn.system("git --version")
  return vim.v.shell_error == 0
end

function M.is_repo(path)
  path = path or vim.fn.getcwd()
  local result = vim.fn.system(string.format("cd '%s' && git rev-parse --git-dir 2>/dev/null", path))
  return vim.v.shell_error == 0
end

function M.get_root(path)
  path = path or vim.fn.getcwd()
  local result = vim.fn.system(string.format("cd '%s' && git rev-parse --show-toplevel 2>/dev/null", path))
  if vim.v.shell_error == 0 then
    return vim.trim(result)
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

  local cmd = string.format(
    "git worktree add '%s' -b '%s' 2>&1",
    workspace_path,
    branch_name
  )

  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify(
      string.format("Failed to create git worktree: %s", result),
      vim.log.levels.ERROR
    )
    return nil
  end

  return workspace_path
end

function M.remove_workspace(workspace_path)
  if not workspace_path or workspace_path == "" then
    return false
  end

  local cmd = string.format("git worktree remove '%s' --force 2>&1", workspace_path)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify(
      string.format("Failed to remove git worktree: %s", result),
      vim.log.levels.WARN
    )
    return false
  end

  return true
end

function M.list_workspaces()
  local cmd = "git worktree list --porcelain"
  local result = vim.fn.system(cmd)

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
  local cmd = "git branch -a --format='%(refname:short)'"
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return {}
  end

  local branches = {}
  for branch in result:gmatch("[^\r\n]+") do
    table.insert(branches, branch)
  end

  return branches
end

return M
