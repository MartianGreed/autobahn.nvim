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

  parser.reset_state()

  local config = require("autobahn.config")
  local agent_config = config.get_agent_config(session.agent_type)

  if not agent_config then
    vim.notify(
      string.format("Agent config not found: %s", session.agent_type),
      vim.log.levels.ERROR
    )
    return nil
  end

  local interactive_mode = session.interactive or agent_config.interactive
  local args = { "-p", task }

  if interactive_mode and session.claude_session_id then
    table.insert(args, "--resume")
    table.insert(args, session.claude_session_id)
  end

  if agent_config.output_format then
    table.insert(args, "--output-format")
    table.insert(args, agent_config.output_format)

    if agent_config.output_format == "stream-json" then
      table.insert(args, "--verbose")
    end
  end

  if session.auto_accept or agent_config.auto_accept then
    if agent_config.auto_accept_flag then
      if type(agent_config.auto_accept_flag) == "table" then
        for _, flag in ipairs(agent_config.auto_accept_flag) do
          table.insert(args, flag)
        end
      else
        table.insert(args, agent_config.auto_accept_flag)
      end
    else
      table.insert(args, "--dangerously-skip-permissions")
    end
  end

  local buffer_id = session.buffer_id

  if not buffer_id or not vim.api.nvim_buf_is_valid(buffer_id) then
    buffer_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buffer_id, "modifiable", false)
    vim.api.nvim_buf_set_option(buffer_id, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buffer_id, "filetype", "markdown")
    vim.api.nvim_buf_set_name(buffer_id, string.format("autobahn://%s", session_id))
  end

  local output_lines = session.output or {}
  local message_start_time = os.time()
  local last_cost = session.last_cost or 0

  if not session.buffer_id or not vim.api.nvim_buf_is_valid(session.buffer_id) then
    local startup_lines = parser.format_session_header(session)
    table.insert(startup_lines, "")
    table.insert(startup_lines, string.format("**Initial Task:** %s", task))
    table.insert(startup_lines, "")

    vim.api.nvim_buf_set_option(buffer_id, "modifiable", true)
    vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, startup_lines)
    vim.api.nvim_buf_set_option(buffer_id, "modifiable", false)

    vim.list_extend(output_lines, startup_lines)
  else
    local user_message_lines = parser.format_user_message(task, message_start_time)
    vim.api.nvim_buf_set_option(buffer_id, "modifiable", true)
    vim.api.nvim_buf_set_lines(buffer_id, -1, -1, false, user_message_lines)
    vim.api.nvim_buf_set_option(buffer_id, "modifiable", false)

    vim.list_extend(output_lines, user_message_lines)
  end

  local thinking_line_idx = nil
  local first_content_received = false

  local function append_to_buffer(lines)
    if #lines == 0 then
      return
    end

    local split_lines = {}
    for _, line in ipairs(lines) do
      for sub_line in (line .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(split_lines, sub_line)
      end
    end

    vim.schedule(function()
      vim.api.nvim_buf_set_option(buffer_id, "modifiable", true)

      if not first_content_received and thinking_line_idx then
        vim.api.nvim_buf_set_lines(buffer_id, thinking_line_idx, thinking_line_idx + 1, false, {})
        thinking_line_idx = nil
        first_content_received = true
      end

      vim.api.nvim_buf_set_lines(buffer_id, -1, -1, false, split_lines)
      vim.api.nvim_buf_set_option(buffer_id, "modifiable", false)
    end)
  end

  local thinking_placeholder = parser.format_thinking_placeholder()
  vim.api.nvim_buf_set_option(buffer_id, "modifiable", true)
  local current_line_count = vim.api.nvim_buf_line_count(buffer_id)
  vim.api.nvim_buf_set_lines(buffer_id, -1, -1, false, thinking_placeholder)
  thinking_line_idx = current_line_count
  vim.api.nvim_buf_set_option(buffer_id, "modifiable", false)
  vim.list_extend(output_lines, thinking_placeholder)

  local full_cmd = vim.list_extend({ agent_config.cmd }, args)

  local job_id = vim.fn.jobstart(full_cmd, {
    cwd = session.workspace_path,
    stdout_buffered = false,
    stderr_buffered = false,
    stdin = "null",
    pty = false,
    on_stdout = function(_, data, _)
      vim.schedule(function()
        for _, line in ipairs(data) do
          if line ~= "" then
            local parsed = parser.parse_stream_json(line)
            if parsed then
              if config.get().debug then
                local debug_file = session.workspace_path .. "/" .. config.get().debug_file_name
                local log_entry = vim.json.encode({
                  timestamp = os.date("%Y-%m-%dT%H:%M:%S"),
                  session_id = session_id,
                  type = parsed.type,
                  data = parsed
                })
                vim.fn.writefile({log_entry}, debug_file, "a")
              end

              if parsed.type == "system" and parsed.session_id then
                session_module.update(session_id, {
                  claude_session_id = parsed.session_id,
                })
              end

              local cost_delta = 0
              if parsed.total_cost_usd then
                cost_delta = parsed.total_cost_usd - last_cost
                last_cost = parsed.total_cost_usd
                session_module.update(session_id, {
                  cost_usd = parsed.total_cost_usd,
                  last_cost = last_cost,
                })
              end

              local response_time = os.time()
              local formatted = parser.format_output(parsed, session_id, response_time, cost_delta)
              if formatted then
                vim.list_extend(output_lines, formatted)
                append_to_buffer(formatted)
              end
            end
          end
        end
      end)
    end,
    on_stderr = function(_, data, _)
      vim.schedule(function()
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(output_lines, "[stderr] " .. line)
            append_to_buffer({ "[stderr] " .. line })
          end
        end
      end)
    end,
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        session_module.update(session_id, {
          status = exit_code == 0
              and session_module.SessionStatus.COMPLETED
            or session_module.SessionStatus.ERROR,
          job_id = nil,
        })

        local event_type = exit_code == 0 and events.EventType.SESSION_COMPLETED
          or events.EventType.SESSION_ERROR

        local last_lines = {}
        local start_idx = math.max(1, #output_lines - 3)
        for i = start_idx, #output_lines do
          table.insert(last_lines, output_lines[i])
        end

        events.emit(event_type, {
          id = session_id,
          exit_code = exit_code,
          last_output = last_lines,
        })

        if exit_code ~= 0 then
          vim.notify(
            string.format(
              "Session %s failed (code %d). Check output buffer for details.",
              session_id,
              exit_code
            ),
            vim.log.levels.ERROR
          )
        end

        session_module.save_state()
      end)
    end,
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
    interactive = interactive_mode,
  })

  events.emit(events.EventType.SESSION_STARTED, session)

  return job_id
end

function M.send_message(session_id, message)
  local session = session_module.get(session_id)
  if not session then
    vim.notify("Session not found", vim.log.levels.ERROR)
    return false
  end

  if not session.interactive then
    vim.notify("Session is not in interactive mode", vim.log.levels.ERROR)
    return false
  end

  if not session.claude_session_id then
    vim.notify(
      "Session hasn't initialized yet. Wait for first response.",
      vim.log.levels.WARN
    )
    return false
  end

  if session.job_id and M.is_running(session_id) then
    vim.notify(
      "Session is still processing. Wait for it to complete.",
      vim.log.levels.WARN
    )
    return false
  end

  return M.spawn(session_id, message)
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
