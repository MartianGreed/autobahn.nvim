if vim.g.loaded_autobahn then
  return
end
vim.g.loaded_autobahn = true

vim.api.nvim_create_user_command("AutobahnDashboard", function()
  require("autobahn").show_dashboard()
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
