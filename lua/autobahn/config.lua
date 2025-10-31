local M = {}

M.defaults = {
  default_agent = "claude-code",
  vcs = "auto",
  dashboard_position = "right",
  dashboard_size = "30%",
  persist = true,
  restore_on_startup = false,
  max_concurrent_sessions = 10,
  agents = {
    ["claude-code"] = {
      cmd = "claude",
      auto_accept = false,
      max_cost_usd = 1.0,
      output_format = "stream-json",
    },
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

function M.get()
  return M.options
end

function M.get_agent_config(agent_name)
  return M.options.agents[agent_name]
end

return M
