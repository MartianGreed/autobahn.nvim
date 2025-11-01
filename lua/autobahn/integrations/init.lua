local M = {}

M.telescope = require("autobahn.integrations.telescope")
M.worktree = require("autobahn.integrations.worktree")

local function setup_snacks()
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    return false
  end

  local config = require("autobahn.config")
  local snacks_config = config.get().snacks

  if snacks_config and snacks_config.styles then
    snacks.config.styles = vim.tbl_deep_extend(
      "force",
      snacks.config.styles or {},
      snacks_config.styles
    )
  end

  return true
end

function M.setup()
  setup_snacks()

  if M.telescope.is_available() then
    M.telescope.setup()
  end

  if M.worktree.is_available() then
    M.worktree.setup()
  end
end

return M
