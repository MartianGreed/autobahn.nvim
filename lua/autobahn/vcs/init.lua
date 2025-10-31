local M = {}

local backends = {
  git = require("autobahn.vcs.git"),
  jj = require("autobahn.vcs.jj"),
}

local function detect_vcs()
  if backends.jj.is_repo() then
    return "jj"
  elseif backends.git.is_repo() then
    return "git"
  end
  return nil
end

local function get_backend()
  local config = require("autobahn.config")
  local vcs_type = config.get().vcs

  if vcs_type == "auto" then
    vcs_type = detect_vcs()
  end

  if not vcs_type then
    vim.notify("No VCS detected (git or jj)", vim.log.levels.ERROR)
    return nil
  end

  local backend = backends[vcs_type]
  if not backend then
    vim.notify(string.format("Unknown VCS type: %s", vcs_type), vim.log.levels.ERROR)
    return nil
  end

  if not backend.is_available() then
    vim.notify(string.format("%s is not available", vcs_type), vim.log.levels.ERROR)
    return nil
  end

  return backend
end

function M.create_workspace(opts)
  local backend = get_backend()
  if not backend then
    return nil
  end

  return backend.create_workspace(opts)
end

function M.remove_workspace(workspace_path)
  local backend = get_backend()
  if not backend then
    return false
  end

  return backend.remove_workspace(workspace_path)
end

function M.list_workspaces()
  local backend = get_backend()
  if not backend then
    return {}
  end

  return backend.list_workspaces()
end

function M.get_branches()
  local backend = get_backend()
  if not backend then
    return {}
  end

  return backend.get_branches()
end

function M.get_root()
  local backend = get_backend()
  if not backend then
    return nil
  end

  return backend.get_root()
end

function M.detect()
  return detect_vcs()
end

return M
