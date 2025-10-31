local M = {}

local config = require("autobahn.config")
local session = require("autobahn.session")
local events = require("autobahn.events")

function M.setup(opts)
  config.setup(opts)

  if config.get().restore_on_startup then
    session.load_state()
  end

  local integrations = require("autobahn.integrations")
  integrations.setup()
end

function M.create_session(opts)
  local vcs = require("autobahn.vcs")
  local agent = require("autobahn.agent")

  local workspace_path = vcs.create_workspace(opts)
  if not workspace_path then
    vim.notify("Failed to create workspace", vim.log.levels.ERROR)
    return nil
  end

  local new_session = session.create({
    agent_type = opts.agent_type or config.get().default_agent,
    workspace_path = workspace_path,
    task = opts.task,
    branch = opts.branch,
    auto_accept = opts.auto_accept,
  })

  events.emit(events.EventType.SESSION_CREATED, new_session)

  if opts.start_immediately ~= false then
    agent.start(new_session.id, opts.task)
  end

  return new_session
end

function M.delete_session(session_id)
  local s = session.get(session_id)
  if not s then
    vim.notify("Session not found", vim.log.levels.ERROR)
    return false
  end

  local agent = require("autobahn.agent")
  local vcs = require("autobahn.vcs")

  if s.job_id then
    agent.stop(session_id)
  end

  if s.workspace_path then
    vcs.remove_workspace(s.workspace_path)
  end

  session.delete(session_id)
  session.save_state()
  events.emit(events.EventType.SESSION_DELETED, { id = session_id })

  return true
end

function M.view_session(session_id)
  local ui = require("autobahn.ui")
  ui.show_session_output(session_id)
end

function M.show_dashboard()
  local ui = require("autobahn.ui")
  ui.show_dashboard()
end

function M.list_sessions()
  return session.get_all()
end

function M.restore_sessions()
  if session.load_state() then
    vim.notify(
      string.format("Restored %d sessions", vim.tbl_count(session.get_all())),
      vim.log.levels.INFO
    )
    return true
  end
  vim.notify("No saved sessions found", vim.log.levels.WARN)
  return false
end

return M
