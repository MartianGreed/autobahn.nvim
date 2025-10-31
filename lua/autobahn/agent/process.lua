local M = {}

local session_module = require("autobahn.session")
local events = require("autobahn.events")
local parser = require("autobahn.agent.parser")

function M.spawn(session_id, task)
  local session = session_module.get(session_id)
  if not session then
    vim.notify("Session not found", vim.log.levels.ERROR)
    return nil
  end

  local config = require("autobahn.config")
  local agent_config = config.get_agent_config(session.agent_type)

  if not agent_config then
    vim.notify(
      string.format("Agent config not found: %s", session.agent_type),
      vim.log.levels.ERROR
    )
    return nil
  end

  local args = { "-p", task }

  if agent_config.output_format then
    table.insert(args, "--output-format")
    table.insert(args, agent_config.output_format)
  end

  if session.auto_accept or agent_config.auto_accept then
    table.insert(args, "-y")
  end

  local buffer_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buffer_id, "modifiable", false)
  vim.api.nvim_buf_set_option(buffer_id, "buftype", "nofile")
  vim.api.nvim_buf_set_name(buffer_id, string.format("autobahn://%s", session_id))

  local output_lines = {}

  local function append_to_buffer(lines)
    if #lines == 0 then
      return
    end

    vim.schedule(function()
      vim.api.nvim_buf_set_option(buffer_id, "modifiable", true)
      vim.api.nvim_buf_set_lines(buffer_id, -1, -1, false, lines)
      vim.api.nvim_buf_set_option(buffer_id, "modifiable", false)
    end)
  end

  local job_id = vim.fn.jobstart({ agent_config.cmd, unpack(args) }, {
    cwd = session.workspace_path,
    on_stdout = vim.schedule_wrap(function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          local parsed = parser.parse_stream_json(line)
          if parsed then
            local formatted = parser.format_output(parsed)
            if formatted then
              vim.list_extend(output_lines, formatted)
              append_to_buffer(formatted)
            end

            if parsed.cost_usd then
              session_module.update(session_id, {
                cost_usd = (session.cost_usd or 0) + parsed.cost_usd,
              })
            end
          else
            table.insert(output_lines, line)
            append_to_buffer({ line })
          end
        end
      end
    end),
    on_stderr = vim.schedule_wrap(function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(output_lines, "[stderr] " .. line)
          append_to_buffer({ "[stderr] " .. line })
        end
      end
    end),
    on_exit = vim.schedule_wrap(function(_, exit_code, _)
      session_module.update(session_id, {
        status = exit_code == 0
            and session_module.SessionStatus.COMPLETED
          or session_module.SessionStatus.ERROR,
        job_id = nil,
      })

      local event_type = exit_code == 0 and events.EventType.SESSION_COMPLETED
        or events.EventType.SESSION_ERROR

      events.emit(event_type, { id = session_id, exit_code = exit_code })

      local status_line = string.format(
        "\n[%s] Exit code: %d",
        exit_code == 0 and "Completed" or "Error",
        exit_code
      )
      append_to_buffer({ status_line })

      session_module.save_state()
    end),
  })

  if job_id <= 0 then
    vim.notify("Failed to start agent process", vim.log.levels.ERROR)
    vim.api.nvim_buf_delete(buffer_id, { force = true })
    return nil
  end

  session_module.update(session_id, {
    job_id = job_id,
    buffer_id = buffer_id,
    status = session_module.SessionStatus.RUNNING,
    output = output_lines,
  })

  events.emit(events.EventType.SESSION_STARTED, session)

  return job_id
end

function M.stop(session_id)
  local session = session_module.get(session_id)
  if not session or not session.job_id then
    return false
  end

  vim.fn.jobstop(session.job_id)

  session_module.update(session_id, {
    status = session_module.SessionStatus.IDLE,
    job_id = nil,
  })

  events.emit(events.EventType.STATUS_CHANGED, session)

  return true
end

function M.is_running(session_id)
  local session = session_module.get(session_id)
  if not session or not session.job_id then
    return false
  end

  return vim.fn.jobwait({ session.job_id }, 0)[1] == -1
end

return M
