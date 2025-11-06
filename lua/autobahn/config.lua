--- Configuration management
--- @module autobahn.config
local M = {}

--- Default configuration
M.defaults = {
  default_agent = "claude-code",
  vcs = "auto",
  dashboard_position = "right",
  dashboard_size = "30%",
  persist = true,
  restore_on_startup = false,
  max_concurrent_sessions = 10,
  ui = "snacks",
  ui_show_preview = true,
  debug = false,
  debug_file_name = ".autobahn-debug.json",
  snacks = {
    styles = {
      autobahn_history = {
        border = "rounded",
        zindex = 100,
        width = 0.7,
        height = 0.6,
        minimal = false,
        title = " Autobahn Sessions ",
        title_pos = "center",
        ft = "autobahn",
        wo = {
          winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
          cursorline = true,
        },
        bo = {
          filetype = "autobahn",
          modifiable = false,
        },
        keys = {
          q = "close",
        },
      },
    },
  },
  agents = {
    ["claude-code"] = {
      cmd = "claude",
      auto_accept = false,
      auto_accept_flag = "--dangerously-skip-permissions",
      max_cost_usd = 1.0,
      output_format = "stream-json",
      interactive = false,
    },
    ["opencode"] = {
      cmd = "opencode",
      auto_accept = false,
      auto_accept_flag = "--dangerously-skip-permissions",
      max_cost_usd = 1.0,
      output_format = "stream-json",
      interactive = false,
    },
    ["codex"] = {
      cmd = "codex",
      auto_accept = false,
      auto_accept_flag = "--dangerously-skip-permissions",
      max_cost_usd = 1.0,
      output_format = "stream-json",
      interactive = false,
    },
  },
}

M.options = {}

--- Setup configuration with user options
--- @param opts table|nil User configuration options
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

--- Get current configuration
--- @return table config Current configuration
function M.get()
  return M.options
end

--- Get agent configuration by name
--- @param agent_name string Agent name
--- @return table|nil agent_config Agent configuration or nil
function M.get_agent_config(agent_name)
  return M.options.agents[agent_name]
end

return M
