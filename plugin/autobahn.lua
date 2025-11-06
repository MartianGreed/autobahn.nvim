if vim.g.loaded_autobahn then
  return
end
vim.g.loaded_autobahn = true

vim.api.nvim_create_user_command("Autobahn", function(opts)
  local subcommand = opts.args
  if subcommand == "" or subcommand == "all" then
    require("autobahn").show()
  elseif subcommand == "last" then
    require("autobahn").show_last()
  elseif subcommand == "running" then
    require("autobahn").show_running()
  elseif subcommand == "errors" then
    require("autobahn").show_errors()
  else
    vim.notify("Unknown subcommand: " .. subcommand, vim.log.levels.ERROR)
  end
end, {
  nargs = "?",
  complete = function()
    return { "all", "last", "running", "errors" }
  end
})

vim.api.nvim_create_user_command("AutobahnDashboard", function()
  require("autobahn").show_dashboard()
end, {})

vim.api.nvim_create_user_command("AutobahnDashboardSplit", function()
  require("autobahn").show_dashboard_split()
end, {})

vim.api.nvim_create_user_command("AutobahnNew", function()
  require("autobahn.ui").show_new_session_form()
end, {})

vim.api.nvim_create_user_command("AutobahnRestore", function()
  require("autobahn").restore_sessions()
end, {})

vim.api.nvim_create_user_command("AutobahnClear", function()
  require("autobahn.session").clear_state()
  vim.notify("Cleared all session state", vim.log.levels.INFO)
end, {})

vim.api.nvim_create_user_command("AutobahnSend", function(opts)
  local session_id = opts.args
  if session_id == "" then
    local sessions = require("autobahn.session").get_all()
    local first_session = next(sessions)
    if first_session then
      session_id = first_session
    else
      vim.notify("No active sessions", vim.log.levels.WARN)
      return
    end
  end
  require("autobahn").send_message_interactive(session_id)
end, { nargs = "?" })

vim.api.nvim_create_user_command("AutobahnSetupHooks", function()
  require("autobahn.hooks").setup_project()
end, {})
