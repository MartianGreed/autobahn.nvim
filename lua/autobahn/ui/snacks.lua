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

      table.insert(items, {
        idx = #items + 1,
        text = text,
        detail = detail,
        score = 0,
        session_id = id,
        session = s,
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

  local config_opts = require("autobahn.config").get()
  local show_preview = config_opts.ui_show_preview ~= false

  snacks.picker.pick({
    items = items,
    prompt = " Autobahn Sessions ",
    format = function(item)
      return {
        { item.text, get_status_hl(item.session.status) },
        { " " .. item.detail, "Comment" },
      }
    end,
    layout = {
      preview = show_preview,
    },
    preview = show_preview and function(item, ctx)
      if not item or not item.session then
        return {}
      end

      local s = item.session
      local lines = {}

      if s.buffer_id and vim.api.nvim_buf_is_valid(s.buffer_id) then
        lines = vim.api.nvim_buf_get_lines(s.buffer_id, 0, -1, false)
      elseif s.output and #s.output > 0 then
        lines = s.output
      else
        lines = {
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
        }
      end

      return {
        text = lines,
        ft = "autobahn-preview",
      }
    end or nil,
    confirm = function(picker, item)
      if item and item.session_id then
        picker:close()
        require("autobahn").view_session(item.session_id)
      end
    end,
    actions = {
      delete = function(picker, item)
        if item and item.session_id then
          require("autobahn").delete_session(item.session_id)
          picker:close()
          vim.defer_fn(function()
            M.show_history(opts)
          end, 50)
        end
      end,
      send_message = function(picker, item)
        if item and item.session_id and item.session and item.session.interactive then
          picker:close()
          require("autobahn").send_message_interactive(item.session_id)
        elseif item then
          vim.notify("Session is not in interactive mode", vim.log.levels.WARN)
        end
      end,
      new_session = function(picker)
        picker:close()
        vim.schedule(function()
          require("autobahn.ui").show_new_session_form()
        end)
      end,
    },
    keys = {
      d = "delete",
      m = "send_message",
      n = "new_session",
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
