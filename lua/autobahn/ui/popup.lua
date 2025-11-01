local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local session = require("autobahn.session")

local M = {}

local function format_duration(timestamp)
  local duration = os.time() - timestamp
  if duration < 60 then
    return string.format("%ds", duration)
  elseif duration < 3600 then
    return string.format("%dm", math.floor(duration / 60))
  else
    return string.format("%dh", math.floor(duration / 3600))
  end
end

local function get_status_icon(status)
  return ({
    idle = " ",
    running = "󰑮 ",
    completed = " ",
    error = " ",
    paused = " ",
  })[status] or "? "
end

local function render_session_list(sessions, opts)
  opts = opts or {}
  local lines = {}
  local highlights = {}

  table.insert(lines, "╭─ Autobahn Sessions ─────────────────────────────────────────╮")

  local session_list = {}
  for id, s in pairs(sessions) do
    if not opts.filter or opts.filter(s) then
      table.insert(session_list, { id = id, session = s })
    end
  end

  table.sort(session_list, function(a, b)
    return a.session.created_at > b.session.created_at
  end)

  if #session_list == 0 then
    table.insert(lines, "│                                                              │")
    table.insert(lines, "│  No sessions found                                           │")
    table.insert(lines, "│                                                              │")
  else
    table.insert(lines, "│                                                              │")

    for _, item in ipairs(session_list) do
      local s = item.session
      local icon = get_status_icon(s.status)
      local age = format_duration(s.created_at)
      local cost = string.format("$%.3f", s.cost_usd or 0)

      local task_preview = s.task:sub(1, 35)
      if #s.task > 35 then
        task_preview = task_preview .. "..."
      end

      local mode_icon = s.interactive and "󰊢 " or "󱕘 "

      local line = string.format(
        "│ %s%s%-38s %6s %5s %s│",
        icon,
        mode_icon,
        task_preview,
        cost,
        age,
        s.status == "running" and "󰑮" or " "
      )

      table.insert(lines, line)

      local hl_group = ({
        idle = "Comment",
        running = "DiagnosticInfo",
        completed = "DiagnosticOk",
        error = "DiagnosticError",
        paused = "DiagnosticWarn",
      })[s.status] or "Normal"

      table.insert(highlights, { line = #lines, group = hl_group })
    end

    table.insert(lines, "│                                                              │")
  end

  table.insert(lines, "├──────────────────────────────────────────────────────────────┤")
  table.insert(lines, "│ <Enter> View │ d Delete │ m Message │ n New │ q Close       │")
  table.insert(lines, "╰──────────────────────────────────────────────────────────────╯")

  return lines, highlights, session_list
end

function M.show_all(opts)
  opts = opts or {}
  local sessions = session.get_all()

  local lines, highlights, session_list = render_session_list(sessions, opts)

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "none",
    },
    position = "50%",
    size = {
      width = "70%",
      height = math.min(#lines + 2, vim.o.lines - 10),
    },
    buf_options = {
      modifiable = false,
      readonly = true,
      filetype = "autobahn",
    },
  })

  popup:mount()

  vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", false)

  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(popup.bufnr, -1, hl.group, hl.line - 1, 0, -1)
  end

  local function get_session_at_cursor()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local session_index = cursor_line - 3
    if session_index > 0 and session_index <= #session_list then
      return session_list[session_index].id
    end
    return nil
  end

  popup:map("n", "<CR>", function()
    local session_id = get_session_at_cursor()
    if session_id then
      popup:unmount()
      require("autobahn").view_session(session_id)
    end
  end)

  popup:map("n", "d", function()
    local session_id = get_session_at_cursor()
    if session_id then
      require("autobahn").delete_session(session_id)
      popup:unmount()
      vim.defer_fn(function()
        M.show_all(opts)
      end, 50)
    end
  end)

  popup:map("n", "m", function()
    local session_id = get_session_at_cursor()
    if session_id then
      popup:unmount()
      require("autobahn").send_message_interactive(session_id)
    end
  end)

  popup:map("n", "n", function()
    popup:unmount()
    require("autobahn.ui").show_new_session_form()
  end)

  popup:map("n", "q", function()
    popup:unmount()
  end)

  popup:on(event.BufLeave, function()
    popup:unmount()
  end)
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
  M.show_all({
    filter = function(s)
      return s.status == "running"
    end
  })
end

function M.show_errors()
  M.show_all({
    filter = function(s)
      return s.status == "error"
    end
  })
end

return M
