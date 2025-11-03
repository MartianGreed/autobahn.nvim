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

	local ok, Snacks = pcall(require, "snacks")
	if not ok then
		vim.notify("snacks.nvim not installed", vim.log.levels.ERROR)
		return
	end

	local wins = vim.api.nvim_list_wins()
	for _, win in ipairs(wins) do
		if vim.api.nvim_win_get_buf(win) == session.buffer_id then
			vim.api.nvim_set_current_win(win)
			return
		end
	end

	vim.api.nvim_buf_set_option(session.buffer_id, "filetype", "markdown")
	Snacks.win({
		buf = session.buffer_id,
		border = "rounded",
		title = string.format(" %s ", session.task or session.id:sub(9)),
		title_pos = "center",
		width = 0.8,
		height = 0.8,
		wo = {
			wrap = true,
			number = false,
			relativenumber = false,
		},
		keys = {
			q = "close",
		},
	})
end

return M
