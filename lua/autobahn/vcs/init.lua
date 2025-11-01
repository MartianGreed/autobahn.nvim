--- VCS abstraction layer
--- @module autobahn.vcs
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

--- Create a new workspace
--- @param opts table Workspace options
--- @field branch string|nil Branch name
--- @return string|nil workspace_path Workspace path or nil on failure
function M.create_workspace(opts)
  local backend = get_backend()
  if not backend then
    return nil
  end

  return backend.create_workspace(opts)
end

--- Remove a workspace
--- @param workspace_path string Workspace path
--- @return boolean success True if workspace was removed
function M.remove_workspace(workspace_path)
  local backend = get_backend()
  if not backend then
    return false
  end

  return backend.remove_workspace(workspace_path)
end

--- List all workspaces
--- @return table workspaces List of workspace paths
function M.list_workspaces()
  local backend = get_backend()
  if not backend then
    return {}
  end

  return backend.list_workspaces()
end

--- Get all branches
--- @return table branches List of branch names
function M.get_branches()
  local backend = get_backend()
  if not backend then
    return {}
  end

  return backend.get_branches()
end

--- Get repository root
--- @return string|nil root Repository root path or nil
function M.get_root()
  local backend = get_backend()
  if not backend then
    return nil
  end

  return backend.get_root()
end

--- Detect VCS type
--- @return string|nil vcs_type "git", "jj", or nil
function M.detect()
  return detect_vcs()
end

return M
