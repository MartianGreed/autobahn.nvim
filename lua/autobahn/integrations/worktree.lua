local M = {}

function M.is_available()
  local ok = pcall(require, "git-worktree")
  return ok
end

function M.setup()
  if not M.is_available() then
    return
  end

  local worktree = require("git-worktree")
  local events = require("autobahn.events")

  worktree.on_tree_change(function(op, metadata)
    if op == worktree.Operations.Create then
      events.emit("worktree_created", {
        path = metadata.path,
        branch = metadata.branch,
      })
    elseif op == worktree.Operations.Delete then
      events.emit("worktree_deleted", {
        path = metadata.path,
      })
    elseif op == worktree.Operations.Switch then
      events.emit("worktree_switched", {
        path = metadata.path,
        prev_path = metadata.prev_path,
      })
    end
  end)
end

return M
