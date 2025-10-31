local M = {}

local dashboard = require("autobahn.ui.dashboard")
local form = require("autobahn.ui.form")

function M.show_dashboard()
  dashboard.show()
end

function M.hide_dashboard()
  dashboard.hide()
end

function M.toggle_dashboard()
  dashboard.toggle()
end

function M.show_new_session_form()
  form.show()
end

function M.show_session_output(session_id)
  local session = require("autobahn.session").get(session_id)
  if not session then
    vim.notify("Session not found", vim.log.levels.ERROR)
    return
  end

  if not session.buffer_id or not vim.api.nvim_buf_is_valid(session.buffer_id) then
    vim.notify("No output buffer available", vim.log.levels.WARN)
    return
  end

  local wins = vim.api.nvim_list_wins()
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_get_buf(win) == session.buffer_id then
      vim.api.nvim_set_current_win(win)
      return
    end
  end

  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, session.buffer_id)
end

return M
