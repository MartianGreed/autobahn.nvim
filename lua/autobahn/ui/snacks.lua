local M = {}
local session = require("autobahn.session")

local function format_duration(timestamp)
	local duration = os.time() - timestamp
	if duration < 60 then
		return string.format("%ds ago", duration)
	elseif duration < 3600 then
		return string.format("%dm ago", math.floor(duration / 60))
	elseif duration < 86400 then
		return string.format("%dh ago", math.floor(duration / 3600))
	else
		return string.format("%dd ago", math.floor(duration / 86400))
	end
end

local function get_status_icon(status)
	return ({
		idle = "",
		running = "󰑮",
		completed = "",
		error = "",
		paused = "",
	})[status] or "?"
end

local function get_status_hl(status)
	return ({
		idle = "DiagnosticHint",
		running = "DiagnosticInfo",
		completed = "DiagnosticOk",
		error = "DiagnosticError",
		paused = "DiagnosticWarn",
	})[status] or "Normal"
end

function M.show_history(opts)
	opts = opts or {}

	local ok, snacks = pcall(require, "snacks")
	if not ok then
		vim.notify("snacks.nvim not installed", vim.log.levels.ERROR)
		return
	end

	local sessions = session.get_all()
	local items = {}

	for id, s in pairs(sessions) do
		local passes_filter = not opts.filter or opts.filter(s)
		if passes_filter then
			local status_icon = get_status_icon(s.status)
			local mode_icon = s.interactive and "󰊢" or "󱕘"
			local task_text = s.task or "No task description"
			local cost_text = string.format("$%.3f", s.cost_usd or 0)
			local duration_text = format_duration(s.created_at)
			local id_short = s.id:sub(9)

			local text = string.format("%s %s %s", status_icon, mode_icon, task_text)
			local detail = string.format("%s • %s • %s", cost_text, duration_text, id_short)

			-- Generate preview content
			local preview_lines = {}
			if s.buffer_id and vim.api.nvim_buf_is_valid(s.buffer_id) then
				preview_lines = vim.api.nvim_buf_get_lines(s.buffer_id, 0, -1, false)
			elseif s.output and #s.output > 0 then
				preview_lines = s.output
			else
				preview_lines = {
					"",
					string.format("Session: %s", s.id),
					string.format("Status: %s", s.status),
					string.format("Task: %s", s.task or "N/A"),
					string.format("Branch: %s", s.branch or "N/A"),
					string.format("Cost: $%.3f", s.cost_usd or 0),
					string.format("Created: %s", format_duration(s.created_at)),
					"",
					"No output yet...",
				}
			end

			table.insert(items, {
				idx = #items + 1,
				text = text,
				detail = detail,
				score = 0,
				session_id = id,
				session = s,
				preview = {
					text = table.concat(preview_lines, "\n"),
					ft = "markdown",
				},
			})
		end
	end

	table.sort(items, function(a, b)
		return a.session.created_at > b.session.created_at
	end)

	for i, item in ipairs(items) do
		item.idx = i
	end

	if #items == 0 then
		vim.notify("No sessions found", vim.log.levels.WARN)
		return
	end

	-- local config_opts = require("autobahn.config").get()
	-- local show_preview = config_opts.ui_show_preview ~= false

	local picker = snacks.picker.pick({
		items = items,
		prompt = " Autobahn Sessions ",
		format = function(item)
			return {
				{ item.text, get_status_hl(item.session.status) },
				{ " " .. item.detail, "Comment" },
			}
		end,
		-- Preview with live buffer support
		preview = function(ctx)
			local item = ctx.item
			if not item or not item.session then
				ctx.preview:set_lines({ "No session" })
				return
			end

			local s = item.session

			local metadata_lines = {
				string.format(
					"Status: %s | Cost: $%.3f | Duration: %s",
					s.status,
					s.cost_usd or 0,
					format_duration(s.created_at)
				),
				string.rep("─", 80),
				"",
			}

			-- If session has a live buffer, display it with metadata header
			if s.buffer_id and vim.api.nvim_buf_is_valid(s.buffer_id) then
				local buffer_lines = vim.api.nvim_buf_get_lines(s.buffer_id, 0, -1, false)
				local all_lines = vim.list_extend(metadata_lines, buffer_lines)
				ctx.preview:set_lines(all_lines)
				vim.schedule(function()
					if ctx.preview.buf and vim.api.nvim_buf_is_valid(ctx.preview.buf) then
						vim.api.nvim_buf_set_option(ctx.preview.buf, "filetype", "markdown")
					end
				end)
				return
			end

			-- Fallback: create a temporary buffer with stored output
			local lines = {}
			if s.output and #s.output > 0 then
				lines = s.output
			else
				lines = {
					"",
					string.format("Session: %s", s.id),
					string.format("Task: %s", s.task or "N/A"),
					string.format("Branch: %s", s.branch or "N/A"),
					"",
					"No output yet...",
				}
			end

			-- Prepend metadata and set lines in preview buffer
			local all_lines = vim.list_extend(metadata_lines, lines)
			ctx.preview:set_lines(all_lines)

			-- Set filetype for syntax highlighting
			vim.schedule(function()
				if ctx.preview.buf and vim.api.nvim_buf_is_valid(ctx.preview.buf) then
					vim.api.nvim_buf_set_option(ctx.preview.buf, "filetype", "markdown")
				end
			end)
		end,
		confirm = function(picker, item)
			if item and item.session_id then
				picker:close()
				vim.schedule(function()
					require("autobahn").view_session(item.session_id)
				end)
			end
		end,
		actions = {
			send_message = function(picker, item)
				if not item then
					vim.notify("No session selected", vim.log.levels.WARN)
					return
				end

				if not item.session_id then
					vim.notify("Invalid session", vim.log.levels.ERROR)
					return
				end

				local s = item.session
				if not s.interactive then
					vim.notify("Session is not in interactive mode", vim.log.levels.WARN)
					return
				end

				snacks.input({
					prompt = string.format("Message to %s %s:", s.task or s.id:sub(9), s.plan_mode and "[Plan]" or "[Build]"),
					completion = "file",
					highlight = function(text)
						-- Highlight @file references in blue
						local highlights = {}
						for match_start, match_end in text:gmatch("()@[%w/.-_]+()") do
							table.insert(highlights, {
								match_start - 1, -- 0-indexed start
								match_end - 1, -- 0-indexed end
								"Special", -- highlight group
							})
						end
						-- Highlight /plan and /build prefixes in yellow
						if text:match("^/plan%s") or text:match("^/build%s") then
							local space_pos = text:find("%s")
							if space_pos then
								table.insert(highlights, {
									0,
									space_pos - 1,
									"WarningMsg",
								})
							end
						end
						return highlights
					end,
				}, function(message)
					if message and message ~= "" then
						local override_mode = nil
						local cleaned_message = message

						if message:match("^/plan%s") then
							override_mode = true
							cleaned_message = message:gsub("^/plan%s+", "")
						elseif message:match("^/build%s") then
							override_mode = false
							cleaned_message = message:gsub("^/build%s+", "")
						end

						if override_mode ~= nil and override_mode ~= s.plan_mode then
							require("autobahn.session").update(item.session_id, { plan_mode = override_mode })
							vim.notify(
								string.format(
									"Switched to %s mode for this message",
									override_mode and "plan" or "build"
								),
								vim.log.levels.INFO
							)
						end

						require("autobahn").send_message(item.session_id, cleaned_message)
						vim.notify(
							string.format("Message sent to session %s", item.session_id:sub(9)),
							vim.log.levels.INFO
						)
					end
				end)
			end,
			new_session = function(picker, item)
				picker:close()
				vim.schedule(function()
					require("autobahn.ui").show_new_session_form()
				end)
			end,
			delete_session = function(picker, item)
				if not item or not item.session_id then
					vim.notify("No session to delete", vim.log.levels.WARN)
					return
				end

				-- Confirm deletion
				vim.ui.select({ "Yes", "No" }, {
					prompt = string.format("Delete session '%s'?", item.session.task or item.session_id),
				}, function(choice)
					if choice == "Yes" then
						require("autobahn").delete_session(item.session_id)
						picker:close()
						vim.defer_fn(function()
							M.show_history(opts)
						end, 100)
					end
				end)
			end,
		},
		win = {
			input = {
				keys = {
					["n"] = { "new_session", mode = { "n" } },
					["m"] = { "send_message", mode = { "n" } },
					["d"] = { "delete_session", mode = { "n" } },
					["<C-r>"] = { "reload", mode = { "i", "n" } },
				},
			},
			list = {
				footer = function()
					return {
						{ " <CR> ", "Special" },
						{ "View ", "Comment" },
						{ " d ", "Special" },
						{ "Delete ", "Comment" },
						{ " m ", "Special" },
						{ "Message ", "Comment" },
						{ " n ", "Special" },
						{ "New ", "Comment" },
						{ " q ", "Special" },
						{ "Close ", "Comment" },
					}
				end,
			},
		},
	})
end

function M.show_all()
	M.show_history()
end

function M.show_last()
	local sessions = session.get_all()
	local latest = nil
	local latest_time = 0

	for _, s in pairs(sessions) do
		if s.updated_at > latest_time then
			latest = s
			latest_time = s.updated_at
		end
	end

	if not latest then
		vim.notify("No sessions found", vim.log.levels.WARN)
		return
	end

	require("autobahn").view_session(latest.id)
end

function M.show_running()
	M.show_history({
		filter = function(s)
			return s.status == "running"
		end,
	})
end

function M.show_errors()
	M.show_history({
		filter = function(s)
			return s.status == "error"
		end,
	})
end

return M
