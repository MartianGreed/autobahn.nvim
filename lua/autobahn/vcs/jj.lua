local M = {}

function M.is_available()
  local result = vim.fn.system("jj --version")
  return vim.v.shell_error == 0
end

function M.is_repo(path)
  path = path or vim.fn.getcwd()
  local result = vim.fn.system(string.format("cd '%s' && jj status 2>/dev/null", path))
  return vim.v.shell_error == 0
end

function M.get_root(path)
  path = path or vim.fn.getcwd()
  local result = vim.fn.system(string.format("cd '%s' && jj root 2>/dev/null", path))
  if vim.v.shell_error == 0 then
    return vim.trim(result)
  end
  return nil
end

function M.create_workspace(opts)
  local root = M.get_root()
  if not root then
    vim.notify("Not a jj repository", vim.log.levels.ERROR)
    return nil
  end

  local workspace_name = opts.branch or ("autobahn-" .. os.date("%Y%m%d-%H%M%S"))
  local workspace_path = root .. "/.autobahn/" .. workspace_name

  local rev = opts.rev or "@"
  local message = opts.task or "Autobahn agent workspace"

  local cmd = string.format(
    "jj workspace add '%s' --revision '%s' 2>&1",
    workspace_path,
    rev
  )

  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify(
      string.format("Failed to create jj workspace: %s", result),
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

  local cmd = string.format("jj workspace forget '%s' 2>&1", workspace_path)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify(
      string.format("Failed to forget jj workspace: %s", result),
      vim.log.levels.WARN
    )
  end

  vim.fn.system(string.format("rm -rf '%s'", workspace_path))

  return true
end

function M.list_workspaces()
  local cmd = "jj workspace list"
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return {}
  end

  local workspaces = {}

  for line in result:gmatch("[^\r\n]+") do
    local path = line:match("^(.+):")
    if path then
      table.insert(workspaces, { path = vim.trim(path) })
    end
  end

  return workspaces
end

function M.get_branches()
  local cmd = "jj bookmark list"
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return {}
  end

  local branches = {}
  for line in result:gmatch("[^\r\n]+") do
    local branch = line:match("^(%S+):")
    if branch then
      table.insert(branches, branch)
    end
  end

  return branches
end

return M
