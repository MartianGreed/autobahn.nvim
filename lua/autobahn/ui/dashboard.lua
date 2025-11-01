local Split = require("nui.split")
local session = require("autobahn.session")
local events = require("autobahn.events")

local M = {}

local dashboard_split = nil

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

local function render_dashboard()
  if not dashboard_split or not dashboard_split.bufnr then
    return
  end

  local sessions = session.get_all()
  local lines = {
    "╭─ Autobahn Sessions ─────────────────────────────╮",
    "│                                                  │",
  }

  local session_list = {}
  for id, s in pairs(sessions) do
    table.insert(session_list, { id = id, session = s })
  end

  table.sort(session_list, function(a, b)
    return a.session.created_at > b.session.created_at
  end)

  if #session_list == 0 then
    table.insert(lines, "│  No sessions                                     │")
  else
    for _, item in ipairs(session_list) do
      local s = item.session
      local status_icon = ({
        idle = "○",
        running = "●",
        completed = "✓",
        error = "✗",
        paused = "⏸",
      })[s.status] or "?"

      local age = format_duration(s.created_at)
      local cost = string.format("$%.2f", s.cost_usd or 0)
      local task_preview = s.task:sub(1, 20)
      if #s.task > 20 then
        task_preview = task_preview .. "..."
      end

      local line = string.format(
        "│ %s %-8s %-23s %6s %5s │",
        status_icon,
        s.id:sub(9, 16),
        task_preview,
        cost,
        age
      )
      table.insert(lines, line)
    end
  end

  table.insert(lines, "│                                                  │")
  table.insert(lines, "├──────────────────────────────────────────────────┤")
  table.insert(lines, "│ <Enter> View | d Delete | n New | r Refresh     │")
  table.insert(lines, "│ m Message    | q Quit                           │")
  table.insert(lines, "╰──────────────────────────────────────────────────╯")

  vim.api.nvim_buf_set_option(dashboard_split.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(dashboard_split.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(dashboard_split.bufnr, "modifiable", false)
end

local function setup_keymaps()
  if not dashboard_split or not dashboard_split.bufnr then
    return
  end

  local function get_session_at_line()
    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    if line_num < 3 then
      return nil
    end

    local sessions = session.get_all()
    local session_list = {}
    for id, s in pairs(sessions) do
      table.insert(session_list, { id = id, session = s })
    end

    table.sort(session_list, function(a, b)
      return a.session.created_at > b.session.created_at
    end)

    local index = line_num - 2
    if index > 0 and index <= #session_list then
      return session_list[index].id
    end

    return nil
  end

  vim.keymap.set("n", "<CR>", function()
    local session_id = get_session_at_line()
    if session_id then
      require("autobahn.ui").show_session_output(session_id)
    end
  end, { buffer = dashboard_split.bufnr, silent = true })

  vim.keymap.set("n", "d", function()
    local session_id = get_session_at_line()
    if session_id then
      require("autobahn").delete_session(session_id)
      render_dashboard()
    end
  end, { buffer = dashboard_split.bufnr, silent = true })

  vim.keymap.set("n", "n", function()
    require("autobahn.ui").show_new_session_form()
  end, { buffer = dashboard_split.bufnr, silent = true })

  vim.keymap.set("n", "r", function()
    render_dashboard()
  end, { buffer = dashboard_split.bufnr, silent = true })

  vim.keymap.set("n", "m", function()
    local session_id = get_session_at_line()
    if session_id then
      require("autobahn").send_message_interactive(session_id)
    end
  end, { buffer = dashboard_split.bufnr, silent = true })

  vim.keymap.set("n", "q", function()
    if dashboard_split then
      dashboard_split:unmount()
      dashboard_split = nil
    end
  end, { buffer = dashboard_split.bufnr, silent = true })
end

function M.show()
  if dashboard_split then
    dashboard_split:mount()
    render_dashboard()
    return
  end

  local config = require("autobahn.config")
  local opts = config.get()

  dashboard_split = Split({
    relative = "editor",
    position = opts.dashboard_position,
    size = opts.dashboard_size,
    buf_options = {
      modifiable = false,
      readonly = true,
      filetype = "autobahn-dashboard",
    },
  })

  dashboard_split:mount()

  render_dashboard()
  setup_keymaps()

  events.on(events.EventType.SESSION_CREATED, function()
    render_dashboard()
  end)

  events.on(events.EventType.SESSION_DELETED, function()
    render_dashboard()
  end)

  events.on(events.EventType.STATUS_CHANGED, function()
    render_dashboard()
  end)

  events.on(events.EventType.SESSION_COMPLETED, function()
    render_dashboard()
  end)

  events.on(events.EventType.SESSION_ERROR, function()
    render_dashboard()
  end)
end

function M.hide()
  if dashboard_split then
    dashboard_split:unmount()
    dashboard_split = nil
  end
end

function M.toggle()
  if dashboard_split and dashboard_split.winid then
    M.hide()
  else
    M.show()
  end
end

return M
