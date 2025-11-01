--- Agent interface
--- @module autobahn.agent
local M = {}

local process = require("autobahn.agent.process")
local session = require("autobahn.session")

--- Start an agent for a session
--- @param session_id string Session identifier
--- @param task string|nil Task description
--- @return boolean success True if agent was started
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

--- Stop an agent
--- @param session_id string Session identifier
--- @return boolean success True if agent was stopped
function M.stop(session_id)
  return process.stop(session_id)
end

--- Check if agent is running
--- @param session_id string Session identifier
--- @return boolean running True if agent is running
function M.is_running(session_id)
  return process.is_running(session_id)
end

--- Restart an agent
--- @param session_id string Session identifier
--- @param task string|nil Task description
function M.restart(session_id, task)
  M.stop(session_id)
  vim.defer_fn(function()
    M.start(session_id, task)
  end, 100)
end

--- Send message to an interactive agent
--- @param session_id string Session identifier
--- @param message string Message to send
--- @return boolean success True if message was sent
function M.send_message(session_id, message)
  return process.send_message(session_id, message)
end

return M
