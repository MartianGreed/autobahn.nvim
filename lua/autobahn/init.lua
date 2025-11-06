--- Multi-agent coding session manager for Neovim
--- @module autobahn
local M = {}

local config = require("autobahn.config")
local session = require("autobahn.session")
local events = require("autobahn.events")

--- Setup autobahn with user configuration
--- @param opts table|nil Configuration options
--- @field default_agent string Default agent to use (default: "claude-code")
--- @field vcs string VCS type: "auto", "git", or "jj" (default: "auto")
--- @field dashboard_position string Dashboard position: "left", "right", "top", "bottom"
--- @field dashboard_size string Dashboard size (default: "30%")
--- @field persist boolean Persist sessions to disk (default: true)
--- @field restore_on_startup boolean Restore sessions on startup (default: false)
--- @field max_concurrent_sessions number Maximum concurrent sessions (default: 10)
--- @field agents table Agent configurations
function M.setup(opts)
  config.setup(opts)

  if config.get().restore_on_startup then
    session.load_state()
  end

  local integrations = require("autobahn.integrations")
  integrations.setup()
end

--- Create a new agent session
--- @param opts table Session options
--- @field task string Task description for the agent
--- @field branch string|nil Branch name for the workspace
--- @field agent_type string|nil Agent type to use (defaults to default_agent)
--- @field auto_accept boolean|nil Auto-accept agent suggestions
--- @field interactive boolean|nil Enable interactive mode
--- @field start_immediately boolean|nil Start agent immediately (default: true)
--- @return table|nil session Session object or nil on failure
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
    interactive = opts.interactive,
    plan_mode = opts.plan_mode,
  })

  events.emit(events.EventType.SESSION_CREATED, new_session)

  if opts.start_immediately ~= false then
    agent.start(new_session.id, opts.task)
  end

  return new_session
end

--- Delete a session and clean up resources
--- @param session_id string Session identifier
--- @return boolean success True if session was deleted
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

--- View session output in a buffer
--- @param session_id string Session identifier
function M.view_session(session_id)
  local ui = require("autobahn.ui")
  ui.show_session_output(session_id)
end

--- Show the dashboard UI
function M.show_dashboard()
  local config = require("autobahn.config")
  local ui_type = config.get().ui or "snacks"

  if ui_type == "snacks" then
    local snacks_ui = require("autobahn.ui.snacks")
    snacks_ui.show_all()
  else
    local popup = require("autobahn.ui.popup")
    popup.show_all()
  end
end

--- Show all sessions
function M.show()
  M.show_dashboard()
end

--- Show the old split dashboard UI
function M.show_dashboard_split()
  local ui = require("autobahn.ui")
  ui.show_dashboard()
end

--- Show last session
function M.show_last()
  local config = require("autobahn.config")
  local ui_type = config.get().ui or "snacks"

  if ui_type == "snacks" then
    local snacks_ui = require("autobahn.ui.snacks")
    snacks_ui.show_last()
  else
    local popup = require("autobahn.ui.popup")
    popup.show_last()
  end
end

--- Show running sessions
function M.show_running()
  local config = require("autobahn.config")
  local ui_type = config.get().ui or "snacks"

  if ui_type == "snacks" then
    local snacks_ui = require("autobahn.ui.snacks")
    snacks_ui.show_running()
  else
    local popup = require("autobahn.ui.popup")
    popup.show_running()
  end
end

--- Show error sessions
function M.show_errors()
  local config = require("autobahn.config")
  local ui_type = config.get().ui or "snacks"

  if ui_type == "snacks" then
    local snacks_ui = require("autobahn.ui.snacks")
    snacks_ui.show_errors()
  else
    local popup = require("autobahn.ui.popup")
    popup.show_errors()
  end
end

--- List all sessions
--- @return table sessions Dictionary of session_id -> session
function M.list_sessions()
  return session.get_all()
end

--- Restore sessions from disk
--- @return boolean success True if sessions were restored
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

--- Send a message to an interactive session
--- @param session_id string Session identifier
--- @param message string Message to send
--- @return boolean success True if message was sent
function M.send_message(session_id, message)
  local agent = require("autobahn.agent")
  return agent.send_message(session_id, message)
end

--- Prompt user for a message and send to interactive session
--- @param session_id string Session identifier
function M.send_message_interactive(session_id)
  local input_ui = require("autobahn.ui.input")
  input_ui.prompt_message(session_id, function(message)
    M.send_message(session_id, message)
  end)
end

return M
