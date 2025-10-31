local M = {}

M.telescope = require("autobahn.integrations.telescope")
M.worktree = require("autobahn.integrations.worktree")

function M.setup()
  if M.telescope.is_available() then
    M.telescope.setup()
  end

  if M.worktree.is_available() then
    M.worktree.setup()
  end
end

return M
