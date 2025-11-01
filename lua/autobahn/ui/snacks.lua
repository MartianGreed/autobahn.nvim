local M = {}
local session = require("autobahn.session")

local ns = vim.api.nvim_create_namespace("autobahn_sessions")

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

local function render_session_item(buf, line_num, session_data, is_selected)
  local s = session_data.session

  local status_icon = get_status_icon(s.status)
  local mode_icon = s.interactive and "󰊢" or "󱕘"
  local task_text = s.task or "No task description"

  if #task_text > 45 then
    task_text = task_text:sub(1, 42) .. "..."
  end

  local cost_text = string.format("$%.3f", s.cost_usd or 0)
  local duration_text = format_duration(s.created_at)
  local id_short = s.id:sub(9)

  local prefix = is_selected and "▶ " or "  "
  local line_text = string.format("%s%s %s %s", prefix, status_icon, mode_icon, task_text)

  vim.api.nvim_buf_set_lines(buf, line_num, line_num + 1, false, { line_text })

  local status_hl = get_status_hl(s.status)
  vim.api.nvim_buf_add_highlight(buf, ns, status_hl, line_num, 0, -1)

  local virt_text = {
    { " ", "Normal" },
    { cost_text, "Number" },
    { " • ", "Comment" },
    { duration_text, "Comment" },
    { " • ", "Comment" },
    { id_short, "Comment" },
  }

  vim.api.nvim_buf_set_extmark(buf, ns, line_num, 0, {
    virt_text = virt_text,
    virt_text_pos = "eol",
  })
end

local function get_filtered_sessions(filter_opts)
  local sessions = session.get_all()
  local session_list = {}

  for id, s in pairs(sessions) do
    if not filter_opts or not filter_opts.filter or filter_opts.filter(s) then
      table.insert(session_list, { id = id, session = s })
    end
  end

  table.sort(session_list, function(a, b)
    return a.session.created_at > b.session.created_at
  end)

  return session_list
end

local function render_preview(preview_buf, session_data)
  if not session_data then
    vim.api.nvim_buf_set_option(preview_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, {
      "",
      "  No session selected",
      "",
    })
    vim.api.nvim_buf_set_option(preview_buf, "modifiable", false)
    return
  end

  local s = session_data.session
  vim.api.nvim_buf_set_option(preview_buf, "modifiable", true)

  if s.buffer_id and vim.api.nvim_buf_is_valid(s.buffer_id) then
    local lines = vim.api.nvim_buf_get_lines(s.buffer_id, 0, -1, false)
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
  elseif s.output and #s.output > 0 then
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, s.output)
  else
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, {
      "",
      string.format("  Session: %s", s.id),
      string.format("  Status: %s", s.status),
      string.format("  Task: %s", s.task or "N/A"),
      string.format("  Branch: %s", s.branch or "N/A"),
      string.format("  Cost: $%.3f", s.cost_usd or 0),
      string.format("  Created: %s", format_duration(s.created_at)),
      "",
      "  No output yet...",
      "",
    })
  end

  vim.api.nvim_buf_set_option(preview_buf, "modifiable", false)
end

