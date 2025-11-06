local M = {}

function M.is_available()
  local result = vim.fn.system({ "jj", "--version" })
  return vim.v.shell_error == 0
end

function M.is_repo(path)
  path = path or vim.fn.getcwd()
  local result = vim.fn.systemlist({ "jj", "-R", path, "status" })
  return vim.v.shell_error == 0
end

function M.get_root(path)
  path = path or vim.fn.getcwd()
  local result = vim.fn.systemlist({ "jj", "-R", path, "root" })
  if vim.v.shell_error == 0 and #result > 0 then
    return vim.trim(result[1])
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

  if vim.fn.isdirectory(workspace_path) == 1 then
    local existing = vim.fn.system({ "jj", "workspace", "list" })
    if existing:match(vim.pesc(workspace_path)) then
      return workspace_path
    end
  end

  local rev = opts.rev or "@"

  vim.fn.mkdir(vim.fn.fnamemodify(workspace_path, ":h"), "p")

  local result = vim.fn.system({
    "jj",
    "workspace",
    "add",
    workspace_path,
    "--revision",
    rev,
  })

  if vim.v.shell_error ~= 0 then
    if result:match("already exists") or result:match("Workspace already exists") then
      return workspace_path
    end
    vim.notify(
      string.format("Failed to create jj workspace: %s", vim.trim(result)),
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

  local result = vim.fn.system({ "jj", "workspace", "forget", workspace_path })

  if vim.v.shell_error ~= 0 then
    vim.notify(
      string.format("Failed to forget jj workspace: %s", vim.trim(result)),
      vim.log.levels.WARN
    )
  end

  vim.fn.delete(workspace_path, "rf")

  return true
end

function M.list_workspaces()
  local result = vim.fn.system({ "jj", "workspace", "list" })

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
  local result = vim.fn.system({ "jj", "bookmark", "list" })

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
