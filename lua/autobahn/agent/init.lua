local M = {}

local process = require("autobahn.agent.process")
local session = require("autobahn.session")

function M.start(session_id, task)
  local s = session.get(session_id)
  if not s then
    vim.notify("Session not found", vim.log.levels.ERROR)
    return false
  end

  if s.job_id and process.is_running(session_id) then
    vim.notify("Agent is already running", vim.log.levels.WARN)
    return false
  end

  local job_id = process.spawn(session_id, task or s.task)
  return job_id ~= nil
end

function M.stop(session_id)
  return process.stop(session_id)
end

function M.is_running(session_id)
  return process.is_running(session_id)
end

function M.restart(session_id, task)
  M.stop(session_id)
  vim.defer_fn(function()
    M.start(session_id, task)
  end, 100)
end

return M