function M.show_history(opts)
  opts = opts or {}

  local ok, snacks = pcall(require, "snacks")
  if not ok then
    vim.notify("snacks.nvim not installed", vim.log.levels.ERROR)
    return
  end

  local session_list = get_filtered_sessions(opts)

  local list_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(list_buf, "modifiable", true)
  vim.api.nvim_buf_set_option(list_buf, "filetype", "autobahn")
  vim.api.nvim_buf_set_option(list_buf, "bufhidden", "wipe")

  local preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(preview_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(preview_buf, "filetype", "autobahn-preview")
  vim.api.nvim_buf_set_option(preview_buf, "bufhidden", "wipe")

  local config_opts = require("autobahn.config").get()
  local show_preview = config_opts.ui_show_preview ~= false

  local wins = {
    list = snacks.win({
      buf = list_buf,
      title = " Autobahn Sessions ",
      title_pos = "center",
      border = "rounded",
      show = false,
      wo = {
        cursorline = true,
      },
    }),
  }

  local layout_box

  if show_preview then
    wins.preview = snacks.win({
      buf = preview_buf,
      title = " Session Output ",
      title_pos = "center",
      border = "rounded",
      show = false,
      wo = {
        wrap = true,
      },
    })

    layout_box = {
      box = "horizontal",
      { win = "list", width = 0.45 },
      { win = "preview" },
    }
  else
    layout_box = {
      box = "vertical",
      { win = "list" },
    }
  end

  local layout = snacks.layout.new({
    backdrop = false,
    width = show_preview and 0.9 or 0.7,
    height = 0.8,
    wins = wins,
    layout = layout_box,
  })

  if #session_list == 0 then
    local empty_lines = {
      "",
      "  No sessions found",
      "",
      "  Press 'n' to create a new session",
      "",
    }
    vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, empty_lines)
    for i = 0, #empty_lines - 1 do
      vim.api.nvim_buf_add_highlight(list_buf, ns, "Comment", i, 0, -1)
    end
  else
    for i, item in ipairs(session_list) do
      render_session_item(list_buf, i - 1, item, i == 1)
    end
  end

  vim.api.nvim_buf_set_option(list_buf, "modifiable", false)

  if show_preview then
    if #session_list > 0 then
      render_preview(preview_buf, session_list[1])
    else
      render_preview(preview_buf, nil)
    end
  end

  local current_line = 0

  local function get_current_session()
    if #session_list == 0 then
      return nil, nil, nil
    end
    local wins = layout:windows()
    local list_win = wins.list
    if not list_win or not vim.api.nvim_win_is_valid(list_win.win) then
      return nil, nil, nil
    end
    local line = vim.api.nvim_win_get_cursor(list_win.win)[1]
    if line > 0 and line <= #session_list then
      return session_list[line].id, session_list[line].session, session_list[line]
    end
    return nil, nil, nil
  end

  local function update_selection()
    if #session_list == 0 then
      return
    end
    local wins = layout:windows()
    local list_win = wins.list
    if not list_win or not vim.api.nvim_win_is_valid(list_win.win) then
      return
    end

    local new_line = vim.api.nvim_win_get_cursor(list_win.win)[1] - 1
    if new_line ~= current_line then
      vim.api.nvim_buf_set_option(list_buf, "modifiable", true)

      if current_line >= 0 and current_line < #session_list then
        render_session_item(list_buf, current_line, session_list[current_line + 1], false)
      end

      if new_line >= 0 and new_line < #session_list then
        render_session_item(list_buf, new_line, session_list[new_line + 1], true)

        if show_preview then
          render_preview(preview_buf, session_list[new_line + 1])
        end
      end

      vim.api.nvim_buf_set_option(list_buf, "modifiable", false)
      current_line = new_line
    end
  end

  local function close_all()
    layout:close()
  end

  vim.keymap.set("n", "<CR>", function()
    local session_id, _ = get_current_session()
    if session_id then
      close_all()
      require("autobahn").view_session(session_id)
    end
  end, { buffer = list_buf, silent = true })

  vim.keymap.set("n", "d", function()
    local session_id, _ = get_current_session()
    if session_id then
      require("autobahn").delete_session(session_id)
      close_all()
      vim.defer_fn(function()
        M.show_history(opts)
      end, 50)
    end
  end, { buffer = list_buf, silent = true })

  vim.keymap.set("n", "m", function()
    local session_id, sess = get_current_session()
    if session_id and sess and sess.interactive then
      close_all()
      require("autobahn").send_message_interactive(session_id)
    elseif session_id then
      vim.notify("Session is not in interactive mode", vim.log.levels.WARN)
    end
  end, { buffer = list_buf, silent = true })

  vim.keymap.set("n", "n", function()
    close_all()
    vim.schedule(function()
      require("autobahn.ui").show_new_session_form()
    end)
  end, { buffer = list_buf, silent = true })

  vim.keymap.set("n", "q", function()
    close_all()
  end, { buffer = list_buf, silent = true })

  vim.keymap.set("n", "j", function()
    vim.cmd("normal! j")
    update_selection()
  end, { buffer = list_buf, silent = true })

  vim.keymap.set("n", "k", function()
    vim.cmd("normal! k")
    update_selection()
  end, { buffer = list_buf, silent = true })

  vim.keymap.set("n", "p", function()
    local new_show_preview = not show_preview
    local config = require("autobahn.config")
    config.get().ui_show_preview = new_show_preview
    close_all()
    vim.defer_fn(function()
      M.show_history(opts)
    end, 50)
  end, { buffer = list_buf, silent = true })

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = list_buf,
    callback = update_selection,
  })

  layout:show()

  if #session_list > 0 then
    local wins = layout:windows()
    local list_win = wins.list
    if list_win and vim.api.nvim_win_is_valid(list_win.win) then
      vim.api.nvim_win_set_cursor(list_win.win, { 1, 0 })
    end
  end
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
